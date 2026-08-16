#!/usr/bin/env python3
"""RQ1 Slither security statistics using the independent seed-1 eval reports.

Functionality (Compiled and FullPass) comes exclusively from the fixed-seed
hidden-eval reports. Slither findings and SLOC are read/reconstructed for the
exact database row and selected code checkpoint recorded by those reports.

Usage:
    python stats/rq1_security_slither_statistics.py --db output/progress.db
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import sqlite3
import sys
from pathlib import Path
from typing import Any, Dict, List, Mapping, Sequence, Tuple

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.code_metrics import count_loc
from stats.rq1_eval_utils import (
    DEFAULT_EVAL_RESULT_PATHS,
    entry_eval_key,
    eval_test_fields,
    load_eval_results,
    select_eval_code,
)
from stats.rq1_security_aderyn_statistics import (
    analyze,
    percentage,
)
from stats.rq1_security_statistics import (
    AGENT_DISPLAY_NAMES,
    RAW_MODEL,
    SOLAGENT,
    FileSecurityRecord,
    as_nonnegative_int,
    print_table,
    safe_json_loads,
)


FIXED_FUZZ_SEED = "0x" + "0" * 63 + "1"
DEFAULT_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
AGENT_SOURCES = ["metagpt", "deepcode", "qwenagent", "copilot"]
GENERATED_SOURCES = ["rawmodel", "solagent", *AGENT_SOURCES]
DEFAULT_OUTPUT = Path("stats/slither") / f"{Path(__file__).stem}.csv"
DEFAULT_MISSING_SLITHER = Path("stats/slither/ex_rq1_security_slither_missing.json")
SOURCE_METHODS = {
    "rawmodel": RAW_MODEL,
    "solagent": SOLAGENT,
    **AGENT_DISPLAY_NAMES,
}


class SlitherEvalStatisticsError(RuntimeError):
    """Raised when seed-1 eval results cannot be aligned with the database."""


def normalize_csv(value: str) -> List[str]:
    return list(dict.fromkeys(item.strip() for item in value.split(",") if item.strip()))


def fetch_entries(
    db_path: str, sources: Sequence[str], models: Sequence[str]
) -> List[Dict[str, Any]]:
    path = Path(db_path)
    if not path.is_file():
        raise SlitherEvalStatisticsError(f"Database file not found: {db_path}")
    placeholders = ",".join("?" for _ in models)
    entries: List[Dict[str, Any]] = []
    connection = sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    try:
        for source in sources:
            if source == "rawmodel":
                table = "progress_tracker_rawmodel"
                sql = f"SELECT * FROM {table} WHERE status = 1 AND model_coding IN ({placeholders})"
                parameters: List[Any] = list(models)
                source_kind = "rawmodel"
            elif source == "solagent":
                table = "process_tracking"
                sql = f"SELECT * FROM {table} WHERE status = 1 AND model_coding IN ({placeholders})"
                parameters = list(models)
                source_kind = "solagent"
            elif source in AGENT_SOURCES:
                table = "progress_tracker_agent"
                sql = f"SELECT * FROM {table} WHERE agent_type = ? AND model_coding IN ({placeholders})"
                parameters = [source, *models]
                source_kind = "agent"
            else:
                raise SlitherEvalStatisticsError(f"Unsupported source: {source}")
            try:
                rows = connection.execute(sql, parameters)
            except sqlite3.Error as error:
                raise SlitherEvalStatisticsError(
                    f"Cannot query required table {table}: {error}"
                ) from error
            for raw in rows:
                entry = dict(raw)
                entry["_source"] = source
                entry["_source_kind"] = source_kind
                entry["_model"] = entry.get("model_coding") or "unknown"
                entry["_table"] = table
                entries.append(entry)
    finally:
        connection.close()
    return entries


def slither_count_for_eval_entry(
    entry: Mapping[str, Any], result: Mapping[str, Any]
) -> int | None:
    if entry.get("_source") != "solagent":
        return as_nonnegative_int(entry.get("vuln_count"))

    best_round = result.get("best_round")
    if best_round is None:
        return None
    by_round = safe_json_loads(entry.get("round_vuln_count"), {})
    if not isinstance(by_round, dict):
        return None
    count = as_nonnegative_int(by_round.get(str(best_round)))
    reported = result.get("best_vuln")
    if reported != count:
        raise SlitherEvalStatisticsError(
            f"Slither count mismatch for {entry_eval_key(dict(entry))}: "
            f"database={count!r}, eval report best_vuln={reported!r}"
        )
    return count


def load_missing_slither(
    path: Path | None,
) -> Dict[Tuple[str, str, str], Mapping[str, Any]]:
    if path is None:
        return {}
    if not path.is_file():
        raise SlitherEvalStatisticsError(f"Missing-Slither result file not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SlitherEvalStatisticsError(
            f"Cannot read missing-Slither result file {path}: {error}"
        ) from error
    records = data.get("records") if isinstance(data, dict) else None
    if not isinstance(records, list):
        raise SlitherEvalStatisticsError(
            f"Missing-Slither result file has no records list: {path}"
        )
    results: Dict[Tuple[str, str, str], Mapping[str, Any]] = {}
    for record in records:
        if not isinstance(record, dict):
            raise SlitherEvalStatisticsError(f"Invalid missing-Slither record in {path}")
        key = (
            str(record.get("source") or ""),
            str(record.get("model") or ""),
            str(record.get("file_path") or ""),
        )
        if not all(key):
            raise SlitherEvalStatisticsError(
                f"Incomplete missing-Slither record key in {path}: {key}"
            )
        if key in results:
            raise SlitherEvalStatisticsError(
                f"Duplicate missing-Slither record in {path}: {key}"
            )
        results[key] = record
    return results


def missing_slither_count_for_code(
    key: Tuple[str, str, str],
    code: str | None,
    record: Mapping[str, Any] | None,
) -> int | None:
    if record is None:
        return None
    if record.get("status") != "analyzed":
        raise SlitherEvalStatisticsError(
            f"Missing-Slither scan is not analyzed for {key}: {record.get('status')}"
        )
    if not code:
        raise SlitherEvalStatisticsError(
            f"Missing-Slither result exists but eval code is unavailable for {key}"
        )
    actual_hash = hashlib.sha256(code.encode()).hexdigest()
    actual_bytes = len(code.encode())
    if record.get("code_sha256") != actual_hash:
        raise SlitherEvalStatisticsError(
            f"Missing-Slither code hash mismatch for {key}: "
            f"scan={record.get('code_sha256')}, eval={actual_hash}"
        )
    if int(record.get("code_bytes") or -1) != actual_bytes:
        raise SlitherEvalStatisticsError(
            f"Missing-Slither code length mismatch for {key}: "
            f"scan={record.get('code_bytes')}, eval={actual_bytes}"
        )
    count = as_nonnegative_int(record.get("vuln_count"))
    if count is None:
        raise SlitherEvalStatisticsError(
            f"Missing-Slither scan has invalid vuln_count for {key}"
        )
    return count


def validate_eval_configuration(eval_results: Mapping[Tuple[str, str, str], Mapping]) -> None:
    bad_seeds = {
        str(result.get("fuzz_seed"))
        for result in eval_results.values()
        if result.get("fuzz_seed") != FIXED_FUZZ_SEED
    }
    if bad_seeds:
        raise SlitherEvalStatisticsError(
            "Eval reports are not uniformly seed1; unexpected fuzz_seed values: "
            + ", ".join(sorted(bad_seeds))
        )
    bad_solagent_policy = {
        str(result.get("selection_policy"))
        for key, result in eval_results.items()
        if key[0] == "solagent"
        and result.get("selection_policy") != "test-first-security-second"
    }
    if bad_solagent_policy:
        raise SlitherEvalStatisticsError(
            "SolAgent eval report has an unexpected selection policy: "
            + ", ".join(sorted(bad_solagent_policy))
        )


def collect_groups(
    db_path: str,
    sources: Sequence[str],
    models: Sequence[str],
    eval_paths: Sequence[Path],
    missing_slither: Mapping[Tuple[str, str, str], Mapping[str, Any]] | None = None,
) -> Dict[Tuple[str, str], List[FileSecurityRecord]]:
    eval_results = load_eval_results(eval_paths)
    validate_eval_configuration(eval_results)
    entries = fetch_entries(db_path, sources, models)
    entries_by_key = {entry_eval_key(entry): entry for entry in entries}

    selected_keys = {
        key
        for key in eval_results
        if key[0] in sources and key[1] in models
    }
    missing_entries = sorted(selected_keys - set(entries_by_key))
    missing_results = sorted(set(entries_by_key) - selected_keys)
    if missing_entries:
        raise SlitherEvalStatisticsError(
            f"Missing {len(missing_entries)} database rows required by eval reports; "
            f"first={missing_entries[0]}"
        )
    if missing_results:
        raise SlitherEvalStatisticsError(
            f"Missing {len(missing_results)} eval results for selected database rows; "
            f"first={missing_results[0]}"
        )

    groups: Dict[Tuple[str, str], List[FileSecurityRecord]] = {}
    for key in sorted(selected_keys):
        entry = entries_by_key[key]
        result = eval_results[key]
        method = SOURCE_METHODS.get(key[0])
        if method is None:
            continue

        code, _code_meta = select_eval_code(entry, result)
        test_fields = eval_test_fields(result)
        vuln_count = slither_count_for_eval_entry(entry, result)
        if vuln_count is None:
            vuln_count = missing_slither_count_for_code(
                key,
                code,
                (missing_slither or {}).get(key),
            )
        sloc = count_loc(code) if code else None
        record = FileSecurityRecord(
            method=method,
            model=key[1],
            file_path=key[2],
            test_pass=test_fields["test_pass"],
            test_total=test_fields["test_total"],
            vuln_count=vuln_count,
            sloc=sloc if sloc and sloc > 0 else None,
        )
        groups.setdefault((method, key[1]), []).append(record)
    return groups


def build_paper_table(
    result: Mapping[str, Any],
    groups: Mapping[Tuple[str, str], Sequence[FileSecurityRecord]],
    models: Sequence[str],
) -> List[Dict[str, Any]]:
    primary = {
        (row["method"], row["model"]): row for row in result["primary"]
    }
    paired_secure = {
        (row["baseline"], row["model"]): row
        for row in result["paired_solagent_vs_baselines"]
    }
    baseline_methods = [RAW_MODEL, *(AGENT_DISPLAY_NAMES.values())]
    rows: List[Dict[str, Any]] = []
    for model in models:
        sol_primary = primary[(SOLAGENT, model)]
        rows.append(
            {
                "model": model,
                "method": SOLAGENT,
                "attempted": sol_primary["attempted"],
                "safe_full_pass": sol_primary["safe_full_pass"],
                "secure_pass_at_1": sol_primary["secure_pass_at_1"],
                "safe_at_full_pass": sol_primary["safe_at_full_pass"],
                "safe_at_full_pass_denominator": sol_primary["full_pass"],
                "baseline_solagent_findings_with_n": None,
                "baseline_solagent_findings_per_kloc": None,
                "solagent_finding_count_reduction": None,
                "holm_p": None,
            }
        )
        for baseline in baseline_methods:
            sol_records = {
                record.file_path: record
                for record in groups.get((SOLAGENT, model), [])
            }
            baseline_records = {
                record.file_path: record
                for record in groups.get((baseline, model), [])
            }
            pairs = [
                (sol_records[file_path], baseline_records[file_path])
                for file_path in sorted(set(sol_records) & set(baseline_records))
                if sol_records[file_path].full_pass
                and baseline_records[file_path].full_pass
                and sol_records[file_path].scan_valid
                and baseline_records[file_path].scan_valid
                and sol_records[file_path].sloc is not None
                and baseline_records[file_path].sloc is not None
            ]
            sol_findings = sum(left.vuln_count for left, _ in pairs)
            baseline_findings = sum(right.vuln_count for _, right in pairs)
            sol_sloc = sum(left.sloc for left, _ in pairs)
            baseline_sloc = sum(right.sloc for _, right in pairs)
            baseline_primary = primary[(baseline, model)]
            secure_pair = paired_secure[(baseline, model)]
            sol_density = sol_findings / sol_sloc * 1000.0 if sol_sloc else None
            baseline_density = (
                baseline_findings / baseline_sloc * 1000.0
                if baseline_sloc
                else None
            )
            rows.append(
                {
                    "model": model,
                    "method": baseline,
                    "attempted": baseline_primary["attempted"],
                    "safe_full_pass": baseline_primary["safe_full_pass"],
                    "secure_pass_at_1": baseline_primary["secure_pass_at_1"],
                    "safe_at_full_pass": baseline_primary["safe_at_full_pass"],
                    "safe_at_full_pass_denominator": baseline_primary["full_pass"],
                    "baseline_solagent_findings_with_n": (
                        f"{baseline_findings}/{sol_findings} (n={len(pairs)})"
                    ),
                    "baseline_solagent_findings_per_kloc": (
                        f"{baseline_density:.2f}/{sol_density:.2f}"
                        if baseline_density is not None and sol_density is not None
                        else None
                    ),
                    "solagent_finding_count_reduction": (
                        (baseline_findings - sol_findings) / baseline_findings
                        if baseline_findings
                        else None
                    ),
                    "holm_p": secure_pair["holm_p"],
                }
            )
    return rows


def print_results(rows: Sequence[Mapping[str, Any]]) -> None:
    print("\n" + "=" * 120)
    print("RQ-1 Slither Security Statistics: Independent Eval Tests, Fixed Fuzz Seed 1")
    print("=" * 120)

    print("\nMain Table")
    print_table(
        [
            "Model",
            "Method",
            "SecurePass@1",
            "Zero-Finding@FullPass",
            "Baseline/SolAgent Findings (n)",
            "Finding Count Reduction ↑",
            "Baseline/SolAgent Findings/KLOC",
            "Secure Holm p",
        ],
        [
            [
                row["model"],
                row["method"],
                (
                    f"{percentage(row['secure_pass_at_1'])} "
                    f"({row['safe_full_pass']}/{row['attempted']})"
                ),
                (
                    "N/A"
                    if row["safe_at_full_pass"] is None
                    else (
                        f"{percentage(row['safe_at_full_pass'])} "
                        f"({row['safe_full_pass']}/{row['safe_at_full_pass_denominator']})"
                    )
                ),
                (
                    "—"
                    if row["baseline_solagent_findings_with_n"] is None
                    else row["baseline_solagent_findings_with_n"]
                ),
                (
                    "—"
                    if row["solagent_finding_count_reduction"] is None
                    else f"{row['solagent_finding_count_reduction'] * 100:+.2f}%"
                ),
                (
                    "—"
                    if row["baseline_solagent_findings_per_kloc"] is None
                    else row["baseline_solagent_findings_per_kloc"]
                ),
                "—" if row["holm_p"] is None else f"{row['holm_p']:.4g}",
            ]
            for row in rows
        ],
    )

    print("\nNotes:")
    print("- Functionality comes from the independent seed1 eval reports, not database feedback tests.")
    print("- SecurePass@1 = eval FullPass and zero Slither findings / all 81 tasks.")
    print("- Zero-Finding@FullPass = zero-Slither eval FullPass files / eval FullPass files.")
    print("- n is the number of same-task files where both methods eval FullPass with valid Slither and SLOC.")
    print("- The same n matched files are used for both finding counts and Findings/KLOC.")
    print("- Findings denote Slither High+Medium+Low findings.")
    print("- Positive Finding Count Reduction means SolAgent has fewer total findings.")
    print("- Secure Holm p tests paired SecurePass@1 over all 81 attempted files.")
    print("- SolAgent has no single paired count or density because its paired file set differs by baseline.")


def write_table_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0]) if rows else []
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Analyze RQ1 Slither security using independent seed1 eval results"
    )
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--models", default=",".join(DEFAULT_MODELS))
    parser.add_argument("--sources", default=",".join(GENERATED_SOURCES))
    parser.add_argument(
        "--eval-files",
        default=",".join(DEFAULT_EVAL_RESULT_PATHS),
        help="Comma-separated seed1 eval report JSON files",
    )
    parser.add_argument(
        "--missing-slither",
        default="",
        help=(
            "Optional supplemental exact-code Slither JSON used only when the "
            f"database Slither count is invalid (e.g. {DEFAULT_MISSING_SLITHER})"
        ),
    )
    parser.add_argument(
        "--output", default=str(DEFAULT_OUTPUT)
    )
    args = parser.parse_args()

    try:
        models = normalize_csv(args.models)
        sources = normalize_csv(args.sources)
        unknown_sources = [source for source in sources if source not in GENERATED_SOURCES]
        if unknown_sources:
            raise SlitherEvalStatisticsError(
                "Unsupported source(s): " + ", ".join(unknown_sources)
            )
        eval_paths = [Path(item.strip()) for item in args.eval_files.split(",") if item.strip()]
        missing_path = Path(args.missing_slither) if args.missing_slither.strip() else None
        missing_slither = load_missing_slither(missing_path)
        groups = collect_groups(
            args.db,
            sources,
            models,
            eval_paths,
            missing_slither=missing_slither,
        )
        result = analyze(groups, models)
        paper_table = build_paper_table(result, groups, models)

        output = Path(args.output)
        write_table_csv(output, paper_table)
        print_results(paper_table)
        print(f"\nWrote: {output}")
        return 0
    except (OSError, ValueError, SlitherEvalStatisticsError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
