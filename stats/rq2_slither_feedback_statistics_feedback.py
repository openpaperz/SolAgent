#!/usr/bin/env python3
"""RQ2 Slither-feedback statistics matched on feedback-test outcomes.

This preserves the original RQ2 feedback-test analysis and adds a stricter
paired comparison restricted to files for which both variants pass every
feedback test in the selected round.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from dataclasses import replace
from pathlib import Path
from typing import Mapping, Sequence

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.rq2_slither_feedback_statistics import (
    DEFAULT_SUPPLEMENTAL_SLITHER_DIR,
    TARGET_MODELS,
    PairedResult,
    SelectedRound,
    StatisticsError,
    connect_read_only,
    exact_sign_test_p_value,
    holm_adjust,
    load_group,
    load_supplemental_scans,
    compare_pairs,
    paired_result_rows,
    print_table,
    validate_tables,
    write_paired_csv,
)


DEFAULT_CSV = "stats/slither/rq2/rq2_slither_feedback_statistics_feedback.csv"


def compare_both_full_pass(
    full: Mapping[str, SelectedRound],
    no_slither: Mapping[str, SelectedRound],
) -> PairedResult:
    pairs = []
    for file_path in set(full) & set(no_slither):
        left = full[file_path]
        right = no_slither[file_path]
        if not (
            left.full_pass
            and right.full_pass
            and left.scan_valid
            and right.scan_valid
        ):
            continue
        pairs.append((left, right))

    lower = sum(left.vuln_count < right.vuln_count for left, right in pairs)
    higher = sum(left.vuln_count > right.vuln_count for left, right in pairs)
    equal = len(pairs) - lower - higher
    return PairedResult(
        files=len(pairs),
        full_findings=sum(left.vuln_count for left, _ in pairs),
        no_slither_findings=sum(right.vuln_count for _, right in pairs),
        full_lower=lower,
        equal=equal,
        full_higher=higher,
        p_value=exact_sign_test_p_value(lower, higher),
    )


def print_both_full_pass(
    models: Sequence[str],
    groups: Mapping[str, tuple[Mapping[str, SelectedRound], Mapping[str, SelectedRound]]],
) -> None:
    results = [compare_both_full_pass(*groups[model]) for model in models]
    adjusted = holm_adjust([result.p_value for result in results])
    results = [
        replace(result, adjusted_p_value=adjusted[index])
        for index, result in enumerate(results)
    ]

    print("\n[Both selected outputs pass all feedback tests]")
    print_table(
        ["Model", "Files", "Full/No Findings", "Lower/Equal/Higher", "p", "Holm p"],
        [
            [
                model,
                result.files,
                f"{result.full_findings}/{result.no_slither_findings}",
                f"{result.full_lower}/{result.equal}/{result.full_higher}",
                f"{result.p_value:.6f}",
                f"{result.adjusted_p_value:.6f}",
            ]
            for model, result in zip(models, results)
        ],
    )
    print("\nNote: lower/equal/higher is Full relative to w/o Slither feedback.")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="RQ2 paired Slither-feedback statistics using feedback tests"
    )
    parser.add_argument("--db", default="output/progress.db", help="SQLite experiment database")
    parser.add_argument("--csv", default=DEFAULT_CSV, help="Output CSV path")
    parser.add_argument(
        "--models",
        default=",".join(TARGET_MODELS),
        help="Comma-separated model names",
    )
    parser.add_argument(
        "--supplemental-slither-dir",
        default=str(DEFAULT_SUPPLEMENTAL_SLITHER_DIR),
        help="Directory containing successful exact-code Slither rescans",
    )
    args = parser.parse_args()
    models = [model.strip() for model in args.models.split(",") if model.strip()]

    try:
        supplemental_scans = load_supplemental_scans(
            Path(args.supplemental_slither_dir)
        )
        connection = connect_read_only(args.db)
        validate_tables(connection)
        groups = {}
        for model in models:
            full = load_group(
                connection,
                "process_tracking",
                model,
                supplemental_scans=supplemental_scans,
            )
            no_slither = load_group(
                connection,
                "process_tracking_ablation",
                model,
                ablation_type=3,
                supplemental_scans=supplemental_scans,
            )
            if not full or not no_slither:
                print(
                    f"[WARNING] Skipping {model}: Full={len(full)}, "
                    f"w/o Slither feedback={len(no_slither)}",
                    file=sys.stderr,
                )
                continue
            groups[model] = (full, no_slither)

        selected_models = [model for model in models if model in groups]
        if not selected_models:
            raise StatisticsError("No complete Full/No-Slither model groups found")
        matched_results = [
            compare_pairs(*groups[model], require_same_tests=True)
            for model in selected_models
        ]
        print("\nRQ2 Slither-Feedback Analysis Using Feedback Tests")
        print("Selection: max passed -> min H+M+L among identical (passed,total) -> earliest")
        adjusted = holm_adjust([result.p_value for result in matched_results])
        matched_results = [
            replace(result, adjusted_p_value=adjusted[index])
            for index, result in enumerate(matched_results)
        ]
        print("\n[Identical selected feedback-test (passed,total)]")
        print_table(
            ["Model", "Files", "Full/No Findings", "Lower/Equal/Higher", "Reduction", "p", "Holm p"],
            [
                [
                    model,
                    result.files,
                    f"{result.full_findings}/{result.no_slither_findings}",
                    f"{result.full_lower}/{result.equal}/{result.full_higher}",
                    (
                        f"{100.0 * (result.no_slither_findings - result.full_findings) / result.no_slither_findings:.2f}%"
                        if result.no_slither_findings else "n/a"
                    ),
                    f"{result.p_value:.6f}",
                    f"{result.adjusted_p_value:.6f}",
                ]
                for model, result in zip(selected_models, matched_results)
            ],
        )
        full_pass_results = [compare_both_full_pass(*groups[model]) for model in selected_models]
        print_both_full_pass(selected_models, groups)
        rows = paired_result_rows(
            selected_models,
            [
                ("feedback_functionality_matched", matched_results),
                ("feedback_both_full_pass", full_pass_results),
            ],
        )
        write_paired_csv(Path(args.csv), rows)
        print(f"Wrote: {args.csv}")
        connection.close()
        return 0
    except (sqlite3.Error, StatisticsError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
