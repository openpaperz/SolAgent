#!/usr/bin/env python3
"""RQ3-style symbolic-testing table for Mimo SolAgent versus OpenCode."""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from dataclasses import asdict
from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.mimo_opencode_utils import EXPECTED_TASKS, MODEL, MimoComparisonError  # noqa: E402
from stats.rq3_symbolic_testing_statistics import (  # noqa: E402
    SymbolicRow,
    percentage,
    summarize_group,
)


DEFAULT_SOLAGENT_REPORT = Path("testing/symbolic/mimo_solagent_verify_symbolic.json")
DEFAULT_OPENCODE_REPORT = Path("testing/symbolic/mimo_opencode_verify_symbolic.json")
DEFAULT_OUTPUT = Path("stats/symbolic") / f"{Path(__file__).stem}.csv"


def load_row(path: Path, method: str, source: str) -> SymbolicRow:
    if not path.is_file():
        raise MimoComparisonError(f"Symbolic report not found: {path}")
    report = json.loads(path.read_text(encoding="utf-8"))
    results = report.get("results")
    if not isinstance(results, list):
        raise MimoComparisonError(f"Symbolic report has no results list: {path}")
    if len(results) != EXPECTED_TASKS:
        raise MimoComparisonError(
            f"Expected {EXPECTED_TASKS} symbolic results in {path}, got {len(results)}"
        )
    for result in results:
        if result.get("source") != source or result.get("model") != MODEL:
            raise MimoComparisonError(f"Unexpected symbolic row identity in {path}")
    return summarize_group(MODEL, method, results)


def print_rows(rows: list[SymbolicRow]) -> None:
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
    widths = [max(len(str(row[i])) for row in [headers, *values]) for i in range(len(headers))]
    print("\nMimo SolAgent vs OpenCode: Halmos Symbolic Testing")
    line = "  ".join(header.ljust(widths[i]) for i, header in enumerate(headers))
    print(line)
    print("=" * len(line))
    for row in values:
        print("  ".join(str(value).ljust(widths[i]) for i, value in enumerate(row)))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--solagent-report", type=Path, default=DEFAULT_SOLAGENT_REPORT)
    parser.add_argument("--opencode-report", type=Path, default=DEFAULT_OPENCODE_REPORT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        rows = [
            load_row(args.solagent_report, "SolAgent", "solagent"),
            load_row(args.opencode_report, "OpenCode", "opencode"),
        ]
        if rows[0].expected_checks != rows[1].expected_checks:
            raise MimoComparisonError("Symbolic reports use different check denominators")
        print_rows(rows)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=list(asdict(rows[0])),
                lineterminator="\n",
            )
            writer.writeheader()
            writer.writerows(asdict(row) for row in rows)
        print(f"\nWrote: {args.output}")
        return 0
    except (OSError, json.JSONDecodeError, MimoComparisonError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
