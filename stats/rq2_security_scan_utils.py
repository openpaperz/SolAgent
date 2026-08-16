#!/usr/bin/env python3
"""Shared RQ2 selected-code and eval-alignment utilities."""

from __future__ import annotations

import hashlib
import json
import os
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Tuple

from stats.rq1_eval_utils import eval_compiled, eval_test_fields
from stats.rq2_slither_feedback_statistics import (
    SelectedRound,
    connect_read_only,
    select_test_first_security_second,
    validate_tables,
)
from testing.rq1_verify_eval_models import _select_solagent_code


DEFAULT_EVAL_REPORT = "testing/eval/rq2_verify_eval_ablation.json"
SELECTION_POLICY = "test-first-security-second"
DEFAULT_SOURCES = ("full", "no_slither")
SOURCE_CONFIG = {
    "full": ("process_tracking", None),
    "no_slither": ("process_tracking_ablation", 3),
}
EvalKey = Tuple[str, str, str]


@contextmanager
def temporary_missing_project_dependencies(
    project_root: Path,
    orig_repo: Path,
    current_repo: Path,
):
    """Link missing project dependency roots to the eval repository copy."""
    created: List[Path] = []
    try:
        fallback_root = current_repo / project_root.relative_to(orig_repo)
    except ValueError:
        fallback_root = None
    if fallback_root is not None and fallback_root.is_dir():
        for name in ("node_modules",):
            target = project_root / name
            fallback = fallback_root / name
            if os.path.lexists(target) or not fallback.exists():
                continue
            target.symlink_to(fallback.resolve(), target_is_directory=True)
            created.append(target)
    try:
        yield
    finally:
        for path in reversed(created):
            path.unlink(missing_ok=True)


def parse_csv(value: str) -> List[str]:
    return list(
        dict.fromkeys(item.strip() for item in value.split(",") if item.strip())
    )


def sql_placeholders(values: Iterable[object]) -> str:
    return ",".join("?" for _ in values)


def fetch_entries(
    db_path: str,
    sources: List[str],
    models: List[str],
) -> List[Dict[str, Any]]:
    entries: List[Dict[str, Any]] = []
    with connect_read_only(db_path) as connection:
        validate_tables(connection)
        for source in sources:
            table, ablation_type = SOURCE_CONFIG[source]
            query = (
                f"SELECT * FROM {table} WHERE status IN (1, 2) "
                f"AND model_coding IN ({sql_placeholders(models)})"
            )
            parameters: List[object] = list(models)
            if ablation_type is not None:
                query += " AND ablation_type = ?"
                parameters.append(ablation_type)
            query += " ORDER BY model_coding, id"
            for row in connection.execute(query, parameters):
                entry = dict(row)
                entry["_source"] = source
                entry["_table"] = table
                entry["_model"] = str(entry.get("model_coding") or "unknown")
                entries.append(entry)
    return entries


