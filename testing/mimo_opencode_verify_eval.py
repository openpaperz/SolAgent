#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import tempfile
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
    CodeSelection,
    _build_summary,
    _extract_code_from_messages,
    _extract_from_content,
    _failure_result,
    _gen_copy_path,
    _safe_json_loads,
    _split_csv,
)
from utils.forge_utils import check_forge, parse_forge_stdout  # noqa: E402


DEFAULT_ARTIFACT_DIR = ROOT / "baseline_opencode" / "result" / "mimo-v2.5-pro"
FIXED_FUZZ_SEED = "0x" + "0" * 63 + "1"
REPORT_PATH = ROOT / "testing" / "eval" / "mimo_opencode_verify_eval_seed1.json"


def _resolve_input_path(path: str | Path) -> Path:
    resolved = Path(path)
    if resolved.is_absolute():
        return resolved.resolve()

    if resolved.parts and resolved.parts[0] == ROOT.name:
        return (ROOT.parent / resolved).resolve()

    cwd_resolved = (Path.cwd() / resolved).resolve()
    if cwd_resolved.exists() or cwd_resolved.parent.exists():
        return cwd_resolved

    return (ROOT / resolved).resolve()


def _artifact_file_name(sol_path: str) -> str:
    return f"{sol_path.replace('/', '__')}.json"


def _display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def _load_artifact(artifact_path: Path) -> tuple[dict[str, Any] | None, str | None]:
    if not artifact_path.exists():
        return None, "missing artifact JSON"
    try:
        return json.loads(artifact_path.read_text(encoding="utf-8")), None
    except json.JSONDecodeError as exc:
        return None, f"invalid artifact JSON: {exc}"


def _artifact_model_names(artifact: dict[str, Any]) -> set[str]:
    names = {
        str(artifact.get("model_coding") or "").strip(),
        str(artifact.get("opencode_model") or "").strip(),
    }
    opencode_model = artifact.get("opencode_model")
    if isinstance(opencode_model, str) and "/" in opencode_model:
        names.add(opencode_model.rsplit("/", 1)[-1])
    return {name for name in names if name}


def _artifact_matches_model_filter(artifact: dict[str, Any], model_filter: set[str]) -> bool:
    if not model_filter:
        return True
    return bool(_artifact_model_names(artifact) & model_filter)


def _select_opencode_code(artifact: dict[str, Any], sol_path: str) -> tuple[CodeSelection | None, str | None]:
    file_name = Path(sol_path).name
    messages = _safe_json_loads(artifact.get("coding_messages"), [])
    code, extractor, error = _extract_code_from_messages(messages, file_name)
    if code:
        return CodeSelection(code=code, code_selection="coding_messages", extractor=extractor), None

    export = artifact.get("opencode_export")
    if isinstance(export, str):
        code, extractor = _extract_from_content(export, file_name)
        if code:
            return CodeSelection(code=code, code_selection="opencode_export_fallback", extractor=extractor), None

    generation_error = artifact.get("generation_error")
    if generation_error:
        return None, str(generation_error)
    return None, error or "no valid Solidity code in artifact JSON"


def _base_result(
    sol_path: str,
    case: dict[str, Any] | None,
    methods: list[dict[str, str]],
    feedback_rel: str | None,
    shared_group: list[str],
    artifact_path: Path,
) -> dict[str, Any]:
    expected_tests = len(methods)
    return {
        "source": "opencode",
        "source_name": "OpenCode",
        "model": "unknown",
        "agent_type": "opencode",
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
        "artifact_path": _display_path(artifact_path),
    }


