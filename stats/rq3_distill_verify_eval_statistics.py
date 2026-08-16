#!/usr/bin/env python3
"""Build the RQ3 distillation table from the fixed-seed eval report.

Unlike ``rq3_distill_statistics.py``, this script uses only independent eval
tests.  The 64 training files are excluded, leaving the same 17 held-out tasks
for every model.

Usage:
    python stats/rq3_distill_verify_eval_statistics.py
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
    CorrectnessRow,
    RQ1EvalStatisticsError,
    percentage,
    print_table,
    summarize_group,
    validate_result_selection,
)
from testing.rq3_distill_verify_eval import (  # noqa: E402
    FUZZ_SEED,
    MODELS,
    held_out_paths,
)


EXPECTED_TASKS_PER_MODEL = 17
EXPECTED_TESTS_PER_MODEL = 373
EXPECTED_SELECTION_POLICY = "test-first-security-second"
DEFAULT_REPORT = Path("testing/eval/rq3_distill_verify_eval_seed1.json")
DEFAULT_OUTPUT = Path("stats/eval") / f"{Path(__file__).stem}.csv"
DISPLAY_NAMES = {
    "Qwen/Qwen3-8B": "Qwen3-8B",
    "Qwen/Qwen3-32B": "Qwen3-32B",
    "solagent-4k-tracker-v1": "SOLAGENT-tracker-v1",
    "solagent-4k-tracker-v2": "SOLAGENT-tracker-v2",
}


class DistillEvalError(RuntimeError):
    """Raised when the distillation eval report is incomplete or inconsistent."""


@dataclass(frozen=True)
class DistillCorrectnessRow:
    model: str
    database_model: str
    method: str
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


def build_row(model: str, results: Sequence[Mapping[str, Any]]) -> DistillCorrectnessRow:
    base: CorrectnessRow = summarize_group(model, "SolAgent", results)
    return DistillCorrectnessRow(
        model=DISPLAY_NAMES[model],
        database_model=model,
        method="SolAgent",
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


def _summary_groups(report: Mapping[str, Any]) -> Dict[str, Mapping[str, Any]]:
    summary = report.get("summary")
    groups = summary.get("groups") if isinstance(summary, dict) else None
    if not isinstance(groups, list):
        raise DistillEvalError("Eval report has no summary.groups list")
    indexed: Dict[str, Mapping[str, Any]] = {}
    for group in groups:
        if not isinstance(group, dict):
            raise DistillEvalError("Eval report contains an invalid summary group")
        if group.get("source") != "solagent":
            raise DistillEvalError(f"Unexpected summary source: {group.get('source')!r}")
        model = str(group.get("model") or "")
        if model in indexed:
            raise DistillEvalError(f"Duplicate summary group for {model}")
        indexed[model] = group
    return indexed


def _validate_stored_summary(
    row: DistillCorrectnessRow,
    stored: Mapping[str, Any] | None,
) -> None:
    if stored is None:
        raise DistillEvalError(f"Missing stored summary for {row.database_model}")
    expected = {
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
        raise DistillEvalError(
            f"Stored summary mismatch for {row.database_model}: {mismatches}"
        )


def load_rows(path: Path) -> List[DistillCorrectnessRow]:
    if not path.is_file():
        raise DistillEvalError(f"Eval report not found: {path}")
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DistillEvalError(f"Cannot read eval report {path}: {error}") from error
    if not isinstance(report, dict) or not isinstance(report.get("results"), list):
        raise DistillEvalError(f"Eval report has no results list: {path}")

    config = report.get("config") or {}
    if config.get("fuzz_seed") != FUZZ_SEED:
        raise DistillEvalError("Eval report does not use fixed fuzz seed 1")
    if config.get("selection_policy") != EXPECTED_SELECTION_POLICY:
        raise DistillEvalError(
            "Eval report does not use test-first-security-second selection"
        )

    expected_paths = set(held_out_paths())
    if len(expected_paths) != EXPECTED_TASKS_PER_MODEL:
        raise DistillEvalError(
            f"Expected {EXPECTED_TASKS_PER_MODEL} held-out files, got {len(expected_paths)}"
        )

    grouped: Dict[str, List[Mapping[str, Any]]] = {model: [] for model in MODELS}
    seen: set[Tuple[str, str]] = set()
    for raw in report["results"]:
        if not isinstance(raw, dict):
            raise DistillEvalError("Eval report contains a non-object result")
        source = raw.get("source")
        model = str(raw.get("model") or "")
        sol_path = str(raw.get("sol_path") or "")
        if source != "solagent" or model not in grouped or not sol_path:
            raise DistillEvalError(
                f"Unexpected result identity: {(source, model, sol_path)}"
            )
        if sol_path not in expected_paths:
            raise DistillEvalError(f"Training or unknown file in eval report: {sol_path}")
        key = (model, sol_path)
        if key in seen:
            raise DistillEvalError(f"Duplicate eval task: {key}")
        seen.add(key)
        try:
            validate_result_selection(raw, "SolAgent")
        except RQ1EvalStatisticsError as error:
            raise DistillEvalError(str(error)) from error
        grouped[model].append(raw)

    stored_groups = _summary_groups(report)
    rows: List[DistillCorrectnessRow] = []
    for model in MODELS:
        results = grouped[model]
        actual_paths = {str(result["sol_path"]) for result in results}
        if actual_paths != expected_paths:
            missing = sorted(expected_paths - actual_paths)
            extra = sorted(actual_paths - expected_paths)
            raise DistillEvalError(
                f"Held-out task mismatch for {model}: missing={missing}, extra={extra}"
            )
        try:
            row = build_row(model, results)
        except RQ1EvalStatisticsError as error:
            raise DistillEvalError(str(error)) from error
        if row.attempted != EXPECTED_TASKS_PER_MODEL:
            raise DistillEvalError(
                f"Expected {EXPECTED_TASKS_PER_MODEL} tasks for {model}, got {row.attempted}"
            )
        if row.expected_tests != EXPECTED_TESTS_PER_MODEL:
            raise DistillEvalError(
                f"Expected {EXPECTED_TESTS_PER_MODEL} eval tests for {model}, "
                f"got {row.expected_tests}"
            )
        _validate_stored_summary(row, stored_groups.get(model))
        rows.append(row)
    return rows


def print_results(rows: Sequence[DistillCorrectnessRow]) -> None:
    print("\n" + "=" * 100)
    print("RQ-3 Distillation: Independent Eval Tests on 17 Held-Out Tasks, Fuzz Seed 1")
    print("=" * 100)
    print_table(
        ["Model", "Method", "Compile Rate", "Test Pass Rate", "Pass@1"],
        [
            [
                row.model,
                row.method,
                f"{percentage(row.compilation_rate)} ({row.compiled}/{row.attempted})",
                f"{percentage(row.test_pass_rate)} ({row.passed_tests}/{row.expected_tests})",
                f"{percentage(row.pass_at_1_rate)} ({row.pass_at_1}/{row.attempted})",
            ]
            for row in rows
        ],
    )
    print("\nNotes:")
    print("- All functionality comes from independent seed1 eval tests, not feedback tests.")
    print("- The same 17 files excluded from training and 373 tests are used for every model.")
    print("- Compilation/extraction failures remain in both denominators and pass zero tests.")
    print("- All models use test-first-security-second checkpoint selection.")


def write_csv(path: Path, rows: Sequence[DistillCorrectnessRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(asdict(rows[0])) if rows else []
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(asdict(row) for row in rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build the RQ3 fixed-seed independent-eval distillation table"
    )
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        rows = load_rows(args.report)
        write_csv(args.output, rows)
        print_results(rows)
        print(f"\nWrote: {args.output}")
        return 0
    except (OSError, ValueError, DistillEvalError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
