#!/usr/bin/env python3
"""Build the RQ3 symbolic-testing table from the authoritative Halmos report."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence


TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
METHOD_ORDER = [
    "SolAgent",
    "RawModel",
    "MetaGPT",
    "DeepCode",
    "QwenAgent",
    "Copilot",
]
SUPPORTED_METHODS = ["SolAgent", "SolAgent-Summary", *METHOD_ORDER[1:]]
EXPECTED_TASKS_PER_GROUP = 81
DEFAULT_REPORT = Path("testing/symbolic/rq3_verify_symbolic_models.json")
DEFAULT_OUTPUT = Path("stats/symbolic") / f"{Path(__file__).stem}.csv"

SOURCE_METHODS = {
    "rawmodel": "RawModel",
    "solagent": "SolAgent",
    "solagent-summary": "SolAgent-Summary",
}
AGENT_METHODS = {
    "metagpt": "MetaGPT",
    "deepcode": "DeepCode",
    "qwenagent": "QwenAgent",
    "copilot": "Copilot",
}
METHOD_ALIASES = {
    **{method.lower(): method for method in SUPPORTED_METHODS},
    "raw-model": "RawModel",
}


class RQ3SymbolicStatisticsError(RuntimeError):
    """Raised when the Halmos report cannot reproduce the RQ3 table."""


@dataclass(frozen=True)
class SymbolicRow:
    model: str
    method: str
    attempted: int
    compiled: int
    compile_rate: float
    passed_checks: int
    expected_checks: int
    symbolic_check_pass_rate: float
    symbolic_pass_at_1_count: int
    symbolic_pass_at_1: float
    compile_errors: int
    extract_errors: int
    missing_rows: int


def parse_csv(value: str) -> list[str]:
    return list(dict.fromkeys(item.strip() for item in value.split(",") if item.strip()))


def normalize_methods(value: str) -> list[str]:
    methods: list[str] = []
    for raw in parse_csv(value):
        method = METHOD_ALIASES.get(raw.lower())
        if method is None:
            raise RQ3SymbolicStatisticsError(f"Unsupported method: {raw}")
        if method not in methods:
            methods.append(method)
    return methods


def method_for_result(result: Mapping[str, Any]) -> str:
    source = str(result.get("source") or "")
    if source == "agent":
        agent_type = str(result.get("agent_type") or "")
        method = AGENT_METHODS.get(agent_type)
        if method is None:
            raise RQ3SymbolicStatisticsError(f"Unknown agent_type: {agent_type!r}")
        return method
    method = SOURCE_METHODS.get(source)
    if method is None:
        raise RQ3SymbolicStatisticsError(f"Unknown symbolic source: {source!r}")
    return method


def summarize_group(
    model: str,
    method: str,
    results: Sequence[Mapping[str, Any]],
) -> SymbolicRow:
    attempted = len(results)
    compiled = 0
    passed_checks = 0
    expected_checks = 0
    pass_at_1 = 0
    compile_errors = 0
    extract_errors = 0
    missing_rows = 0

    for result in results:
        expected = int(result.get("expected_checks") or 0)
        passed = int(result.get("proved_checks") or 0)
        if expected < 0 or passed < 0 or passed > expected:
            raise RQ3SymbolicStatisticsError(
                f"Invalid check counts for {(model, method, result.get('sol_path'))}: "
                f"passed={passed}, expected={expected}"
            )
        has_compile_error = bool(result.get("compile_error"))
        has_extract_error = bool(result.get("extract_error"))
        is_missing = bool(result.get("missing_row"))
        compiled += int(not has_compile_error and not has_extract_error and not is_missing)
        passed_checks += passed
        expected_checks += expected
        pass_at_1 += int(bool(result.get("ok")))
        compile_errors += int(has_compile_error)
        extract_errors += int(has_extract_error)
        missing_rows += int(is_missing)

    return SymbolicRow(
        model=model,
        method=method,
        attempted=attempted,
        compiled=compiled,
        compile_rate=compiled / attempted if attempted else 0.0,
        passed_checks=passed_checks,
        expected_checks=expected_checks,
        symbolic_check_pass_rate=(passed_checks / expected_checks if expected_checks else 0.0),
        symbolic_pass_at_1_count=pass_at_1,
        symbolic_pass_at_1=pass_at_1 / attempted if attempted else 0.0,
        compile_errors=compile_errors,
        extract_errors=extract_errors,
        missing_rows=missing_rows,
    )


def validate_stored_summary(
    row: SymbolicRow,
    stored: Mapping[str, Any] | None,
) -> None:
    if stored is None:
        raise RQ3SymbolicStatisticsError(
            f"Missing stored summary for {(row.model, row.method)}"
        )
    expected = {
        "sols": row.attempted,
        "proved_sols": row.symbolic_pass_at_1_count,
        "expected_checks": row.expected_checks,
        "proved_checks": row.passed_checks,
        "compile_errors": row.compile_errors,
        "extract_errors": row.extract_errors,
        "missing_rows": row.missing_rows,
    }
    mismatches = {
        key: (stored.get(key), value)
        for key, value in expected.items()
        if stored.get(key) != value
    }
    if mismatches:
        raise RQ3SymbolicStatisticsError(
            f"Stored summary mismatch for {(row.model, row.method)}: {mismatches}"
        )


def load_rows(
    report_path: Path,
    models: Sequence[str],
    methods: Sequence[str],
) -> list[SymbolicRow]:
    if not report_path.is_file():
        raise RQ3SymbolicStatisticsError(f"Symbolic report not found: {report_path}")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    results = report.get("results")
    summary = report.get("summary")
    groups = summary.get("groups") if isinstance(summary, dict) else None
    if not isinstance(results, list) or not isinstance(groups, list):
        raise RQ3SymbolicStatisticsError(f"Invalid symbolic report: {report_path}")

    grouped: dict[tuple[str, str], list[Mapping[str, Any]]] = {}
    for result in results:
        if not isinstance(result, dict):
            raise RQ3SymbolicStatisticsError("Symbolic report contains a non-object result")
        method = method_for_result(result)
        key = (str(result.get("model") or ""), method)
        grouped.setdefault(key, []).append(result)

    stored: dict[tuple[str, str], Mapping[str, Any]] = {}
    for group in groups:
        if not isinstance(group, dict):
            raise RQ3SymbolicStatisticsError("Symbolic summary contains a non-object group")
        key = (str(group.get("model") or ""), method_for_result(group))
        if key in stored:
            raise RQ3SymbolicStatisticsError(f"Duplicate summary group: {key}")
        stored[key] = group

    rows: list[SymbolicRow] = []
    expected_checks_per_group: int | None = None
    for model in models:
        for method in methods:
            key = (model, method)
            values = grouped.get(key)
            if values is None:
                raise RQ3SymbolicStatisticsError(f"Missing symbolic group: {key}")
            row = summarize_group(model, method, values)
            if row.attempted != EXPECTED_TASKS_PER_GROUP:
                raise RQ3SymbolicStatisticsError(
                    f"Expected {EXPECTED_TASKS_PER_GROUP} tasks for {key}, got {row.attempted}"
                )
            if row.missing_rows:
                raise RQ3SymbolicStatisticsError(f"Missing DB rows for {key}: {row.missing_rows}")
            if expected_checks_per_group is None:
                expected_checks_per_group = row.expected_checks
            elif row.expected_checks != expected_checks_per_group:
                raise RQ3SymbolicStatisticsError(
                    f"Inconsistent symbolic denominator for {key}: "
                    f"{row.expected_checks} != {expected_checks_per_group}"
                )
            validate_stored_summary(row, stored.get(key))
            rows.append(row)
    return rows


def percentage(count: int, total: int) -> str:
    return "N/A" if total <= 0 else f"{count / total * 100:.2f}% ({count}/{total})"


def print_table(rows: Sequence[SymbolicRow]) -> None:
    headers = [
        "Model",
        "Method",
        "Compile Rate",
        "Symbolic Check Pass Rate",
        "Symbolic Pass@1",
    ]
    values = [
        [
            row.model,
            row.method,
            percentage(row.compiled, row.attempted),
            percentage(row.passed_checks, row.expected_checks),
            percentage(row.symbolic_pass_at_1_count, row.attempted),
        ]
        for row in rows
    ]
    widths = [len(header) for header in headers]
    for value_row in values:
        for index, value in enumerate(value_row):
            widths[index] = max(widths[index], len(value))
    print("\nRQ3 Symbolic Testing Statistics (Halmos)")
    line = "  ".join(header.ljust(widths[index]) for index, header in enumerate(headers))
    print(line)
    print("=" * len(line))
    for value_row in values:
        print("  ".join(value.ljust(widths[index]) for index, value in enumerate(value_row)))


def write_csv(path: Path, rows: Sequence[SymbolicRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(asdict(rows[0])) if rows else []
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(asdict(row) for row in rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the RQ3 Halmos symbolic-testing table")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--models", default=",".join(TARGET_MODELS))
    parser.add_argument("--methods", default=",".join(METHOD_ORDER))
    args = parser.parse_args()

    try:
        models = parse_csv(args.models)
        methods = normalize_methods(args.methods)
        rows = load_rows(args.report, models, methods)
        print_table(rows)
        write_csv(args.output, rows)
        print(f"\nWrote: {args.output}")
        return 0
    except (OSError, json.JSONDecodeError, RQ3SymbolicStatisticsError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
