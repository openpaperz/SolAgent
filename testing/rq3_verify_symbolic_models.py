#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from testing.generate_eval_tests import (  # noqa: E402
    DEFAULT_DATASET,
    _load_dataset,
    _safe_join,
)
from testing.eval_overlay_utils import locked_path_replacements  # noqa: E402
from testing.rq1_verify_eval_models import (  # noqa: E402
    Target,
    _connect_readonly,
    _gen_copy_path,
    _resolve_db_path,
    _select_code,
    _source_targets,
    _split_csv,
    _table_exists,
)
from testing.symbolic_utils import (  # noqa: E402
    DEFENDER_DEPLOY_SOL,
    OPENZEPPELIN_UTILS_SOL,
    build_symbolic_summary,
    classify_symbolic_failure,
    halmos_extra_args_for_sol,
    openzeppelin_utils_stub_source,
    parse_halmos_runs,
    run_halmos,
    split_check_chunks,
)


DEFAULT_MANIFEST = ROOT / "testing" / "symbolic" / "symbolic_manifest.json"
REPORT_PATH = ROOT / "testing" / "symbolic" / "rq3_verify_symbolic_models.json"
DEFAULT_SELECTION_POLICY = "test-first-security-second"
FunctionKey = tuple[str, str, str, str]


def _bounded(value: str, limit: int = 20000) -> str:
    if len(value) <= limit:
        return value
    return value[:limit] + f"\n...[truncated {len(value) - limit} chars]"