def load_eval_results(
    path: Path,
) -> Tuple[Dict[EvalKey, Dict[str, Any]], Dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    meta = payload.get("meta") if isinstance(payload, dict) else None
    if not isinstance(meta, dict):
        raise ValueError(f"RQ2 eval report has no meta object: {path}")
    if meta.get("selection_policy") != SELECTION_POLICY:
        raise ValueError(
            f"RQ2 eval selection policy is {meta.get('selection_policy')!r}, "
            f"expected {SELECTION_POLICY!r}"
        )
    if meta.get("interrupted"):
        raise ValueError(f"RQ2 eval report is interrupted: {path}")

    rows = payload.get("results")
    if not isinstance(rows, list):
        raise ValueError(f"RQ2 eval report has no results list: {path}")
    results: Dict[EvalKey, Dict[str, Any]] = {}
    for raw in rows:
        if not isinstance(raw, dict):
            raise ValueError(f"RQ2 eval report contains a non-object row: {path}")
        source = str(raw.get("source") or "")
        if source not in DEFAULT_SOURCES:
            continue
        row = dict(raw)
        row["_report_path"] = str(path)
        key = (source, str(row.get("model") or ""), str(row.get("sol_path") or ""))
        if not all(key):
            raise ValueError(f"Incomplete RQ2 eval key: {key}")
        if key in results:
            raise ValueError(f"Duplicate RQ2 eval row: {key}")
        results[key] = row
    return results, dict(meta)


def eval_key_for_entry(entry: Mapping[str, Any]) -> EvalKey:
    return (
        str(entry["_source"]),
        str(entry["_model"]),
        str(entry["file_path"]),
    )


def _selection_metadata(selection: Any, selected: SelectedRound) -> Dict[str, Any]:
    return {
        "strategy": "rq2_test_first_security_second",
        "selection_policy": SELECTION_POLICY,
        "code_selection": selection.code_selection,
        "code_extractor": selection.extractor,
        "best_round": selection.best_round,
        "best_pass": selection.best_pass,
        "best_total": selection.best_total,
        "best_vuln": selection.best_vuln,
        "code_bytes": len(selection.code.encode("utf-8")),
        "sha256": hashlib.sha256(selection.code.encode("utf-8")).hexdigest(),
        "skip_reason": None,
        "feedback_compiled": selected.compiled,
    }


def _validate_eval_alignment(
    entry: Mapping[str, Any],
    selected: SelectedRound,
    selection: Any,
    result: Mapping[str, Any],
) -> None:
    checks = {
        "row_id": (result.get("row_id"), entry.get("id")),
        "selection_policy": (result.get("selection_policy"), SELECTION_POLICY),
        "best_round": (result.get("best_round"), selected.round_index),
        "best_pass": (result.get("best_pass"), selected.passed),
        "best_total": (result.get("best_total"), selected.total),
        "code_bytes": (
            result.get("code_bytes"),
            len(selection.code.encode("utf-8")),
        ),
        "code_selection": (
            result.get("code_selection"),
            selection.code_selection,
        ),
        "code_extractor": (result.get("code_extractor"), selection.extractor),
    }
    mismatches = {
        key: values for key, values in checks.items() if values[0] != values[1]
    }
    if mismatches:
        raise ValueError(
            f"RQ2 eval/code mismatch for {eval_key_for_entry(entry)}: {mismatches}"
        )


def eval_metadata(result: Mapping[str, Any]) -> Dict[str, Any]:
    test_path = str(result.get("eval_test_path") or "")
    profile = None
    parts = Path(test_path).parts
    for index, part in enumerate(parts):
        if part == "test-profiles" and index + 1 < len(parts):
            profile = parts[index + 1]
            break
    sol_path = str(result.get("sol_path") or "")
    if profile is None and "solady" in sol_path and "/ext/ithaca/" in sol_path:
        profile = "ithaca"
    if profile is None and "solady" in sol_path and "Transient" in Path(sol_path).name:
        profile = "post_cancun"
    return {
        "report_path": result.get("_report_path"),
        "row_id": result.get("row_id"),
        "selection_policy": result.get("selection_policy"),
        "fuzz_seed": result.get("fuzz_seed"),
        "eval_test_path": result.get("eval_test_path"),
        "foundry_profile": profile,
        "best_round": result.get("best_round"),
        "compiled": eval_compiled(dict(result)),
        "full_pass": bool(result.get("ok")),
        "expected_tests": int(result.get("expected_tests") or 0),
        "passed_tests": int(result.get("passed") or 0),
        "forge_total": int(result.get("forge_total") or 0),
        "compile_error": result.get("compile_error"),
        "extract_error": result.get("extract_error"),
        "error": result.get("error"),
    }


def prepare_entry(
    entry: Mapping[str, Any],
    eval_results: Mapping[EvalKey, Dict[str, Any]],
) -> Tuple[
    Optional[str],
    Dict[str, Any],
    Dict[str, int],
    Dict[str, Any],
    Dict[str, Any],
]:
    selected = select_test_first_security_second(entry)
    selection, error = _select_solagent_code(
        dict(entry),
        str(entry["file_path"]),
        SELECTION_POLICY,
    )
    result = eval_results.get(eval_key_for_entry(entry))
    if result is None:
        raise ValueError(f"Missing RQ2 eval row for {eval_key_for_entry(entry)}")

    slither = {"count": selected.vuln_count, "summary": selected.severity}
    if selection is None:
        expected_error = result.get("extract_error")
        if not expected_error:
            raise ValueError(
                f"Could not reconstruct code for {eval_key_for_entry(entry)}: {error}"
            )
        code_meta = {
            "strategy": "rq2_test_first_security_second",
            "selection_policy": SELECTION_POLICY,
            "best_round": selected.round_index,
            "best_pass": selected.passed,
            "best_total": selected.total,
            "best_vuln": selected.vuln_count,
            "sha256": None,
            "skip_reason": f"code extraction failed: {expected_error}",
            "feedback_compiled": selected.compiled,
        }
        return (
            None,
            code_meta,
            eval_test_fields(result),
            eval_metadata(result),
            slither,
        )

    _validate_eval_alignment(entry, selected, selection, result)
    code_meta = _selection_metadata(selection, selected)
    if not eval_compiled(result) and not selected.compiled:
        code_meta["skip_reason"] = (
            "selected code did not compile in feedback or eval tests"
        )
    return (
        selection.code,
        code_meta,
        eval_test_fields(result),
        eval_metadata(result),
        slither,
    )


def solidity_sloc(code: str) -> int:
    """Count non-empty Solidity lines after removing comments."""
    output: List[str] = []
    index = 0
    state = "normal"
    quote = ""
    while index < len(code):
        char = code[index]
        next_char = code[index + 1] if index + 1 < len(code) else ""
        if state == "line_comment":
            if char == "\n":
                output.append(char)
                state = "normal"
            index += 1
            continue
        if state == "block_comment":
            if char == "*" and next_char == "/":
                state = "normal"
                index += 2
                continue
            if char == "\n":
                output.append(char)
            index += 1
            continue
        if state == "string":
            output.append(char)
            if char == "\\" and next_char:
                output.append(next_char)
                index += 2
                continue
            if char == quote:
                state = "normal"
            index += 1
            continue
        if char == "/" and next_char == "/":
            state = "line_comment"
            index += 2
            continue
        if char == "/" and next_char == "*":
            state = "block_comment"
            index += 2
            continue
        if char in {"'", '"'}:
            state = "string"
            quote = char
        output.append(char)
        index += 1
    return sum(bool(line.strip()) for line in "".join(output).splitlines())
