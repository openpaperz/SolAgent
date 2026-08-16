#!/usr/bin/env python3
"""Run the RQ3 Halmos suite against Mimo OpenCode artifacts."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from testing.generate_eval_tests import DEFAULT_DATASET, _load_dataset  # noqa: E402
from testing.mimo_opencode_verify_eval import (  # noqa: E402
    DEFAULT_ARTIFACT_DIR,
    _artifact_file_name,
    _load_artifact,
)
from testing.rq1_verify_eval_models import Target, _split_csv  # noqa: E402
from testing.rq3_verify_symbolic_models import (  # noqa: E402
    DEFAULT_MANIFEST,
    _check_method_map,
    _run_one,
    _write_report,
)


MODEL = "mimo-v2.5-pro"
REPORT_PATH = ROOT / "testing" / "symbolic" / "mimo_opencode_verify_symbolic.json"


def artifact_connection(
    artifact_dir: Path,
    sol_paths: list[str],
) -> sqlite3.Connection:
    connection = sqlite3.connect(":memory:")
    connection.row_factory = sqlite3.Row
    connection.execute(
        """
        CREATE TABLE progress_tracker_rawmodel (
            id INTEGER PRIMARY KEY,
            status INTEGER,
            file_path TEXT,
            model_coding TEXT,
            coding_messages TEXT
        )
        """
    )
    for index, sol_path in enumerate(sol_paths, start=1):
        artifact_path = artifact_dir / _artifact_file_name(sol_path)
        artifact, error = _load_artifact(artifact_path)
        if artifact is None:
            raise ValueError(f"Cannot load OpenCode artifact {artifact_path}: {error}")
        connection.execute(
            "INSERT INTO progress_tracker_rawmodel VALUES (?, ?, ?, ?, ?)",
            (
                index,
                int(artifact.get("status") or 0),
                sol_path,
                MODEL,
                json.dumps(artifact.get("coding_messages") or []),
            ),
        )
    connection.commit()
    return connection


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-dir", type=Path, default=DEFAULT_ARTIFACT_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--symbolic-dir", type=Path)
    parser.add_argument("--sol")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--fail-fast", action="store_true")
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--halmos-bin")
    parser.add_argument("--chunk-size", type=int)
    parser.add_argument("--loop", type=int, default=2)
    parser.add_argument("--solver-timeout-assertion", type=int, default=1000)
    parser.add_argument("--solver-timeout-branching", type=int, default=1)
    parser.add_argument("--report", type=Path, default=REPORT_PATH)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.halmos_bin:
        os.environ["HALMOS_BIN"] = args.halmos_bin
    dataset = _load_dataset(DEFAULT_DATASET)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    symbolic_dir = (args.symbolic_dir or args.manifest.resolve().parent).resolve()
    cases = {case["sol_path"]: case for case in manifest["cases"]}
    methods: dict[str, list[dict[str, Any]]] = {}
    for item in manifest["methods"]:
        methods.setdefault(item["sol_path"], []).append(item)
    shared_groups: dict[str, list[str]] = {}
    for case in manifest["cases"]:
        shared_groups.setdefault(case["symbolic_test_path"], []).append(case["sol_path"])
    check_method_map = _check_method_map(manifest, dataset, symbolic_dir)

    sol_paths = list(dataset)
    if args.sol:
        requested = set(_split_csv(args.sol, []))
        unknown = sorted(requested - set(dataset))
        if unknown:
            print(f"[error] unknown sol_path filter: {unknown}", file=sys.stderr)
            return 2
        sol_paths = [path for path in sol_paths if path in requested]
    if args.limit is not None:
        sol_paths = sol_paths[: args.limit]
    if not sol_paths:
        print("[error] no symbolic tasks selected", file=sys.stderr)
        return 2

    target = Target("rawmodel", "OpenCode", "progress_tracker_rawmodel", MODEL)
    results: list[dict[str, Any]] = []
    try:
        connection = artifact_connection(args.artifact_dir, list(dataset))
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"[error] {error}", file=sys.stderr)
        return 2
    with connection:
        for index, sol_path in enumerate(sol_paths, start=1):
            print(f"[symbolic] {index}/{len(sol_paths)} opencode {sol_path}", flush=True)
            result = _run_one(
                connection,
                target,
                sol_path,
                symbolic_dir,
                cases,
                methods,
                shared_groups,
                check_method_map,
                selection_policy="test-first-security-second",
                timeout=args.timeout,
                loop=args.loop,
                solver_timeout_assertion=args.solver_timeout_assertion,
                solver_timeout_branching=args.solver_timeout_branching,
                chunk_size=args.chunk_size,
            )
            result.update(source="opencode", source_name="OpenCode", agent_type="opencode")
            results.append(result)
            if result.get("ok"):
                print(
                    f"[proved] opencode {sol_path} "
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
                print(f"[fail] opencode {sol_path}: {reason}", flush=True)
                if args.fail_fast:
                    break
            _write_report(args.report, results)
    summary = _write_report(args.report, results)
    global_summary = summary["global"]
    print(
        f"[symbolic] sols={global_summary['sols']} "
        f"proved_sols={global_summary['proved_sols']} "
        f"expected_checks={global_summary['expected_checks']} "
        f"proved_checks={global_summary['proved_checks']} "
        f"compile_errors={global_summary['compile_errors']} "
        f"extract_errors={global_summary['extract_errors']}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
