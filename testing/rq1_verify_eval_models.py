#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from file_parser import extract_code_blocks  # noqa: E402
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
from utils.code_utils import extract_solidity_code, try_extract_code  # noqa: E402
from utils.forge_utils import check_forge, parse_forge_stdout  # noqa: E402


DEFAULT_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
DEFAULT_AGENTS = ["metagpt", "deepcode", "qwenagent", "copilot"]
REPORT_PATH = ROOT / "testing" / "eval" / "rq1_verify_eval_models.json"
DEFAULT_FUZZ_SEED = "0x0000000000000000000000000000000000000000000000000000000000000001"
DEFAULT_SELECTION_POLICY = "test-first-security-second"


@dataclass(frozen=True)
class Target:
    source: str
    source_name: str
    table: str
    model: str
    agent_type: str | None = None


@dataclass(frozen=True)
class CodeSelection:
    code: str
    code_selection: str
    best_round: int | None = None
    best_pass: int | None = None
    best_total: int | None = None
    best_vuln: int | None = None
    extractor: str | None = None


def _gen_copy_path(sol_path: Path) -> Path:
    return sol_path.with_name(f"{sol_path.stem}.solagent_gen{sol_path.suffix}")


def _safe_json_loads(value: Any, default: Any = None) -> Any:
    if value is None:
        return default
    if isinstance(value, (dict, list)):
        return value
    if not isinstance(value, str) or not value:
        return default
    try:
        return json.loads(value)
    except (json.JSONDecodeError, TypeError):
        return default


def _get_best_pass_round(round_test_json: Any) -> tuple[int, int, int]:
    if not isinstance(round_test_json, dict):
        return (0, 0, 0)

    best_round = 0
    max_pass = -1
    best_total = 0
    for round_idx, test_info in round_test_json.items():
        if not isinstance(test_info, dict):
            continue
        pass_count = int(test_info.get("pass", test_info.get("passed", 0)) or 0)
        total_count = int(test_info.get("total", 0) or 0)
        if pass_count > max_pass:
            try:
                best_round = int(round_idx)
            except (TypeError, ValueError):
                best_round = 0
            max_pass = pass_count
            best_total = total_count
    return (best_round, max_pass if max_pass >= 0 else 0, best_total)


def _get_test_first_security_second_round(
    round_test_json: Any,
    round_vuln_json: Any,
) -> tuple[int, int, int, int | None]:
    """Select max-passed, then min-vulnerability among exact test ties."""
    if not isinstance(round_test_json, dict):
        return (0, 0, 0, None)
    if not isinstance(round_vuln_json, dict):
        round_vuln_json = {}

    candidates: list[tuple[int, int, int, int, int | None]] = []
    for order, (round_idx, test_info) in enumerate(round_test_json.items()):
        if not isinstance(test_info, dict):
            continue
        try:
            parsed_round = int(round_idx)
        except (TypeError, ValueError):
            continue
        pass_count = int(test_info.get("pass", test_info.get("passed", 0)) or 0)
        total_count = int(test_info.get("total", 0) or 0)
        raw_vuln = round_vuln_json.get(str(parsed_round))
        vuln_count = None
        if isinstance(raw_vuln, (int, float)) and not isinstance(raw_vuln, bool):
            parsed_vuln = int(raw_vuln)
            if parsed_vuln >= 0 and parsed_vuln == raw_vuln:
                vuln_count = parsed_vuln
        candidates.append((order, parsed_round, pass_count, total_count, vuln_count))

    if not candidates:
        return (0, 0, 0, None)
    max_pass = max(candidate[2] for candidate in candidates)
    first_best = next(candidate for candidate in candidates if candidate[2] == max_pass)
    exact_test_ties = [
        candidate
        for candidate in candidates
        if (candidate[2], candidate[3]) == (first_best[2], first_best[3])
    ]
    scanned_ties = [candidate for candidate in exact_test_ties if candidate[4] is not None]
    selected = (
        min(scanned_ties, key=lambda candidate: (candidate[4], candidate[0]))
        if scanned_ties
        else min(exact_test_ties, key=lambda candidate: candidate[0])
    )
    return (selected[1], selected[2], selected[3], selected[4])


def _split_csv(value: str | None, default: list[str]) -> list[str]:
    if not value:
        return list(default)
    return [item.strip() for item in value.split(",") if item.strip()]


def _resolve_db_path(path: str) -> Path:
    db_path = Path(path)
    if not db_path.is_absolute():
        db_path = ROOT / db_path
    return db_path.resolve()


def _connect_readonly(db_path: Path) -> sqlite3.Connection:
    uri = f"file:{db_path.as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name = ?", (table,))
    return cursor.fetchone() is not None


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


