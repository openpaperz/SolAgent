#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict, deque
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = ROOT / "data" / "dataset.json"
DEFAULT_MANIFEST = ROOT / "testing" / "eval" / "eval_manifest.json"
DEFAULT_REPORT = ROOT / "testing" / "eval" / "eval_function_coverage.json"


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _method_name(method: dict[str, Any]) -> str:
    if method.get("identifier"):
        return str(method["identifier"])
    signature = method.get("full_signature") or ""
    match = re.search(r"function\s+([A-Za-z_][A-Za-z0-9_]*)", signature)
    if match:
        return match.group(1)
    return "constructor" if method.get("kind") == "constructor" else "unknown"


def _function_key(sol_path: str, class_name: str, method: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        sol_path,
        class_name,
        _method_name(method),
        str(method.get("full_signature") or ""),
    )


def _manifest_key(item: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(item["sol_path"]),
        str(item["class_name"]),
        str(item["method_name"]),
        str(item.get("full_signature") or ""),
    )


def _call_pattern(name: str) -> re.Pattern[str]:
    return re.compile(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"\s*\(")


def _classify_gap(sol_path: str, class_name: str, method: dict[str, Any]) -> str:
    name = _method_name(method)
    visibility = str(method.get("visibility") or "")
    if sol_path.endswith("/contracts/governance/Governor.sol") and name in {"CLOCK_MODE", "quorum"}:
        return "abstract_hook_harness_override"
    if class_name.startswith("I") and visibility == "external":
        return "interface_callback"
    if sol_path.endswith("/src/internal/DefenderDeploy.sol") and name in {"deploy", "proposeUpgrade", "getApprovalProcess"}:
        return "ffi_cli_wrapper"
    if (
        sol_path.endswith("/src/LegacyUpgrades.sol")
        and class_name == "Upgrades"
        and name in {"upgradeProxy", "upgradeBeacon"}
        and "Options memory opts" not in str(method.get("full_signature") or "")
    ):
        return "ffi_validation_path"
    if "openzeppelin-foundry-upgrades" in sol_path and name in {"validateUpgrade", "validateImplementation"}:
        return "ffi_validation_path"
    return "needs_eval_coverage"


def build_report(dataset: dict[str, Any], manifest: dict[str, Any]) -> dict[str, Any]:
    methods = manifest.get("methods") or []
    covered = {_manifest_key(item) for item in methods}
    covered_scopes: dict[tuple[str, str], set[str]] = defaultdict(set)
    for item in methods:
        covered_scopes[(str(item["sol_path"]), str(item["class_name"]))].add(str(item["method_name"]))

    functions: list[tuple[tuple[str, str, str, str], str, str, dict[str, Any], dict[str, Any]]] = []
    all_callables: list[tuple[tuple[str, str, str, str], str, str, dict[str, Any], dict[str, Any]]] = []
    by_scope: dict[tuple[str, str], list[tuple[tuple[str, str, str, str], dict[str, Any]]]] = defaultdict(list)
    by_scope_name: dict[tuple[str, str, str], list[tuple[tuple[str, str, str, str], dict[str, Any]]]] = defaultdict(list)

    for sol_path, classes in dataset.items():
        for cls in classes:
            class_name = str(cls.get("identifier") or "")
            for method in cls.get("methods", []):
                if method.get("kind") not in {"function", "constructor"}:
                    continue
                key = _function_key(sol_path, class_name, method)
                all_callables.append((key, sol_path, class_name, cls, method))
                by_scope[(sol_path, class_name)].append((key, method))
                by_scope_name[(sol_path, class_name, _method_name(method))].append((key, method))
                if method.get("kind") == "function":
                    functions.append((key, sol_path, class_name, cls, method))

    edges: dict[tuple[str, str, str, str], set[tuple[str, str, str, str]]] = defaultdict(set)
    for caller_key, sol_path, class_name, _cls, method in all_callables:
        body = method.get("body") or ""
        caller_name = _method_name(method)
        for (candidate_sol, candidate_class, candidate_name), candidates in by_scope_name.items():
            if candidate_sol != sol_path or candidate_class != class_name or candidate_name == caller_name:
                continue
            if not _call_pattern(candidate_name).search(body):
                continue
            for callee_key, callee in candidates:
                if callee.get("kind") == "function":
                    edges[caller_key].add(callee_key)

    starts = set(covered)
    for scope in covered_scopes:
        for constructor_key, constructor in by_scope.get(scope, []):
            if constructor.get("kind") == "constructor":
                starts.add(constructor_key)

    reachable = set(starts)
    queue: deque[tuple[str, str, str, str]] = deque(starts)
    while queue:
        current = queue.popleft()
        for nxt in edges.get(current, set()):
            if nxt not in reachable:
                reachable.add(nxt)
                queue.append(nxt)

    direct_missing = []
    transitive_missing = []
    for key, sol_path, class_name, _cls, method in functions:
        item = {
            "sol_path": sol_path,
            "class_name": class_name,
            "method_name": _method_name(method),
            "full_signature": method.get("full_signature") or "",
            "visibility": method.get("visibility") or "",
            "gap_category": _classify_gap(sol_path, class_name, method),
        }
        if key not in covered:
            direct_missing.append(item)
        if key not in reachable:
            transitive_missing.append(item)

    direct_missing_visibility = Counter(item["visibility"] for item in direct_missing)
    transitive_missing_visibility = Counter(item["visibility"] for item in transitive_missing)
    transitive_missing_category = Counter(item["gap_category"] for item in transitive_missing)
    by_sol = Counter(item["sol_path"] for item in transitive_missing)

    return {
        "summary": {
            "dataset_functions": len(functions),
            "eval_methods": len(methods),
            "direct_covered": len(functions) - len(direct_missing),
            "direct_missing": len(direct_missing),
            "transitive_covered": len(functions) - len(transitive_missing),
            "transitive_missing": len(transitive_missing),
            "direct_missing_visibility": dict(sorted(direct_missing_visibility.items())),
            "transitive_missing_visibility": dict(sorted(transitive_missing_visibility.items())),
            "transitive_missing_category": dict(sorted(transitive_missing_category.items())),
            "transitive_missing_by_sol": dict(by_sol.most_common()),
        },
        "direct_missing": direct_missing,
        "transitive_missing": transitive_missing,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Report dataset function coverage by generated hidden eval tests.")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()

    report = build_report(_load_json(args.dataset), _load_json(args.manifest))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    summary = report["summary"]
    print(
        "[eval-coverage] "
        f"dataset_functions={summary['dataset_functions']} eval_methods={summary['eval_methods']} "
        f"direct={summary['direct_covered']}/{summary['dataset_functions']} "
        f"transitive={summary['transitive_covered']}/{summary['dataset_functions']} "
        f"transitive_missing={summary['transitive_missing']}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
