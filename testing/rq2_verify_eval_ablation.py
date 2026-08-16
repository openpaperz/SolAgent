#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from testing.generate_eval_tests import (  # noqa: E402
    DEFAULT_DATASET,
    DEFAULT_MANIFEST,
    DEFAULT_TEST_MAP,
    _load_dataset,
    _load_test_map,
    _render_test_file,
    _safe_join,
)
from testing.eval_overlay_utils import locked_path_replacements  # noqa: E402
from testing.rq1_verify_eval_models import (  # noqa: E402
    DEFAULT_FUZZ_SEED,
    DEFAULT_MODELS,
    _connect_readonly,
    _empty_summary,
    _failure_result,
    _gen_copy_path,
    _resolve_db_path,
    _select_solagent_code,
    _split_csv,
    _table_exists,
)
from utils.forge_utils import check_forge, parse_forge_stdout  # noqa: E402


ABLATION_TYPES = {
    2: "no_forge",
    3: "no_slither",
    4: "no_tools",
}
DEFAULT_SOURCES = ["full", *ABLATION_TYPES.values()]
REPORT_PATH = ROOT / "testing" / "eval" / "rq2_verify_eval_ablation.json"
DEFAULT_SELECTION_POLICY = "test-first-security-second"


@dataclass(frozen=True)
class Target:
    source: str
    source_name: str
    table: str
    model: str
    ablation_type: int


def _source_name(source: str, ablation_type: int) -> str:
    if ablation_type == 0:
        return "SolAgent (Full)"
    return f"Ablation-{source}"


def _source_targets(args: argparse.Namespace) -> list[Target]:
    models = _split_csv(args.model, DEFAULT_MODELS)
    requested_sources = _split_csv(args.source, DEFAULT_SOURCES)

    invalid = sorted(set(requested_sources) - set(DEFAULT_SOURCES))
    if invalid:
        raise ValueError(f"unknown source filter: {invalid}")

    if args.ablation_type:
        requested_types = {int(item) for item in _split_csv(args.ablation_type, [])}
        invalid_types = sorted(requested_types - set(ABLATION_TYPES))
        if invalid_types:
            raise ValueError(f"unknown ablation_type filter: {invalid_types}")
        requested_sources = [source for source in requested_sources if source == "full"]
        requested_sources.extend(ABLATION_TYPES[item] for item in sorted(requested_types))

    targets: list[Target] = []
    for model in models:
        for source in requested_sources:
            if source == "full":
                targets.append(Target(source, _source_name(source, 0), "process_tracking", model, 0))
                continue
            ablation_type = next(key for key, value in ABLATION_TYPES.items() if value == source)
            targets.append(
                Target(
                    source,
                    _source_name(source, ablation_type),
                    "process_tracking_ablation",
                    model,
                    ablation_type,
                )
            )
    return targets


def _fetch_row(conn: sqlite3.Connection, target: Target, sol_path: str) -> dict[str, Any] | None:
    if target.ablation_type == 0:
        cursor = conn.execute(
            """
            SELECT * FROM process_tracking
            WHERE file_path = ? AND model_coding = ?
            """,
            (sol_path, target.model),
        )
    else:
        cursor = conn.execute(
            """
            SELECT * FROM process_tracking_ablation
            WHERE file_path = ? AND model_coding = ? AND ablation_type = ?
            """,
            (sol_path, target.model, target.ablation_type),
        )
    row = cursor.fetchone()
    return dict(row) if row else None


def _group_key(result: dict[str, Any]) -> str:
    return f"{result['source']}|{result['model']}|{result['ablation_type']}"


def _accumulate_summary(summary: dict[str, int], result: dict[str, Any]) -> None:
    summary["sols"] += 1
    if result.get("ok"):
        summary["passed_sols"] += 1
    else:
        summary["failed_sols"] += 1
    summary["expected_tests"] += int(result.get("expected_tests") or 0)
    summary["passed_tests"] += int(result.get("passed") or 0)
    summary["failed_tests"] += int(result.get("failed_tests") or 0)
    if result.get("compile_error"):
        summary["compile_errors"] += 1
    if result.get("extract_error"):
        summary["extract_errors"] += 1
    if result.get("missing_row"):
        summary["missing_rows"] += 1