def _message_content(message: dict[str, Any]) -> str:
    content = message.get("content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        pieces: list[str] = []
        for item in content:
            if isinstance(item, str):
                pieces.append(item)
            elif isinstance(item, dict):
                text = item.get("text") or item.get("content")
                if isinstance(text, str):
                    pieces.append(text)
        return "\n".join(pieces)
    if content is None:
        return ""
    return str(content)


def _normalize_code(code: Any) -> str | None:
    if not isinstance(code, str):
        return None
    code = code.strip()
    if not code or code == "NoContent":
        return None
    extracted, ok = extract_solidity_code(code)
    if ok:
        code = extracted.strip()
    primary_prefixes = ("// SPDX", "pragma solidity")
    declaration_prefixes = ("contract ", "abstract contract ", "library ", "interface ", "type ")
    prefixes = primary_prefixes + declaration_prefixes
    stripped = code.lstrip()
    primary_positions = [stripped.find(prefix) for prefix in primary_prefixes if stripped.find(prefix) >= 0]
    if primary_positions:
        stripped = stripped[min(primary_positions) :].lstrip()
    elif not stripped.startswith(prefixes):
        positions = [stripped.find(prefix) for prefix in declaration_prefixes if stripped.find(prefix) >= 0]
        if positions:
            stripped = stripped[min(positions) :].lstrip()
    code = stripped
    if not code or code == "NoContent":
        return None
    return code


def _looks_like_solidity(code: str | None, file_stem: str | None = None, require_stem: bool = False) -> bool:
    if not code:
        return False
    prefixes = ("// SPDX", "pragma solidity", "contract ", "abstract contract ", "library ", "interface ", "type ")
    stripped = code.lstrip()
    if not stripped.startswith(prefixes):
        return False
    if stripped.startswith(("contract ", "abstract contract ", "library ", "interface ")):
        declaration_re = r"^(?:abstract\s+contract|contract|library|interface)\s+[A-Za-z_][A-Za-z0-9_]*(?:\s+is\s+[^{]+)?\s*\{"
        if not re.search(declaration_re, stripped, flags=re.DOTALL):
            return False
    elif stripped.startswith("type "):
        if not re.search(r"^type\s+[A-Za-z_][A-Za-z0-9_]*\s+is\s+", stripped):
            return False
    if require_stem and file_stem:
        stem = re.escape(file_stem)
        same_name_re = (
            rf"\b(?:abstract\s+contract|contract|library|interface)\s+{stem}\b"
            rf"|\btype\s+{stem}\s+is\b"
        )
        if not re.search(same_name_re, code):
            return False
    return True


def _extract_from_tool_call_input(input_data: Any, file_name: str) -> tuple[str | None, str | None]:
    if isinstance(input_data, str):
        input_data = _safe_json_loads(input_data, {})
    if not isinstance(input_data, dict):
        return None, None

    path_value = input_data.get("file_path") or input_data.get("path") or input_data.get("filename")
    if path_value:
        path_text = str(path_value)
        if path_text != file_name and Path(path_text).name != file_name:
            return None, None

    code = _normalize_code(input_data.get("content") or input_data.get("code"))
    if code and _looks_like_solidity(code):
        return code, "deepcode_tool_call"
    return None, None


def _extract_from_deepcode_tool_calls(message: dict[str, Any], file_name: str) -> tuple[str | None, str | None]:
    tool_calls = message.get("tool_calls") or []
    if not isinstance(tool_calls, list):
        return None, None
    for call in reversed(tool_calls):
        if not isinstance(call, dict):
            continue
        name = call.get("name")
        input_data = call.get("input") or call.get("args") or call.get("arguments")
        function_data = call.get("function")
        if isinstance(function_data, dict):
            name = name or function_data.get("name")
            input_data = input_data or function_data.get("arguments")
        if name != "write_file":
            continue
        code, extractor = _extract_from_tool_call_input(input_data, file_name)
        if code:
            return code, extractor
    return None, None


def _extract_from_content(content: str, file_name: str, require_stem: bool = False) -> tuple[str | None, str | None]:
    file_stem = Path(file_name).stem
    try:
        all_files, _remaining = extract_code_blocks(content, target_filename=file_name)
        for item in all_files:
            if not isinstance(item, dict):
                continue
            code = _normalize_code(item.get("code"))
            if _looks_like_solidity(code, file_stem=file_stem, require_stem=require_stem):
                return code, "extract_code_blocks"
    except Exception:
        pass

    code = _normalize_code(try_extract_code(content))
    if _looks_like_solidity(code, file_stem=file_stem, require_stem=require_stem):
        return code, "try_extract_code"
    return None, None


def _extract_code_from_messages(
    messages: Any,
    file_name: str,
    agent_type: str | None = None,
) -> tuple[str | None, str | None, str | None]:
    if not isinstance(messages, list):
        return None, None, "messages is not a list"

    require_stem = agent_type == "metagpt"
    for message in reversed(messages):
        if not isinstance(message, dict) or message.get("role") != "assistant":
            continue
        content = _message_content(message)

        if agent_type == "metagpt":
            code = _normalize_code(try_extract_code(content))
            if _looks_like_solidity(code, file_stem=Path(file_name).stem, require_stem=True):
                return code, "try_extract_code", None

        code, extractor = _extract_from_content(content, file_name, require_stem=require_stem)
        if code:
            return code, extractor, None

        if agent_type == "deepcode":
            code, extractor = _extract_from_deepcode_tool_calls(message, file_name)
            if code:
                return code, extractor, None

    return None, None, "no assistant message with valid Solidity code"


def _select_solagent_code(
    row: dict[str, Any],
    sol_path: str,
    selection_policy: str,
) -> tuple[CodeSelection | None, str | None]:
    file_name = Path(sol_path).name
    round_test_json = _safe_json_loads(row.get("test_json"), {})
    best_vuln = None
    if selection_policy == "test-first-security-second":
        round_vuln_json = _safe_json_loads(row.get("round_vuln_count"), {})
        best_round, best_pass, best_total, best_vuln = _get_test_first_security_second_round(
            round_test_json,
            round_vuln_json,
        )
    else:
        best_round, best_pass, best_total = _get_best_pass_round(round_test_json)

    if best_round > 0:
        round_messages = _safe_json_loads(row.get("round_messages"), {})
        if isinstance(round_messages, dict):
            messages = round_messages.get(str(best_round))
            code, extractor, error = _extract_code_from_messages(messages, file_name)
            if code:
                return (
                    CodeSelection(
                        code=code,
                        code_selection="round_messages",
                        best_round=best_round,
                        best_pass=best_pass,
                        best_total=best_total,
                        best_vuln=best_vuln,
                        extractor=extractor,
                    ),
                    None,
                )
            round_error = error or f"no round_messages for best_round={best_round}"
        else:
            round_error = "round_messages is not a dict"
    else:
        round_error = "no valid best-pass round"

    coding_messages = _safe_json_loads(row.get("coding_messages"), [])
    code, extractor, error = _extract_code_from_messages(coding_messages, file_name)
    if code:
        return (
            CodeSelection(
                code=code,
                code_selection="coding_messages_fallback",
                best_round=best_round or None,
                best_pass=best_pass,
                best_total=best_total,
                best_vuln=best_vuln,
                extractor=extractor,
            ),
            None,
        )
    return None, f"{round_error}; coding_messages fallback failed: {error}"


def _select_coding_messages_code(
    row: dict[str, Any],
    sol_path: str,
    agent_type: str | None = None,
) -> tuple[CodeSelection | None, str | None]:
    messages = _safe_json_loads(row.get("coding_messages"), [])
    code, extractor, error = _extract_code_from_messages(messages, Path(sol_path).name, agent_type=agent_type)
    if not code:
        return None, error or "no valid code in coding_messages"
    return CodeSelection(code=code, code_selection="coding_messages", extractor=extractor), None


def _select_code(
    target: Target,
    row: dict[str, Any],
    sol_path: str,
    selection_policy: str,
) -> tuple[CodeSelection | None, str | None]:
    if target.source in {"solagent", "solagent-summary"}:
        if int(row.get("status") or 0) != 1:
            return None, f"row status is {row.get('status')}, expected status=1"
        return _select_solagent_code(row, sol_path, selection_policy)
    if target.source == "rawmodel":
        if int(row.get("status") or 0) != 1:
            return None, f"row status is {row.get('status')}, expected status=1"
        return _select_coding_messages_code(row, sol_path)
    return _select_coding_messages_code(row, sol_path, agent_type=target.agent_type)


def select_code(
    target: Target,
    row: dict[str, Any],
    sol_path: str,
    selection_policy: str,
) -> tuple[CodeSelection | None, str | None]:
    """Public entrypoint for reconstructing the code evaluated by this runner."""
    return _select_code(target, row, sol_path, selection_policy)


def _source_targets(args: argparse.Namespace) -> list[Target]:
    models = _split_csv(args.model, DEFAULT_MODELS)
    agents = _split_csv(args.agent, DEFAULT_AGENTS)
    sources = [args.source] if args.source else ["rawmodel", "solagent", "solagent-summary", "agent"]

    targets: list[Target] = []
    for source in sources:
        if source == "rawmodel":
            targets.extend(Target(source, "Raw Model", "progress_tracker_rawmodel", model) for model in models)
        elif source == "solagent":
            targets.extend(Target(source, "SolAgent", "process_tracking", model) for model in models)
        elif source == "solagent-summary":
            targets.extend(Target(source, "SolAgent-Summary", "process_tracking_summary", model) for model in models)
        elif source == "agent":
            for agent in agents:
                targets.extend(
                    Target(source, f"Agent-{agent}", "progress_tracker_agent", model, agent) for model in models
                )
    return targets


def _empty_summary() -> dict[str, int]:
    return {
        "sols": 0,
        "passed_sols": 0,
        "failed_sols": 0,
        "expected_tests": 0,
        "passed_tests": 0,
        "failed_tests": 0,
        "compile_errors": 0,
        "extract_errors": 0,
        "missing_rows": 0,
    }


def _group_key(result: dict[str, Any]) -> str:
    agent = result.get("agent_type") or ""
    return f"{result['source']}|{result['model']}|{agent}"


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
                "agent_type": result.get("agent_type"),
                **_empty_summary(),
            }
        _accumulate_summary(groups[key], result)
    return {
        "global": global_summary,
        "groups": sorted(groups.values(), key=lambda item: (item["source"], item["model"], item.get("agent_type") or "")),
    }


