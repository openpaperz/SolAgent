#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from testing.generate_symbolic_tests import (  # noqa: E402
    DEFAULT_MANIFEST,
    DEFAULT_SYMBOLIC_DIR,
    _active_method_risk_reason,
    _extract_function_bodies,
)


DEFAULT_OUTPUT = DEFAULT_SYMBOLIC_DIR / "symbolic_active_check_audit.json"


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_active_checks(manifest_path: Path, symbolic_dir: Path) -> dict[str, Any]:
    manifest = _load_json(manifest_path)
    sol_to_symbolic = {
        str(case.get("sol_path")): str(case.get("symbolic_test_path"))
        for case in manifest.get("cases", [])
        if case.get("sol_path") and case.get("symbolic_test_path")
    }
    functions_cache: dict[str, dict[str, str]] = {}
    findings: list[dict[str, Any]] = []
    missing_symbolic_tests: list[dict[str, Any]] = []

    for method in manifest.get("methods", []):
        sol_path = str(method.get("sol_path") or "")
        symbolic_rel = sol_to_symbolic.get(sol_path)
        if not symbolic_rel:
            missing_symbolic_tests.append(method)
            continue
        if symbolic_rel not in functions_cache:
            symbolic_path = symbolic_dir / symbolic_rel
            try:
                functions_cache[symbolic_rel] = _extract_function_bodies(
                    symbolic_path.read_text(encoding="utf-8")
                )
            except OSError as exc:
                findings.append(
                    {
                        "sol_path": sol_path,
                        "check_name": method.get("check_name"),
                        "symbolic_test_path": symbolic_rel,
                        "reason": f"failed to read symbolic test: {exc}",
                    }
                )
                continue
        reason = _active_method_risk_reason(method, functions_cache[symbolic_rel])
        if reason:
            findings.append(
                {
                    "sol_path": sol_path,
                    "check_name": method.get("check_name"),
                    "test_name": method.get("test_name"),
                    "symbolic_test_path": symbolic_rel,
                    "reason": reason,
                }
            )

    reason_counts = Counter(str(item.get("reason") or "") for item in findings)
    hard_failures = [
        item
        for item in findings
        if str(item.get("reason") or "").startswith("failed to read symbolic test:")
    ]
    return {
        "schema": 1,
        "manifest": str(manifest_path),
        "symbolic_dir": str(symbolic_dir),
        "active_checks": len(manifest.get("methods", [])),
        "cases": len(manifest.get("cases", [])),
        "description": (
            "Fixed/bounded-input findings are advisory coverage notes. They do not "
            "invalidate active checks; ref-as-gen Halmos proof is the pass/fail gate."
        ),
        "findings": findings,
        "findings_count": len(findings),
        "hard_failures": hard_failures,
        "hard_failures_count": len(hard_failures),
        "missing_symbolic_tests": missing_symbolic_tests,
        "missing_symbolic_tests_count": len(missing_symbolic_tests),
        "reason_counts": dict(reason_counts.most_common()),
        "ok": not hard_failures and not missing_symbolic_tests,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Audit active Halmos symbolic checks for fixed/bounded harness dependencies."
    )
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--symbolic-dir", type=Path, default=DEFAULT_SYMBOLIC_DIR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    report = audit_active_checks(args.manifest.resolve(), args.symbolic_dir.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"[audit-symbolic-active] active_checks={report['active_checks']} "
        f"findings={report['findings_count']} missing_tests={report['missing_symbolic_tests_count']} "
        f"ok={report['ok']}"
    )
    print(f"report={args.output}")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
