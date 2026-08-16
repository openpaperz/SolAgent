#!/usr/bin/env python3
"""Build the RQ1 test-level correctness table from fixed-seed eval reports.

Unlike ``rq1_statistics.py``, this script never reads feedback-test results from
``progress.db``.  Compilation, passed tests, and FullPass are reconstructed
only from the independent seed-1 eval reports.

Usage:
    python stats/rq1_verify_eval_statistics.py
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Sequence, Tuple


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from stats.rq1_eval_utils import eval_compiled, eval_test_fields


FIXED_FUZZ_SEED = "0x" + "0" * 63 + "1"
EXPECTED_TASKS_PER_GROUP = 81
EXPECTED_TESTS_PER_GROUP = 1708
TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
METHOD_ORDER = [
    "SolAgent",
    "SolAgent-Summary",
    "RawModel",
    "MetaGPT",
    "DeepCode",
    "QwenAgent",
    "Copilot",
]
DEFAULT_REPORTS = [
    Path("testing/eval/rq1_verify_eval_rawmodel_seed1.json"),
    Path("testing/eval/rq1_verify_eval_models_security_selected_seed1.json"),
    Path("testing/eval/rq1_verify_eval_solagent_summary_seed1.json"),
    Path("testing/eval/rq1_verify_eval_agents_seed1.json"),
]
DEFAULT_OUTPUT = Path("stats/eval") / f"{Path(__file__).stem}.csv"

AGENT_METHODS = {
    "metagpt": "MetaGPT",
    "deepcode": "DeepCode",
    "qwenagent": "QwenAgent",
    "copilot": "Copilot",
}
SOURCE_METHODS = {
    "rawmodel": "RawModel",
    "solagent": "SolAgent",
    "solagent-summary": "SolAgent-Summary",
}
METHOD_ALIASES = {
    "rawmodel": "RawModel",
    "raw-model": "RawModel",
    "solagent": "SolAgent",
    "solagent-summary": "SolAgent-Summary",
    **AGENT_METHODS,
}


class RQ1EvalStatisticsError(RuntimeError):
    """Raised when an eval report cannot reproduce the paper table."""


@dataclass(frozen=True)
class CorrectnessRow:
    model: str
    method: str
    attempted: int
    compiled: int
    compilation_rate: float
    passed_tests: int
    expected_tests: int
    test_level_correctness: float
    full_pass: int
    full_pass_rate: float
    compile_errors: int
    extract_errors: int
    missing_rows: int


def normalize_csv(value: str) -> List[str]:
    return list(dict.fromkeys(item.strip() for item in value.split(",") if item.strip()))


def normalize_methods(value: str) -> List[str]:
    methods: List[str] = []
    for raw in normalize_csv(value):
        method = METHOD_ALIASES.get(raw.lower())
        if method is None:
            raise RQ1EvalStatisticsError(f"Unsupported method: {raw}")
        if method not in methods:
            methods.append(method)
    return methods


def method_for_result(result: Mapping[str, Any]) -> str:
    source = str(result.get("source") or "")
    if source == "agent":
        agent_type = str(result.get("agent_type") or "")
        method = AGENT_METHODS.get(agent_type)
        if method is None:
            raise RQ1EvalStatisticsError(
                f"Unknown or missing agent_type in eval result: {agent_type!r}"
            )
        return method
    method = SOURCE_METHODS.get(source)
    if method is None:
        raise RQ1EvalStatisticsError(f"Unknown eval source: {source!r}")
    return method


def validate_result_selection(result: Mapping[str, Any], method: str) -> None:
    """Validate the effective selection rule, not a baseline report label."""
    if result.get("fuzz_seed") != FIXED_FUZZ_SEED:
        raise RQ1EvalStatisticsError(
            f"Non-seed1 result for {(method, result.get('model'), result.get('sol_path'))}: "
            f"{result.get('fuzz_seed')!r}"
        )

    if method in {"SolAgent", "SolAgent-Summary"}:
        # Selection metadata is attached only after code extraction succeeds.
        # Extract failures still inherit the validated report-level policy.
        if (
            result.get("extract_error") is None
            and result.get("selection_policy") != "test-first-security-second"
        ):
            raise RQ1EvalStatisticsError(
                f"Unexpected {method} selection policy for {result.get('sol_path')}: "
                f"{result.get('selection_policy')!r}"
            )
        return

    # Single-shot baselines do not use selection_policy.  The runner extracts
    # the last valid Solidity artifact by traversing coding_messages backwards.
    if result.get("best_round") is not None:
        raise RQ1EvalStatisticsError(
            f"Single-shot method {method} unexpectedly selected best_round="
            f"{result.get('best_round')} for {result.get('sol_path')}"
        )
    if result.get("extract_error") is None and result.get("code_selection") != "coding_messages":
        raise RQ1EvalStatisticsError(
            f"Single-shot method {method} did not use coding_messages for "
            f"{result.get('sol_path')}: {result.get('code_selection')!r}"
        )


def summarize_group(model: str, method: str, results: Sequence[Mapping[str, Any]]) -> CorrectnessRow:
    attempted = len(results)
    compiled = 0
    passed_tests = 0
    expected_tests = 0
    full_pass = 0
    compile_errors = 0
    extract_errors = 0
    missing_rows = 0

    for result in results:
        try:
            # This also rejects inconsistent ok/compiled/test combinations.
            eval_test_fields(dict(result))
        except ValueError as error:
            raise RQ1EvalStatisticsError(str(error)) from error

        expected = int(result.get("expected_tests") or 0)
        passed = int(result.get("passed") or 0)
        if expected < 0 or passed < 0 or passed > expected:
            raise RQ1EvalStatisticsError(
                f"Invalid test counts for {(method, model, result.get('sol_path'))}: "
                f"passed={passed}, expected={expected}"
            )
        compiled += int(eval_compiled(dict(result)))
        passed_tests += passed
        expected_tests += expected
        full_pass += int(bool(result.get("ok")))
        compile_errors += int(bool(result.get("compile_error")))
        extract_errors += int(bool(result.get("extract_error")))
        missing_rows += int(bool(result.get("missing_row")))

    return CorrectnessRow(
        model=model,
        method=method,
        attempted=attempted,
        compiled=compiled,
        compilation_rate=compiled / attempted if attempted else 0.0,
        passed_tests=passed_tests,
        expected_tests=expected_tests,
        test_level_correctness=(passed_tests / expected_tests if expected_tests else 0.0),
        full_pass=full_pass,
        full_pass_rate=full_pass / attempted if attempted else 0.0,
        compile_errors=compile_errors,
        extract_errors=extract_errors,
        missing_rows=missing_rows,
    )


def _stored_summary_by_group(report: Mapping[str, Any], path: Path) -> Dict[Tuple[str, str], Mapping[str, Any]]:
    summary = report.get("summary")
    groups = summary.get("groups") if isinstance(summary, dict) else None
    if not isinstance(groups, list):
        raise RQ1EvalStatisticsError(f"Eval report has no summary.groups list: {path}")
    stored: Dict[Tuple[str, str], Mapping[str, Any]] = {}
    for group in groups:
        if not isinstance(group, dict):
            raise RQ1EvalStatisticsError(f"Invalid summary group in {path}")
        method = method_for_result(group)
        key = (method, str(group.get("model") or ""))
        if key in stored:
            raise RQ1EvalStatisticsError(f"Duplicate summary group {key} in {path}")
        stored[key] = group
    return stored


def _validate_stored_summary(
    row: CorrectnessRow,
    stored: Mapping[str, Any] | None,
    path: Path,
) -> None:
    if stored is None:
        raise RQ1EvalStatisticsError(
            f"Missing stored summary for {(row.method, row.model)} in {path}"
        )
    expected = {
        "sols": row.attempted,
        "passed_sols": row.full_pass,
        "failed_sols": row.attempted - row.full_pass,
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
        raise RQ1EvalStatisticsError(
            f"Stored summary mismatch for {(row.method, row.model)} in {path}: {mismatches}"
        )


def load_rows(
    paths: Iterable[Path],
    models: Sequence[str],
    methods: Sequence[str],
    *,
    expected_tasks: int = EXPECTED_TASKS_PER_GROUP,
    expected_tests: int = EXPECTED_TESTS_PER_GROUP,
) -> List[CorrectnessRow]:
    selected_models = set(models)
    selected_methods = set(methods)
    grouped: Dict[Tuple[str, str], List[Mapping[str, Any]]] = {}
    group_paths: Dict[Tuple[str, str], Path] = {}
    seen_tasks: set[Tuple[str, str, str]] = set()

    for path in paths:
        if not path.is_file():
            raise RQ1EvalStatisticsError(f"Eval report not found: {path}")
        try:
            report = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise RQ1EvalStatisticsError(f"Cannot read eval report {path}: {error}") from error
        if not isinstance(report, dict) or not isinstance(report.get("results"), list):
            raise RQ1EvalStatisticsError(f"Eval report has no results list: {path}")
        config = report.get("config") or {}
        if config.get("fuzz_seed") != FIXED_FUZZ_SEED:
            raise RQ1EvalStatisticsError(
                f"Eval report is not fixed seed1: {path} has {config.get('fuzz_seed')!r}"
            )
        report_methods = {
            method_for_result(raw)
            for raw in report["results"]
            if isinstance(raw, dict)
        }
        if report_methods & {"SolAgent", "SolAgent-Summary"} and config.get(
            "selection_policy"
        ) != "test-first-security-second":
            raise RQ1EvalStatisticsError(
                f"SolAgent report does not use test-first-security-second: {path} has "
                f"{config.get('selection_policy')!r}"
            )
        stored_summary = _stored_summary_by_group(report, path)
        local_groups: Dict[Tuple[str, str], List[Mapping[str, Any]]] = {}

        for raw in report["results"]:
            if not isinstance(raw, dict):
                raise RQ1EvalStatisticsError(f"Non-object eval result in {path}")
            method = method_for_result(raw)
            model = str(raw.get("model") or "")
            sol_path = str(raw.get("sol_path") or "")
            if not model or not sol_path:
                raise RQ1EvalStatisticsError(f"Incomplete eval result key in {path}")
            if model not in selected_models or method not in selected_methods:
                continue
            validate_result_selection(raw, method)
            task_key = (method, model, sol_path)
            if task_key in seen_tasks:
                raise RQ1EvalStatisticsError(f"Duplicate eval task: {task_key}")
            seen_tasks.add(task_key)
            local_groups.setdefault((method, model), []).append(raw)

        for key, results in local_groups.items():
            if key in grouped:
                raise RQ1EvalStatisticsError(
                    f"Method/model group occurs in multiple reports: {key}"
                )
            row = summarize_group(key[1], key[0], results)
            _validate_stored_summary(row, stored_summary.get(key), path)
            grouped[key] = results
            group_paths[key] = path

    missing_groups = [
        (method, model)
        for model in models
        for method in methods
        if (method, model) not in grouped
    ]
    if missing_groups:
        raise RQ1EvalStatisticsError(
            f"Missing {len(missing_groups)} requested method/model groups; first={missing_groups[0]}"
        )

    rows: List[CorrectnessRow] = []
    for model in models:
        for method in methods:
            row = summarize_group(model, method, grouped[(method, model)])
            if row.attempted != expected_tasks:
                raise RQ1EvalStatisticsError(
                    f"Expected {expected_tasks} tasks for {(method, model)}, got {row.attempted} "
                    f"from {group_paths[(method, model)]}"
                )
            if row.expected_tests != expected_tests:
                raise RQ1EvalStatisticsError(
                    f"Expected {expected_tests} tests for {(method, model)}, got "
                    f"{row.expected_tests} from {group_paths[(method, model)]}"
                )
            rows.append(row)
    return rows


def percentage(value: float) -> str:
    return f"{value * 100:.2f}%"


def print_table(headers: Sequence[str], data: Sequence[Sequence[Any]]) -> None:
    rows = [[str(cell) for cell in row] for row in data]
    widths = [len(header) for header in headers]
    for row in rows:
        for index, cell in enumerate(row):
            widths[index] = max(widths[index], len(cell))
    line = "  ".join("=" * width for width in widths)
    print("  ".join(header.ljust(widths[index]) for index, header in enumerate(headers)))
    print(line)
    for row in rows:
        print("  ".join(cell.ljust(widths[index]) for index, cell in enumerate(row)))


def print_results(rows: Sequence[CorrectnessRow]) -> None:
    print("\n" + "=" * 110)
    print("RQ-1 Test-Level Correctness: Independent Eval Tests, Fixed Fuzz Seed 1")
    print("=" * 110)
    print("\nMain Table")
    print_table(
        [
            "Model",
            "Method",
            "Compile Rate",
            "Test Pass Rate",
            "Pass@1",
        ],
        [
            [
                row.model,
                row.method,
                f"{percentage(row.compilation_rate)} ({row.compiled}/{row.attempted})",
                (
                    f"{percentage(row.test_level_correctness)} "
                    f"({row.passed_tests}/{row.expected_tests})"
                ),
                f"{percentage(row.full_pass_rate)} ({row.full_pass}/{row.attempted})",
            ]
            for row in rows
        ],
    )
    print("\nNotes:")
    print("- All functionality comes from the independent seed1 eval reports, not database feedback tests.")
    print("- Compilation/extraction failures keep their eval tests in the denominator and contribute zero passes.")
    print("- Pass@1 = files that pass every eval test / all 81 attempted tasks.")
    print("- RawModel and agent baselines use the last valid Solidity artifact from coding_messages; no test-based checkpoint selection is applied.")
    print("- SolAgent and SolAgent-Summary use test-first-security-second checkpoint selection.")


def write_csv(path: Path, rows: Sequence[CorrectnessRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(asdict(rows[0])) if rows else []
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(asdict(row) for row in rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build the RQ1 seed1 eval test-level correctness table"
    )
    parser.add_argument(
        "--eval-files",
        default=",".join(str(path) for path in DEFAULT_REPORTS),
        help="Comma-separated fixed-seed RQ1 eval report JSON files",
    )
    parser.add_argument("--models", default=",".join(TARGET_MODELS))
    parser.add_argument("--methods", default=",".join(METHOD_ORDER))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    args = parser.parse_args()

    try:
        models = normalize_csv(args.models)
        methods = normalize_methods(args.methods)
        paths = [Path(item) for item in normalize_csv(args.eval_files)]
        rows = load_rows(paths, models, methods)
        output = Path(args.output)
        write_csv(output, rows)
        print_results(rows)
        print(f"\nWrote: {output}")
        return 0
    except (OSError, ValueError, RQ1EvalStatisticsError) as error:
        print(f"[ERROR] {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
