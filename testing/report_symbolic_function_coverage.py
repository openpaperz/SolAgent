#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = ROOT / "data" / "dataset.json"
DEFAULT_SYMBOLIC_MANIFEST = ROOT / "testing" / "symbolic" / "symbolic_manifest.json"
DEFAULT_SYMBOLIC_DIR = ROOT / "testing" / "symbolic"
DEFAULT_OUTPUT = ROOT / "testing" / "symbolic" / "symbolic_function_coverage_report.json"


FunctionKey = tuple[str, str, str, str]


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _normalize_signature(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _function_key(item: dict[str, Any]) -> FunctionKey:
    return (
        str(item.get("sol_path") or ""),
        str(item.get("class_name") or item.get("class") or ""),
        str(item.get("method_name") or item.get("identifier") or ""),
        _normalize_signature(item.get("full_signature")),
    )


def _dataset_item(
    sol_path: str,
    class_name: str,
    class_kind: str,
    method: dict[str, Any],
) -> dict[str, Any]:
    return {
        "sol_path": sol_path,
        "class_name": class_name,
        "class_kind": class_kind,
        "method_name": str(method.get("identifier") or ""),
        "visibility": str(method.get("visibility") or ""),
        "modifiers": str(method.get("modifiers") or ""),
        "full_signature": _normalize_signature(method.get("full_signature")),
        "start": method.get("start"),
        "end": method.get("end"),
        "kind": str(method.get("kind") or ""),
    }


def _iter_dataset_functions(
    dataset: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], dict[str, int]]:
    first_value = next(iter(dataset.values()), [])
    if not (
        isinstance(first_value, list)
        and first_value
        and isinstance(first_value[0], dict)
        and "methods" in first_value[0]
    ):
        raise ValueError("unsupported dataset layout: expected current nested data/dataset.json format")

    functions: list[dict[str, Any]] = []
    constructors: list[dict[str, Any]] = []
    records = 0
    for sol_path, classes in sorted(dataset.items()):
        for cls in classes:
            class_name = str(cls.get("identifier") or "")
            class_kind = str(cls.get("kind") or "")
            records += len(cls.get("methods", []))
            for method in cls.get("methods", []):
                if method.get("kind") == "constructor":
                    constructors.append(_dataset_item(sol_path, class_name, class_kind, method))
                    continue
                if method.get("kind") != "function":
                    continue
                functions.append(_dataset_item(sol_path, class_name, class_kind, method))
    meta = {
        "records": records,
        "function_records": len(functions),
        "non_function_records": records - len(functions),
    }
    return functions, constructors, meta


def _is_original_function(item: dict[str, Any], original_keys: set[FunctionKey]) -> bool:
    return _function_key(item) in original_keys


