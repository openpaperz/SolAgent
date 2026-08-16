#!/usr/bin/env python3
"""RQ1-style Aderyn table for Mimo SolAgent versus OpenCode."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.mimo_opencode_security_slither_statistics import (  # noqa: E402
    build_rows,
    print_rows,
    write_csv,
)
from stats.mimo_opencode_utils import (  # noqa: E402
    DEFAULT_OPENCODE_EVAL,
    DEFAULT_SOLAGENT_EVAL,
    METHODS,
    MODEL,
    MimoComparisonError,
    SecuritySample,
    load_eval_groups,
    read_json,
)


DEFAULT_SUMMARY = Path("stats/aderyn/mimo_opencode/summary.json")
DEFAULT_OUTPUT = Path("stats/aderyn") / f"{Path(__file__).stem}.csv"


def load_aderyn_groups(
    summary_path: Path,
    solagent_report: Path,
    opencode_report: Path,
) -> dict[str, dict[str, SecuritySample]]:
    eval_groups = load_eval_groups(solagent_report, opencode_report)
    summary = read_json(summary_path)
    records = summary.get("records")
    if not isinstance(records, list):
        raise MimoComparisonError(f"Aderyn summary has no records list: {summary_path}")
    groups: dict[str, dict[str, SecuritySample]] = {method: {} for method in METHODS}
    for raw in records:
        if not isinstance(raw, dict):
            raise MimoComparisonError("Aderyn summary contains a non-object record")
        method = str(raw.get("method") or "")
        file_path = str(raw.get("file_path") or "")
        if method not in groups or file_path not in eval_groups[method]:
            raise MimoComparisonError(f"Unexpected Aderyn record: {(method, file_path)}")
        count = raw.get("finding_count") if raw.get("status") == "analyzed" else None
        sloc = raw.get("sloc") if raw.get("status") == "analyzed" else None
        groups[method][file_path] = SecuritySample(
            model=MODEL,
            method=method,
            file_path=file_path,
            code=None,
            sloc=sloc if isinstance(sloc, int) and sloc > 0 else None,
            finding_count=count if isinstance(count, int) and count >= 0 else None,
            eval_result=eval_groups[method][file_path],
        )
    for method in METHODS:
        if set(groups[method]) != set(eval_groups[method]):
            raise MimoComparisonError(f"Incomplete Aderyn records for {method}")
    return groups


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--solagent-report", type=Path, default=DEFAULT_SOLAGENT_EVAL)
    parser.add_argument("--opencode-report", type=Path, default=DEFAULT_OPENCODE_EVAL)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        rows = build_rows(
            load_aderyn_groups(args.summary, args.solagent_report, args.opencode_report)
        )
        print_rows(rows, analyzer="Aderyn")
        write_csv(args.output, rows)
        print(f"\nWrote: {args.output}")
        return 0
    except (OSError, MimoComparisonError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
