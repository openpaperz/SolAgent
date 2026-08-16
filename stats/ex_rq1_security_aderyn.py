#!/usr/bin/env python3
"""Run Aderyn for RQ1 outputs using the RQ1 security best-code rule."""

from __future__ import annotations

import argparse
import json
import os
import sys
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover
    load_dotenv = None

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.ex_rq1_security_mythril import (
    DEFAULT_MODELS,
    DEFAULT_SOURCES,
    code_for_entry,
    fetch_entries,
    file_slug,
    int_or_zero,
    model_slug,
    nearest_project_root,
    normalize_models,
    normalize_sources,
    slither_from_entry,
    temporary_generated_file,
    test_fields_for_entry,
)
from stats.rq1_eval_utils import (
    DEFAULT_EVAL_RESULT_PATHS,
    entry_eval_key,
    eval_metadata,
    eval_skip_reason,
    eval_test_fields,
    load_eval_results,
    select_eval_code,
)
from stats.rq1_security_statistics import wilson_interval
from utils.aderyn_utils import (
    DEFAULT_ADERYN_TIMEOUT,
    count_vulnerabilities as count_aderyn_vulnerabilities,
    get_sloc as get_aderyn_sloc,
    get_vulnerability_summary as get_aderyn_summary,
    resolve_aderyn_bin,
    run_aderyn,
)


def print_flush(*args, **kwargs) -> None:
    kwargs.setdefault("flush", True)
    print(*args, **kwargs)


def ensure_env(env_path: str) -> None:
    if load_dotenv is not None:
        load_dotenv(env_path)


