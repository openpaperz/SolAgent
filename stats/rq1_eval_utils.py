"""Load RQ1 eval reports and reconstruct the exact code they tested."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Dict, Iterable, Optional, Tuple

from testing.rq1_verify_eval_models import CodeSelection, Target, select_code


DEFAULT_EVAL_RESULT_PATHS = [
    "testing/eval/rq1_verify_eval_agents_seed1.json",
    "testing/eval/rq1_verify_eval_models_security_selected_seed1.json",
    "testing/eval/rq1_verify_eval_rawmodel_seed1.json",
]

EvalKey = Tuple[str, str, str]


def eval_source(result: Dict[str, Any]) -> str:
    source = str(result.get("source") or "")
    if source == "agent":
        agent_type = str(result.get("agent_type") or "")
        if not agent_type:
            raise ValueError("Agent eval result is missing agent_type")
        return agent_type
    return source


def eval_key(result: Dict[str, Any]) -> EvalKey:
    return (
        eval_source(result),
        str(result.get("model") or ""),
        str(result.get("sol_path") or ""),
    )


def entry_eval_key(entry: Dict[str, Any]) -> EvalKey:
    return (
        str(entry.get("_source") or ""),
        str(entry.get("_model") or ""),
        str(entry.get("file_path") or ""),
    )


def load_eval_results(paths: Iterable[Path]) -> Dict[EvalKey, Dict[str, Any]]:
    results: Dict[EvalKey, Dict[str, Any]] = {}
    for path in paths:
        data = json.loads(path.read_text(encoding="utf-8"))
        rows = data.get("results") if isinstance(data, dict) else None
        if not isinstance(rows, list):
            raise ValueError(f"Eval report has no results list: {path}")
        for raw in rows:
            if not isinstance(raw, dict):
                raise ValueError(f"Eval report contains a non-object result: {path}")
            row = dict(raw)
            row["_report_path"] = str(path)
            key = eval_key(row)
            if not all(key):
                raise ValueError(f"Eval result has an incomplete key in {path}: {key}")
            if key in results:
                raise ValueError(f"Duplicate eval result for {key}")
            results[key] = row
    return results


def eval_compiled(result: Dict[str, Any]) -> bool:
    if (
        result.get("compile_error")
        or result.get("extract_error")
        or result.get("error")
    ):
        return False
    expected = int(result.get("expected_tests") or 0)
    forge_total = int(result.get("forge_total") or 0)
    return expected > 0 and forge_total > 0


def eval_test_fields(result: Dict[str, Any]) -> Dict[str, int]:
    expected = int(result.get("expected_tests") or 0)
    passed = int(result.get("passed") or 0)
    compiled = eval_compiled(result)
    full_pass = bool(result.get("ok"))

    if full_pass and (not compiled or passed != expected):
        raise ValueError(
            "Inconsistent eval FullPass result for "
            f"{eval_key(result)}: compiled={compiled}, passed={passed}, expected={expected}"
        )
    if not full_pass and compiled and passed == expected:
        raise ValueError(
            f"Eval result passed every expected test but ok=false for {eval_key(result)}"
        )

    return {
        "test_pass": passed if compiled else 0,
        "test_fail": max(expected - passed, 0) if compiled else 0,
        "test_total": expected if compiled else 0,
    }


def eval_metadata(result: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "report_path": result.get("_report_path"),
        "row_id": result.get("row_id"),
        "row_status": result.get("row_status"),
        "selection_policy": result.get("selection_policy"),
        "code_selection": result.get("code_selection"),
        "code_extractor": result.get("code_extractor"),
        "code_bytes": result.get("code_bytes"),
        "best_round": result.get("best_round"),
        "best_pass": result.get("best_pass"),
        "best_total": result.get("best_total"),
        "best_vuln": result.get("best_vuln"),
        "compiled": eval_compiled(result),
        "full_pass": bool(result.get("ok")),
        "expected_tests": int(result.get("expected_tests") or 0),
        "passed_tests": int(result.get("passed") or 0),
        "failed_tests": int(result.get("failed_tests") or 0),
        "forge_failed": int(result.get("forge_failed") or 0),
        "forge_total": int(result.get("forge_total") or 0),
        "compile_error": result.get("compile_error"),
        "extract_error": result.get("extract_error"),
        "error": result.get("error"),
        "fuzz_seed": result.get("fuzz_seed"),
    }


def _target_for_entry(entry: Dict[str, Any]) -> Target:
    source = str(entry["_source"])
    model = str(entry["_model"])
    table = str(entry["_table"])
    if source == "rawmodel":
        return Target("rawmodel", "Raw Model", table, model)
    if source == "solagent":
        return Target("solagent", "SolAgent", table, model)
    return Target("agent", f"Agent-{source}", table, model, source)


def _validate_selection(
    entry: Dict[str, Any], result: Dict[str, Any], selection: CodeSelection
) -> None:
    expected_row_id = result.get("row_id")
    if expected_row_id is not None and int(expected_row_id) != int(entry["id"]):
        raise ValueError(
            f"Eval row_id mismatch for {entry_eval_key(entry)}: "
            f"report={expected_row_id}, db={entry['id']}"
        )

    code_bytes = len(selection.code.encode("utf-8"))
    expected_bytes = result.get("code_bytes")
    if expected_bytes is not None and code_bytes != int(expected_bytes):
        raise ValueError(
            f"Eval code length mismatch for {entry_eval_key(entry)}: "
            f"reconstructed={code_bytes}, report={expected_bytes}"
        )

    checks = {
        "best_round": selection.best_round,
        "best_pass": selection.best_pass,
        "best_total": selection.best_total,
        "best_vuln": selection.best_vuln,
        "code_selection": selection.code_selection,
        "code_extractor": selection.extractor,
    }
    for key, actual in checks.items():
        expected = result.get(key)
        if expected != actual:
            raise ValueError(
                f"Eval selection mismatch for {entry_eval_key(entry)} field {key}: "
                f"reconstructed={actual!r}, report={expected!r}"
            )


def select_eval_code(
    entry: Dict[str, Any], result: Dict[str, Any]
) -> Tuple[Optional[str], Dict[str, Any]]:
    policy = str(result.get("selection_policy") or "best-pass-first")
    selection, error = select_code(
        _target_for_entry(entry),
        entry,
        str(entry["file_path"]),
        policy,
    )
    meta: Dict[str, Any] = {
        "strategy": "eval_report_selection",
        "selection_policy": policy,
        "skip_reason": None,
        "eval_report_path": result.get("_report_path"),
    }
    if selection is None:
        expected_error = result.get("extract_error")
        if not expected_error:
            raise ValueError(
                f"Could not reconstruct eval code for {entry_eval_key(entry)}: {error}"
            )
        meta["skip_reason"] = str(expected_error)
        return None, meta

    _validate_selection(entry, result, selection)
    meta.update(
        {
            "code_selection": selection.code_selection,
            "code_extractor": selection.extractor,
            "best_round": selection.best_round,
            "best_pass": selection.best_pass,
            "best_total": selection.best_total,
            "best_vuln": selection.best_vuln,
            "sha256": hashlib.sha256(selection.code.encode("utf-8")).hexdigest(),
        }
    )
    return selection.code, meta


def eval_skip_reason(result: Dict[str, Any]) -> Optional[str]:
    if result.get("extract_error"):
        return f"eval code extraction failed: {result['extract_error']}"
    if result.get("compile_error"):
        return "eval compilation failed"
    if result.get("error"):
        return f"eval execution failed: {result['error']}"
    if not eval_compiled(result):
        return "eval did not produce a compiled test result"
    return None
