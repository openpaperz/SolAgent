#!/usr/bin/env python3
"""RQ1-style Slither table for Mimo SolAgent versus OpenCode."""

from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.mimo_opencode_utils import (  # noqa: E402
    DEFAULT_ARTIFACT_DIR,
    DEFAULT_DB,
    DEFAULT_OPENCODE_EVAL,
    DEFAULT_SOLAGENT_EVAL,
    METHODS,
    MODEL,
    MimoComparisonError,
    SecuritySample,
    load_security_samples,
)


DEFAULT_OUTPUT = Path("stats/slither") / f"{Path(__file__).stem}.csv"


def build_rows(groups: Mapping[str, Mapping[str, SecuritySample]]) -> list[dict[str, Any]]:
    primary: dict[str, dict[str, Any]] = {}
    for method in METHODS:
        values = list(groups[method].values())
        full_pass = [sample for sample in values if sample.eval_full_pass]
        safe = [sample for sample in full_pass if sample.scan_valid and sample.finding_count == 0]
        primary[method] = {
            "attempted": len(values),
            "full_pass": len(full_pass),
            "safe_full_pass": len(safe),
        }

    solagent = groups["SolAgent"]
    opencode = groups["OpenCode"]
    pairs = [
        (opencode[file_path], solagent[file_path])
        for file_path in sorted(set(solagent) & set(opencode))
        if opencode[file_path].eval_full_pass
        and solagent[file_path].eval_full_pass
        and opencode[file_path].scan_valid
        and solagent[file_path].scan_valid
        and opencode[file_path].sloc
        and solagent[file_path].sloc
    ]
    baseline_findings = sum(left.finding_count for left, _ in pairs)
    solagent_findings = sum(right.finding_count for _, right in pairs)
    baseline_sloc = sum(left.sloc for left, _ in pairs)
    solagent_sloc = sum(right.sloc for _, right in pairs)
    baseline_density = baseline_findings / baseline_sloc * 1000 if baseline_sloc else None
    solagent_density = solagent_findings / solagent_sloc * 1000 if solagent_sloc else None

    rows: list[dict[str, Any]] = []
    for method in METHODS:
        item = primary[method]
        row = {
            "model": MODEL,
            "method": method,
            **item,
            "secure_pass_at_1": item["safe_full_pass"] / item["attempted"],
            "zero_finding_at_full_pass": (
                item["safe_full_pass"] / item["full_pass"] if item["full_pass"] else None
            ),
            "baseline_solagent_findings_with_n": None,
            "finding_count_reduction": None,
            "baseline_solagent_findings_per_kloc": None,
        }
        if method == "OpenCode":
            row.update(
                {
                    "paired_files": len(pairs),
                    "baseline_findings": baseline_findings,
                    "solagent_findings": solagent_findings,
                    "baseline_solagent_findings_with_n": (
                        f"{baseline_findings}/{solagent_findings} (n={len(pairs)})"
                    ),
                    "finding_count_reduction": (
                        (baseline_findings - solagent_findings) / baseline_findings
                        if baseline_findings
                        else None
                    ),
                    "baseline_findings_per_kloc": baseline_density,
                    "solagent_findings_per_kloc": solagent_density,
                    "baseline_solagent_findings_per_kloc": (
                        f"{baseline_density:.2f}/{solagent_density:.2f}"
                        if baseline_density is not None and solagent_density is not None
                        else None
                    ),
                }
            )
        rows.append(row)
    return rows


def rate(value: float | None, numerator: int, denominator: int) -> str:
    return "N/A" if value is None else f"{value * 100:.2f}% ({numerator}/{denominator})"


def print_rows(rows: Sequence[Mapping[str, Any]], analyzer: str = "Slither") -> None:
    headers = [
        "Model",
        "Method",
        "SecurePass@1",
        "Zero-Finding@FullPass",
        "Baseline/SolAgent Findings (n)",
        "Finding Count Reduction ↑",
        "Baseline/SolAgent Findings/KLOC",
    ]
    values = []
    for row in rows:
        values.append(
            [
                row["model"],
                row["method"],
                rate(row["secure_pass_at_1"], row["safe_full_pass"], row["attempted"]),
                rate(
                    row["zero_finding_at_full_pass"],
                    row["safe_full_pass"],
                    row["full_pass"],
                ),
                row.get("baseline_solagent_findings_with_n") or "—",
                (
                    "—"
                    if row.get("finding_count_reduction") is None
                    else f"{row['finding_count_reduction'] * 100:+.2f}%"
                ),
                row.get("baseline_solagent_findings_per_kloc") or "—",
            ]
        )
    widths = [max(len(str(row[i])) for row in [headers, *values]) for i in range(len(headers))]
    print(f"\nMimo SolAgent vs OpenCode: Eval-FullPass {analyzer} Security")
    line = "  ".join(header.ljust(widths[i]) for i, header in enumerate(headers))
    print(line)
    print("=" * len(line))
    for row in values:
        print("  ".join(str(value).ljust(widths[i]) for i, value in enumerate(row)))


def write_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames: list[str] = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--artifact-dir", type=Path, default=DEFAULT_ARTIFACT_DIR)
    parser.add_argument("--solagent-report", type=Path, default=DEFAULT_SOLAGENT_EVAL)
    parser.add_argument("--opencode-report", type=Path, default=DEFAULT_OPENCODE_EVAL)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        groups = load_security_samples(
            args.db,
            args.artifact_dir,
            args.solagent_report,
            args.opencode_report,
        )
        rows = build_rows(groups)
        print_rows(rows)
        write_csv(args.output, rows)
        print(f"\nWrote: {args.output}")
        return 0
    except (OSError, MimoComparisonError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