def _sol_to_symbolic_test(manifest: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for case in manifest.get("cases", []):
        sol_path = case.get("sol_path")
        test_path = case.get("symbolic_test_path")
        if sol_path and test_path:
            mapping[str(sol_path)] = str(test_path)
    return mapping


def _source_path_for_sol(sol_path: str) -> Path:
    return ROOT / sol_path


def _function_body(function: dict[str, Any], source_cache: dict[str, list[str]]) -> str:
    sol_path = str(function.get("sol_path") or "")
    source_path = _source_path_for_sol(sol_path)
    try:
        start = int(function.get("start") or 0)
        end = int(function.get("end") or 0)
    except (TypeError, ValueError):
        return ""
    if start <= 0 or end < start or not source_path.exists():
        return ""
    if sol_path not in source_cache:
        source_cache[sol_path] = source_path.read_text(encoding="utf-8").splitlines()
    lines = source_cache[sol_path]
    return "\n".join(lines[start - 1 : min(end, len(lines))])


def _strip_assembly_blocks(body: str) -> str:
    """Remove Solidity assembly blocks before regex-based Solidity call scanning."""
    pattern = re.compile(r"\bassembly(?:\s*\([^)]*\))?\s*\{")
    result: list[str] = []
    index = 0
    while True:
        match = pattern.search(body, index)
        if not match:
            result.append(body[index:])
            break
        result.append(body[index : match.start()])
        depth = 1
        position = match.end()
        while position < len(body) and depth:
            char = body[position]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
            position += 1
        index = position
    return "".join(result)


def _resolve_import_path(sol_path: str, import_path: str) -> str | None:
    if not import_path.endswith(".sol"):
        return None
    current_path = _source_path_for_sol(sol_path)
    if import_path.startswith("."):
        target = (current_path.parent / import_path).resolve()
    else:
        target = (ROOT / import_path).resolve()
    try:
        return target.relative_to(ROOT).as_posix()
    except ValueError:
        return None


def _imported_symbols_by_sol(sol_path: str, source_cache: dict[str, list[str]]) -> dict[str, str]:
    source_path = _source_path_for_sol(sol_path)
    if not source_path.exists():
        return {}
    if sol_path not in source_cache:
        source_cache[sol_path] = source_path.read_text(encoding="utf-8").splitlines()
    content = "\n".join(source_cache[sol_path])
    symbols: dict[str, str] = {}
    for match in re.finditer(r'import\s*\{([^}]+)\}\s*from\s*"([^"]+)"\s*;', content):
        imported_sol = _resolve_import_path(sol_path, match.group(2))
        if not imported_sol:
            continue
        for raw_symbol in match.group(1).split(","):
            raw_symbol = raw_symbol.strip()
            if not raw_symbol:
                continue
            alias_match = re.fullmatch(
                r"([A-Za-z_][A-Za-z0-9_]*)\s+as\s+([A-Za-z_][A-Za-z0-9_]*)",
                raw_symbol,
            )
            if alias_match:
                symbols[alias_match.group(2)] = imported_sol
            else:
                symbols[raw_symbol] = imported_sol
    for match in re.finditer(r'import\s+"([^"]+)"\s*;', content):
        imported_sol = _resolve_import_path(sol_path, match.group(1))
        if not imported_sol:
            continue
        for function in source_cache.get(imported_sol, []):
            _ = function
    return symbols


def _internal_call_graph(functions: list[dict[str, Any]]) -> dict[FunctionKey, set[FunctionKey]]:
    """Build a conservative direct call graph from dataset source ranges.

    The graph records same-scope `name(...)` calls and imported-library `Library.name(...)`
    calls. Dynamic dispatch and contract-instance calls are intentionally ignored.
    """

    by_scope: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for function in functions:
        by_scope[(function["sol_path"], function["class_name"])].append(function)

    interface_methods_by_sol: dict[str, dict[str, list[FunctionKey]]] = defaultdict(lambda: defaultdict(list))
    for function in functions:
        if function.get("class_kind") == "interface":
            interface_methods_by_sol[function["sol_path"]][function["method_name"]].append(_function_key(function))

    keys_by_sol_class_method: dict[tuple[str, str, str], list[FunctionKey]] = defaultdict(list)
    for function in functions:
        keys_by_sol_class_method[
            (function["sol_path"], function["class_name"], function["method_name"])
        ].append(_function_key(function))

    source_cache: dict[str, list[str]] = {}
    imports_cache: dict[str, dict[str, str]] = {}
    graph: dict[FunctionKey, set[FunctionKey]] = defaultdict(set)
    for scoped_functions in by_scope.values():
        names = sorted({item["method_name"] for item in scoped_functions if item["method_name"]}, key=len, reverse=True)
        if not names:
            continue
        name_pattern = re.compile(r"\b(" + "|".join(re.escape(name) for name in names) + r")\s*\(")
        keys_by_name: dict[str, list[FunctionKey]] = defaultdict(list)
        for target in scoped_functions:
            keys_by_name[target["method_name"]].append(_function_key(target))

        for source in scoped_functions:
            source_key = _function_key(source)
            body = _function_body(source, source_cache)
            if not body:
                continue
            # Remove the declaration prefix so the function name itself is not counted as a self-call.
            brace_index = body.find("{")
            if brace_index != -1:
                body = body[brace_index + 1 :]
            body = _strip_assembly_blocks(body)
            for match in name_pattern.finditer(body):
                for target_key in keys_by_name[match.group(1)]:
                    if target_key != source_key:
                        graph[source_key].add(target_key)

            for interface_name, interface_keys in interface_methods_by_sol.get(source["sol_path"], {}).items():
                if re.search(r"\.\s*" + re.escape(interface_name) + r"\s*\(", body):
                    for target_key in interface_keys:
                        graph[source_key].add(target_key)

            imported_symbols = imports_cache.setdefault(
                source["sol_path"],
                _imported_symbols_by_sol(source["sol_path"], source_cache),
            )
            for match in re.finditer(
                r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(",
                body,
            ):
                imported_sol = imported_symbols.get(match.group(1))
                if not imported_sol:
                    continue
                args = _call_arguments(body, match.end() - 1)
                arg_count = len(args) if args is not None else None
                candidates = keys_by_sol_class_method.get(
                    (imported_sol, match.group(1), match.group(2)),
                    [],
                )
                if arg_count is not None:
                    candidates = [
                        key for key in candidates if _parameter_count_from_signature(key[3]) == arg_count
                    ]
                if len(candidates) == 1 and candidates[0] != source_key:
                    graph[source_key].add(candidates[0])
    return graph


def _reachable_internal_calls(
    graph: dict[FunctionKey, set[FunctionKey]],
    roots: set[FunctionKey],
) -> tuple[set[FunctionKey], dict[FunctionKey, set[FunctionKey]]]:
    reached: set[FunctionKey] = set()
    reached_from: dict[FunctionKey, set[FunctionKey]] = defaultdict(set)
    for root in sorted(roots):
        stack = list(graph.get(root, set()))
        seen = {root}
        while stack:
            key = stack.pop()
            if key in seen:
                continue
            seen.add(key)
            reached.add(key)
            reached_from[key].add(root)
            stack.extend(graph.get(key, set()) - seen)
    return reached, reached_from


def _wrapper_usage_by_test(symbolic_dir: Path, manifest: dict[str, Any]) -> dict[str, set[str]]:
    used: dict[str, set[str]] = defaultdict(set)
    active_check_names_by_test: dict[str, set[str]] = defaultdict(set)
    sol_to_test = _sol_to_symbolic_test(manifest)
    for method in manifest.get("methods", []):
        sol_path = str(method.get("sol_path") or "")
        check_name = str(method.get("check_name") or "")
        test_path = sol_to_test.get(sol_path)
        if test_path and check_name:
            active_check_names_by_test[test_path].add(check_name)

    for case in manifest.get("cases", []):
        test_path = case.get("symbolic_test_path")
        if not test_path:
            continue
        source_path = symbolic_dir / str(test_path)
        if not source_path.exists():
            continue
        content = source_path.read_text(encoding="utf-8")
        active_content = _reachable_test_content(content, active_check_names_by_test.get(str(test_path), set()))
        for match in re.finditer(r"\b((?:ref|gen)_call_[A-Za-z0-9_]+_\d+(?:_state)?)\.selector", active_content):
            wrapper = match.group(1)
            wrapper = re.sub(r"^(?:ref|gen)_", "", wrapper)
            wrapper = wrapper.removesuffix("_state")
            used[str(test_path)].add(wrapper)
        for match in re.finditer(r"\b(?:Ref|Gen)[A-Za-z0-9_]*\.exposed_([A-Za-z0-9_]+_\d+)\.selector", active_content):
            used[str(test_path)].add(f"call_{match.group(1)}")
    return used


def _wrapper_usage_by_check(symbolic_dir: Path, manifest: dict[str, Any]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    sol_to_test = _sol_to_symbolic_test(manifest)
    body_cache: dict[str, dict[str, str]] = {}
    seen: set[tuple[str, str]] = set()
    for method in manifest.get("methods", []):
        sol_path = str(method.get("sol_path") or "")
        check_name = str(method.get("check_name") or "")
        test_path = sol_to_test.get(sol_path)
        if not sol_path or not check_name or not test_path or (test_path, check_name) in seen:
            continue
        seen.add((test_path, check_name))
        source_path = symbolic_dir / str(test_path)
        if not source_path.exists():
            continue
        target_wrapper_name = str(method.get("target_wrapper_name") or "")
        if target_wrapper_name:
            records.append(
                {
                    "symbolic_test_path": str(test_path),
                    "sol_path": sol_path,
                    "check_name": check_name,
                    "wrappers": [target_wrapper_name],
                    "target_wrapper_name": target_wrapper_name,
                    "wrapper_source": "manifest_target",
                }
            )
            continue
        content = source_path.read_text(encoding="utf-8")
        bodies = body_cache.setdefault(str(test_path), _function_bodies_by_name(content))
        active_content = _reachable_function_content(bodies, {check_name})
        wrappers: set[str] = set()
        for match in re.finditer(r"\b((?:ref|gen)_call_[A-Za-z0-9_]+_\d+(?:_state)?)\.selector", active_content):
            wrapper = match.group(1)
            wrapper = re.sub(r"^(?:ref|gen)_", "", wrapper)
            wrapper = wrapper.removesuffix("_state")
            wrappers.add(wrapper)
        for match in re.finditer(r"\b(?:Ref|Gen)[A-Za-z0-9_]*\.exposed_([A-Za-z0-9_]+_\d+)\.selector", active_content):
            wrappers.add(f"call_{match.group(1)}")
        records.append(
            {
                "symbolic_test_path": str(test_path),
                "sol_path": sol_path,
                "check_name": check_name,
                "wrappers": sorted(wrappers),
                "target_wrapper_name": None,
                "wrapper_source": "selector_scan",
            }
        )
    return records


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
                    bodies[name] = content[brace_start + 1 : index]
                    break
    return bodies


def _reachable_test_content(content: str, roots: set[str]) -> str:
    if not roots:
        return ""
    bodies = _function_bodies_by_name(content)
    return _reachable_function_content(bodies, roots)


def _reachable_function_content(bodies: dict[str, str], roots: set[str]) -> str:
    if not roots:
        return ""
    reachable: list[str] = []
    stack = list(roots)
    seen: set[str] = set()
    while stack:
        name = stack.pop()
        if name in seen:
            continue
        seen.add(name)
        body = bodies.get(name, "")
        if not body:
            continue
        reachable.append(body)
        for candidate in bodies:
            if candidate in seen:
                continue
            if re.search(r"\b" + re.escape(candidate) + r"\s*(?:\(|\.selector\b)", body):
                stack.append(candidate)
    return "\n".join(reachable)


def _extract_function_body(content: str, function_name: str) -> str:
    match = re.search(r"\bfunction\s+" + re.escape(function_name) + r"\s*\(", content)
    if not match:
        return ""
    brace_start = content.find("{", match.end())
    if brace_start == -1:
        return ""
    depth = 0
    for index in range(brace_start, len(content)):
        char = content[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return content[brace_start + 1 : index]
    return ""


def _parameter_count_from_signature(signature: str) -> int | None:
    open_paren = signature.find("(")
    if open_paren == -1:
        return None
    args = _call_arguments(signature, open_paren)
    if args is None:
        return None
    params = ",".join(args).strip()
    if not params:
        return 0
    return len(args)


def _call_argument_count(content: str, open_paren_index: int) -> int | None:
    args = _call_arguments(content, open_paren_index)
    if args is None:
        return None
    return len(args)


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


def _resolve_method_candidates(
    keys_by_sol_method: dict[tuple[str, str], list[FunctionKey]],
    sol_path: str,
    method_name: str,
    arg_count: int | None,
    args: list[str] | None = None,
) -> tuple[FunctionKey | None, bool]:
    candidates = keys_by_sol_method.get((sol_path, method_name), [])
    if arg_count is not None:
        candidates = [
            key for key in candidates if _parameter_count_from_signature(key[3]) == arg_count
        ]
    if len(candidates) > 1 and args:
        storage_type_hints = {
            "AddressSet": r"\bAddressSet\s+storage\b",
            "Bytes32Set": r"\bBytes32Set\s+storage\b",
            "Uint256Set": r"\bUint256Set\s+storage\b",
            "Int256Set": r"\bInt256Set\s+storage\b",
            "Uint8Set": r"\bUint8Set\s+storage\b",
            "AddressToAddressMap": r"\bAddressToAddressMap\s+storage\b",
            "AddressToBytes32Map": r"\bAddressToBytes32Map\s+storage\b",
            "AddressToUint256Map": r"\bAddressToUint256Map\s+storage\b",
            "Bytes32ToAddressMap": r"\bBytes32ToAddressMap\s+storage\b",
            "Bytes32ToBytes32Map": r"\bBytes32ToBytes32Map\s+storage\b",
            "Bytes32ToUint256Map": r"\bBytes32ToUint256Map\s+storage\b",
            "Uint256ToAddressMap": r"\bUint256ToAddressMap\s+storage\b",
            "Uint256ToBytes32Map": r"\bUint256ToBytes32Map\s+storage\b",
            "Uint256ToUint256Map": r"\bUint256ToUint256Map\s+storage\b",
        }
        for arg in args:
            matched = [
                key
                for type_name, signature_pattern in storage_type_hints.items()
                if type_name in arg
                for key in candidates
                if re.search(signature_pattern, key[3])
            ]
            if len(matched) == 1:
                candidates = matched
                break
    if len(candidates) > 1 and args:
        if any(arg.lstrip().startswith(("\"", "'")) for arg in args):
            string_candidates = [key for key in candidates if "string memory" in key[3] or "string calldata" in key[3]]
            if len(string_candidates) == 1:
                candidates = string_candidates
        elif any(re.search(r"\bbytes32\s*\(", arg) for arg in args) or any(
            re.fullmatch(r"(?:rawSlot|bytes32[A-Za-z0-9_]*)", arg.strip()) for arg in args
        ):
            bytes32_candidates = [key for key in candidates if re.search(r"\bbytes32\s+\w+", key[3])]
            if len(bytes32_candidates) == 1:
                candidates = bytes32_candidates
        elif any(re.search(r"\buint(?:8|16|32|64|128|160|256)?\s*\(", arg) for arg in args) or any(
            re.fullmatch(r"\d+", arg.strip()) for arg in args
        ) or any(
            re.fullmatch(r"(?:uintSlot|uint(?:8|16|32|64|128|160|256)?[A-Za-z0-9_]*)", arg.strip()) for arg in args
        ):
            uint_candidates = [key for key in candidates if re.search(r"\buint(?:8|16|32|64|128|160|256)?\s+\w+", key[3])]
            if len(uint_candidates) == 1:
                candidates = uint_candidates
    if len(candidates) == 1:
        return candidates[0], False
    return None, bool(candidates)


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


def _resolve_exposed_method_name(method_name: str) -> str:
    match = re.fullmatch(r"exposed_([A-Za-z0-9_]+)_\d+", method_name)
    if match:
        return match.group(1)
    return method_name


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
        elif hint == "bytes32":
            matched = [key for key in narrowed if re.search(r"\bbytes32\s+\w+", key[3])]
        else:
            matched = [key for key in narrowed if re.search(r"\b" + re.escape(hint) + r"\s+\w+", key[3])]
        if matched:
            narrowed = matched
    return narrowed


def _class_name_from_static_ref_gen_prefix(prefix: str) -> str | None:
    match = re.fullmatch(r"(?:Ref|Gen)([A-Za-z0-9_]*?)(?:_\d+|Extra_\d+)?", prefix)
    if not match:
        return None
    class_name = match.group(1)
    return class_name or None


def _resolve_static_ref_gen_call(
    keys_by_sol_method: dict[tuple[str, str], list[FunctionKey]],
    keys_by_sol_class_method: dict[tuple[str, str, str], list[FunctionKey]],
    sol_path: str,
    static_prefix: str,
    method_name: str,
    arg_count: int | None,
    args: list[str] | None,
) -> tuple[FunctionKey | None, bool]:
    class_name = _class_name_from_static_ref_gen_prefix(static_prefix)
    if class_name:
        candidates = keys_by_sol_class_method.get((sol_path, class_name, method_name), [])
        if candidates:
            return _resolve_method_candidates(
                {(sol_path, method_name): candidates},
                sol_path,
                method_name,
                arg_count,
                args,
            )
    return _resolve_method_candidates(keys_by_sol_method, sol_path, method_name, arg_count, args)


def _direct_ref_gen_calls_by_test(
    symbolic_dir: Path,
    manifest: dict[str, Any],
    functions: list[dict[str, Any]],
    extra_wrappers_by_test: dict[str, set[str]] | None = None,
) -> tuple[dict[str, set[FunctionKey]], list[dict[str, str]]]:
    keys_by_sol_method: dict[tuple[str, str], list[FunctionKey]] = defaultdict(list)
    keys_by_sol_class_method: dict[tuple[str, str, str], list[FunctionKey]] = defaultdict(list)
    for function in functions:
        key = _function_key(function)
        keys_by_sol_method[(function["sol_path"], function["method_name"])].append(key)
        keys_by_sol_class_method[(function["sol_path"], function["class_name"], function["method_name"])].append(key)

    used: dict[str, set[FunctionKey]] = defaultdict(set)
    unresolved: list[dict[str, str]] = []
    for case in manifest.get("cases", []):
        sol_path = str(case.get("sol_path") or "")
        test_path = case.get("symbolic_test_path")
        if not sol_path or not test_path:
            continue
        source_path = symbolic_dir / str(test_path)
        if not source_path.exists():
            continue
        content = source_path.read_text(encoding="utf-8")
        check_names = sorted(
            {
                str(method.get("check_name") or "")
                for method in manifest.get("methods", [])
                if method.get("sol_path") == sol_path and method.get("check_name")
            }
        )
        active_content = _reachable_test_content(content, set(check_names))
        static_call_pattern = re.compile(
            r"\b((?:Ref|Gen)[A-Za-z0-9_]*(?:_\d+|Extra_\d+)?)\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\("
        )
        for match in static_call_pattern.finditer(active_content):
            static_prefix = match.group(1)
            prefix = "Ref" if static_prefix.startswith("Ref") else "Gen"
            method_name = match.group(2)
            args = _call_arguments(active_content, match.end() - 1)
            arg_count = _call_argument_count(active_content, match.end() - 1)
            type_hints = _argument_type_hints(active_content, args, match.start())
            counterpart = "Gen" if prefix == "Ref" else "Ref"
            counterpart_prefix = counterpart + static_prefix[3:]
            counterpart_pattern = (
                r"\b"
                + re.escape(counterpart_prefix)
                + r"\s*\.\s*"
                + re.escape(method_name)
                + r"\s*\("
            )
            if not re.search(counterpart_pattern, active_content):
                continue
            key, ambiguous = _resolve_static_ref_gen_call(
                keys_by_sol_method,
                keys_by_sol_class_method,
                sol_path,
                static_prefix,
                method_name,
                arg_count,
                args,
            )
            if key is None and ambiguous:
                candidates = keys_by_sol_method.get((sol_path, method_name), [])
                if arg_count is not None:
                    candidates = [
                        candidate for candidate in candidates if _parameter_count_from_signature(candidate[3]) == arg_count
                    ]
                candidates = _filter_candidates_by_type_hints(candidates, type_hints)
                if len(candidates) == 1:
                    key = candidates[0]
                    ambiguous = False
            if key is not None:
                used[str(test_path)].add(key)
            elif ambiguous:
                unresolved.append(
                    {
                        "symbolic_test_path": str(test_path),
                        "method_name": method_name,
                        "reason": "ambiguous overloaded direct Ref/Gen call",
                    }
                )

        instance_vars: dict[str, dict[str, str]] = {"Ref": {}, "Gen": {}}
        for match in re.finditer(
            r"\b(Ref|Gen)([A-Za-z0-9_]*)_\d+\s+([A-Za-z_][A-Za-z0-9_]*)\b",
            active_content,
        ):
            side = match.group(1)
            class_name = match.group(2)
            var_name = match.group(3)
            instance_vars[side][var_name] = class_name
        if instance_vars["Ref"] and instance_vars["Gen"]:
            called_by_side: dict[str, set[tuple[str, str]]] = {"Ref": set(), "Gen": set()}
            for side, names in instance_vars.items():
                for name, class_name in names.items():
                    for match in re.finditer(
                        r"\b"
                        + re.escape(name)
                        + r"\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:\{[^{}]*\}\s*)?\(",
                        active_content,
                    ):
                        called_by_side[side].add((class_name, _resolve_exposed_method_name(match.group(1))))
            for class_name, method_name in sorted(called_by_side["Ref"] & called_by_side["Gen"]):
                candidates = keys_by_sol_class_method.get((sol_path, class_name, method_name), [])
                if len(candidates) == 1:
                    used[str(test_path)].add(candidates[0])
                elif candidates:
                    unresolved.append(
                        {
                            "symbolic_test_path": str(test_path),
                            "class_name": class_name,
                            "method_name": method_name,
                            "reason": "ambiguous overloaded direct Ref/Gen instance call",
                        }
                    )

        extra_parts: list[str] = []
        for wrapper in sorted((extra_wrappers_by_test or {}).get(str(test_path), set())):
            extra_parts.append(_extract_function_body(content, f"ref_{wrapper}"))
            extra_parts.append(_extract_function_body(content, f"gen_{wrapper}"))
        extra_content = "\n".join(extra_parts)
        for match in re.finditer(
            r"\b(ref|gen)Instance_[A-Za-z0-9_]+_\d+\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(",
            extra_content,
        ):
            prefix = match.group(1)
            method_name = _resolve_exposed_method_name(match.group(2))
            counterpart = "gen" if prefix == "ref" else "ref"
            counterpart_pattern = (
                r"\b"
                + counterpart
                + r"Instance_[A-Za-z0-9_]+_\d+\s*\.\s*"
                + re.escape(method_name)
                + r"\s*\("
            )
            if not re.search(counterpart_pattern, extra_content):
                continue
            candidates = keys_by_sol_method.get((sol_path, method_name), [])
            if len(candidates) == 1:
                used[str(test_path)].add(candidates[0])
            elif candidates:
                unresolved.append(
                    {
                        "symbolic_test_path": str(test_path),
                        "method_name": method_name,
                        "reason": "ambiguous overloaded direct ref/gen instance call",
                    }
                )
        for match in static_call_pattern.finditer(extra_content):
            static_prefix = match.group(1)
            prefix = "Ref" if static_prefix.startswith("Ref") else "Gen"
            method_name = match.group(2)
            args = _call_arguments(extra_content, match.end() - 1)
            arg_count = _call_argument_count(extra_content, match.end() - 1)
            type_hints = _argument_type_hints(extra_content, args, match.start())
            counterpart = "Gen" if prefix == "Ref" else "Ref"
            counterpart_prefix = counterpart + static_prefix[3:]
            counterpart_pattern = (
                r"\b"
                + re.escape(counterpart_prefix)
                + r"\s*\.\s*"
                + re.escape(method_name)
                + r"\s*\("
            )
            if not re.search(counterpart_pattern, extra_content):
                continue
            key, ambiguous = _resolve_static_ref_gen_call(
                keys_by_sol_method,
                keys_by_sol_class_method,
                sol_path,
                static_prefix,
                method_name,
                arg_count,
                args,
            )
            if key is None and ambiguous:
                candidates = keys_by_sol_method.get((sol_path, method_name), [])
                if arg_count is not None:
                    candidates = [
                        candidate for candidate in candidates if _parameter_count_from_signature(candidate[3]) == arg_count
                    ]
                candidates = _filter_candidates_by_type_hints(candidates, type_hints)
                if len(candidates) == 1:
                    key = candidates[0]
                    ambiguous = False
            if key is not None:
                used[str(test_path)].add(key)
            elif ambiguous:
                unresolved.append(
                    {
                        "symbolic_test_path": str(test_path),
                        "method_name": method_name,
                        "reason": "ambiguous overloaded direct Ref/Gen call in wrapper",
                    }
                )
    return used, unresolved


def _direct_ref_gen_calls_by_check(
    symbolic_dir: Path,
    manifest: dict[str, Any],
    functions: list[dict[str, Any]],
) -> dict[tuple[str, str], set[FunctionKey]]:
    keys_by_sol_method: dict[tuple[str, str], list[FunctionKey]] = defaultdict(list)
    keys_by_sol_class_method: dict[tuple[str, str, str], list[FunctionKey]] = defaultdict(list)
    for function in functions:
        key = _function_key(function)
        keys_by_sol_method[(function["sol_path"], function["method_name"])].append(key)
        keys_by_sol_class_method[(function["sol_path"], function["class_name"], function["method_name"])].append(key)

    sol_to_test = _sol_to_symbolic_test(manifest)
    body_cache: dict[str, dict[str, str]] = {}
    source_cache: dict[str, str] = {}
    used: dict[tuple[str, str], set[FunctionKey]] = defaultdict(set)
    static_call_pattern = re.compile(
        r"\b((?:Ref|Gen)[A-Za-z0-9_]*(?:_\d+|Extra_\d+)?)\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\("
    )
    for method in manifest.get("methods", []):
        sol_path = str(method.get("sol_path") or "")
        check_name = str(method.get("check_name") or "")
        test_path = sol_to_test.get(sol_path)
        if not sol_path or not check_name or not test_path:
            continue
        source_path = symbolic_dir / str(test_path)
        if not source_path.exists():
            continue
        content = source_cache.setdefault(str(test_path), source_path.read_text(encoding="utf-8"))
        bodies = body_cache.setdefault(str(test_path), _function_bodies_by_name(content))
        active_content = _reachable_function_content(bodies, {check_name})
        if not active_content:
            continue

        for match in static_call_pattern.finditer(active_content):
            static_prefix = match.group(1)
            prefix = "Ref" if static_prefix.startswith("Ref") else "Gen"
            method_name = match.group(2)
            args = _call_arguments(active_content, match.end() - 1)
            arg_count = _call_argument_count(active_content, match.end() - 1)
            type_hints = _argument_type_hints(active_content, args, match.start())
            counterpart = "Gen" if prefix == "Ref" else "Ref"
            counterpart_prefix = counterpart + static_prefix[3:]
            counterpart_pattern = (
                r"\b"
                + re.escape(counterpart_prefix)
                + r"\s*\.\s*"
                + re.escape(method_name)
                + r"\s*\("
            )
            if not re.search(counterpart_pattern, active_content):
                continue
            key, ambiguous = _resolve_static_ref_gen_call(
                keys_by_sol_method,
                keys_by_sol_class_method,
                sol_path,
                static_prefix,
                method_name,
                arg_count,
                args,
            )
            if key is None and ambiguous:
                candidates = keys_by_sol_method.get((sol_path, method_name), [])
                if arg_count is not None:
                    candidates = [
                        candidate for candidate in candidates if _parameter_count_from_signature(candidate[3]) == arg_count
                    ]
                candidates = _filter_candidates_by_type_hints(candidates, type_hints)
                if len(candidates) == 1:
                    key = candidates[0]
            if key is not None:
                used[(str(test_path), check_name)].add(key)

        instance_vars: dict[str, dict[str, str]] = {"Ref": {}, "Gen": {}}
        for match in re.finditer(
            r"\b(Ref|Gen)([A-Za-z0-9_]*)_\d+\s+([A-Za-z_][A-Za-z0-9_]*)\b",
            active_content,
        ):
            instance_vars[match.group(1)][match.group(3)] = match.group(2)
        if not instance_vars["Ref"] or not instance_vars["Gen"]:
            continue
        called_by_side: dict[str, set[tuple[str, str]]] = {"Ref": set(), "Gen": set()}
        for side, names in instance_vars.items():
            for name, class_name in names.items():
                for match in re.finditer(
                    r"\b"
                    + re.escape(name)
                    + r"\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:\{[^{}]*\}\s*)?\(",
                    active_content,
                ):
                    called_by_side[side].add((class_name, _resolve_exposed_method_name(match.group(1))))
        for class_name, method_name in sorted(called_by_side["Ref"] & called_by_side["Gen"]):
            candidates = keys_by_sol_class_method.get((sol_path, class_name, method_name), [])
            if len(candidates) == 1:
                used[(str(test_path), check_name)].add(candidates[0])
    return used


def _constructor_called_keys_by_test(
    symbolic_dir: Path,
    manifest: dict[str, Any],
    used_wrappers_by_test: dict[str, set[str]],
    constructors: list[dict[str, Any]],
    functions: list[dict[str, Any]],
) -> dict[str, set[FunctionKey]]:
    constructors_by_sol_class: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for constructor in constructors:
        constructors_by_sol_class[(constructor["sol_path"], constructor["class_name"])].append(constructor)

    function_keys_by_sol_class_name: dict[tuple[str, str, str], list[FunctionKey]] = defaultdict(list)
    for function in functions:
        function_keys_by_sol_class_name[
            (function["sol_path"], function["class_name"], function["method_name"])
        ].append(_function_key(function))

    used: dict[str, set[FunctionKey]] = defaultdict(set)
    source_cache: dict[str, list[str]] = {}
    for case in manifest.get("cases", []):
        sol_path = str(case.get("sol_path") or "")
        test_path = case.get("symbolic_test_path")
        if not sol_path or not test_path:
            continue
        source_path = symbolic_dir / str(test_path)
        if not source_path.exists():
            continue
        content = source_path.read_text(encoding="utf-8")
        check_names = sorted(
            {
                str(method.get("check_name") or "")
                for method in manifest.get("methods", [])
                if method.get("sol_path") == sol_path and method.get("check_name")
            }
        )
        active_parts = [_extract_function_body(content, name) for name in check_names]
        for wrapper in sorted(used_wrappers_by_test.get(str(test_path), set())):
            active_parts.append(_extract_function_body(content, f"ref_{wrapper}"))
            active_parts.append(_extract_function_body(content, f"gen_{wrapper}"))
        active_content = "\n".join(active_parts)
        if not re.search(r"\bnew\s+(?:Ref|Gen)[A-Za-z0-9_]*_\d+\s*\(", active_content):
            continue

        for (constructor_sol, class_name), scoped_constructors in constructors_by_sol_class.items():
            if constructor_sol != sol_path:
                continue
            for constructor in scoped_constructors:
                body = _function_body(constructor, source_cache)
                if not body:
                    continue
                for match in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", body):
                    candidates = function_keys_by_sol_class_name.get((sol_path, class_name, match.group(1)), [])
                    if len(candidates) == 1:
                        used[str(test_path)].add(candidates[0])
    return used


def _skip_category(function: dict[str, Any], reason: str | None) -> str:
    sol_path = function["sol_path"]
    method_name = function["method_name"]
    class_kind = function["class_kind"]
    visibility = function["visibility"]
    reason_text = (reason or "").lower()

    if class_kind == "contract" and visibility not in {"public", "external"}:
        return "non_public_contract_method"
    if class_kind == "library" and visibility == "private":
        return "private_library_method"
    if "unsupported parameter type" in reason_text or "unsupported return type" in reason_text:
        return "unsupported_abi_type"
    if "profile-dependent" in reason_text:
        return "profile_dependent"
    if "constructor" in reason_text or "abstract" in reason_text:
        return "constructor_or_abstract_harness"
    if "external victim state" in reason_text or "deployed address" in reason_text or "external" in reason_text:
        return "external_environment_state"
    if "gas" in reason_text or sol_path.endswith("/GasBurnerLib.sol"):
        return "gas_modeling"
    if any(name in sol_path for name in ("LibClone.sol", "Clones.sol", "Create2.sol", "CREATE3.sol", "ERC1967Factory.sol", "SSTORE2.sol")):
        if any(token in method_name.lower() for token in ("deploy", "clone", "write", "create", "upgrade")):
            return "create_deploy_semantics"
    if any(
        name in sol_path
        for name in (
            "LibBitmap.sol",
            "LibMap.sol",
            "EnumerableMapLib.sol",
            "EnumerableSetLib.sol",
            "Checkpoints.sol",
            "Heap.sol",
            "MinHeapLib.sol",
            "LibTransient.sol",
        )
    ):
        return "symbolic_storage_or_transient_storage"
    if any(
        name in sol_path
        for name in (
            "DynamicBufferLib.sol",
            "DynamicArrayLib.sol",
            "LibBytes.sol",
            "Strings.sol",
            "JSONParserLib.sol",
            "LibZip.sol",
            "Base64.sol",
            "LibRLP.sol",
        )
    ):
        return "dynamic_bytes_memory_or_loops"
    if any(
        name in sol_path
        for name in (
            "BLS.sol",
            "P256.sol",
            "WebAuthn.sol",
            "ECDSA.sol",
            "SignatureCheckerLib.sol",
            "EfficientHashLib.sol",
            "MerkleProofLib.sol",
        )
    ):
        return "crypto_precompile_or_hash_modeling"
    if any(name in sol_path for name in ("ERC4626.sol", "Governor.sol", "ethernaut.git/contracts/src/levels/")):
        return "stateful_protocol_environment"
    if reason:
        return "other_generator_or_halmos_skip"
    return "not_represented_in_symbolic_manifest"


def build_report(dataset_path: Path, manifest_path: Path, symbolic_dir: Path) -> dict[str, Any]:
    dataset = _load_json(dataset_path)
    manifest = _load_json(manifest_path)
    functions, constructors, dataset_meta = _iter_dataset_functions(dataset)
    function_by_key = {_function_key(item): item for item in functions}
    original_keys = set(function_by_key)

    sol_to_test = _sol_to_symbolic_test(manifest)
    active_direct_keys: set[FunctionKey] = set()
    active_methods_not_in_denominator: list[dict[str, Any]] = []
    for method in manifest.get("methods", []):
        key = _function_key(method)
        if key in original_keys:
            active_direct_keys.add(key)
        else:
            active_methods_not_in_denominator.append(method)

    skipped_reasons: dict[FunctionKey, list[str]] = defaultdict(list)
    skipped_extra_count = 0
    for method in manifest.get("skipped_methods", []):
        key = _function_key(method)
        if key in original_keys:
            reason = str(method.get("reason") or "skipped")
            if reason not in skipped_reasons[key]:
                skipped_reasons[key].append(reason)
        else:
            skipped_extra_count += 1

    wrappers_by_test: dict[str, dict[str, FunctionKey]] = defaultdict(dict)
    for method in list(manifest.get("methods", [])) + list(manifest.get("skipped_methods", [])):
        key = _function_key(method)
        if key not in original_keys:
            continue
        test_path = sol_to_test.get(key[0])
        wrapper_name = method.get("wrapper_name")
        if not test_path or not wrapper_name:
            continue
        wrappers_by_test[test_path][str(wrapper_name)] = key

    wrapper_usage_records = _wrapper_usage_by_check(symbolic_dir, manifest)
    wrapper_counts_by_check = {
        (record["symbolic_test_path"], record["check_name"]): len(record["wrappers"])
        for record in wrapper_usage_records
    }
    aggregate_symbolic_checks: list[dict[str, Any]] = []
    single_check_wrapper_keys: set[FunctionKey] = set()
    aggregate_check_wrapper_keys: set[FunctionKey] = set()
    for record in wrapper_usage_records:
        test_path = record["symbolic_test_path"]
        wrapper_map = wrappers_by_test.get(test_path, {})
        resolved_keys = sorted(
            {
                wrapper_map[wrapper]
                for wrapper in record["wrappers"]
                if wrapper in wrapper_map
            }
        )
        if len(record["wrappers"]) == 1:
            single_check_wrapper_keys.update(resolved_keys)
        elif len(record["wrappers"]) > 1:
            aggregate_check_wrapper_keys.update(resolved_keys)
            aggregate_symbolic_checks.append(
                {
                    **record,
                    "resolved_functions": [
                        {
                            "sol_path": key[0],
                            "class_name": key[1],
                            "method_name": key[2],
                            "full_signature": key[3],
                        }
                        for key in resolved_keys
                    ],
                }
            )

    # A manifest_target record is an explicit one-method attribution even when
    # the Solidity property calls the ref/gen implementation directly instead
    # of going through a generated wrapper selector.
    wrapper_called_keys: set[FunctionKey] = set(single_check_wrapper_keys)
    used_wrappers_by_test = _wrapper_usage_by_test(symbolic_dir, manifest)
    unresolved_wrapper_uses: list[dict[str, str]] = []
    extra_wrappers_by_test: dict[str, set[str]] = defaultdict(set)
    for test_path, wrappers in used_wrappers_by_test.items():
        wrapper_map = wrappers_by_test.get(test_path, {})
        for wrapper in sorted(wrappers):
            key = wrapper_map.get(wrapper)
            if key is None:
                extra_wrappers_by_test[test_path].add(wrapper)
                continue
            if key in single_check_wrapper_keys:
                wrapper_called_keys.add(key)

    direct_ref_gen_calls_by_test, unresolved_direct_ref_gen_calls = _direct_ref_gen_calls_by_test(
        symbolic_dir,
        manifest,
        functions,
        extra_wrappers_by_test,
    )
    direct_ref_gen_called_keys: set[FunctionKey] = set()
    for keys in direct_ref_gen_calls_by_test.values():
        direct_ref_gen_called_keys.update(keys)
    single_check_direct_ref_gen_keys: set[FunctionKey] = set()
    direct_ref_gen_calls_by_check = _direct_ref_gen_calls_by_check(
        symbolic_dir,
        manifest,
        functions,
    )
    for keys in direct_ref_gen_calls_by_check.values():
        if len(keys) == 1:
            single_check_direct_ref_gen_keys.update(keys)

    resolved_extra_wrapper_uses: set[tuple[str, str]] = set()
    for test_path, keys in direct_ref_gen_calls_by_test.items():
        if test_path not in extra_wrappers_by_test or not keys:
            continue
        for wrapper in extra_wrappers_by_test[test_path]:
            resolved_extra_wrapper_uses.add((test_path, wrapper))
    for test_path, wrappers in extra_wrappers_by_test.items():
        for wrapper in sorted(wrappers):
            if (test_path, wrapper) not in resolved_extra_wrapper_uses:
                unresolved_wrapper_uses.append({"symbolic_test_path": test_path, "wrapper_name": wrapper})

    constructor_called_by_test = _constructor_called_keys_by_test(
        symbolic_dir,
        manifest,
        used_wrappers_by_test,
        constructors,
        functions,
    )
    constructor_called_keys: set[FunctionKey] = set()
    for keys in constructor_called_by_test.values():
        constructor_called_keys.update(keys)

    method_level_single_target_keys = active_direct_keys | wrapper_called_keys | single_check_direct_ref_gen_keys

    call_graph = _internal_call_graph(functions)
    internal_called_keys, internal_called_from = _reachable_internal_calls(
        call_graph,
        active_direct_keys | wrapper_called_keys | direct_ref_gen_called_keys | constructor_called_keys,
    )

    records: list[dict[str, Any]] = []
    by_sol: dict[str, dict[str, Any]] = {}
    category_counter: Counter[str] = Counter()
    visibility_counter: Counter[str] = Counter()
    visibility_uncovered_counter: Counter[str] = Counter()
    class_kind_counter: Counter[str] = Counter()
    class_kind_uncovered_counter: Counter[str] = Counter()

    for key, function in sorted(function_by_key.items()):
        direct = key in active_direct_keys
        called = key in wrapper_called_keys
        aggregate_called = key in aggregate_check_wrapper_keys
        direct_ref_gen_called = key in direct_ref_gen_called_keys
        constructor_called = key in constructor_called_keys
        internal_called = key in internal_called_keys
        covered = direct or called or direct_ref_gen_called or constructor_called or internal_called
        method_level_single_target = key in method_level_single_target_keys
        reasons = skipped_reasons.get(key, [])
        category = None if covered else (
            "aggregate_symbolic_check_only" if aggregate_called else _skip_category(function, reasons[0] if reasons else None)
        )
        coverage_kind = (
            "direct_check"
            if direct
            else "property_or_check_wrapper_call"
            if called
            else "aggregate_symbolic_check_only"
            if aggregate_called
            else "property_direct_ref_gen_call"
            if direct_ref_gen_called
            else "constructor_call_from_active_property"
            if constructor_called
            else "internal_call_from_checked_wrapper"
            if internal_called
            else "uncovered"
        )
        record = {
            **function,
            "covered": covered,
            "coverage_kind": coverage_kind,
            "active_direct_check": direct,
            "called_by_active_symbolic_check": called,
            "method_level_single_target_check": method_level_single_target,
            "called_by_aggregate_symbolic_check": aggregate_called,
            "called_directly_by_property_ref_gen": direct_ref_gen_called,
            "called_by_active_constructor_path": constructor_called,
            "reached_by_internal_call_graph": internal_called,
            "internal_call_roots": [
                {
                    "method_name": function_by_key[root]["method_name"],
                    "full_signature": function_by_key[root]["full_signature"],
                }
                for root in sorted(internal_called_from.get(key, set()))
                if root in function_by_key
            ],
            "skip_reasons": reasons,
            "skip_category": category,
        }
        records.append(record)

        sol = key[0]
        sol_summary = by_sol.setdefault(
            sol,
            {
                "sol_path": sol,
                "functions": 0,
                "covered": 0,
                "direct_checks": 0,
                "wrapper_called": 0,
                "method_level_single_target": 0,
                "uncovered": 0,
                "visibility": Counter(),
                "uncovered_visibility": Counter(),
                "uncovered_categories": Counter(),
                "uncovered_functions": [],
                "property_checks": 0,
            },
        )
        sol_summary["functions"] += 1
        sol_summary["visibility"][function["visibility"]] += 1
        if covered:
            sol_summary["covered"] += 1
        else:
            sol_summary["uncovered"] += 1
            sol_summary["uncovered_visibility"][function["visibility"]] += 1
            sol_summary["uncovered_categories"][category] += 1
            sol_summary["uncovered_functions"].append(
                {
                    "class_name": function["class_name"],
                    "method_name": function["method_name"],
                    "visibility": function["visibility"],
                    "full_signature": function["full_signature"],
                    "skip_category": category,
                    "skip_reasons": reasons,
                }
            )
            category_counter[category] += 1
            visibility_uncovered_counter[function["visibility"]] += 1
            class_kind_uncovered_counter[function["class_kind"]] += 1
        if direct:
            sol_summary["direct_checks"] += 1
        if called:
            sol_summary["wrapper_called"] += 1
        if method_level_single_target:
            sol_summary["method_level_single_target"] += 1
        visibility_counter[function["visibility"]] += 1
        class_kind_counter[function["class_kind"]] += 1

    property_like_methods = [
        method
        for method in active_methods_not_in_denominator
        if str(method.get("method_name") or "").startswith("property_")
    ]
    property_checks_by_sol = Counter(str(method.get("sol_path") or "") for method in property_like_methods)
    property_names_by_sol: dict[str, list[str]] = defaultdict(list)
    for method in property_like_methods:
        property_names_by_sol[str(method.get("sol_path") or "")].append(str(method.get("method_name") or ""))
    for sol, count in property_checks_by_sol.items():
        by_sol.setdefault(
            sol,
            {
                "sol_path": sol,
                "functions": 0,
                "covered": 0,
                "direct_checks": 0,
                "wrapper_called": 0,
                "method_level_single_target": 0,
                "uncovered": 0,
                "visibility": Counter(),
                "uncovered_visibility": Counter(),
                "uncovered_categories": Counter(),
                "uncovered_functions": [],
                "property_checks": 0,
            },
        )
        by_sol[sol]["property_checks"] = count
        by_sol[sol]["property_check_names"] = sorted(property_names_by_sol[sol])

    per_sol = []
    for summary in by_sol.values():
        summary = dict(summary)
        summary["visibility"] = dict(summary["visibility"])
        summary["uncovered_visibility"] = dict(summary["uncovered_visibility"])
        summary["uncovered_categories"] = dict(summary["uncovered_categories"])
        summary.setdefault("property_check_names", [])
        per_sol.append(summary)
    per_sol.sort(key=lambda item: (-item["uncovered"], -item["functions"], item["sol_path"]))

    covered_count = sum(1 for item in records if item["covered"])
    direct_count = sum(1 for item in records if item["active_direct_check"])
    wrapper_called_count = sum(1 for item in records if item["called_by_active_symbolic_check"])
    aggregate_wrapper_called_count = sum(1 for item in records if item["called_by_aggregate_symbolic_check"])
    direct_ref_gen_called_count = sum(1 for item in records if item["called_directly_by_property_ref_gen"])
    constructor_called_count = sum(1 for item in records if item["called_by_active_constructor_path"])
    internal_called_count = sum(1 for item in records if item["reached_by_internal_call_graph"])
    method_level_single_target_count = len(method_level_single_target_keys)
    single_check_direct_ref_gen_count = len(single_check_direct_ref_gen_keys)
    covered_without_method_level_single_target_count = sum(
        1
        for item in records
        if item["covered"] and not item["method_level_single_target_check"]
    )
    method_level_records = [item for item in records if item["method_level_single_target_check"]]
    method_level_gap_records = [item for item in records if not item["method_level_single_target_check"]]
    method_level_by_kind = Counter(item["coverage_kind"] for item in method_level_records)
    method_level_gap_by_kind = Counter(item["coverage_kind"] for item in method_level_gap_records)
    method_level_gap_by_visibility = Counter(item["visibility"] for item in method_level_gap_records)
    report = {
        "schema": 1,
        "description": "Function-level coverage audit for generated Halmos symbolic checks over the original dataset functions.",
        "inputs": {
            "dataset": str(dataset_path),
            "symbolic_manifest": str(manifest_path),
            "symbolic_dir": str(symbolic_dir),
        },
        "summary": {
            "dataset_sols": len(dataset),
            "dataset_records": dataset_meta["records"],
            "dataset_function_records": dataset_meta["function_records"],
            "dataset_non_function_records": dataset_meta["non_function_records"],
            "sols_with_functions": len({item["sol_path"] for item in functions}),
            "original_functions": len(functions),
            "covered_functions": covered_count,
            "uncovered_functions": len(functions) - covered_count,
            "method_level_single_target_functions": method_level_single_target_count,
            "method_level_single_target_gap_functions": len(functions) - method_level_single_target_count,
            "method_level_single_target_by_kind": dict(method_level_by_kind),
            "method_level_single_target_gap_by_kind": dict(method_level_gap_by_kind),
            "method_level_single_target_gap_by_visibility": dict(method_level_gap_by_visibility),
            "covered_without_method_level_single_target_functions": covered_without_method_level_single_target_count,
            "direct_active_function_checks": direct_count,
            "functions_called_by_active_symbolic_checks": wrapper_called_count,
            "functions_called_by_single_direct_ref_gen_check": single_check_direct_ref_gen_count,
            "functions_called_by_aggregate_symbolic_checks": aggregate_wrapper_called_count,
            "aggregate_symbolic_checks": len(aggregate_symbolic_checks),
            "functions_called_directly_by_property_ref_gen": direct_ref_gen_called_count,
            "functions_called_by_active_constructor_paths": constructor_called_count,
            "functions_reached_by_internal_call_graph": internal_called_count,
            "property_like_checks": len(property_like_methods),
            "active_symbolic_check_functions": len(manifest.get("methods", [])),
            "active_methods_not_in_denominator": len(active_methods_not_in_denominator),
            "manifest_active_methods": len(manifest.get("methods", [])),
            "manifest_skipped_methods": len(manifest.get("skipped_methods", [])),
            "manifest_skipped_non_dataset_records": skipped_extra_count,
            "unresolved_wrapper_uses": len(unresolved_wrapper_uses),
            "unresolved_direct_ref_gen_calls": len(unresolved_direct_ref_gen_calls),
            "visibility": dict(visibility_counter),
            "uncovered_visibility": dict(visibility_uncovered_counter),
            "class_kind": dict(class_kind_counter),
            "uncovered_class_kind": dict(class_kind_uncovered_counter),
            "uncovered_categories": dict(category_counter),
        },
        "per_sol": per_sol,
        "functions": records,
        "aggregate_symbolic_checks": aggregate_symbolic_checks,
        "unresolved_wrapper_uses": unresolved_wrapper_uses,
        "unresolved_direct_ref_gen_calls": unresolved_direct_ref_gen_calls,
        "active_methods_not_in_denominator": active_methods_not_in_denominator,
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description="Report original dataset function coverage by symbolic checks.")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_SYMBOLIC_MANIFEST)
    parser.add_argument("--symbolic-dir", type=Path, default=DEFAULT_SYMBOLIC_DIR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    report = build_report(args.dataset.resolve(), args.manifest.resolve(), args.symbolic_dir.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    summary = report["summary"]
    print(
        "original_functions={original_functions} covered={covered_functions} "
        "uncovered={uncovered_functions} method_level_single_target={method_level_single_target_functions} "
        "active_symbolic_check_functions={active_symbolic_check_functions} direct={direct_active_function_checks} "
        "wrapper_called={functions_called_by_active_symbolic_checks} "
        "property_like={property_like_checks} not_in_denominator={active_methods_not_in_denominator}".format(
            **summary
        )
    )
    print(f"report={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
