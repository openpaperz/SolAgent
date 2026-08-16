#!/usr/bin/env python3
"""Run Aderyn for the RQ2 Full vs. no-Slither-feedback comparison."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Tuple

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover
    load_dotenv = None


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from stats.ex_rq1_security_aderyn import (  # noqa: E402
    temporary_broken_symlink_fallbacks,
)
from stats.ex_rq1_security_mythril import (  # noqa: E402
    file_slug,
    model_slug,
    nearest_project_root,
    temporary_generated_file,
)
from stats.rq2_security_scan_utils import (  # noqa: E402
    DEFAULT_EVAL_REPORT,
    DEFAULT_SOURCES,
    SELECTION_POLICY,
    fetch_entries,
    load_eval_results,
    parse_csv,
    prepare_entry,
    solidity_sloc,
    temporary_missing_project_dependencies,
)
from stats.rq2_slither_feedback_statistics import TARGET_MODELS  # noqa: E402
from utils.aderyn_utils import (  # noqa: E402
    DEFAULT_ADERYN_TIMEOUT,
    count_vulnerabilities,
    get_sloc,
    get_vulnerability_summary,
    resolve_aderyn_bin,
    run_aderyn,
)


def print_flush(*args: Any, **kwargs: Any) -> None:
    kwargs.setdefault("flush", True)
    print(*args, **kwargs)


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False),
        encoding="utf-8",
    )


def sample_output_path(out_dir: Path, entry: Mapping[str, Any]) -> Path:
    filename = f"{int(entry['id']):04d}__{file_slug(str(entry['file_path']))}.json"
    return out_dir / str(entry["_source"]) / model_slug(str(entry["_model"])) / filename


def rq1_reuse_path(reuse_dir: Path, entry: Mapping[str, Any]) -> Path:
    filename = f"{int(entry['id']):04d}__{file_slug(str(entry['file_path']))}.json"
    return reuse_dir / "solagent" / model_slug(str(entry["_model"])) / filename


def base_record(
    entry: Mapping[str, Any],
    code_meta: Mapping[str, Any],
    tests: Mapping[str, int],
    eval_meta: Mapping[str, Any],
    slither: Mapping[str, Any],
    code: Optional[str],
) -> Dict[str, Any]:
    normalized_code_meta = dict(code_meta)
    normalized_code_meta["sloc"] = solidity_sloc(code) if code else None
    return {
        "source": entry["_source"],
        "source_name": (
            "SolAgent (Full)" if entry["_source"] == "full" else "w/o Slither feedback"
        ),
        "table": entry["_table"],
        "model": entry["_model"],
        "id": entry["id"],
        "file_path": entry["file_path"],
        "row_status": entry.get("status"),
        **tests,
        "test_source": "rq2_eval",
        "eval": dict(eval_meta),
        "code": normalized_code_meta,
        "slither": dict(slither),
        "scan_config": {
            "tool": "Aderyn",
            "foundry_profile": eval_meta.get("foundry_profile"),
            "source_dir": eval_meta.get("foundry_source_dir"),
        },
        "status": "pending",
        "aderyn": {},
        "created_at": datetime.now(timezone.utc).isoformat(),
    }


def cache_matches(
    record: Mapping[str, Any],
    code_meta: Mapping[str, Any],
    eval_meta: Mapping[str, Any],
) -> bool:
    cached = record.get("code")
    if not isinstance(cached, dict):
        return False
    keys = (
        "selection_policy",
        "best_round",
        "best_pass",
        "best_total",
        "best_vuln",
        "sha256",
        "skip_reason",
    )
    if not all(cached.get(key) == code_meta.get(key) for key in keys):
        return False
    if record.get("status") == "skipped":
        return True
    aderyn = record.get("aderyn")
    raw = aderyn.get("raw") if isinstance(aderyn, dict) else None
    cached_profile = raw.get("profile") if isinstance(raw, dict) else None
    expected_source = eval_meta.get("foundry_source_dir")
    cached_source = raw.get("source_dir") if isinstance(raw, dict) else None
    return (
        cached_profile == eval_meta.get("foundry_profile")
        and cached_source == expected_source
    )


def refresh_cached_record(
    record: Dict[str, Any],
    entry: Mapping[str, Any],
    code_meta: Mapping[str, Any],
    tests: Mapping[str, int],
    eval_meta: Mapping[str, Any],
    slither: Mapping[str, Any],
    code: Optional[str],
) -> Dict[str, Any]:
    refreshed = base_record(entry, code_meta, tests, eval_meta, slither, code)
    for key in (
        "status",
        "skip_reason",
        "aderyn",
        "scan_origin",
        "reused_from",
        "created_at",
    ):
        if key in record:
            refreshed[key] = record[key]
    aderyn = refreshed.get("aderyn")
    if isinstance(aderyn, dict) and refreshed["status"] == "analyzed":
        aderyn["sloc"] = refreshed["code"]["sloc"]
    refreshed["refreshed_at"] = datetime.now(timezone.utc).isoformat()
    return refreshed


def load_rq1_reuse(
    reuse_dir: Path,
    entry: Mapping[str, Any],
    code_meta: Mapping[str, Any],
    foundry_profile: Optional[str],
    source_dir: Optional[str],
) -> Optional[Tuple[Dict[str, Any], str]]:
    if entry["_source"] != "full" or not code_meta.get("sha256"):
        return None
    path = rq1_reuse_path(reuse_dir, entry)
    if not path.is_file():
        return None
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if record.get("status") != "analyzed":
        return None
    if (record.get("code") or {}).get("sha256") != code_meta["sha256"]:
        return None
    aderyn = record.get("aderyn")
    if not isinstance(aderyn, dict) or not isinstance(aderyn.get("count"), int):
        return None
    raw = aderyn.get("raw")
    if (
        not isinstance(raw, dict)
        or raw.get("profile") != foundry_profile
        or raw.get("source_dir") != source_dir
    ):
        return None
    return aderyn, str(path)


def analyze_record(
    record: Dict[str, Any],
    code: Optional[str],
    orig_repo: Path,
    current_repo: Path,
    aderyn_bin: str,
    timeout: int,
    foundry_profile: Optional[str],
) -> Dict[str, Any]:
    skip_reason = (record.get("code") or {}).get("skip_reason")
    if skip_reason:
        record["status"] = "skipped"
        record["skip_reason"] = skip_reason
        return record
    if not code:
        record["status"] = "skipped"
        record["skip_reason"] = "no generated code"
        return record

    sol_path = orig_repo / str(record["file_path"])
    try:
        project_root = nearest_project_root(sol_path)
        source_dir = (record.get("eval") or {}).get("foundry_source_dir")
        with temporary_generated_file(sol_path, code):
            with temporary_missing_project_dependencies(
                project_root, orig_repo, current_repo
            ):
                with temporary_broken_symlink_fallbacks(
                    project_root,
                    orig_repo=str(orig_repo),
                    cur_repo=str(current_repo),
                ):
                    raw = run_aderyn(
                        str(sol_path),
                        project_root=str(project_root),
                        aderyn_bin=aderyn_bin,
                        timeout=timeout,
                        foundry_profile=foundry_profile,
                        source_dir=source_dir,
                    )
    except Exception as exc:
        raw = {"error": f"Unexpected Aderyn runner failure: {exc}"}

    if "error" in raw:
        record["status"] = "error"
        record["aderyn"] = {"error": raw["error"], "raw": raw}
    else:
        code_sloc = (record.get("code") or {}).get("sloc")
        record["status"] = "analyzed"
        record["aderyn"] = {
            "count": count_vulnerabilities(raw),
            "summary": get_vulnerability_summary(raw),
            "sloc": code_sloc,
            "reported_sloc": get_sloc(raw),
            "raw": raw,
        }
        record["scan_origin"] = "rq2_scan"
    return record


def summarize_sample(record: Mapping[str, Any]) -> Dict[str, Any]:
    aderyn = record.get("aderyn") if isinstance(record.get("aderyn"), dict) else {}
    slither = record.get("slither") if isinstance(record.get("slither"), dict) else {}
    code = record.get("code") if isinstance(record.get("code"), dict) else {}
    return {
        "source": record["source"],
        "source_name": record["source_name"],
        "model": record["model"],
        "id": record["id"],
        "file_path": record["file_path"],
        "status": record["status"],
        "skip_reason": record.get("skip_reason"),
        "test_pass": record["test_pass"],
        "test_fail": record["test_fail"],
        "test_total": record["test_total"],
        "test_source": record.get("test_source"),
        "eval_compiled": (record.get("eval") or {}).get("compiled"),
        "eval_full_pass": (record.get("eval") or {}).get("full_pass"),
        "best_round": code.get("best_round"),
        "feedback_test_pass": code.get("best_pass"),
        "feedback_test_total": code.get("best_total"),
        "best_vuln": code.get("best_vuln"),
        "code_sha256": code.get("sha256"),
        "code_bytes": code.get("code_bytes"),
        "code_sloc": code.get("sloc"),
        "feedback_compiled": code.get("feedback_compiled"),
        "feedback_full_pass": bool(code.get("feedback_compiled"))
        and code.get("best_pass") == code.get("best_total"),
        "slither_count": slither.get("count"),
        "slither_summary": slither.get("summary"),
        "aderyn_count": aderyn.get("count"),
        "aderyn_summary": aderyn.get("summary") or {},
        "aderyn_sloc": aderyn.get("sloc"),
        "aderyn_error": aderyn.get("error"),
        "finding_count": aderyn.get("count"),
        "finding_summary": aderyn.get("summary") or {},
        "scan_error": aderyn.get("error"),
        "scan_origin": record.get("scan_origin"),
        "reused_from": record.get("reused_from"),
    }


def aggregate_group(
    records: List[Mapping[str, Any]], source: str, model: str
) -> Dict[str, Any]:
    group = [
        record
        for record in records
        if record["source"] == source and record["model"] == model
    ]
    compiled = [record for record in group if int(record.get("test_total") or 0) > 0]
    analyzed = [record for record in compiled if record.get("status") == "analyzed"]
    full_pass = [
        record
        for record in compiled
        if int(record.get("test_pass") or 0) == int(record.get("test_total") or 0)
    ]
    safe_full_pass = [
        record
        for record in full_pass
        if record.get("status") == "analyzed"
        and (record.get("aderyn") or {}).get("count") == 0
    ]
    findings = sum(
        int((record.get("aderyn") or {}).get("count") or 0) for record in analyzed
    )
    sloc = sum(
        int((record.get("aderyn") or {}).get("sloc") or 0) for record in analyzed
    )
    severity = {"High": 0, "Low": 0}
    for record in analyzed:
        for impact, count in (
            (record.get("aderyn") or {}).get("summary") or {}
        ).items():
            severity[impact] = severity.get(impact, 0) + int(count or 0)
    return {
        "source": source,
        "model": model,
        "attempted": len(group),
        "compiled": len(compiled),
        "full_pass": len(full_pass),
        "analyzed": len(analyzed),
        "errors": sum(record.get("status") == "error" for record in group),
        "skipped": sum(record.get("status") == "skipped" for record in group),
        "reused": sum(record.get("scan_origin") == "rq1_sha_reuse" for record in group),
        "safe_full_pass": len(safe_full_pass),
        "aderyn_findings": findings,
        "aderyn_sloc": sloc,
        "aderyn_findings_per_kloc": findings / (sloc / 1000.0) if sloc else None,
        "aderyn_by_severity": severity,
    }


def aderyn_version(aderyn_bin: str) -> Optional[str]:
    try:
        completed = subprocess.run(
            [aderyn_bin, "--version"],
            check=True,
            capture_output=True,
            text=True,
            timeout=10,
        )
        return (completed.stdout or completed.stderr).strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def run(
    db_path: str,
    eval_report: Path,
    out_dir: Path,
    sources: List[str],
    models: List[str],
    aderyn_bin: str,
    timeout: int,
    resume: bool,
    retry_errors: bool,
    reuse_rq1: bool,
    rq1_reuse_dir: Path,
    limit: Optional[int],
) -> Dict[str, Any]:
    orig_repo_value = os.environ.get("ORIG_REPO")
    if not orig_repo_value:
        raise RuntimeError("ORIG_REPO is not set; load .env or set it before running")
    orig_repo = Path(orig_repo_value).expanduser().resolve()
    eval_results, eval_report_meta = load_eval_results(eval_report)
    entries = fetch_entries(db_path, sources, models)
    records: List[Dict[str, Any]] = []
    seen: Dict[Tuple[str, str], int] = {}

    print_flush(f"DB: {db_path}")
    print_flush(f"Entries loaded: {len(entries)}")
    print_flush(f"Selection: {SELECTION_POLICY}")
    print_flush(f"Eval report: {eval_report}")
    print_flush(
        f"Aderyn: {aderyn_bin} ({aderyn_version(aderyn_bin) or 'version unknown'})"
    )
    print_flush(f"Output: {out_dir}")

    for ordinal, entry in enumerate(entries, start=1):
        group_key = (str(entry["_source"]), str(entry["_model"]))
        if limit is not None and seen.get(group_key, 0) >= limit:
            continue
        seen[group_key] = seen.get(group_key, 0) + 1
        code, code_meta, tests, eval_meta, slither = prepare_entry(entry, eval_results)
        if eval_meta.get("foundry_profile"):
            sol_path = orig_repo / str(entry["file_path"])
            project_root = nearest_project_root(sol_path)
            eval_meta["foundry_source_dir"] = sol_path.relative_to(project_root).parts[
                0
            ]
        else:
            eval_meta["foundry_source_dir"] = None
        out_path = sample_output_path(out_dir, entry)
        label = f"{entry['_source']}/{entry['_model']} id={entry['id']} {entry['file_path']}"

        if resume and out_path.is_file():
            cached = json.loads(out_path.read_text(encoding="utf-8"))
            retry = retry_errors and cached.get("status") == "error"
            if cache_matches(cached, code_meta, eval_meta) and not retry:
                cached = refresh_cached_record(
                    cached,
                    entry,
                    code_meta,
                    tests,
                    eval_meta,
                    slither,
                    code,
                )
                write_json(out_path, cached)
                records.append(cached)
                print_flush(f"[{ordinal}/{len(entries)}] cached {label}")
                continue

        record = base_record(entry, code_meta, tests, eval_meta, slither, code)
        if code_meta.get("skip_reason"):
            record = analyze_record(
                record,
                code,
                orig_repo,
                ROOT,
                aderyn_bin,
                timeout,
                eval_meta.get("foundry_profile"),
            )
            write_json(out_path, record)
            records.append(record)
            print_flush(
                f"[{ordinal}/{len(entries)}] skip {label}: {record['skip_reason']}"
            )
            continue

        reused = (
            load_rq1_reuse(
                rq1_reuse_dir,
                entry,
                code_meta,
                eval_meta.get("foundry_profile"),
                eval_meta.get("foundry_source_dir"),
            )
            if reuse_rq1
            else None
        )
        if reused is not None:
            aderyn, reused_from = reused
            aderyn = dict(aderyn)
            aderyn["sloc"] = record["code"]["sloc"]
            record["status"] = "analyzed"
            record["aderyn"] = aderyn
            record["scan_origin"] = "rq1_sha_reuse"
            record["reused_from"] = reused_from
            print_flush(f"[{ordinal}/{len(entries)}] reuse {label}")
        else:
            print_flush(f"[{ordinal}/{len(entries)}] aderyn {label}")
            record = analyze_record(
                record,
                code,
                orig_repo,
                ROOT,
                aderyn_bin,
                timeout,
                eval_meta.get("foundry_profile"),
            )
            if record["status"] == "analyzed":
                print_flush(
                    f"  ok: findings={record['aderyn']['count']} "
                    f"sloc={record['aderyn'].get('sloc')}"
                )
            else:
                print_flush(f"  error: {record['aderyn'].get('error', '')[:200]}")

        write_json(out_path, record)
        records.append(record)

    flattened = [summarize_sample(record) for record in records]
    eligible = [
        record
        for record in flattened
        if record.get("eval_compiled") or record.get("feedback_compiled")
    ]
    aggregates = [
        aggregate_group(records, source, model)
        for source in sources
        for model in models
        if any(
            record["source"] == source and record["model"] == model
            for record in records
        )
    ]
    summary = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "db_path": db_path,
        "selection_policy": SELECTION_POLICY,
        "eval_report": str(eval_report),
        "eval_report_meta": eval_report_meta,
        "sources": sources,
        "models": models,
        "aderyn_bin": aderyn_bin,
        "aderyn_version": aderyn_version(aderyn_bin),
        "timeout": timeout,
        "analysis_scope": "feedback-or-eval-compiled",
        "analysis_eligible": len(eligible),
        "analysis_complete": sum(
            record.get("status") == "analyzed" for record in eligible
        ),
        "rq1_reuse_enabled": reuse_rq1,
        "rq1_reuse_dir": str(rq1_reuse_dir),
        "records": flattened,
        "by_source_model": aggregates,
    }
    write_json(out_dir / "summary.json", summary)
    return summary


def print_summary(summary: Mapping[str, Any]) -> None:
    print_flush("\nRQ2 Aderyn scan summary")
    print_flush(
        "Analysis scope (feedback or eval compiled): "
        f"{summary['analysis_complete']}/{summary['analysis_eligible']} complete"
    )
    print_flush(
        f"{'Variant':<12} {'Model':<22} {'Compiled':>10} {'Scanned':>8} "
        f"{'Err':>4} {'Reuse':>5} {'Findings':>8} {'KLOC':>8}"
    )
    print_flush("-" * 88)
    for row in summary["by_source_model"]:
        kloc = float(row["aderyn_sloc"]) / 1000.0
        print_flush(
            f"{row['source']:<12} {row['model']:<22} "
            f"{row['compiled']:>3}/{row['attempted']:<6} {row['analyzed']:>8} "
            f"{row['errors']:>4} {row['reused']:>5} {row['aderyn_findings']:>8} {kloc:>8.2f}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Aderyn for RQ2 Full vs. no-Slither feedback"
    )
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--env", default=".env")
    parser.add_argument("--eval-report", default=DEFAULT_EVAL_REPORT)
    parser.add_argument("--out-dir", default="stats/aderyn/rq2")
    parser.add_argument("--sources", default=",".join(DEFAULT_SOURCES))
    parser.add_argument("--models", default=",".join(TARGET_MODELS))
    parser.add_argument("--aderyn-bin", default=None)
    parser.add_argument("--timeout", type=int, default=DEFAULT_ADERYN_TIMEOUT)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--retry-errors", action="store_true")
    parser.add_argument("--no-rq1-reuse", action="store_true")
    parser.add_argument("--rq1-reuse-dir", default="stats/aderyn")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if load_dotenv is not None:
        load_dotenv(args.env)
    sources = parse_csv(args.sources)
    unknown_sources = sorted(set(sources) - set(DEFAULT_SOURCES))
    if unknown_sources:
        print(f"[ERROR] Unknown sources: {', '.join(unknown_sources)}", file=sys.stderr)
        return 2
    models = parse_csv(args.models)
    try:
        summary = run(
            db_path=args.db,
            eval_report=Path(args.eval_report),
            out_dir=Path(args.out_dir),
            sources=sources,
            models=models,
            aderyn_bin=resolve_aderyn_bin(args.aderyn_bin),
            timeout=args.timeout,
            resume=not args.no_resume,
            retry_errors=args.retry_errors,
            reuse_rq1=not args.no_rq1_reuse,
            rq1_reuse_dir=Path(args.rq1_reuse_dir),
            limit=args.limit,
        )
    except (OSError, sqlite3.Error, RuntimeError, ValueError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1
    print_summary(summary)
    print_flush(f"\nWrote: {Path(args.out_dir) / 'summary.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
