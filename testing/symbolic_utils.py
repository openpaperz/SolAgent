from __future__ import annotations

import json
import os
import re
import shutil
import signal
import subprocess
from pathlib import Path
from typing import Any


CHECK_PREFIX = "check_"
TEST_PREFIX = "test_"

GENERIC_STORAGE_LAYOUT_SOLS = {
    "repository/solady/lib/solady/src/utils/EnumerableMapLib.sol",
    "repository/solady/lib/solady/src/utils/EnumerableSetLib.sol",
}

DEFENDER_DEPLOY_SOL = "repository/openzeppelin-foundry-upgrades/lib/openzeppelin-foundry-upgrades/src/internal/DefenderDeploy.sol"
OPENZEPPELIN_UTILS_SOL = "repository/openzeppelin-foundry-upgrades/lib/openzeppelin-foundry-upgrades/src/internal/Utils.sol"


def openzeppelin_utils_stub_source() -> str:
    return """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

struct ContractInfo {
    string contractPath;
    string shortName;
    string license;
    string sourceCodeHash;
    string artifactPath;
}

library Utils {
    address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

    function getFullyQualifiedName(string memory contractName, string memory)
        internal
        pure
        returns (string memory)
    {
        return contractName;
    }

    function getContractInfo(string memory contractName, string memory)
        internal
        pure
        returns (ContractInfo memory info)
    {
        info.contractPath = "src/Token.sol";
        info.shortName = contractName;
        info.license = "MIT";
        info.sourceCodeHash = "0x1234";
        info.artifactPath = "out/Token.sol/Token.json";
    }

    function getBuildInfoFile(string memory, string memory, string memory)
        internal
        pure
        returns (string memory)
    {
        return "out/build-info/build.json";
    }

    function getOutDir() internal pure returns (string memory) {
        return "out";
    }

    function toBashCommand(string[] memory inputs, string memory bashPath)
        internal
        pure
        returns (string[] memory result)
    {
        result = new string[](3);
        result[0] = bashPath;
        result[1] = "-c";
        string memory commandString;
        for (uint256 i; i < inputs.length; ++i) {
            commandString = string(abi.encodePacked(commandString, inputs[i]));
            if (i + 1 != inputs.length) commandString = string(abi.encodePacked(commandString, " "));
        }
        result[2] = commandString;
    }

    function runAsBashCommand(string[] memory) internal pure returns (Vm.FfiResult memory result) {
        result.exitCode = 0;
        result.stdout = bytes("Approval process ID: symbolic-approval-process\\n");
    }
}
"""


def halmos_extra_args_for_sol(sol_path: str) -> list[str]:
    args: list[str] = []
    if sol_path in GENERIC_STORAGE_LAYOUT_SOLS:
        args.extend(["--storage-layout", "generic"])
    return args


