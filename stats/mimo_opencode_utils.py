#!/usr/bin/env python3
"""Shared loaders for the Mimo SolAgent versus OpenCode comparison."""

from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

from stats.rq2_security_scan_utils import solidity_sloc
from stats.rq2_slither_feedback_statistics import select_test_first_security_second
from testing.mimo_opencode_verify_eval import (
    FIXED_FUZZ_SEED,
    _artifact_file_name,
    _load_artifact,
    _select_opencode_code,
)
from testing.rq1_verify_eval_models import _select_solagent_code


MODEL = "mimo-v2.5-pro"
METHODS = ("SolAgent", "OpenCode")
EXPECTED_TASKS = 81
EXPECTED_TESTS = 1708
SELECTION_POLICY = "test-first-security-second"
DEFAULT_DB = Path("output/progress.db")
DEFAULT_ARTIFACT_DIR = Path("baseline_opencode/result/mimo-v2.5-pro")
DEFAULT_SOLAGENT_EVAL = Path("testing/eval/mimo_solagent_verify_eval_seed1.json")
DEFAULT_OPENCODE_EVAL = Path("testing/eval/mimo_opencode_verify_eval_seed1.json")


class MimoComparisonError(RuntimeError):
    """Raised when Mimo comparison inputs are missing or inconsistent."""


@dataclass(frozen=True)
class SecuritySample:
    model: str
    method: str
    file_path: str
    code: str | None
    sloc: int | None
    finding_count: int | None
    eval_result: Mapping[str, Any]

    @property
    def eval_full_pass(self) -> bool:
        return bool(self.eval_result.get("ok"))

    @property
    def scan_valid(self) -> bool:
        return self.finding_count is not None


def read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise MimoComparisonError(f"Input file not found: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise MimoComparisonError(f"Cannot read {path}: {error}") from error
    if not isinstance(value, dict):
        raise MimoComparisonError(f"Expected a JSON object: {path}")
    return value


def load_eval_report(path: Path, expected_source: str) -> dict[str, dict[str, Any]]:
    report = read_json(path)
    config = report.get("config") or {}
    if config.get("fuzz_seed") != FIXED_FUZZ_SEED:
        raise MimoComparisonError(
            f"Report {path} does not use fixed fuzz seed 1: {config.get('fuzz_seed')!r}"
        )
    results = report.get("results")
    if not isinstance(results, list):
        raise MimoComparisonError(f"Report has no results list: {path}")
    by_path: dict[str, dict[str, Any]] = {}
    for raw in results:
        if not isinstance(raw, dict):
            raise MimoComparisonError(f"Non-object result in {path}")
        if raw.get("source") != expected_source or raw.get("model") != MODEL:
            raise MimoComparisonError(
                f"Unexpected report row identity in {path}: "
                f"{(raw.get('source'), raw.get('model'), raw.get('sol_path'))}"
            )
        sol_path = str(raw.get("sol_path") or "")
        if not sol_path or sol_path in by_path:
            raise MimoComparisonError(f"Missing or duplicate sol_path in {path}: {sol_path!r}")
        if raw.get("fuzz_seed") != FIXED_FUZZ_SEED:
            raise MimoComparisonError(f"Non-seed1 result for {sol_path} in {path}")
        by_path[sol_path] = raw
    if len(by_path) != EXPECTED_TASKS:
        raise MimoComparisonError(f"Expected {EXPECTED_TASKS} rows in {path}, got {len(by_path)}")
    expected_tests = sum(int(row.get("expected_tests") or 0) for row in by_path.values())
    if expected_tests != EXPECTED_TESTS:
        raise MimoComparisonError(
            f"Expected {EXPECTED_TESTS} tests in {path}, got {expected_tests}"
        )
    return by_path


def load_eval_groups(
    solagent_report: Path = DEFAULT_SOLAGENT_EVAL,
    opencode_report: Path = DEFAULT_OPENCODE_EVAL,
) -> dict[str, dict[str, dict[str, Any]]]:
    groups = {
        "SolAgent": load_eval_report(solagent_report, "solagent"),
        "OpenCode": load_eval_report(opencode_report, "opencode"),
    }
    if set(groups["SolAgent"]) != set(groups["OpenCode"]):
        raise MimoComparisonError("SolAgent and OpenCode eval reports cover different tasks")
    return groups


def _connect_read_only(path: Path) -> sqlite3.Connection:
    if not path.is_file():
        raise MimoComparisonError(f"Database not found: {path}")
    connection = sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def load_security_samples(
    db_path: Path = DEFAULT_DB,
    artifact_dir: Path = DEFAULT_ARTIFACT_DIR,
    solagent_report: Path = DEFAULT_SOLAGENT_EVAL,
    opencode_report: Path = DEFAULT_OPENCODE_EVAL,
) -> dict[str, dict[str, SecuritySample]]:
    eval_groups = load_eval_groups(solagent_report, opencode_report)
    samples: dict[str, dict[str, SecuritySample]] = {method: {} for method in METHODS}

    with _connect_read_only(db_path) as connection:
        rows = connection.execute(
            "SELECT * FROM process_tracking WHERE status IN (1, 2) AND model_coding = ?",
            (MODEL,),
        ).fetchall()
    if len(rows) != EXPECTED_TASKS:
        raise MimoComparisonError(
            f"Expected {EXPECTED_TASKS} SolAgent DB rows for {MODEL}, got {len(rows)}"
        )
    for sqlite_row in rows:
        row = dict(sqlite_row)
        file_path = str(row.get("file_path") or "")
        eval_result = eval_groups["SolAgent"].get(file_path)
        if eval_result is None:
            raise MimoComparisonError(f"Missing SolAgent eval result for {file_path}")
        selected = select_test_first_security_second(row)
        selection, _error = _select_solagent_code(row, file_path, SELECTION_POLICY)
        if selected.round_index != eval_result.get("best_round"):
            raise MimoComparisonError(
                f"SolAgent selected-round mismatch for {file_path}: "
                f"DB={selected.round_index}, eval={eval_result.get('best_round')}"
            )
        code = selection.code if selection is not None else None
        if code is not None and len(code.encode("utf-8")) != eval_result.get("code_bytes"):
            raise MimoComparisonError(f"SolAgent selected-code mismatch for {file_path}")
        samples["SolAgent"][file_path] = SecuritySample(
            model=MODEL,
            method="SolAgent",
            file_path=file_path,
            code=code,
            sloc=solidity_sloc(code) if code else None,
            finding_count=selected.vuln_count if selected.scan_valid else None,
            eval_result=eval_result,
        )

    for file_path, eval_result in eval_groups["OpenCode"].items():
        artifact_path = artifact_dir / _artifact_file_name(file_path)
        artifact, error = _load_artifact(artifact_path)
        if artifact is None:
            raise MimoComparisonError(f"Cannot load OpenCode artifact {artifact_path}: {error}")
        selection, _extract_error = _select_opencode_code(artifact, file_path)
        code = selection.code if selection is not None else None
        if code is not None and len(code.encode("utf-8")) != eval_result.get("code_bytes"):
            raise MimoComparisonError(f"OpenCode selected-code mismatch for {file_path}")
        raw_count = artifact.get("vuln_count")
        finding_count = raw_count if isinstance(raw_count, int) and raw_count >= 0 else None
        samples["OpenCode"][file_path] = SecuritySample(
            model=MODEL,
            method="OpenCode",
            file_path=file_path,
            code=code,
            sloc=solidity_sloc(code) if code else None,
            finding_count=finding_count,
            eval_result=eval_result,
        )
    return samples
