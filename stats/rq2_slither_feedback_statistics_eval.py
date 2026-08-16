#!/usr/bin/env python3
"""RQ2 Slither-feedback statistics matched on independent eval-test outcomes."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from dataclasses import replace
from pathlib import Path
from typing import Callable, Mapping, Sequence

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
    paired_result_rows,
    print_table,
    validate_tables,
    write_paired_csv,
)


DEFAULT_EVAL_REPORT = "testing/eval/rq2_verify_eval_ablation.json"
DEFAULT_CSV = "stats/slither/rq2/rq2_slither_feedback_statistics_eval.csv"


def load_eval_groups(report_path: str) -> dict[tuple[str, str], dict[str, dict]]:
    path = Path(report_path)
    if not path.is_file():
        raise StatisticsError(f"Eval report not found: {report_path}")
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise StatisticsError(f"Cannot read eval report {report_path}: {error}") from error
    results = report.get("results")
    if not isinstance(results, list):
        raise StatisticsError(f"Eval report has no results list: {report_path}")

    groups: dict[tuple[str, str], dict[str, dict]] = {}
    for result in results:
        if not isinstance(result, dict) or result.get("source") not in {"full", "no_slither"}:
            continue
        key = (str(result.get("source")), str(result.get("model")))
        sol_path = result.get("sol_path")
        if sol_path:
            groups.setdefault(key, {})[str(sol_path)] = result
    return groups


def eval_compiled(result: Mapping) -> bool:
    return not result.get("compile_error") and int(result.get("forge_total") or 0) > 0


def eval_score(result: Mapping) -> tuple[int, int]:
    return int(result.get("passed") or 0), int(result.get("expected_tests") or 0)


def eval_full_pass(result: Mapping) -> bool:
    passed, expected = eval_score(result)
    return expected > 0 and passed == expected


def compare_eval_pairs(
    full_records: Mapping[str, SelectedRound],
    no_slither_records: Mapping[str, SelectedRound],
    full_eval: Mapping[str, Mapping],
    no_slither_eval: Mapping[str, Mapping],
    predicate: Callable[[Mapping, Mapping], bool],
) -> PairedResult:
    pairs = []
    common_paths = set(full_records) & set(no_slither_records) & set(full_eval) & set(no_slither_eval)
    for file_path in common_paths:
        left = full_records[file_path]
        right = no_slither_records[file_path]
        left_eval = full_eval[file_path]
        right_eval = no_slither_eval[file_path]
        if not (left.scan_valid and right.scan_valid):
            continue
        if not (eval_compiled(left_eval) and eval_compiled(right_eval)):
            continue
        if not predicate(left_eval, right_eval):
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


def validate_selected_rounds(
    model: str,
    source: str,
    records: Mapping[str, SelectedRound],
    eval_results: Mapping[str, Mapping],
) -> None:
    mismatches = []
    for file_path in set(records) & set(eval_results):
        if records[file_path].round_index != eval_results[file_path].get("best_round"):
            mismatches.append(file_path)
    if mismatches:
        raise StatisticsError(
            f"Selected-round mismatch for {source}/{model}: {len(mismatches)} files"
        )


def print_comparison(title: str, models: Sequence[str], results: Sequence[PairedResult]) -> None:
    adjusted = holm_adjust([result.p_value for result in results])
    adjusted_results = [
        replace(result, adjusted_p_value=adjusted[index])
        for index, result in enumerate(results)
    ]
    print(f"\n[{title}]")
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
                    if result.no_slither_findings
                    else "n/a"
                ),
                f"{result.p_value:.6f}",
                f"{result.adjusted_p_value:.6f}",
            ]
            for model, result in zip(models, adjusted_results)
        ],
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="RQ2 paired Slither-feedback statistics using independent eval tests"
    )
    parser.add_argument("--db", default="output/progress.db", help="SQLite experiment database")
    parser.add_argument("--eval-report", default=DEFAULT_EVAL_REPORT, help="RQ2 eval JSON report")
    parser.add_argument("--csv", default=DEFAULT_CSV, help="Output CSV path")
    parser.add_argument(
        "--models", default=",".join(TARGET_MODELS), help="Comma-separated model names"
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
        eval_groups = load_eval_groups(args.eval_report)
        connection = connect_read_only(args.db)
        validate_tables(connection)
        selected_models = []
        same_eval_results = []
        both_full_pass_results = []
        for model in models:
            full_records = load_group(
                connection,
                "process_tracking",
                model,
                supplemental_scans=supplemental_scans,
            )
            no_slither_records = load_group(
                connection,
                "process_tracking_ablation",
                model,
                ablation_type=3,
                supplemental_scans=supplemental_scans,
            )
            full_eval = eval_groups.get(("full", model), {})
            no_slither_eval = eval_groups.get(("no_slither", model), {})
            if not all((full_records, no_slither_records, full_eval, no_slither_eval)):
                print(
                    f"[WARNING] Skipping {model}: FullDB={len(full_records)}, "
                    f"NoSlitherDB={len(no_slither_records)}, FullEval={len(full_eval)}, "
                    f"NoSlitherEval={len(no_slither_eval)}",
                    file=sys.stderr,
                )
                continue
            validate_selected_rounds(model, "full", full_records, full_eval)
            validate_selected_rounds(model, "no_slither", no_slither_records, no_slither_eval)
            selected_models.append(model)
            same_eval_results.append(
                compare_eval_pairs(
                    full_records,
                    no_slither_records,
                    full_eval,
                    no_slither_eval,
                    lambda left, right: eval_score(left) == eval_score(right),
                )
            )
            both_full_pass_results.append(
                compare_eval_pairs(
                    full_records,
                    no_slither_records,
                    full_eval,
                    no_slither_eval,
                    lambda left, right: eval_full_pass(left) and eval_full_pass(right),
                )
            )
        connection.close()
        if not selected_models:
            raise StatisticsError("No complete Full/No-Slither model groups found")

        print("\nRQ2 Slither-Feedback Analysis Using Independent Eval Tests")
        print("Selection: max feedback-test passed -> min H+M+L on exact ties -> earliest")
        print("Pairing excludes eval compile failures and invalid Slither scans.")
        print_comparison(
            "Identical independent-eval (passed, expected_tests)",
            selected_models,
            same_eval_results,
        )
        print_comparison(
            "Both selected outputs pass all independent eval tests",
            selected_models,
            both_full_pass_results,
        )
        rows = paired_result_rows(
            selected_models,
            [
                ("functionality_matched", same_eval_results),
                ("both_full_pass", both_full_pass_results),
            ],
        )
        write_paired_csv(Path(args.csv), rows)
        print("\nNote: lower/equal/higher is Full relative to w/o Slither feedback.")
        print(f"Wrote: {args.csv}")
        return 0
    except (sqlite3.Error, StatisticsError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