def _halmos_version(halmos_bin: str) -> tuple[int, ...]:
    try:
        process = subprocess.run(
            [halmos_bin, "--version"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ()
    match = re.search(r"(\d+)\.(\d+)(?:\.(\d+))?", process.stdout + process.stderr)
    if not match:
        return ()
    return tuple(int(part) for part in match.groups(default="0"))


def resolve_halmos_bin() -> str:
    configured = os.environ.get("HALMOS_BIN")
    if configured:
        return configured

    candidates: list[str] = []
    user_bin = str(Path.home() / ".local" / "bin" / "halmos")
    if Path(user_bin).exists():
        candidates.append(user_bin)
    path_bin = shutil.which("halmos")
    if path_bin:
        candidates.append(path_bin)

    if not candidates:
        return "halmos"
    return max(candidates, key=_halmos_version)


def check_name(test_name: str) -> str:
    if test_name.startswith(TEST_PREFIX):
        return f"{CHECK_PREFIX}{test_name[len(TEST_PREFIX):]}"
    if test_name.startswith(CHECK_PREFIX):
        return test_name
    return f"{CHECK_PREFIX}{test_name}"


def to_symbolic_content(content: str) -> str:
    content = re.sub(r"\bfunction\s+test_", "function check_", content)
    content = _remove_enum_domain_filters(content)
    return _use_separate_symbolic_harnesses(content)


def _remove_enum_domain_filters(content: str) -> str:
    return re.sub(r"^\s*if \([A-Za-z_][A-Za-z0-9_]* > \d+\) return;\n", "", content, flags=re.MULTILINE)


def _use_separate_symbolic_harnesses(content: str) -> str:
    if "EvalHarness private harness = new EvalHarness();" not in content:
        return content
    if "vm.snapshot()" not in content and "vm.revertTo(" not in content:
        return content
    if "contract CREATE3EquivalenceCheck" in content:
        return content

    content = content.replace(
        "    EvalHarness private harness = new EvalHarness();",
        "    EvalHarness private refHarness = new EvalHarness();\n"
        "    EvalHarness private harness = new EvalHarness();\n"
        "    EvalHarness private genHarness = new EvalHarness();",
    )
    content = _rewrite_snapshot_function_bodies(content)
    content = re.sub(
        r"\n\s*uint256\s+(?:ref|gen)Snapshot\s*=\s*vm\.snapshot\(\);\n",
        "\n",
        content,
    )
    content = re.sub(
        r"\n\s*require\(vm\.revertTo\((?:ref|gen)Snapshot\)\);\n",
        "\n",
        content,
    )
    return content


def _rewrite_snapshot_function_bodies(content: str) -> str:
    pattern = re.compile(r"(    function check_[\s\S]*?^    \}\n)", re.MULTILINE)

    def rewrite(match: re.Match[str]) -> str:
        body = match.group(1)
        if "vm.snapshot()" not in body and "vm.revertTo(" not in body:
            return body
        body = re.sub(
            r"address\(harness\)\.call\(\s*\n\s*abi\.encodeWithSelector\(harness\.(ref_[A-Za-z0-9_]+)\.selector",
            r"address(refHarness).call(\n            abi.encodeWithSelector(refHarness.\1.selector",
            body,
        )
        body = re.sub(
            r"address\(harness\)\.call\(\s*\n\s*abi\.encodeWithSelector\(harness\.(gen_[A-Za-z0-9_]+)\.selector",
            r"address(genHarness).call(\n            abi.encodeWithSelector(genHarness.\1.selector",
            body,
        )
        return body

    return pattern.sub(rewrite, content)


def check_names_from_generated(generated: list[Any]) -> list[str]:
    names: list[str] = []
    for item in generated:
        test_name = getattr(item, "test_name", None)
        if isinstance(item, dict):
            test_name = item.get("test_name")
        if isinstance(test_name, str) and test_name:
            names.append(check_name(test_name))
    return names


def remove_check_functions(content: str, skip_check_names: set[str]) -> str:
    if not skip_check_names:
        return content
    result: list[str] = []
    index = 0
    pattern = re.compile(r"^\s*function (check_[A-Za-z0-9_]+)\b", re.MULTILINE)
    for match in pattern.finditer(content):
        name = match.group(1)
        if name not in skip_check_names:
            continue
        result.append(content[index : match.start()])
        position = match.end()
        brace_start = content.find("{", position)
        if brace_start == -1:
            index = match.end()
            continue
        depth = 0
        end = brace_start
        while end < len(content):
            char = content[end]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    end += 1
                    while end < len(content) and content[end] in " \t\r\n":
                        end += 1
                    break
            end += 1
        index = end
    result.append(content[index:])
    return "".join(result)


def split_check_chunks(check_names: list[str], chunk_size: int | None) -> list[list[str]]:
    if not chunk_size or chunk_size <= 0 or chunk_size >= len(check_names):
        return [check_names]
    return [check_names[index : index + chunk_size] for index in range(0, len(check_names), chunk_size)]


def _bounded(value: str, limit: int = 20000) -> str:
    if len(value) <= limit:
        return value
    return value[:limit] + f"\n...[truncated {len(value) - limit} chars]"


def _match_test_regex(check_names: list[str]) -> str:
    escaped = [f"{re.escape(name)}(?:\\(.*\\))?" for name in check_names]
    return f"^(?:{'|'.join(escaped)})$"


def run_halmos(
    *,
    project_root: Path,
    check_names: list[str],
    timeout: int,
    loop: int,
    solver_timeout_assertion: int,
    solver_timeout_branching: int,
    env: dict[str, str] | None = None,
    extra_args: list[str] | None = None,
) -> dict[str, Any]:
    json_path = project_root / ".halmos-symbolic-result.json"
    json_path.unlink(missing_ok=True)
    halmos_bin = resolve_halmos_bin()
    cmd = [
        halmos_bin,
        "--root",
        str(project_root),
        "--match-test",
        _match_test_regex(check_names),
        "--loop",
        str(loop),
        "--solver-timeout-assertion",
        str(solver_timeout_assertion),
        "--solver-timeout-branching",
        str(solver_timeout_branching),
        "--json-output",
        str(json_path),
        "--minimal-json-output",
    ]
    if extra_args:
        cmd.extend(extra_args)

    process = subprocess.Popen(
        cmd,
        cwd=str(project_root),
        env={**os.environ, **(env or {})},
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
        timed_out = False
        timeout_error = None
        returncode: int | None = process.returncode
    except subprocess.TimeoutExpired:
        timed_out = True
        timeout_error = f"halmos timeout after {timeout}s"
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            stdout, stderr = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            stdout, stderr = process.communicate()
        returncode = None

    halmos_json: Any = None
    json_error: str | None = None
    if json_path.exists():
        raw_json = json_path.read_text(encoding="utf-8", errors="ignore")
        try:
            halmos_json = json.loads(raw_json)
        except json.JSONDecodeError as exc:
            json_error = f"failed to parse halmos JSON: {exc}"
        finally:
            json_path.unlink(missing_ok=True)

    return {
        "command": cmd,
        "returncode": returncode,
        "timed_out": timed_out,
        "timeout_error": timeout_error,
        "stdout": stdout,
        "stderr": stderr,
        "json": halmos_json,
        "json_error": json_error,
    }


def _iter_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _iter_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from _iter_dicts(child)


def _status_from_text(text: str) -> dict[str, str]:
    statuses: dict[str, str] = {}
    for line in text.splitlines():
        if "check_" not in line:
            continue
        found = re.findall(r"\bcheck_[A-Za-z0-9_]+\b", line)
        if not found:
            continue
        lower = line.lower()
        if any(word in lower for word in ("pass", "proved", "success")):
            status = "PASS"
        elif any(word in lower for word in ("fail", "counterexample", "panic", "error")):
            status = "FAIL"
        elif "timeout" in lower:
            status = "TIMEOUT"
        else:
            continue
        for name in found:
            statuses[name] = status
    return statuses


def _status_from_json(halmos_json: Any) -> dict[str, str]:
    statuses: dict[str, str] = {}
    for item in _iter_dicts(halmos_json):
        name = (
            item.get("name")
            or item.get("function")
            or item.get("test")
            or item.get("test_name")
            or item.get("functionName")
        )
        if not isinstance(name, str) or "check_" not in name:
            continue
        match = re.search(r"\bcheck_[A-Za-z0-9_]+\b", name)
        if not match:
            continue
        status_value = item.get("status") or item.get("result") or item.get("exitcode")
        if isinstance(status_value, bool):
            status = "PASS" if status_value else "FAIL"
        else:
            status_text = str(status_value or "").lower()
            if any(word in status_text for word in ("pass", "prove", "success", "ok")):
                status = "PASS"
            elif "timeout" in status_text:
                status = "TIMEOUT"
            elif any(word in status_text for word in ("fail", "counterexample", "error", "panic")):
                status = "FAIL"
            else:
                continue
        statuses[match.group(0)] = status
    return statuses


def _strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def _extract_matching_lines(text: str, patterns: tuple[str, ...], limit: int = 20) -> list[str]:
    lines: list[str] = []
    lowered_patterns = tuple(pattern.lower() for pattern in patterns)
    for raw_line in text.splitlines():
        line = _strip_ansi(raw_line).strip()
        if not line:
            continue
        lower = line.lower()
        if any(pattern in lower for pattern in lowered_patterns):
            lines.append(_bounded(line, 1000))
            if len(lines) >= limit:
                break
    return lines


def _extract_counterexamples(stdout: str, stderr: str) -> list[str]:
    return _extract_matching_lines(
        "\n".join([stdout, stderr]),
        ("counterexample", "[fail]", "[error]", "assertion", "panic"),
    )


def _extract_unsupported_error(stdout: str, stderr: str) -> str | None:
    lines = _extract_matching_lines(
        "\n".join([stdout, stderr]),
        (
            "unsupported",
            "not supported",
            "unimplemented",
            "notconcreteerror",
            "symbolic memory offset",
            "loop unrolling bound",
            "no tests with --match-contract",
        ),
        limit=10,
    )
    if not lines:
        return None
    return "\n".join(lines)


def parse_halmos_result(raw: dict[str, Any], check_names: list[str]) -> dict[str, Any]:
    stdout = raw.get("stdout") or ""
    stderr = raw.get("stderr") or ""
    halmos_json = raw.get("json")
    statuses = _status_from_json(halmos_json)
    statuses.update(_status_from_text(stdout))
    statuses.update(_status_from_text(stderr))
    counterexamples = _extract_counterexamples(stdout, stderr)
    unsupported_error = _extract_unsupported_error(stdout, stderr)

    expected = len(check_names)
    if raw.get("timed_out"):
        passed = [name for name in check_names if statuses.get(name) == "PASS"]
        failed_or_unknown = [name for name in check_names if statuses.get(name) != "PASS"]
        check_statuses = {
            name: statuses.get(name, "TIMEOUT")
            for name in check_names
        }
        return {
            "proved": False,
            "proved_checks": len(passed),
            "failed_checks": max(expected - len(passed), 0),
            "timeouts": 1,
            "failed_check_names": failed_or_unknown,
            "check_statuses": check_statuses,
            "timeout_error": raw.get("timeout_error"),
            "counterexamples": counterexamples,
            "unsupported_error": unsupported_error,
        }

    missing = [name for name in check_names if name not in statuses]
    failed = [name for name in check_names if statuses.get(name) not in {"PASS"}]
    passed = [name for name in check_names if statuses.get(name) == "PASS"]
    timeout_names = [name for name in check_names if statuses.get(name) == "TIMEOUT"]

    stdout_lower = stdout.lower()
    stderr_lower = stderr.lower()
    compile_error = None
    if raw.get("returncode") not in (0, None) and not failed and missing:
        compile_error = _bounded(stderr or stdout)
    elif "compiler run failed" in stdout_lower or "compilation failed" in stdout_lower:
        compile_error = _bounded(stdout)
    elif "compiler run failed" in stderr_lower or "compilation failed" in stderr_lower:
        compile_error = _bounded(stderr)

    return {
        "proved": len(passed) == expected and not failed and not missing and raw.get("returncode") == 0,
        "proved_checks": len(passed),
        "failed_checks": max(expected - len(passed), 0),
        "timeouts": len(timeout_names),
        "failed_check_names": failed + missing,
        "missing_check_names": missing,
        "check_statuses": {name: statuses.get(name, "MISSING") for name in check_names},
        "compile_error": compile_error,
        "counterexamples": counterexamples,
        "unsupported_error": unsupported_error,
    }


def _dedupe(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def parse_halmos_runs(
    raw_runs: list[dict[str, Any]],
    check_chunks: list[list[str]],
    check_names: list[str],
) -> dict[str, Any]:
    if len(raw_runs) != len(check_chunks):
        raise ValueError("raw_runs and check_chunks length mismatch")
    if len(raw_runs) == 1:
        return parse_halmos_result(raw_runs[0], check_chunks[0])

    parsed_chunks = [
        parse_halmos_result(raw, chunk)
        for raw, chunk in zip(raw_runs, check_chunks, strict=True)
    ]
    statuses: dict[str, str] = {}
    counterexamples: list[str] = []
    unsupported_errors: list[str] = []
    timeout_errors: list[str] = []
    compile_error: str | None = None

    for parsed in parsed_chunks:
        statuses.update(parsed.get("check_statuses") or {})
        counterexamples.extend(parsed.get("counterexamples") or [])
        if parsed.get("unsupported_error"):
            unsupported_errors.append(str(parsed["unsupported_error"]))
        if parsed.get("timeout_error"):
            timeout_errors.append(str(parsed["timeout_error"]))
        if not compile_error and parsed.get("compile_error"):
            compile_error = str(parsed["compile_error"])

    expected = len(check_names)
    passed = [name for name in check_names if statuses.get(name) == "PASS"]
    missing = [name for name in check_names if name not in statuses or statuses.get(name) == "MISSING"]
    failed = [name for name in check_names if statuses.get(name) != "PASS"]

    return {
        "proved": len(passed) == expected and all(parsed.get("proved") for parsed in parsed_chunks),
        "proved_checks": len(passed),
        "failed_checks": max(expected - len(passed), 0),
        "timeouts": sum(int(parsed.get("timeouts") or 0) for parsed in parsed_chunks),
        "failed_check_names": failed,
        "missing_check_names": missing,
        "check_statuses": {name: statuses.get(name, "MISSING") for name in check_names},
        "compile_error": compile_error,
        "timeout_error": "\n".join(_dedupe(timeout_errors)) or None,
        "counterexamples": _dedupe(counterexamples),
        "unsupported_error": "\n".join(_dedupe(unsupported_errors)) or None,
    }


def classify_symbolic_failure(result: dict[str, Any]) -> str | None:
    if result.get("skipped"):
        return None
    if result.get("proved") or result.get("ok"):
        return None
    if result.get("missing_row"):
        return "missing_row"
    if result.get("extract_error"):
        return "extract_error"
    if result.get("compile_error"):
        return "compile_error"

    text = "\n".join(
        str(result.get(key) or "")
        for key in (
            "timeout_error",
            "unsupported_error",
            "counterexamples",
            "halmos_stdout",
            "halmos_stderr",
        )
    )
    lowered = text.lower()
    if "no tests with --match-contract" in lowered:
        return "no_matching_checks"
    if result.get("timeouts") or "halmos timeout" in lowered:
        return "timeout"
    if "unsupported cheat code" in lowered or "unsupported opcode" in lowered or "encountered unsupported" in lowered:
        return "unsupported_cheatcode_or_opcode"
    if "notconcreteerror" in lowered or "symbolic memory offset" in lowered:
        return "not_concrete_symbolic_memory"
    if "loop unrolling bound" in lowered or "loop-bound" in lowered:
        return "loop_bound_incomplete"
    if "[fail]" in lowered or "counterexample" in lowered:
        return "concrete_counterexample"
    if "halmosexception" in lowered or "[error]" in lowered or "internal-error" in lowered:
        return "halmos_internal_or_error"
    return "other"


def empty_symbolic_summary() -> dict[str, Any]:
    return {
        "sols": 0,
        "proved_sols": 0,
        "failed_sols": 0,
        "skipped_sols": 0,
        "expected_checks": 0,
        "proved_checks": 0,
        "failed_checks": 0,
        "skipped_checks": 0,
        "timeouts": 0,
        "compile_errors": 0,
        "extract_errors": 0,
        "missing_rows": 0,
        "failure_categories": {},
    }


def accumulate_symbolic_summary(summary: dict[str, Any], result: dict[str, Any]) -> None:
    summary["sols"] += 1
    if result.get("skipped"):
        summary["skipped_sols"] += 1
    elif result.get("proved") or result.get("ok"):
        summary["proved_sols"] += 1
    else:
        summary["failed_sols"] += 1
        category = result.get("failure_category") or classify_symbolic_failure(result)
        if category:
            categories = summary.setdefault("failure_categories", {})
            categories[category] = int(categories.get(category) or 0) + 1
    summary["expected_checks"] += int(result.get("expected_checks") or result.get("expected_tests") or 0)
    summary["proved_checks"] += int(result.get("proved_checks") or 0)
    summary["failed_checks"] += int(result.get("failed_checks") or 0)
    summary["skipped_checks"] += int(result.get("skipped_checks") or 0)
    summary["timeouts"] += int(result.get("timeouts") or 0)
    if result.get("compile_error"):
        summary["compile_errors"] += 1
    if result.get("extract_error"):
        summary["extract_errors"] += 1
    if result.get("missing_row"):
        summary["missing_rows"] += 1


def build_symbolic_summary(results: list[dict[str, Any]]) -> dict[str, Any]:
    global_summary = empty_symbolic_summary()
    groups: dict[str, dict[str, Any]] = {}
    for result in results:
        accumulate_symbolic_summary(global_summary, result)
        key = f"{result.get('source')}|{result.get('model')}|{result.get('agent_type') or ''}"
        if key not in groups:
            groups[key] = {
                "source": result.get("source"),
                "source_name": result.get("source_name"),
                "model": result.get("model"),
                "agent_type": result.get("agent_type"),
                **empty_symbolic_summary(),
            }
        accumulate_symbolic_summary(groups[key], result)
    return {
        "global": global_summary,
        "groups": sorted(groups.values(), key=lambda item: (str(item.get("source")), str(item.get("model")), str(item.get("agent_type") or ""))),
    }
