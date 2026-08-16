#!/usr/bin/env python3
"""Test-level correctness for Mimo SolAgent versus OpenCode."""

from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.mimo_opencode_utils import (
    DEFAULT_OPENCODE_EVAL,
    DEFAULT_SOLAGENT_EVAL,
    METHODS,
    MODEL,
    MimoComparisonError,
    load_eval_groups,
)


DEFAULT_OUTPUT = Path("stats/eval") / f"{Path(__file__).stem}.csv"


def summarize(method: str, results: Mapping[str, Mapping[str, Any]]) -> dict[str, Any]:
    values = list(results.values())
    attempted = len(values)
    compiled = sum(
        not row.get("compile_error")
        and not row.get("extract_error")
        and int(row.get("forge_total") or 0) > 0
        for row in values
    )
    passed = sum(int(row.get("passed") or 0) for row in values)
    expected = sum(int(row.get("expected_tests") or 0) for row in values)
    full_pass = sum(bool(row.get("ok")) for row in values)
    return {
        "model": MODEL,
        "method": method,
        "attempted": attempted,
        "compiled": compiled,
        "compile_rate": compiled / attempted,
        "passed_tests": passed,
        "expected_tests": expected,
        "test_pass_rate": passed / expected,
        "pass_at_1_count": full_pass,
        "pass_at_1": full_pass / attempted,
    }


def format_rate(count: int, total: int) -> str:
    return f"{count / total * 100:.2f}% ({count}/{total})"


def print_rows(rows: Sequence[Mapping[str, Any]]) -> None:
    headers = ["Model", "Method", "Compile Rate", "Test Pass Rate", "Pass@1"]
    values = [
        [
            row["model"],
            row["method"],
            format_rate(row["compiled"], row["attempted"]),
            format_rate(row["passed_tests"], row["expected_tests"]),
            format_rate(row["pass_at_1_count"], row["attempted"]),
        ]
        for row in rows
    ]
    widths = [max(len(str(row[i])) for row in [headers, *values]) for i in range(len(headers))]
    line = "  ".join(header.ljust(widths[i]) for i, header in enumerate(headers))
    print("\nMimo SolAgent vs OpenCode: Independent Eval Correctness")
    print(line)
    print("=" * len(line))
    for row in values:
        print("  ".join(str(value).ljust(widths[i]) for i, value in enumerate(row)))


def write_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--solagent-report", type=Path, default=DEFAULT_SOLAGENT_EVAL)
    parser.add_argument("--opencode-report", type=Path, default=DEFAULT_OPENCODE_EVAL)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        groups = load_eval_groups(args.solagent_report, args.opencode_report)
        rows = [summarize(method, groups[method]) for method in METHODS]
        print_rows(rows)
        write_csv(args.output, rows)
        print(f"\nWrote: {args.output}")
        return 0
    except (OSError, MimoComparisonError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
