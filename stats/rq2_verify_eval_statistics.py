#!/usr/bin/env python3
"""Build the RQ2 ablation correctness table from the fixed-seed eval report.

Usage:
    python stats/rq2_verify_eval_statistics.py
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, List, Mapping, Sequence, Tuple


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from stats.rq1_verify_eval_statistics import (  # noqa: E402
    EXPECTED_TASKS_PER_GROUP,
    EXPECTED_TESTS_PER_GROUP,
    FIXED_FUZZ_SEED,
    CorrectnessRow,
    normalize_csv,
    percentage,
    print_table,
    summarize_group,
)


TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
DEFAULT_REPORT = Path("testing/eval/rq2_verify_eval_ablation.json")
DEFAULT_OUTPUT = Path("stats/eval") / f"{Path(__file__).stem}.csv"
EXPECTED_SELECTION_POLICY = "test-first-security-second"

REPORT_CONFIGURATIONS: Dict[str, Tuple[int, str]] = {
    "full": (0, "Full"),
    "no_forge": (2, "w/o Forge"),
    "no_slither": (3, "w/o Slither"),
    "no_tools": (4, "w/o Tools"),
}
CONFIGURATIONS: Dict[str, Tuple[int, str]] = {
    source: REPORT_CONFIGURATIONS[source]
    for source in ("full", "no_forge", "no_tools")
}
CONFIGURATION_ORDER = list(CONFIGURATIONS)
CONFIGURATION_ALIASES = {
    "full": "full",
    "no_forge": "no_forge",
    "no-forge": "no_forge",
    "w/o forge": "no_forge",
    "no_tools": "no_tools",
    "no-tools": "no_tools",
    "w/o tools": "no_tools",
}


class RQ2EvalStatisticsError(RuntimeError):
    """Raised when the RQ2 eval report cannot reproduce the paper table."""


@dataclass(frozen=True)
class AblationCorrectnessRow:
    model: str
    ablation_configuration: str
    source: str
    ablation_type: int
    attempted: int
    compiled: int
    compilation_rate: float
    passed_tests: int
    expected_tests: int
    test_pass_rate: float
    pass_at_1: int
    pass_at_1_rate: float
    compile_errors: int
    extract_errors: int
    missing_rows: int


def normalize_configurations(value: str) -> List[str]:
    configurations: List[str] = []
    for raw in normalize_csv(value):
        configuration = CONFIGURATION_ALIASES.get(raw.lower())
        if configuration is None:
            raise RQ2EvalStatisticsError(f"Unsupported ablation configuration: {raw}")
        if configuration not in configurations:
            configurations.append(configuration)
    return configurations


def validate_eval_result(result: Mapping[str, Any]) -> Tuple[str, str]:
    source = str(result.get("source") or "")
    model = str(result.get("model") or "")
    sol_path = str(result.get("sol_path") or "")
    if source not in REPORT_CONFIGURATIONS or not model or not sol_path:
        raise RQ2EvalStatisticsError(
            f"Incomplete or unsupported RQ2 result key: {(source, model, sol_path)}"
        )
    expected_type = REPORT_CONFIGURATIONS[source][0]
    if result.get("ablation_type") != expected_type:
        raise RQ2EvalStatisticsError(
            f"Ablation type mismatch for {(source, model, sol_path)}: "
            f"expected {expected_type}, got {result.get('ablation_type')!r}"
        )
    if result.get("fuzz_seed") != FIXED_FUZZ_SEED:
        raise RQ2EvalStatisticsError(
            f"Non-seed1 RQ2 result for {(source, model, sol_path)}: "
            f"{result.get('fuzz_seed')!r}"
        )
    if (
        result.get("extract_error") is None
        and result.get("selection_policy") != EXPECTED_SELECTION_POLICY
    ):
        raise RQ2EvalStatisticsError(
            f"Unexpected selection policy for {(source, model, sol_path)}: "
            f"{result.get('selection_policy')!r}"
        )
    return source, model


def build_row(
    model: str,
    source: str,
    results: Sequence[Mapping[str, Any]],
) -> AblationCorrectnessRow:
    base: CorrectnessRow = summarize_group(model, "SolAgent", results)
    ablation_type, display = CONFIGURATIONS[source]
    return AblationCorrectnessRow(
        model=model,
        ablation_configuration=display,
        source=source,
        ablation_type=ablation_type,
        attempted=base.attempted,
        compiled=base.compiled,
        compilation_rate=base.compilation_rate,
        passed_tests=base.passed_tests,
        expected_tests=base.expected_tests,
        test_pass_rate=base.test_level_correctness,
        pass_at_1=base.full_pass,
        pass_at_1_rate=base.full_pass_rate,
        compile_errors=base.compile_errors,
        extract_errors=base.extract_errors,
        missing_rows=base.missing_rows,
    )


def _summary_groups(report: Mapping[str, Any]) -> Dict[Tuple[str, str], Mapping[str, Any]]:
    summary = report.get("summary")
    groups = summary.get("groups") if isinstance(summary, dict) else None
    if not isinstance(groups, list):
        raise RQ2EvalStatisticsError("RQ2 eval report has no summary.groups list")
    indexed: Dict[Tuple[str, str], Mapping[str, Any]] = {}
    for group in groups:
        if not isinstance(group, dict):
            raise RQ2EvalStatisticsError("RQ2 eval report contains an invalid summary group")
        key = (str(group.get("source") or ""), str(group.get("model") or ""))
        if key in indexed:
            raise RQ2EvalStatisticsError(f"Duplicate RQ2 summary group: {key}")
        indexed[key] = group
    return indexed


def _validate_stored_summary(
    row: AblationCorrectnessRow,
    stored: Mapping[str, Any] | None,
) -> None:
    if stored is None:
        raise RQ2EvalStatisticsError(
            f"Missing RQ2 summary group for {(row.source, row.model)}"
        )
    expected = {
        "ablation_type": row.ablation_type,
        "sols": row.attempted,
        "passed_sols": row.pass_at_1,
        "failed_sols": row.attempted - row.pass_at_1,
        "expected_tests": row.expected_tests,
        "passed_tests": row.passed_tests,
        "failed_tests": row.expected_tests - row.passed_tests,
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
        raise RQ2EvalStatisticsError(
            f"Stored RQ2 summary mismatch for {(row.source, row.model)}: {mismatches}"
        )


def load_rows(
    report_path: Path,
    models: Sequence[str],
    configurations: Sequence[str],
    *,
    expected_tasks: int = EXPECTED_TASKS_PER_GROUP,
    expected_tests: int = EXPECTED_TESTS_PER_GROUP,
) -> List[AblationCorrectnessRow]:
    if not report_path.is_file():
        raise RQ2EvalStatisticsError(f"RQ2 eval report not found: {report_path}")
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RQ2EvalStatisticsError(
            f"Cannot read RQ2 eval report {report_path}: {error}"
        ) from error
    if not isinstance(report, dict) or not isinstance(report.get("results"), list):
        raise RQ2EvalStatisticsError(f"RQ2 eval report has no results list: {report_path}")

    meta = report.get("meta") or {}
    expected_total_tasks = (
        len(TARGET_MODELS) * len(REPORT_CONFIGURATIONS) * expected_tasks
    )
    if meta.get("interrupted") is not False:
        raise RQ2EvalStatisticsError("RQ2 eval report is interrupted or incomplete")
    if meta.get("fuzz_seed") != FIXED_FUZZ_SEED:
        raise RQ2EvalStatisticsError(
            f"RQ2 report is not fixed seed1: {meta.get('fuzz_seed')!r}"
        )
    if meta.get("selection_policy") != EXPECTED_SELECTION_POLICY:
        raise RQ2EvalStatisticsError(
            f"RQ2 report uses an unexpected selection policy: "
            f"{meta.get('selection_policy')!r}"
        )
    if meta.get("total_tasks") != expected_total_tasks or meta.get(
        "completed_tasks"
    ) != len(report["results"]):
        raise RQ2EvalStatisticsError(
            "RQ2 report task metadata does not match the complete 972-task experiment"
        )

    grouped: Dict[Tuple[str, str], List[Mapping[str, Any]]] = {}
    seen: set[Tuple[str, str, str]] = set()
    for raw in report["results"]:
        if not isinstance(raw, dict):
            raise RQ2EvalStatisticsError("RQ2 eval report contains a non-object result")
        source, model = validate_eval_result(raw)
        sol_path = str(raw["sol_path"])
        key = (source, model, sol_path)
        if key in seen:
            raise RQ2EvalStatisticsError(f"Duplicate RQ2 eval task: {key}")
        seen.add(key)
        grouped.setdefault((source, model), []).append(raw)

    stored_groups = _summary_groups(report)
    rows: List[AblationCorrectnessRow] = []
    for model in models:
        for source in configurations:
            results = grouped.get((source, model))
            if results is None:
                raise RQ2EvalStatisticsError(
                    f"Missing RQ2 method/model group: {(source, model)}"
                )
            row = build_row(model, source, results)
            _validate_stored_summary(row, stored_groups.get((source, model)))
            if row.attempted != expected_tasks:
                raise RQ2EvalStatisticsError(
                    f"Expected {expected_tasks} tasks for {(source, model)}, got {row.attempted}"
                )
            if row.expected_tests != expected_tests:
                raise RQ2EvalStatisticsError(
                    f"Expected {expected_tests} tests for {(source, model)}, got "
                    f"{row.expected_tests}"
                )
            rows.append(row)
    return rows


def print_results(rows: Sequence[AblationCorrectnessRow]) -> None:
    print("\n" + "=" * 125)
    print("RQ-2 Ablation Correctness: Independent Eval Tests, Fixed Fuzz Seed 1")
    print("=" * 125)
    print("\nMain Table")
    print_table(
        [
            "Model",
            "Ablation Configuration",
            "Compile Rate",
            "Test Pass Rate",
            "Pass@1",
        ],
        [
            [
                row.model,
                row.ablation_configuration,
                f"{percentage(row.compilation_rate)} ({row.compiled}/{row.attempted})",
                f"{percentage(row.test_pass_rate)} ({row.passed_tests}/{row.expected_tests})",
                f"{percentage(row.pass_at_1_rate)} ({row.pass_at_1}/{row.attempted})",
            ]
            for row in rows
        ],
    )
    print("\nNotes:")
    print("- All functionality comes from the complete independent seed1 RQ2 eval report, not database feedback tests.")
    print("- Compilation/extraction failures retain their eval tests in the denominator and contribute zero passes.")
    print("- Pass@1 = files that pass every eval test / all 81 attempted tasks.")
    print("- Every configuration uses test-first-security-second checkpoint selection.")


def write_csv(path: Path, rows: Sequence[AblationCorrectnessRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(asdict(rows[0])) if rows else []
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(asdict(row) for row in rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build the RQ2 seed1 eval ablation correctness table"
    )
    parser.add_argument("--report", default=str(DEFAULT_REPORT))
    parser.add_argument("--models", default=",".join(TARGET_MODELS))
    parser.add_argument(
        "--configurations", default=",".join(CONFIGURATION_ORDER)
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    args = parser.parse_args()

    try:
        models = normalize_csv(args.models)
        unknown_models = [model for model in models if model not in TARGET_MODELS]
        if unknown_models:
            raise RQ2EvalStatisticsError(
                "Unsupported model(s): " + ", ".join(unknown_models)
            )
        configurations = normalize_configurations(args.configurations)
        rows = load_rows(Path(args.report), models, configurations)
        output = Path(args.output)
        write_csv(output, rows)
        print_results(rows)
        print(f"\nWrote: {output}")
        return 0
    except (OSError, ValueError, RQ2EvalStatisticsError) as error:
        print(f"[ERROR] {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