def _run_one(
    artifact_dir: Path,
    sol_path: str,
    dataset: dict[str, Any],
    test_map: dict[str, str],
    manifest_cases_by_sol: dict[str, dict[str, Any]],
    manifest_methods_by_sol: dict[str, list[dict[str, str]]],
    shared_groups: dict[str, list[str]],
    fuzz_seed: str,
) -> dict[str, Any]:
    case = manifest_cases_by_sol.get(sol_path)
    methods = manifest_methods_by_sol.get(sol_path, [])
    feedback_rel = test_map.get(sol_path) or (case or {}).get("feedback_test_path")
    shared_group = shared_groups.get((case or {}).get("eval_test_path", ""), [])
    artifact_path = artifact_dir / _artifact_file_name(sol_path)
    expected_tests = len(methods)

    result = _base_result(sol_path, case, methods, feedback_rel, shared_group, artifact_path)
    result["fuzz_seed"] = fuzz_seed
    if case is None:
        return _failure_result(result, expected_tests, error="missing manifest case")
    if not methods:
        return _failure_result(result, expected_tests, error="no generated methods for sol_path")
    if feedback_rel != case["feedback_test_path"]:
        return _failure_result(result, expected_tests, error="manifest feedback_test_path mismatch")

    artifact, artifact_error = _load_artifact(artifact_path)
    if artifact is None:
        return _failure_result(
            result,
            expected_tests,
            missing_row=True,
            missing_artifact=True,
            error=artifact_error or "missing artifact JSON",
        )

    result["model"] = artifact.get("model_coding") or artifact.get("opencode_model") or "unknown"
    result["opencode_model"] = artifact.get("opencode_model")
    result["artifact_file_path"] = artifact.get("file_path")
    result["artifact_test_pass"] = int(artifact.get("test_pass") or 0)
    result["artifact_test_fail"] = int(artifact.get("test_fail") or 0)
    result["artifact_test_total"] = int(artifact.get("test_total") or 0)
    result["artifact_generation_error"] = artifact.get("generation_error")

    artifact_file_path = artifact.get("file_path")
    if artifact_file_path and artifact_file_path != sol_path:
        return _failure_result(
            result,
            expected_tests,
            error=f"artifact file_path mismatch: expected {sol_path}, got {artifact_file_path}",
        )

    code_selection, extract_error = _select_opencode_code(artifact, sol_path)
    if code_selection is None:
        return _failure_result(result, expected_tests, extract_error=extract_error or "code extraction failed")

    result["code_selection"] = code_selection.code_selection
    result["code_extractor"] = code_selection.extractor
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

    with tempfile.TemporaryDirectory(prefix="verify_eval_opencode_") as tmp:
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
    parser = argparse.ArgumentParser(description="Run hidden eval tests against OpenCode JSON artifacts")
    parser.add_argument("--artifact-dir", default=str(DEFAULT_ARTIFACT_DIR), help="Directory containing OpenCode JSON artifacts")
    parser.add_argument("--model", help="Optional artifact model filter; comma-separated values are accepted")
    parser.add_argument("--sol", help="Optional dataset sol_path filter; comma-separated values are accepted")
    parser.add_argument("--limit", type=int, help="Optional max number of sol evaluations after filtering")
    parser.add_argument("--fail-fast", action="store_true", help="Stop after the first failed sol evaluation")
    parser.add_argument("--report", default=str(REPORT_PATH), help="Output JSON report path")
    parser.add_argument("--fuzz-seed", default=FIXED_FUZZ_SEED, help="Fixed Forge fuzz seed")
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    artifact_dir = _resolve_input_path(args.artifact_dir)
    report_path = _resolve_input_path(args.report)
    if not artifact_dir.is_dir():
        print(f"[error] artifact dir not found: {artifact_dir}", file=sys.stderr)
        return 2

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

    model_filter = set(_split_csv(args.model, []))
    if model_filter:
        filtered_sol_paths: list[str] = []
        for sol_path in sol_paths:
            artifact, artifact_error = _load_artifact(artifact_dir / _artifact_file_name(sol_path))
            if artifact is None:
                filtered_sol_paths.append(sol_path)
                continue
            if _artifact_matches_model_filter(artifact, model_filter):
                filtered_sol_paths.append(sol_path)
        sol_paths = filtered_sol_paths

    if args.limit is not None:
        sol_paths = sol_paths[: args.limit]
    if not sol_paths:
        print("[error] no eval tasks selected", file=sys.stderr)
        return 2

    results: list[dict[str, Any]] = []
    for index, sol_path in enumerate(sol_paths, start=1):
        print(f"[verify] {index}/{len(sol_paths)} opencode {sol_path}", flush=True)
        result = _run_one(
            artifact_dir,
            sol_path,
            dataset,
            test_map,
            manifest_cases_by_sol,
            manifest_methods_by_sol,
            shared_groups,
            args.fuzz_seed,
        )
        results.append(result)
        if result.get("ok"):
            print(f"[pass] opencode {sol_path} ({result['passed']}/{result['expected_tests']})", flush=True)
        else:
            reason = (
                result.get("extract_error")
                or result.get("compile_error")
                or result.get("error")
                or f"{result.get('failed_tests')}/{result.get('expected_tests')} failed"
            )
            print(f"[fail] opencode {sol_path}: {reason}", flush=True)
            if args.fail_fast:
                break

    summary = _build_summary(results)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(
            {
                "config": {"fuzz_seed": args.fuzz_seed},
                "summary": summary,
                "results": results,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
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