def _build_summary(results: list[dict[str, Any]]) -> dict[str, Any]:
    global_summary = _empty_summary()
    groups: dict[str, dict[str, Any]] = {}
    for result in results:
        _accumulate_summary(global_summary, result)
        key = _group_key(result)
        if key not in groups:
            groups[key] = {
                "source": result["source"],
                "source_name": result["source_name"],
                "model": result["model"],
                "ablation_type": result["ablation_type"],
                **_empty_summary(),
            }
        _accumulate_summary(groups[key], result)
    return {
        "global": global_summary,
        "groups": sorted(groups.values(), key=lambda item: (item["model"], item["ablation_type"])),
    }


def _write_report(
    results: list[dict[str, Any]],
    total_tasks: int,
    selection_policy: str,
    fuzz_seed: str,
    interrupted: bool = False,
) -> dict[str, Any]:
    summary = _build_summary(results)
    payload = {
        "meta": {
            "total_tasks": total_tasks,
            "completed_tasks": len(results),
            "interrupted": interrupted,
            "selection_policy": selection_policy,
            "fuzz_seed": fuzz_seed,
        },
        "summary": summary,
        "results": results,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    temp_path = REPORT_PATH.with_suffix(REPORT_PATH.suffix + ".tmp")
    temp_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temp_path.replace(REPORT_PATH)
    return summary


def _run_one(
    conn: sqlite3.Connection,
    target: Target,
    sol_path: str,
    dataset: dict[str, Any],
    test_map: dict[str, str],
    manifest_cases_by_sol: dict[str, dict[str, Any]],
    manifest_methods_by_sol: dict[str, list[dict[str, str]]],
    shared_groups: dict[str, list[str]],
    selection_policy: str,
    fuzz_seed: str,
) -> dict[str, Any]:
    case = manifest_cases_by_sol.get(sol_path)
    methods = manifest_methods_by_sol.get(sol_path, [])
    expected_tests = len(methods)
    feedback_rel = test_map.get(sol_path) or (case or {}).get("feedback_test_path")
    shared_group = shared_groups.get((case or {}).get("eval_test_path", ""), [])
    result: dict[str, Any] = {
        "source": target.source,
        "source_name": target.source_name,
        "model": target.model,
        "ablation_type": target.ablation_type,
        "selection_policy": selection_policy,
        "fuzz_seed": fuzz_seed,
        "sol_path": sol_path,
        "feedback_test_path": feedback_rel,
        "eval_test_path": (case or {}).get("eval_test_path"),
        "shared_eval_group_size": len(shared_group),
        "shared_eval_group_sol_paths": shared_group,
        "test_names": [item["test_name"] for item in methods],
        "methods_count": expected_tests,
        "expected_tests": expected_tests,
        "passed": 0,
        "forge_failed": 0,
        "forge_total": 0,
        "failed_tests": expected_tests,
        "ok": False,
    }

    if case is None:
        return _failure_result(result, expected_tests, error="missing manifest case")
    if not methods:
        return _failure_result(result, expected_tests, error="no generated methods for sol_path")
    if feedback_rel != case["feedback_test_path"]:
        return _failure_result(result, expected_tests, error="manifest feedback_test_path mismatch")

    row = _fetch_row(conn, target, sol_path)
    if row is None:
        return _failure_result(result, expected_tests, missing_row=True, error="missing DB row")

    result["row_id"] = row.get("id")
    result["row_status"] = row.get("status")
    result["row_test_pass"] = row.get("test_pass")
    result["row_test_fail"] = row.get("test_fail")
    result["row_test_total"] = row.get("test_total")

    if int(row.get("status") or 0) != 1:
        return _failure_result(result, expected_tests, extract_error=f"row status is {row.get('status')}")

    code_selection, extract_error = _select_solagent_code(
        row, sol_path, selection_policy
    )
    if code_selection is None:
        return _failure_result(result, expected_tests, extract_error=extract_error or "code extraction failed")

    result["code_selection"] = code_selection.code_selection
    result["code_extractor"] = code_selection.extractor
    result["best_round"] = code_selection.best_round
    result["best_pass"] = code_selection.best_pass
    result["best_total"] = code_selection.best_total
    result["code_bytes"] = len(code_selection.code.encode("utf-8"))

    try:
        content, generated, _skipped, _project_roots = _render_test_file(
            feedback_rel, [(sol_path, dataset[sol_path])], ROOT
        )
    except Exception as exc:
        return _failure_result(result, expected_tests, error=f"render failed: {exc}")

    expected_tests = len(generated)
    result["methods_count"] = expected_tests
    result["expected_tests"] = expected_tests
    result["failed_tests"] = expected_tests

    sol_abs = _safe_join(ROOT, sol_path)
    feedback_abs = _safe_join(ROOT, feedback_rel)
    gen_copy_abs = _gen_copy_path(sol_abs)

    with tempfile.TemporaryDirectory(prefix="rq2_verify_eval_ablation_") as tmp:
        tmpdir = Path(tmp)
        temp_eval = tmpdir / feedback_abs.name
        temp_gen = tmpdir / gen_copy_abs.name
        temp_eval.write_text(content, encoding="utf-8")
        temp_gen.write_text(code_selection.code.rstrip() + "\n", encoding="utf-8")

        try:
            with locked_path_replacements(
                ROOT,
                feedback_abs,
                [(gen_copy_abs, temp_gen), (feedback_abs, temp_eval)],
                tmpdir,
            ):
                stdout = check_forge(str(feedback_abs), fuzz_seed=fuzz_seed)
                parsed = parse_forge_stdout(stdout)
                if parsed.get("compile_error"):
                    return _failure_result(result, expected_tests, compile_error=str(parsed["compile_error"]))

                passed = int(parsed.get("passed") or 0)
                forge_failed = int(parsed.get("failed") or 0)
                forge_total = int(parsed.get("total") or 0)
                result["passed"] = passed
                result["forge_failed"] = forge_failed
                result["forge_total"] = forge_total
                result["failed_tests"] = max(expected_tests - passed, 0)
                result["fails"] = parsed.get("fails") or {}
                result["ok"] = passed == expected_tests and forge_failed == 0 and forge_total == expected_tests
                if forge_total != expected_tests:
                    result["total_mismatch"] = f"expected {expected_tests}, forge reported {forge_total}"
                return result
        except Exception as exc:
            return _failure_result(result, expected_tests, error=str(exc))


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run hidden eval tests against RQ2 ablation outputs")
    parser.add_argument("--db", default="output/progress.db", help="Path to progress.db")
    parser.add_argument(
        "--source",
        help="Optional source filter; comma-separated: full,no_forge,no_slither,no_tools",
    )
    parser.add_argument(
        "--ablation-type",
        help="Optional ablation type filter; comma-separated values from 2,3,4",
    )
    parser.add_argument("--model", help="Optional model filter; comma-separated values are accepted")
    parser.add_argument("--sol", help="Optional dataset sol_path filter; comma-separated values are accepted")
    parser.add_argument("--limit", type=int, help="Optional max number of sol evaluations after filtering")
    parser.add_argument("--fail-fast", action="store_true", help="Stop after the first failed sol evaluation")
    parser.add_argument("--quiet", action="store_true", help="Suppress per-sol pass/fail lines; JSON keeps details")
    parser.add_argument(
        "--selection-policy",
        choices=["best-pass-first", "test-first-security-second"],
        default=DEFAULT_SELECTION_POLICY,
        help=(
            "SolAgent round-selection policy "
            f"(default: {DEFAULT_SELECTION_POLICY})"
        ),
    )
    parser.add_argument(
        "--fuzz-seed",
        default=DEFAULT_FUZZ_SEED,
        help="Fixed Forge fuzz seed used for every eval test",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=25,
        help="Print and checkpoint progress every N completed tasks; use 0 to disable periodic output",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        targets = _source_targets(args)
    except ValueError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 2

    db_path = _resolve_db_path(args.db)
    dataset = _load_dataset(DEFAULT_DATASET)
    test_map = _load_test_map(DEFAULT_TEST_MAP)
    manifest = json.loads(DEFAULT_MANIFEST.read_text(encoding="utf-8"))

    manifest_cases_by_sol = {case["sol_path"]: case for case in manifest["cases"]}
    manifest_methods_by_sol: dict[str, list[dict[str, str]]] = {}
    for item in manifest["methods"]:
        manifest_methods_by_sol.setdefault(item["sol_path"], []).append(item)
    shared_groups: dict[str, list[str]] = {}
    for case in manifest["cases"]:
        shared_groups.setdefault(case["eval_test_path"], []).append(case["sol_path"])

    sol_paths = list(dataset)
    if args.sol:
        requested = set(_split_csv(args.sol, []))
        unknown = sorted(requested - set(dataset))
        if unknown:
            print(f"[error] unknown sol_path filter: {unknown}", file=sys.stderr)
            return 2
        sol_paths = [sol_path for sol_path in sol_paths if sol_path in requested]

    tasks = [(target, sol_path) for target in targets for sol_path in sol_paths]
    if args.limit is not None:
        tasks = tasks[: args.limit]
    if not tasks:
        print("[error] no eval tasks selected", file=sys.stderr)
        return 2

    start_time = time.monotonic()
    results: list[dict[str, Any]] = []
    interrupted = False
    try:
        with _connect_readonly(db_path) as conn:
            for table in sorted({target.table for target, _sol_path in tasks}):
                if not _table_exists(conn, table):
                    print(f"[error] DB table not found: {table}", file=sys.stderr)
                    return 2

            for index, (target, sol_path) in enumerate(tasks, start=1):
                print(
                    f"[verify] {index}/{len(tasks)} {target.source} {target.model} {sol_path}",
                    flush=True,
                )
                result = _run_one(
                    conn,
                    target,
                    sol_path,
                    dataset,
                    test_map,
                    manifest_cases_by_sol,
                    manifest_methods_by_sol,
                    shared_groups,
                    args.selection_policy,
                    args.fuzz_seed,
                )
                results.append(result)
                if result.get("ok"):
                    print(
                        f"[pass] {target.source} {target.model} {sol_path} "
                        f"({result['passed']}/{result['expected_tests']})",
                        flush=True,
                    )
                else:
                    reason = (
                        result.get("extract_error")
                        or result.get("error")
                        or f"{result.get('failed_tests')}/{result.get('expected_tests')} failed"
                    )
                    if result.get("compile_error"):
                        reason = "compile_error"
                    if not args.quiet:
                        reason = (
                            result.get("extract_error")
                            or result.get("compile_error")
                            or result.get("error")
                            or f"{result.get('failed_tests')}/{result.get('expected_tests')} failed"
                        )
                    print(f"[fail] {target.source} {target.model} {sol_path}: {reason}", flush=True)

                should_checkpoint = (
                    args.progress_every
                    and (len(results) == 1 or len(results) % args.progress_every == 0 or len(results) == len(tasks))
                )
                if should_checkpoint:
                    summary = _write_report(
                        results,
                        len(tasks),
                        args.selection_policy,
                        args.fuzz_seed,
                    )
                    elapsed = time.monotonic() - start_time
                    global_summary = summary["global"]
                    print(
                        f"[progress] completed={len(results)}/{len(tasks)} elapsed={elapsed:.1f}s "
                        f"passed_tests={global_summary['passed_tests']}/{global_summary['expected_tests']} "
                        f"compile_errors={global_summary['compile_errors']} "
                        f"extract_errors={global_summary['extract_errors']}",
                        flush=True,
                    )

                if args.fail_fast and not result.get("ok"):
                    break
    except KeyboardInterrupt:
        interrupted = True
        print("[warn] interrupted; writing partial report", file=sys.stderr, flush=True)

    summary = _write_report(
        results,
        len(tasks),
        args.selection_policy,
        args.fuzz_seed,
        interrupted=interrupted,
    )

    global_summary = summary["global"]
    print(
        f"[verify] sols={global_summary['sols']} "
        f"passed_sols={global_summary['passed_sols']} failed_sols={global_summary['failed_sols']} "
        f"expected_tests={global_summary['expected_tests']} "
        f"passed_tests={global_summary['passed_tests']} failed_tests={global_summary['failed_tests']} "
        f"compile_errors={global_summary['compile_errors']} "
        f"extract_errors={global_summary['extract_errors']} missing_rows={global_summary['missing_rows']}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