def _normalize_signature(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _function_key(item: dict[str, Any]) -> FunctionKey:
    return (
        str(item.get("sol_path") or ""),
        str(item.get("class_name") or item.get("class") or ""),
        str(item.get("method_name") or item.get("identifier") or ""),
        _normalize_signature(item.get("full_signature")),
    )


def _dataset_functions(dataset: dict[str, Any]) -> dict[FunctionKey, dict[str, Any]]:
    functions: dict[FunctionKey, dict[str, Any]] = {}
    for sol_path, classes in dataset.items():
        for cls in classes:
            class_name = str(cls.get("identifier") or "")
            class_kind = str(cls.get("kind") or "")
            for method in cls.get("methods", []):
                if method.get("kind") != "function":
                    continue
                item = {
                    "sol_path": sol_path,
                    "class_name": class_name,
                    "class_kind": class_kind,
                    "method_name": str(method.get("identifier") or ""),
                    "visibility": str(method.get("visibility") or ""),
                    "full_signature": _normalize_signature(method.get("full_signature")),
                }
                functions[_function_key(item)] = item
    return functions


def _sol_to_symbolic_test(manifest: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for case in manifest.get("cases", []):
        sol_path = case.get("sol_path")
        test_path = case.get("symbolic_test_path")
        if sol_path and test_path:
            mapping[str(sol_path)] = str(test_path)
    return mapping


def _function_bodies_by_name(content: str) -> dict[str, str]:
    bodies: dict[str, str] = {}
    for match in re.finditer(r"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", content):
        name = match.group(1)
        brace_start = content.find("{", match.end())
        if brace_start == -1:
            continue
        depth = 0
        for index in range(brace_start, len(content)):
            char = content[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    bodies[name] = content[brace_start : index + 1]
                    break
    return bodies


def _reachable_function_content(bodies: dict[str, str], roots: set[str]) -> str:
    seen: set[str] = set()
    chunks: list[str] = []
    stack = list(roots)
    while stack:
        name = stack.pop()
        if name in seen:
            continue
        seen.add(name)
        body = bodies.get(name)
        if not body:
            continue
        chunks.append(body)
        for match in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", body):
            callee = match.group(1)
            if callee in bodies and callee not in seen:
                stack.append(callee)
        for match in re.finditer(r"\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\.selector\b", body):
            callee = match.group(1)
            if callee in bodies and callee not in seen:
                stack.append(callee)
    return "\n".join(chunks)


def _single_wrapper_for_check(symbolic_dir: Path, test_path: str, check_name: str) -> str | None:
    source_path = symbolic_dir / test_path
    if not source_path.exists():
        return None
    content = source_path.read_text(encoding="utf-8")
    bodies = _function_bodies_by_name(content)
    active_content = _reachable_function_content(bodies, {check_name})
    wrappers: set[str] = set()
    for match in re.finditer(r"\b((?:ref|gen)_call_[A-Za-z0-9_]+_\d+(?:_state)?)\.selector", active_content):
        wrapper = re.sub(r"^(?:ref|gen)_", "", match.group(1))
        wrappers.add(wrapper.removesuffix("_state"))
    for match in re.finditer(r"\b(?:Ref|Gen)[A-Za-z0-9_]*\.exposed_([A-Za-z0-9_]+_\d+)\.selector", active_content):
        wrappers.add(f"call_{match.group(1)}")
    if len(wrappers) == 1:
        return next(iter(wrappers))
    return None


def _call_arguments(content: str, open_paren_index: int) -> list[str] | None:
    depth = 0
    start = open_paren_index + 1
    for index in range(open_paren_index, len(content)):
        char = content[index]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                args_text = content[start:index].strip()
                if not args_text:
                    return []
                nested = 0
                args: list[str] = []
                last = 0
                for arg_index, arg_char in enumerate(args_text):
                    if arg_char in "([":
                        nested += 1
                    elif arg_char in ")]" and nested:
                        nested -= 1
                    elif arg_char == "," and nested == 0:
                        args.append(args_text[last:arg_index].strip())
                        last = arg_index + 1
                args.append(args_text[last:].strip())
                return args
    return None


def _parameter_count_from_signature(signature: str) -> int | None:
    open_paren = signature.find("(")
    if open_paren == -1:
        return None
    args = _call_arguments(signature, open_paren)
    if args is None:
        return None
    return len(args)


def _argument_type_hints(content: str, args: list[str] | None, call_index: int) -> list[str]:
    if not args:
        return []
    prefix = content[:call_index]
    hints: list[str] = []
    for arg in args:
        name = arg.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            continue
        match = re.search(
            r"\b((?:bytes|string)\s+(?:memory|calldata)|bytes32|address|bool|u?int(?:8|16|32|64|128|160|256)?)\s+"
            + re.escape(name)
            + r"\b",
            prefix,
        )
        if match:
            hints.append(match.group(1))
    return hints


def _filter_candidates_by_type_hints(
    candidates: list[FunctionKey],
    type_hints: list[str],
) -> list[FunctionKey]:
    narrowed = candidates
    for hint in type_hints:
        if hint.startswith("bytes memory"):
            matched = [key for key in narrowed if "bytes memory" in key[3]]
        elif hint.startswith("bytes calldata"):
            matched = [key for key in narrowed if "bytes calldata" in key[3]]
        elif hint.startswith("string memory"):
            matched = [key for key in narrowed if "string memory" in key[3]]
        elif hint.startswith("string calldata"):
            matched = [key for key in narrowed if "string calldata" in key[3]]
        elif hint == "bytes32":
            matched = [key for key in narrowed if re.search(r"\bbytes32\s+\w+", key[3])]
        else:
            matched = [key for key in narrowed if re.search(r"\b" + re.escape(hint) + r"\s+\w+", key[3])]
        if matched:
            narrowed = matched
    return narrowed


def _resolve_exposed_method_name(method_name: str) -> str:
    match = re.fullmatch(r"exposed_([A-Za-z0-9_]+)_\d+", method_name)
    if match:
        return match.group(1)
    return method_name


def _class_name_from_static_ref_gen_prefix(prefix: str) -> str | None:
    match = re.fullmatch(r"(?:Ref|Gen)([A-Za-z0-9_]*?)(?:_\d+|Extra_\d+)?", prefix)
    if not match:
        return None
    return match.group(1) or None


def _single_direct_ref_gen_key_for_check(
    symbolic_dir: Path,
    test_path: str,
    sol_path: str,
    check_name: str,
    keys_by_sol_method: dict[tuple[str, str], list[FunctionKey]],
    keys_by_sol_class_method: dict[tuple[str, str, str], list[FunctionKey]],
) -> FunctionKey | None:
    source_path = symbolic_dir / test_path
    if not source_path.exists():
        return None
    content = source_path.read_text(encoding="utf-8")
    bodies = _function_bodies_by_name(content)
    active_content = _reachable_function_content(bodies, {check_name})
    used: set[FunctionKey] = set()

    static_call_pattern = re.compile(
        r"\b((?:Ref|Gen)[A-Za-z0-9_]*(?:_\d+|Extra_\d+)?)\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\("
    )
    for match in static_call_pattern.finditer(active_content):
        static_prefix = match.group(1)
        prefix = "Ref" if static_prefix.startswith("Ref") else "Gen"
        method_name = match.group(2)
        counterpart = "Gen" if prefix == "Ref" else "Ref"
        counterpart_prefix = counterpart + static_prefix[3:]
        counterpart_pattern = (
            r"\b" + re.escape(counterpart_prefix) + r"\s*\.\s*" + re.escape(method_name) + r"\s*\("
        )
        if not re.search(counterpart_pattern, active_content):
            continue
        args = _call_arguments(active_content, match.end() - 1)
        arg_count = len(args) if args is not None else None
        type_hints = _argument_type_hints(active_content, args, match.start())
        class_name = _class_name_from_static_ref_gen_prefix(static_prefix)
        candidates = (
            keys_by_sol_class_method.get((sol_path, class_name, method_name), [])
            if class_name
            else keys_by_sol_method.get((sol_path, method_name), [])
        )
        if arg_count is not None:
            candidates = [
                key for key in candidates if _parameter_count_from_signature(key[3]) == arg_count
            ]
        candidates = _filter_candidates_by_type_hints(candidates, type_hints)
        if len(candidates) == 1:
            used.add(candidates[0])

    instance_vars: dict[str, dict[str, str]] = {"Ref": {}, "Gen": {}}
    for match in re.finditer(
        r"\b(Ref|Gen)([A-Za-z0-9_]*)_\d+\s+([A-Za-z_][A-Za-z0-9_]*)\b",
        active_content,
    ):
        instance_vars[match.group(1)][match.group(3)] = match.group(2)
    if instance_vars["Ref"] and instance_vars["Gen"]:
        called_by_side: dict[str, set[tuple[str, str]]] = {"Ref": set(), "Gen": set()}
        for side, names in instance_vars.items():
            for name, class_name in names.items():
                for match in re.finditer(
                    r"\b" + re.escape(name) + r"\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:\{[^{}]*\}\s*)?\(",
                    active_content,
                ):
                    called_by_side[side].add((class_name, _resolve_exposed_method_name(match.group(1))))
        for class_name, method_name in sorted(called_by_side["Ref"] & called_by_side["Gen"]):
            candidates = keys_by_sol_class_method.get((sol_path, class_name, method_name), [])
            if len(candidates) == 1:
                used.add(candidates[0])

    if len(used) == 1:
        return next(iter(used))
    return None


def _check_method_map(
    manifest: dict[str, Any],
    dataset: dict[str, Any],
    symbolic_dir: Path,
) -> dict[str, dict[str, Any]]:
    """Map active symbolic checks to original dataset functions where attribution is one-to-one."""
    functions = _dataset_functions(dataset)
    original_keys = set(functions)
    sol_to_test = _sol_to_symbolic_test(manifest)

    wrapper_keys_by_sol: dict[str, dict[str, FunctionKey]] = {}
    keys_by_sol_method: dict[tuple[str, str], list[FunctionKey]] = {}
    keys_by_sol_class_method: dict[tuple[str, str, str], list[FunctionKey]] = {}
    for key in original_keys:
        keys_by_sol_method.setdefault((key[0], key[2]), []).append(key)
        keys_by_sol_class_method.setdefault((key[0], key[1], key[2]), []).append(key)
    for method in list(manifest.get("methods", [])) + list(manifest.get("skipped_methods", [])):
        key = _function_key(method)
        wrapper_name = str(method.get("wrapper_name") or "")
        if key in original_keys and wrapper_name:
            wrapper_keys_by_sol.setdefault(key[0], {})[wrapper_name] = key

    mapping: dict[str, dict[str, Any]] = {}
    for method in manifest.get("methods", []):
        check_name = str(method.get("check_name") or "")
        if not check_name:
            continue
        key = _function_key(method)
        target_key: FunctionKey | None = None
        attribution = ""
        if key in original_keys:
            target_key = key
            attribution = "direct_manifest"
        else:
            target_wrapper_name = str(method.get("target_wrapper_name") or "")
            if target_wrapper_name:
                target_key = wrapper_keys_by_sol.get(str(method.get("sol_path") or ""), {}).get(target_wrapper_name)
                attribution = "target_wrapper_name"
            else:
                test_path = sol_to_test.get(str(method.get("sol_path") or ""))
                if test_path:
                    wrapper_name = _single_wrapper_for_check(symbolic_dir, test_path, check_name)
                    if wrapper_name:
                        target_key = wrapper_keys_by_sol.get(str(method.get("sol_path") or ""), {}).get(wrapper_name)
                        attribution = "single_wrapper_selector"
                    if target_key is None:
                        target_key = _single_direct_ref_gen_key_for_check(
                            symbolic_dir,
                            test_path,
                            str(method.get("sol_path") or ""),
                            check_name,
                            keys_by_sol_method,
                            keys_by_sol_class_method,
                        )
                        if target_key is not None:
                            attribution = "single_direct_ref_gen_call"
        if target_key and target_key in functions:
            mapping[check_name] = {
                **functions[target_key],
                "check_name": check_name,
                "test_name": method.get("test_name"),
                "attribution": attribution,
            }
    return mapping


def _attach_method_results(
    result: dict[str, Any],
    check_method_map: dict[str, dict[str, Any]],
    checks_by_sol: dict[str, list[str]] | None = None,
) -> None:
    check_statuses = result.get("check_statuses") or {}
    check_names = list(result.get("check_names") or [])
    if checks_by_sol is not None:
        check_names = list(checks_by_sol.get(str(result.get("sol_path") or ""), check_names))
    if result.get("extract_error"):
        default_status = "EXTRACT_ERROR"
    elif result.get("compile_error"):
        default_status = "COMPILE_ERROR"
    elif result.get("missing_row"):
        default_status = "MISSING_ROW"
    else:
        default_status = "NO_STATUS"
    if checks_by_sol is not None and default_status != "NO_STATUS":
        check_statuses = {check_name: default_status for check_name in check_names}
    elif not check_statuses and checks_by_sol is not None:
        check_statuses = {check_name: default_status for check_name in check_names}
    grouped: dict[FunctionKey, dict[str, Any]] = {}
    for check_name in check_names:
        method = check_method_map.get(str(check_name))
        if not method:
            continue
        status = str(check_statuses.get(check_name) or "MISSING")
        key = _function_key(method)
        item = grouped.setdefault(
            key,
            {
                **{k: v for k, v in method.items() if k not in {"check_name", "test_name", "attribution"}},
                "checks": [],
            },
        )
        item["checks"].append(
            {
                "check_name": check_name,
                "test_name": method.get("test_name"),
                "attribution": method.get("attribution"),
                "status": status,
            }
        )

    method_results = []
    status_counts: Counter[str] = Counter()
    for item in grouped.values():
        statuses = [check["status"] for check in item["checks"]]
        if statuses and all(status == "PASS" for status in statuses):
            status = "PASS"
        elif any(status == "TIMEOUT" for status in statuses):
            status = "TIMEOUT"
        elif any(status == "COMPILE_ERROR" for status in statuses):
            status = "COMPILE_ERROR"
        elif any(status == "EXTRACT_ERROR" for status in statuses):
            status = "EXTRACT_ERROR"
        elif any(status == "MISSING_ROW" for status in statuses):
            status = "MISSING_ROW"
        elif any(status == "MISSING" for status in statuses):
            status = "MISSING"
        else:
            status = "FAIL"
        status_counts[status] += 1
        item["status"] = status
        item["passed"] = status == "PASS"
        method_results.append(item)
    method_results.sort(
        key=lambda item: (
            str(item.get("sol_path")),
            str(item.get("class_name")),
            str(item.get("method_name")),
            str(item.get("full_signature")),
        )
    )

    passed = status_counts.get("PASS", 0)
    total = len(method_results)
    result["method_results"] = method_results
    result["method_level_summary"] = {
        "expected_methods": total,
        "passed_methods": passed,
        "failed_methods": max(total - passed, 0),
        "status_counts": dict(status_counts),
    }


def _failure_result(result: dict[str, Any], expected_checks: int, **updates: Any) -> dict[str, Any]:
    result.update(updates)
    result.setdefault("proved_checks", 0)
    result.setdefault("failed_checks", expected_checks - int(result.get("proved_checks") or 0))
    result.setdefault("timeouts", 0)
    result["proved"] = False
    result["ok"] = False
    return result


def _skipped_result(result: dict[str, Any], reason: str) -> dict[str, Any]:
    result["proved"] = False
    result["ok"] = False
    result["skipped"] = True
    result["skip_reason"] = reason
    result["skipped_checks"] = int(result.get("skipped_checks") or result.get("manifest_skipped_checks") or result.get("expected_checks") or 0)
    result["failed_checks"] = 0
    result["proved_checks"] = 0
    result["timeouts"] = 0
    return result


def _join_halmos_output(raw_runs: list[dict[str, Any]], key: str) -> str:
    if len(raw_runs) == 1:
        return raw_runs[0].get(key) or ""
    parts = []
    total = len(raw_runs)
    for index, raw in enumerate(raw_runs, start=1):
        parts.append(f"--- halmos chunk {index}/{total} ---\n{raw.get(key) or ''}")
    return "\n\n".join(parts)


def _halmos_env_for_feedback(feedback_rel: str | None) -> dict[str, str]:
    if not feedback_rel:
        return {}
    env: dict[str, str] = {}
    if "repository/openzeppelin-foundry-upgrades/" in feedback_rel:
        # Halmos currently does not support Cancun's MCOPY opcode (0x5e). These
        # harnesses do not rely on Cancun semantics, so compile them for Paris.
        env["FOUNDRY_EVM_VERSION"] = "paris"
    parts = Path(feedback_rel).parts
    for index, part in enumerate(parts):
        if part == "test-profiles" and index + 1 < len(parts):
            env["FOUNDRY_PROFILE"] = parts[index + 1]
            return env
    if "repository/solady/lib/solady/test/ext/ithaca" in feedback_rel:
        env["FOUNDRY_PROFILE"] = "ithaca"
        return env
    if "repository/solady/lib/solady/test/" in feedback_rel and "Transient" in feedback_rel:
        env["FOUNDRY_PROFILE"] = "post_cancun"
        return env
    return env


def _fetch_row(conn: sqlite3.Connection, target: Target, sol_path: str) -> dict[str, Any] | None:
    if target.source == "agent":
        cursor = conn.execute(
            """
            SELECT * FROM progress_tracker_agent
            WHERE file_path = ? AND model_coding = ? AND agent_type = ?
            """,
            (sol_path, target.model, target.agent_type),
        )
    else:
        cursor = conn.execute(
            f"""
            SELECT * FROM {target.table}
            WHERE file_path = ? AND model_coding = ?
            """,
            (sol_path, target.model),
        )
    row = cursor.fetchone()
    return dict(row) if row else None


def _run_one(
    conn: sqlite3.Connection,
    target: Target,
    sol_path: str,
    symbolic_dir: Path,
    manifest_cases_by_sol: dict[str, dict[str, Any]],
    manifest_methods_by_sol: dict[str, list[dict[str, Any]]],
    shared_groups: dict[str, list[str]],
    check_method_map: dict[str, dict[str, Any]],
    *,
    selection_policy: str,
    timeout: int,
    loop: int,
    solver_timeout_assertion: int,
    solver_timeout_branching: int,
    chunk_size: int | None,
) -> dict[str, Any]:
    case = manifest_cases_by_sol.get(sol_path)
    methods = manifest_methods_by_sol.get(sol_path, [])
    skipped_methods = (case or {}).get("skipped_methods", [])
    feedback_rel = (case or {}).get("feedback_test_path")
    symbolic_rel = (case or {}).get("symbolic_test_path")
    shared_group = shared_groups.get(symbolic_rel or "", [])
    expected_checks = len(methods)
    check_names = [item["check_name"] for item in methods]
    result: dict[str, Any] = {
        "source": target.source,
        "source_name": target.source_name,
        "model": target.model,
        "agent_type": target.agent_type,
        "sol_path": sol_path,
        "feedback_test_path": feedback_rel,
        "symbolic_test_path": symbolic_rel,
        "shared_symbolic_group_size": len(shared_group),
        "shared_symbolic_group_sol_paths": shared_group,
        "test_names": [item.get("test_name") for item in methods],
        "check_names": check_names,
        "methods_count": expected_checks,
        "manifest_skipped_checks": len(skipped_methods),
        "skipped_checks": 0,
        "expected_checks": expected_checks,
        "expected_tests": expected_checks,
        "proved_checks": 0,
        "failed_checks": expected_checks,
        "timeouts": 0,
        "proved": False,
        "ok": False,
    }

    if case is None:
        return _failure_result(result, expected_checks, error="missing symbolic manifest case")
    if not methods and skipped_methods:
        return _skipped_result(result, "no Halmos-eligible symbolic methods for sol_path")
    if not methods:
        return _skipped_result(result, "no symbolic methods for sol_path")
    if feedback_rel != case["feedback_test_path"]:
        return _failure_result(result, expected_checks, error="manifest feedback_test_path mismatch")

    row = _fetch_row(conn, target, sol_path)
    if row is None:
        return _failure_result(result, expected_checks, missing_row=True, error="missing DB row")

    result["row_id"] = row.get("id")
    result["row_status"] = row.get("status")
    code_selection, extract_error = _select_code(
        target,
        row,
        sol_path,
        selection_policy,
    )
    if code_selection is None:
        return _failure_result(result, expected_checks, extract_error=extract_error or "code extraction failed")

    result["code_selection"] = code_selection.code_selection
    result["code_extractor"] = code_selection.extractor
    result["best_round"] = code_selection.best_round
    result["best_pass"] = code_selection.best_pass
    result["best_total"] = code_selection.best_total
    result["code_bytes"] = len(code_selection.code.encode("utf-8"))

    try:
        symbolic_abs = _safe_join(symbolic_dir, symbolic_rel)
        symbolic_content = symbolic_abs.read_text(encoding="utf-8")
    except Exception as exc:
        return _failure_result(result, expected_checks, error=f"failed to read symbolic test: {exc}")

    feedback_abs = _safe_join(ROOT, feedback_rel)
    project_root_abs = _safe_join(ROOT, case["project_root"])
    halmos_env = _halmos_env_for_feedback(feedback_rel)

    with tempfile.TemporaryDirectory(prefix="verify_symbolic_models_") as tmp:
        tmpdir = Path(tmp)
        temp_symbolic = tmpdir / feedback_abs.name
        temp_symbolic.write_text(symbolic_content, encoding="utf-8")
        replacements = [(feedback_abs, temp_symbolic)]
        shared_code: dict[str, str] = {sol_path: code_selection.code}
        for shared_sol_path in shared_group:
            if shared_sol_path in shared_code:
                continue
            shared_row = _fetch_row(conn, target, shared_sol_path)
            if shared_row is None:
                return _failure_result(
                    result,
                    expected_checks,
                    missing_row=True,
                    error=f"missing DB row for shared symbolic dependency: {shared_sol_path}",
                )
            shared_selection, shared_extract_error = _select_code(
                target,
                shared_row,
                shared_sol_path,
                selection_policy,
            )
            if shared_selection is None:
                return _failure_result(
                    result,
                    expected_checks,
                    extract_error=shared_extract_error
                    or f"code extraction failed for shared symbolic dependency: {shared_sol_path}",
                )
            shared_code[shared_sol_path] = shared_selection.code
        for shared_sol_path, code in shared_code.items():
            shared_sol_abs = _safe_join(ROOT, shared_sol_path)
            gen_copy_abs = _gen_copy_path(shared_sol_abs)
            temp_gen = tmpdir / f"{gen_copy_abs.name}.{abs(hash(shared_sol_path))}.sol"
            temp_gen.write_text(code.rstrip() + "\n", encoding="utf-8")
            replacements.append((gen_copy_abs, temp_gen))
        if sol_path == DEFENDER_DEPLOY_SOL:
            utils_abs = _safe_join(ROOT, OPENZEPPELIN_UTILS_SOL)
            temp_utils = tmpdir / "Utils.sol"
            temp_utils.write_text(openzeppelin_utils_stub_source(), encoding="utf-8")
            replacements.append((utils_abs, temp_utils))

        try:
            check_chunks = split_check_chunks(check_names, chunk_size)
            raw_runs: list[dict[str, Any]] = []
            with locked_path_replacements(
                ROOT,
                feedback_abs,
                replacements,
                tmpdir,
            ):
                for check_chunk in check_chunks:
                    raw_runs.append(
                        run_halmos(
                            project_root=project_root_abs,
                            check_names=check_chunk,
                            timeout=timeout,
                            loop=loop,
                            solver_timeout_assertion=solver_timeout_assertion,
                            solver_timeout_branching=solver_timeout_branching,
                            env=halmos_env,
                            extra_args=halmos_extra_args_for_sol(sol_path),
                        )
                    )
        except Exception as exc:
            return _failure_result(result, expected_checks, error=str(exc))

    parsed = parse_halmos_runs(raw_runs, check_chunks, check_names)
    result.update(parsed)
    _attach_method_results(result, check_method_map)
    result["ok"] = bool(parsed.get("proved"))
    result["halmos_command"] = raw_runs[0]["command"]
    result["halmos_returncode"] = raw_runs[-1].get("returncode")
    result["halmos_stdout"] = _bounded(_join_halmos_output(raw_runs, "stdout"))
    result["halmos_stderr"] = _bounded(_join_halmos_output(raw_runs, "stderr"))
    result["halmos_json_error"] = "\n".join(
        str(raw.get("json_error")) for raw in raw_runs if raw.get("json_error")
    ) or None
    if len(raw_runs) > 1:
        result["halmos_chunk_count"] = len(raw_runs)
        result["halmos_commands"] = [raw["command"] for raw in raw_runs]
    result["failure_category"] = classify_symbolic_failure(result)
    return result


def _empty_method_summary() -> dict[str, Any]:
    return {
        "expected_methods": 0,
        "passed_methods": 0,
        "failed_methods": 0,
        "status_counts": {},
    }


def _accumulate_method_summary(summary: dict[str, Any], result: dict[str, Any]) -> None:
    method_summary = result.get("method_level_summary") or {}
    summary["expected_methods"] += int(method_summary.get("expected_methods") or 0)
    summary["passed_methods"] += int(method_summary.get("passed_methods") or 0)
    summary["failed_methods"] += int(method_summary.get("failed_methods") or 0)
    status_counts = summary.setdefault("status_counts", {})
    for status, count in (method_summary.get("status_counts") or {}).items():
        status_counts[status] = int(status_counts.get(status) or 0) + int(count or 0)


def _method_level_summary(results: list[dict[str, Any]]) -> dict[str, Any]:
    global_summary = _empty_method_summary()
    groups: dict[str, dict[str, Any]] = {}
    for result in results:
        _accumulate_method_summary(global_summary, result)
        key = f"{result.get('source')}|{result.get('model')}|{result.get('agent_type') or ''}"
        if key not in groups:
            groups[key] = {
                "source": result.get("source"),
                "source_name": result.get("source_name"),
                "model": result.get("model"),
                "agent_type": result.get("agent_type"),
                **_empty_method_summary(),
            }
        _accumulate_method_summary(groups[key], result)
    for item in [global_summary, *groups.values()]:
        expected = int(item.get("expected_methods") or 0)
        passed = int(item.get("passed_methods") or 0)
        item["pass_rate"] = (passed / expected) if expected else None
    return {
        "global": global_summary,
        "groups": sorted(
            groups.values(),
            key=lambda item: (str(item.get("source")), str(item.get("model")), str(item.get("agent_type") or "")),
        ),
    }


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run RQ3 Halmos symbolic tests against model outputs from progress.db")
    parser.add_argument("--db", default="output/progress.db", help="Path to progress.db")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST, help="symbolic manifest path")
    parser.add_argument("--symbolic-dir", type=Path, help="symbolic test directory; defaults to manifest parent")
    parser.add_argument(
        "--source",
        choices=["rawmodel", "solagent", "solagent-summary", "agent"],
        help="Optional source filter",
    )
    parser.add_argument("--model", help="Optional model filter; comma-separated values are accepted")
    parser.add_argument("--agent", help="Optional agent filter; comma-separated values are accepted")
    parser.add_argument("--sol", help="Optional dataset sol_path filter; comma-separated values are accepted")
    parser.add_argument("--limit", type=int, help="Optional max number of sol evaluations after filtering")
    parser.add_argument("--fail-fast", action="store_true", help="Stop after first failed sol")
    parser.add_argument("--timeout", type=int, default=60, help="Per-sol Halmos timeout in seconds")
    parser.add_argument("--halmos-bin", help="Optional Halmos executable path; overrides PATH")
    parser.add_argument("--chunk-size", type=int, help="Optional number of checks per Halmos invocation")
    parser.add_argument(
        "--selection-policy",
        choices=["best-pass-first", "test-first-security-second"],
        default=DEFAULT_SELECTION_POLICY,
        help="SolAgent checkpoint selection policy",
    )
    parser.add_argument("--loop", type=int, default=2, help="Halmos loop bound")
    parser.add_argument("--solver-timeout-assertion", type=int, default=1000, help="Halmos assertion solver timeout in ms")
    parser.add_argument("--solver-timeout-branching", type=int, default=1, help="Halmos branching solver timeout in ms")
    parser.add_argument("--report", type=Path, default=REPORT_PATH, help="Output report path")
    return parser.parse_args()


def _write_report(report_path: Path, results: list[dict[str, Any]]) -> dict[str, Any]:
    summary = build_symbolic_summary(results)
    summary["method_level"] = _method_level_summary(results)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps({"summary": summary, "results": results}, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return summary


def main() -> int:
    args = _parse_args()
    if args.halmos_bin:
        os.environ["HALMOS_BIN"] = args.halmos_bin
    db_path = _resolve_db_path(args.db)
    dataset = _load_dataset(DEFAULT_DATASET)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    symbolic_dir = (args.symbolic_dir or args.manifest.resolve().parent).resolve()

    manifest_cases_by_sol = {case["sol_path"]: case for case in manifest["cases"]}
    manifest_methods_by_sol: dict[str, list[dict[str, Any]]] = {}
    for item in manifest["methods"]:
        manifest_methods_by_sol.setdefault(item["sol_path"], []).append(item)
    check_method_map = _check_method_map(manifest, dataset, symbolic_dir)
    shared_groups: dict[str, list[str]] = {}
    for case in manifest["cases"]:
        shared_groups.setdefault(case["symbolic_test_path"], []).append(case["sol_path"])

    sol_paths = list(dataset)
    if args.sol:
        requested = set(_split_csv(args.sol, []))
        unknown = sorted(requested - set(dataset))
        if unknown:
            print(f"[error] unknown sol_path filter: {unknown}", file=sys.stderr)
            return 2
        sol_paths = [sol_path for sol_path in sol_paths if sol_path in requested]

    targets = _source_targets(args)
    tasks = [(target, sol_path) for target in targets for sol_path in sol_paths]
    if args.limit is not None:
        tasks = tasks[: args.limit]
    if not tasks:
        print("[error] no symbolic tasks selected", file=sys.stderr)
        return 2

    missing_tables = sorted({target.table for target, _sol_path in tasks if target.table})
    results: list[dict[str, Any]] = []
    with _connect_readonly(db_path) as conn:
        for table in missing_tables:
            if not _table_exists(conn, table):
                print(f"[error] DB table not found: {table}", file=sys.stderr)
                return 2

        for index, (target, sol_path) in enumerate(tasks, start=1):
            agent_suffix = f"/{target.agent_type}" if target.agent_type else ""
            print(f"[symbolic] {index}/{len(tasks)} {target.source}{agent_suffix} {target.model} {sol_path}", flush=True)
            result = _run_one(
                conn,
                target,
                sol_path,
                symbolic_dir,
                manifest_cases_by_sol,
                manifest_methods_by_sol,
                shared_groups,
                check_method_map,
                selection_policy=args.selection_policy,
                timeout=args.timeout,
                loop=args.loop,
                solver_timeout_assertion=args.solver_timeout_assertion,
                solver_timeout_branching=args.solver_timeout_branching,
                chunk_size=args.chunk_size,
            )
            results.append(result)
            if result.get("skipped"):
                print(
                    f"[skip] {target.source}{agent_suffix} {target.model} {sol_path}: "
                    f"{result.get('skip_reason')}",
                    flush=True,
                )
            elif result.get("ok"):
                print(
                    f"[proved] {target.source}{agent_suffix} {target.model} {sol_path} "
                    f"({result['proved_checks']}/{result['expected_checks']})",
                    flush=True,
                )
            else:
                reason = (
                    result.get("extract_error")
                    or result.get("compile_error")
                    or result.get("timeout_error")
                    or result.get("error")
                    or f"{result.get('failed_checks')}/{result.get('expected_checks')} failed"
                )
                print(f"[fail] {target.source}{agent_suffix} {target.model} {sol_path}: {reason}", flush=True)
                if args.fail_fast:
                    _write_report(args.report, results)
                    break
            _write_report(args.report, results)

    summary = _write_report(args.report, results)
    global_summary = summary["global"]
    print(
        f"[symbolic] sols={global_summary['sols']} "
        f"proved_sols={global_summary['proved_sols']} failed_sols={global_summary['failed_sols']} "
        f"expected_checks={global_summary['expected_checks']} "
        f"proved_checks={global_summary['proved_checks']} failed_checks={global_summary['failed_checks']} "
        f"timeouts={global_summary['timeouts']} compile_errors={global_summary['compile_errors']} "
        f"extract_errors={global_summary['extract_errors']} missing_rows={global_summary['missing_rows']}",
        flush=True,
    )
    method_global = summary["method_level"]["global"]
    print(
        f"[symbolic-methods] expected_methods={method_global['expected_methods']} "
        f"passed_methods={method_global['passed_methods']} failed_methods={method_global['failed_methods']}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