def write_json(path: Path, data: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")


def sample_output_path(out_dir: Path, entry: Dict[str, Any]) -> Path:
    filename = f"{entry['id']:04d}__{file_slug(entry['file_path'])}.json"
    return out_dir / entry["_source"] / model_slug(entry["_model"]) / filename


def prepare_entry(
    entry: Dict[str, Any],
    eval_results: Dict[Tuple[str, str, str], Dict[str, Any]],
) -> Tuple[Optional[str], Dict[str, Any], Dict[str, int], Optional[Dict[str, Any]]]:
    if entry["_source_kind"] == "baseline":
        code, code_meta = code_for_entry(entry)
        return code, code_meta, test_fields_for_entry(entry, code_meta), None

    key = entry_eval_key(entry)
    eval_result = eval_results.get(key)
    if eval_result is None:
        raise ValueError(f"Missing eval result for {key}")

    code, code_meta = select_eval_code(entry, eval_result)
    skip_reason = eval_skip_reason(eval_result)
    if skip_reason:
        code_meta["skip_reason"] = skip_reason
    return (
        code,
        code_meta,
        eval_test_fields(eval_result),
        eval_metadata(eval_result),
    )


@contextmanager
def temporary_broken_symlink_fallbacks(
    project_root: Path, orig_repo: str, cur_repo: str
):
    repaired: List[Tuple[Path, str]] = []
    for root, directories, files in os.walk(project_root, followlinks=False):
        for name in [*directories, *files]:
            path = Path(root) / name
            if not path.is_symlink() or path.exists():
                continue
            try:
                fallback = Path(cur_repo) / path.relative_to(Path(orig_repo))
            except ValueError:
                continue
            if not fallback.exists():
                continue
            original_target = os.readlink(path)
            path.unlink()
            path.symlink_to(fallback.resolve(), target_is_directory=fallback.is_dir())
            repaired.append((path, original_target))
    try:
        yield
    finally:
        for path, original_target in reversed(repaired):
            try:
                path.unlink()
            except FileNotFoundError:
                pass
            path.symlink_to(original_target)


def refresh_cached_record(
    record: Dict[str, Any],
    entry: Dict[str, Any],
    out_path: Path,
    code_meta: Dict[str, Any],
    test_fields: Dict[str, int],
    eval_meta: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    record.update(
        {
            "source": entry["_source"],
            "source_kind": entry["_source_kind"],
            "table": entry["_table"],
            "model": entry["_model"],
            "id": entry["id"],
            "file_path": entry["file_path"],
            "test_pass": test_fields["test_pass"],
            "test_fail": test_fields["test_fail"],
            "test_total": test_fields["test_total"],
            "code": code_meta,
            "eval": eval_meta,
            "test_source": "eval_seed1" if eval_meta else "database",
            "slither": slither_from_entry(entry),
            "refreshed_at": datetime.now(timezone.utc).isoformat(),
        }
    )
    write_json(out_path, record)
    return record


def run_entry(
    entry: Dict[str, Any],
    out_path: Path,
    orig_repo: str,
    cur_repo: str,
    aderyn_bin: str,
    timeout: int,
    code: Optional[str],
    code_meta: Dict[str, Any],
    test_fields: Dict[str, int],
    eval_meta: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    record = {
        "source": entry["_source"],
        "source_kind": entry["_source_kind"],
        "table": entry["_table"],
        "model": entry["_model"],
        "id": entry["id"],
        "file_path": entry["file_path"],
        "status": "pending",
        "test_pass": test_fields["test_pass"],
        "test_fail": test_fields["test_fail"],
        "test_total": test_fields["test_total"],
        "code": code_meta,
        "eval": eval_meta,
        "test_source": "eval_seed1" if eval_meta else "database",
        "slither": slither_from_entry(entry),
        "aderyn": {},
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    if code_meta.get("skip_reason"):
        record["status"] = "skipped"
        record["skip_reason"] = code_meta["skip_reason"]
        write_json(out_path, record)
        return record

    orig_sol = Path(orig_repo) / entry["file_path"]
    try:
        if entry["_source_kind"] == "baseline":
            if not orig_sol.exists():
                aderyn_raw = {"error": f"Baseline file not found: {orig_sol}"}
            else:
                project_root = nearest_project_root(orig_sol)
                with temporary_broken_symlink_fallbacks(
                    project_root, orig_repo=orig_repo, cur_repo=cur_repo
                ):
                    aderyn_raw = run_aderyn(
                        str(orig_sol),
                        project_root=str(project_root),
                        aderyn_bin=aderyn_bin,
                        timeout=timeout,
                    )
        elif not code:
            record["status"] = "skipped"
            record["skip_reason"] = "no generated code"
            write_json(out_path, record)
            return record
        else:
            project_root = nearest_project_root(orig_sol)
            with temporary_generated_file(orig_sol, code):
                with temporary_broken_symlink_fallbacks(
                    project_root, orig_repo=orig_repo, cur_repo=cur_repo
                ):
                    aderyn_raw = run_aderyn(
                        str(orig_sol),
                        project_root=str(project_root),
                        aderyn_bin=aderyn_bin,
                        timeout=timeout,
                    )
    except Exception as exc:
        aderyn_raw = {"error": f"Unexpected Aderyn runner failure: {exc}"}

    if "error" in aderyn_raw:
        record["status"] = "error"
        record["aderyn"] = {"error": aderyn_raw["error"], "raw": aderyn_raw}
    else:
        record["status"] = "analyzed"
        record["aderyn"] = {
            "count": count_aderyn_vulnerabilities(aderyn_raw),
            "summary": get_aderyn_summary(aderyn_raw),
            "sloc": get_aderyn_sloc(aderyn_raw),
            "raw": aderyn_raw,
        }

    write_json(out_path, record)
    return record


def summarize_sample(record: Dict[str, Any]) -> Dict[str, Any]:
    aderyn = record.get("aderyn", {})
    slither = record.get("slither", {})
    slither_count = slither.get("rq1_count", slither.get("count"))
    aderyn_count = aderyn.get("count")
    return {
        "source": record["source"],
        "source_kind": record["source_kind"],
        "model": record["model"],
        "id": record["id"],
        "file_path": record["file_path"],
        "status": record["status"],
        "test_pass": record["test_pass"],
        "test_fail": record.get("test_fail", 0),
        "test_total": record["test_total"],
        "test_source": record.get("test_source"),
        "eval": record.get("eval"),
        "aderyn_count": aderyn_count,
        "aderyn_summary": aderyn.get("summary", {}),
        "aderyn_sloc": aderyn.get("sloc"),
        "aderyn_error": aderyn.get("error"),
        "slither_rq1_count": slither_count,
        "slither_rq1_source": slither.get("rq1_source", slither.get("source")),
        "slither_raw_count": slither.get("raw_count"),
        "slither_raw_present": slither.get("raw_present", False),
        "slither_raw_summary": slither.get("raw_summary", {}),
        "delta_aderyn_minus_slither": (
            aderyn_count - slither_count
            if isinstance(aderyn_count, int) and isinstance(slither_count, int)
            else None
        ),
    }


def aggregate_group(
    records: List[Dict[str, Any]], source: str, model: str
) -> Dict[str, Any]:
    attempted = [r for r in records if r["source"] == source and r["model"] == model]
    analyzed = [r for r in attempted if r["status"] == "analyzed"]
    errors = [r for r in attempted if r["status"] == "error"]
    skipped = [r for r in attempted if r["status"] == "skipped"]
    compiled = [r for r in attempted if int_or_zero(r.get("test_total")) > 0]
    full_pass = [
        r
        for r in compiled
        if int_or_zero(r.get("test_pass")) == int_or_zero(r.get("test_total"))
    ]
    safe_full_pass = [
        r
        for r in full_pass
        if r["status"] == "analyzed" and r["aderyn"].get("count") == 0
    ]

    aderyn_total = sum(r["aderyn"]["count"] for r in analyzed)
    slither_compiled = [
        r
        for r in compiled
        if isinstance(r["slither"].get("rq1_count", r["slither"].get("count")), int)
    ]
    slither_total = sum(
        r["slither"].get("rq1_count", r["slither"].get("count"))
        for r in slither_compiled
    )
    common = [
        r
        for r in analyzed
        if isinstance(r["slither"].get("rq1_count", r["slither"].get("count")), int)
    ]
    slither_common_total = sum(
        r["slither"].get("rq1_count", r["slither"].get("count")) for r in common
    )
    less = sum(
        r["aderyn"]["count"] < r["slither"].get("rq1_count", r["slither"].get("count"))
        for r in common
    )
    more = sum(
        r["aderyn"]["count"] > r["slither"].get("rq1_count", r["slither"].get("count"))
        for r in common
    )
    equal = len(common) - less - more

    severity = {"High": 0, "Low": 0}
    for record in analyzed:
        for key, value in record["aderyn"].get("summary", {}).items():
            severity[key] = severity.get(key, 0) + value

    secure_rate = len(safe_full_pass) / len(attempted) if attempted else 0.0
    safe_at_full_pass = len(safe_full_pass) / len(full_pass) if full_pass else None
    ci_low, ci_high = wilson_interval(len(safe_full_pass), len(attempted))
    return {
        "source": source,
        "model": model,
        "total_entries": len(attempted),
        "compiled_entries": len(compiled),
        "full_pass_entries": len(full_pass),
        "analyzed": len(analyzed),
        "errors": len(errors),
        "skipped": len(skipped),
        "aderyn_total_vuln": aderyn_total,
        "aderyn_by_severity": severity,
        "safe_full_pass": len(safe_full_pass),
        "secure_pass_at_1": secure_rate,
        "safe_at_full_pass": safe_at_full_pass,
        "secure_pass_wilson_ci": [ci_low, ci_high],
        "slither_rq1_compiled_files": len(slither_compiled),
        "slither_rq1_total_vuln": slither_total,
        "slither_rq1_common_files": len(common),
        "slither_rq1_total_vuln_on_aderyn_analyzed": slither_common_total,
        "less_than_slither": less,
        "more_than_slither": more,
        "equal_to_slither": equal,
    }


def aggregate_records(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    groups = sorted({(r["source"], r["model"]) for r in records})
    return [aggregate_group(records, source, model) for source, model in groups]


def run_for_sources(
    db_path: str,
    sources: List[str],
    models: List[str],
    out_dir: Path,
    aderyn_bin: str,
    timeout: int,
    limit: Optional[int],
    resume: bool,
    retry_errors: bool,
    eval_results: Dict[Tuple[str, str, str], Dict[str, Any]],
    eval_paths: List[str],
) -> Dict[str, Any]:
    orig_repo = os.environ.get("ORIG_REPO")
    if not orig_repo:
        raise RuntimeError("ORIG_REPO is not set; load .env or set it before running")

    cur_repo = os.getcwd()
    entries = fetch_entries(db_path, sources, models)
    by_group_seen: Dict[Tuple[str, str], int] = {}
    records: List[Dict[str, Any]] = []

    print_flush(f"DB: {db_path}")
    print_flush(f"Entries loaded: {len(entries)}")
    print_flush(f"Output dir: {out_dir}")
    print_flush(f"Aderyn: {aderyn_bin}")
    print_flush(f"Timeout: {timeout}s")
    print_flush(f"Eval reports: {', '.join(eval_paths)}")

    for ordinal, entry in enumerate(entries, 1):
        group_key = (entry["_source"], entry["_model"])
        if limit is not None and by_group_seen.get(group_key, 0) >= limit:
            continue
        by_group_seen[group_key] = by_group_seen.get(group_key, 0) + 1

        out_path = sample_output_path(out_dir, entry)
        label = f"{entry['_source']}/{entry['_model']} id={entry['id']} {entry['file_path']}"
        code, code_meta, test_fields, eval_meta = prepare_entry(entry, eval_results)

        if code_meta.get("skip_reason"):
            record = run_entry(
                entry,
                out_path,
                orig_repo=orig_repo,
                cur_repo=cur_repo,
                aderyn_bin=aderyn_bin,
                timeout=timeout,
                code=code,
                code_meta=code_meta,
                test_fields=test_fields,
                eval_meta=eval_meta,
            )
            records.append(record)
            print_flush(
                f"[{ordinal}/{len(entries)}] skip {label}: {record.get('skip_reason')}"
            )
            continue

        if resume and out_path.exists():
            cached = json.loads(out_path.read_text(encoding="utf-8"))
            stale_round = False
            selected_meta = code_meta
            cached_meta = cached.get("code", {})
            if entry["_source_kind"] == "solagent":
                stale_round = any(
                    cached_meta.get(key) != selected_meta.get(key)
                    for key in ("best_round", "best_pass", "best_total")
                )
            stale_code = cached_meta.get("sha256") != selected_meta.get("sha256")
            retry = (
                stale_round
                or stale_code
                or (retry_errors and cached.get("status") == "error")
            )
            if not retry:
                records.append(
                    refresh_cached_record(
                        cached,
                        entry,
                        out_path,
                        code_meta=code_meta,
                        test_fields=test_fields,
                        eval_meta=eval_meta,
                    )
                )
                print_flush(f"[{ordinal}/{len(entries)}] cached {label}")
                continue
            if stale_round:
                reason = "selector changed"
            elif stale_code:
                reason = "code changed"
            else:
                reason = "cached error"
            print_flush(f"[{ordinal}/{len(entries)}] retry {label} ({reason})")

        print_flush(f"[{ordinal}/{len(entries)}] aderyn {label}")
        record = run_entry(
            entry,
            out_path,
            orig_repo=orig_repo,
            cur_repo=cur_repo,
            aderyn_bin=aderyn_bin,
            timeout=timeout,
            code=code,
            code_meta=code_meta,
            test_fields=test_fields,
            eval_meta=eval_meta,
        )
        records.append(record)
        if record["status"] == "analyzed":
            sev = record["aderyn"].get("summary", {})
            print_flush(
                f"  ok: aderyn={record['aderyn'].get('count')} "
                f"(H:{sev.get('High', 0)} L:{sev.get('Low', 0)}), "
                f"slither={record['slither'].get('count')}"
            )
        elif record["status"] == "skipped":
            print_flush(f"  skip: {record.get('skip_reason')}")
        else:
            print_flush(f"  error: {record['aderyn'].get('error', '')[:200]}")

    summary = {
        "db_path": db_path,
        "sources": sources,
        "models": models,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "aderyn_bin": aderyn_bin,
        "timeout": timeout,
        "limit": limit,
        "test_source": "eval_seed1",
        "eval_reports": eval_paths,
        "records": [summarize_sample(r) for r in records],
        "by_source_model": aggregate_records(records),
    }
    write_json(out_dir / "summary.json", summary)
    write_json(out_dir / "summary_eval_seed1.json", summary)
    comparison = {
        "created_at": summary["created_at"],
        "by_source_model": summary["by_source_model"],
        "records": summary["records"],
    }
    write_json(
        out_dir / "comparison_with_slither.json",
        comparison,
    )
    write_json(out_dir / "comparison_with_slither_eval_seed1.json", comparison)
    return summary


def print_summary(summary: Dict[str, Any]) -> None:
    print_flush("\nAderyn vs RQ1-Slither summary")
    print_flush(
        f"{'Source':<12} {'Model':<22} {'Compiled':>9} {'Analyzed':>8} "
        f"{'Err':>5} {'Skip':>5} {'Aderyn':>8} {'Slither':>9} {'Slither@A':>10} "
        f"{'SafeFull':>8} {'Secure@1':>9} {'Safe@Full':>9}"
    )
    print_flush("-" * 132)
    for row in summary["by_source_model"]:
        safe_at_full = row["safe_at_full_pass"]
        safe_at_full_text = (
            "N/A" if safe_at_full is None else f"{safe_at_full * 100:.2f}%"
        )
        print_flush(
            f"{row['source']:<12} {row['model']:<22} "
            f"{row['compiled_entries']:>3}/{row['total_entries']:<5} "
            f"{row['analyzed']:>8} {row['errors']:>5} {row['skipped']:>5} "
            f"{row['aderyn_total_vuln']:>8} {row['slither_rq1_total_vuln']:>9} "
            f"{row['slither_rq1_total_vuln_on_aderyn_analyzed']:>10} "
            f"{row['safe_full_pass']:>8} {row['secure_pass_at_1'] * 100:>8.2f}% "
            f"{safe_at_full_text:>9}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Aderyn on RQ1 outputs without writing DB"
    )
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--env", default=".env")
    parser.add_argument("--out-dir", default="stats/aderyn")
    parser.add_argument("--sources", default=",".join(DEFAULT_SOURCES))
    parser.add_argument("--models", default=",".join(DEFAULT_MODELS))
    parser.add_argument(
        "--aderyn-bin",
        default=None,
        help="Aderyn binary; defaults to ADERYN_BIN from .env, then aderyn on PATH",
    )
    parser.add_argument("--timeout", type=int, default=DEFAULT_ADERYN_TIMEOUT)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--retry-errors", action="store_true")
    parser.add_argument(
        "--eval-files",
        default=",".join(DEFAULT_EVAL_RESULT_PATHS),
        help="comma-separated eval result JSON files",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    ensure_env(args.env)
    aderyn_bin = resolve_aderyn_bin(args.aderyn_bin)
    sources = normalize_sources(args.sources)
    models = normalize_models(args.models)
    eval_paths = [item.strip() for item in args.eval_files.split(",") if item.strip()]
    eval_results = load_eval_results(Path(item) for item in eval_paths)
    summary = run_for_sources(
        db_path=args.db,
        sources=sources,
        models=models,
        out_dir=Path(args.out_dir),
        aderyn_bin=aderyn_bin,
        timeout=args.timeout,
        limit=args.limit,
        resume=not args.no_resume,
        retry_errors=args.retry_errors,
        eval_results=eval_results,
        eval_paths=eval_paths,
    )
    print_summary(summary)
    print_flush(f"\nWrote: {Path(args.out_dir) / 'summary.json'}")
    print_flush(f"Wrote: {Path(args.out_dir) / 'summary_eval_seed1.json'}")
    print_flush(f"Wrote: {Path(args.out_dir) / 'comparison_with_slither.json'}")
    print_flush(
        f"Wrote: {Path(args.out_dir) / 'comparison_with_slither_eval_seed1.json'}"
    )


if __name__ == "__main__":
    main()