def _failure_result(result: dict[str, Any], expected_tests: int, **updates: Any) -> dict[str, Any]:
    result.update(updates)
    result.setdefault("passed", 0)
    result.setdefault("forge_failed", 0)
    result.setdefault("forge_total", 0)
    result["failed_tests"] = expected_tests - int(result.get("passed") or 0)
    result["ok"] = False
    return result


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
        "agent_type": target.agent_type,
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
        "fuzz_seed": fuzz_seed,
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
    code_selection, extract_error = _select_code(target, row, sol_path, selection_policy)
    if code_selection is None:
        return _failure_result(result, expected_tests, extract_error=extract_error or "code extraction failed")

    result["code_selection"] = code_selection.code_selection
    result["code_extractor"] = code_selection.extractor
    result["best_round"] = code_selection.best_round
    result["best_pass"] = code_selection.best_pass
    result["best_total"] = code_selection.best_total
    result["best_vuln"] = code_selection.best_vuln
    result["selection_policy"] = selection_policy
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

    with tempfile.TemporaryDirectory(prefix="verify_eval_models_") as tmp:
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
    parser = argparse.ArgumentParser(description="Run hidden eval tests against RQ1 model outputs from progress.db")
    parser.add_argument("--db", default="output/progress.db", help="Path to progress.db")
    parser.add_argument(
        "--source",
        choices=["rawmodel", "solagent", "solagent-summary", "agent"],
        help="Optional source filter",
    )
    parser.add_argument("--model", help="Optional model filter; comma-separated values are accepted")
    parser.add_argument("--agent", help="Optional agent filter; comma-separated values are accepted")
    parser.add_argument("--sol", help="Optional dataset sol_path filter; comma-separated values are accepted")
    parser.add_argument("--limit", type=int, help="Optional max number of sol evaluations after filtering")
    parser.add_argument("--fail-fast", action="store_true", help="Stop after the first failed sol evaluation")
    parser.add_argument(
        "--selection-policy",
        choices=["best-pass-first", "test-first-security-second"],
        default=DEFAULT_SELECTION_POLICY,
        help=f"SolAgent round-selection policy (default: {DEFAULT_SELECTION_POLICY})",
    )
    parser.add_argument(
        "--report",
        help="Optional report path; relative paths are resolved from the agent-smart root",
    )
    parser.add_argument(
        "--fuzz-seed",
        default=DEFAULT_FUZZ_SEED,
        help="Fixed Forge fuzz seed used for every eval test",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
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

    targets = _source_targets(args)
    tasks = [(target, sol_path) for target in targets for sol_path in sol_paths]
    if args.limit is not None:
        tasks = tasks[: args.limit]
    if not tasks:
        print("[error] no eval tasks selected", file=sys.stderr)
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
            print(
                f"[verify] {index}/{len(tasks)} {target.source}{agent_suffix} {target.model} {sol_path}",
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
                    f"[pass] {target.source}{agent_suffix} {target.model} {sol_path} "
                    f"({result['passed']}/{result['expected_tests']})",
                    flush=True,
                )
            else:
                reason = (
                    result.get("extract_error")
                    or result.get("compile_error")
                    or result.get("error")
                    or f"{result.get('failed_tests')}/{result.get('expected_tests')} failed"
                )
                print(f"[fail] {target.source}{agent_suffix} {target.model} {sol_path}: {reason}", flush=True)
                if args.fail_fast:
                    break

    summary = _build_summary(results)
    report_path = Path(args.report) if args.report else REPORT_PATH
    if not report_path.is_absolute():
        report_path = ROOT / report_path
    report_path = report_path.resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(
            {
                "config": {
                    "selection_policy": args.selection_policy,
                    "fuzz_seed": args.fuzz_seed,
                },
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
