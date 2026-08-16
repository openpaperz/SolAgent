#!/usr/bin/env python3
"""Shared runner for one RQ2 cross-analyzer and one test regime."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, Mapping, Sequence, Tuple


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from stats.rq2_security_cross_analyzer_statistics import (  # noqa: E402
    ANALYZER_LABELS,
    DEFAULT_EVAL_REPORT,
    load_expected_samples,
    load_external_records,
    paired_rows,
    write_csv,
)
from stats.rq2_slither_feedback_statistics import (  # noqa: E402
    TARGET_MODELS,
    StatisticsError,
    print_table,
)


REGIMES: Dict[str, Tuple[Tuple[str, str], Tuple[str, str]]] = {
    "feedback": (
        (
            "feedback_functionality_matched",
            "Identical selected feedback-test (passed,total)",
        ),
        (
            "feedback_both_full_pass",
            "Both selected outputs pass all feedback tests",
        ),
    ),
    "eval": (
        (
            "functionality_matched",
            "Identical independent-eval (passed,expected_tests)",
        ),
        (
            "both_full_pass",
            "Both selected outputs pass all independent eval tests",
        ),
    ),
}


def model_rows(rows: Sequence[Mapping[str, Any]]) -> list[Dict[str, Any]]:
    return [dict(row) for row in rows if row["model"] != "ALL"]


def print_rows(title: str, rows: Sequence[Mapping[str, Any]]) -> None:
    print(f"\n[{title}]")
    print_table(
        [
            "Model",
            "Files",
            "Full/No Findings",
            "Lower/Equal/Higher",
            "Reduction",
            "p",
            "Holm p",
        ],
        [
            [
                row["model"],
                row["files"],
                f"{row['full_findings']}/{row['no_slither_findings']}",
                f"{row['full_lower']}/{row['equal']}/{row['full_higher']}",
                (
                    "n/a"
                    if row["finding_reduction"] is None
                    else f"{row['finding_reduction'] * 100:.2f}%"
                ),
                f"{row['p_value']:.6f}",
                f"{row['holm_p_within_analyzer']:.6f}",
            ]
            for row in model_rows(rows)
        ],
    )


def run_analyzer_statistics(
    analyzer: str,
    regime: str,
    db_path: str,
    eval_report: Path,
    summary_path: Path,
    models: Sequence[str],
    csv_path: Path,
    output_path: Path | None = None,
) -> Dict[str, Any]:
    if analyzer not in ANALYZER_LABELS or analyzer == "slither":
        raise StatisticsError(f"Unsupported independent analyzer: {analyzer}")
    if regime not in REGIMES:
        raise StatisticsError(f"Unsupported test regime: {regime}")

    expected, eval_meta = load_expected_samples(db_path, eval_report, models)
    records = load_external_records(analyzer, summary_path, expected)
    analyzer_records = {analyzer: records}
    (matched_mode, matched_title), (full_mode, full_title) = REGIMES[regime]
    matched = paired_rows(analyzer_records, models, matched_mode)
    both_full_pass = paired_rows(analyzer_records, models, full_mode)

    result = {
        "analyzer": analyzer,
        "analyzer_name": ANALYZER_LABELS[analyzer],
        "regime": regime,
        "db_path": db_path,
        "eval_report": str(eval_report),
        "eval_meta": dict(eval_meta),
        "summary_path": str(summary_path),
        "models": list(models),
        "functionality_matched": matched,
        "both_full_pass": both_full_pass,
        "notes": [
            "Lower/equal/higher is Full relative to w/o Slither feedback.",
            "Holm correction is applied across the configured models.",
            "Only complete scans on both sides are included.",
        ],
    }

    write_csv(csv_path, [*model_rows(matched), *model_rows(both_full_pass)])
    if output_path is not None:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False),
            encoding="utf-8",
        )

    print(f"\nRQ2 {ANALYZER_LABELS[analyzer]} Analysis Using {regime.title()} Tests")
    print_rows(matched_title, matched)
    print_rows(full_title, both_full_pass)
    print("\nNote: lower/equal/higher is Full relative to w/o Slither feedback.")
    if output_path is not None:
        print(f"Wrote: {output_path}")
    print(f"Wrote: {csv_path}")
    return result


def analyzer_cli(
    analyzer: str,
    regime: str,
    default_summary: str,
    default_output_or_csv: str,
    default_csv: str | None = None,
) -> int:
    parser = argparse.ArgumentParser(
        description=(f"RQ2 {ANALYZER_LABELS[analyzer]} statistics using {regime} tests")
    )
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--eval-report", default=DEFAULT_EVAL_REPORT)
    parser.add_argument("--summary", default=default_summary)
    parser.add_argument("--models", default=",".join(TARGET_MODELS))
    legacy_json_output = default_csv is not None
    resolved_csv = default_csv if default_csv is not None else default_output_or_csv
    if legacy_json_output:
        parser.add_argument("--output", default=default_output_or_csv)
    parser.add_argument("--csv", default=resolved_csv)
    args = parser.parse_args()
    models = [item.strip() for item in args.models.split(",") if item.strip()]

    try:
        run_analyzer_statistics(
            analyzer,
            regime,
            args.db,
            Path(args.eval_report),
            Path(args.summary),
            models,
            Path(args.csv),
            Path(args.output) if legacy_json_output else None,
        )
        return 0
    except (OSError, StatisticsError, ValueError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1
