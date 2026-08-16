#!/usr/bin/env python3
"""Tests for the fixed-seed RQ3 distillation eval statistics."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from stats.rq3_distill_verify_eval_statistics import (
    FUZZ_SEED,
    MODELS,
    DistillEvalError,
    build_row,
    load_rows,
)


def result(**updates):
    value = {
        "source": "solagent",
        "model": "Qwen/Qwen3-8B",
        "sol_path": "Foo.sol",
        "expected_tests": 2,
        "passed": 0,
        "forge_total": 0,
        "forge_failed": 0,
        "ok": False,
        "compile_error": None,
        "extract_error": None,
        "error": None,
        "missing_row": False,
    }
    value.update(updates)
    return value


class DistillAggregationTests(unittest.TestCase):
    def test_failures_remain_in_fixed_denominators(self):
        full_pass = result(
            sol_path="A.sol",
            passed=2,
            forge_total=2,
            forge_failed=0,
            ok=True,
        )
        unrun = result(sol_path="B.sol", extract_error="no generated code")

        row = build_row("Qwen/Qwen3-8B", [full_pass, unrun])

        self.assertEqual(row.attempted, 2)
        self.assertEqual(row.compiled, 1)
        self.assertEqual(row.passed_tests, 2)
        self.assertEqual(row.expected_tests, 4)
        self.assertEqual(row.pass_at_1, 1)

    def test_partial_test_pass_is_not_pass_at_1(self):
        partial = result(
            passed=1,
            forge_total=2,
            forge_failed=1,
        )

        row = build_row("Qwen/Qwen3-8B", [partial])

        self.assertEqual(row.compiled, 1)
        self.assertEqual(row.test_pass_rate, 0.5)
        self.assertEqual(row.pass_at_1, 0)


class DistillReportTests(unittest.TestCase):
    def make_report(self, paths):
        results = []
        groups = []
        for model in MODELS:
            for index, sol_path in enumerate(paths):
                expected = 21 if index == 0 else 22
                results.append(
                    result(
                        model=model,
                        sol_path=sol_path,
                        fuzz_seed=FUZZ_SEED,
                        selection_policy="test-first-security-second",
                        code_selection="round_messages",
                        best_round=1,
                        expected_tests=expected,
                        forge_total=expected,
                        forge_failed=expected,
                    )
                )
            groups.append(
                {
                    "source": "solagent",
                    "model": model,
                    "sols": 17,
                    "passed_sols": 0,
                    "failed_sols": 17,
                    "expected_tests": 373,
                    "passed_tests": 0,
                    "failed_tests": 373,
                    "compile_errors": 0,
                    "extract_errors": 0,
                    "missing_rows": 0,
                }
            )
        return {
            "config": {
                "selection_policy": "test-first-security-second",
                "fuzz_seed": FUZZ_SEED,
            },
            "results": results,
            "summary": {"groups": groups},
        }

    def write_report(self, report):
        directory = tempfile.TemporaryDirectory()
        path = Path(directory.name) / "report.json"
        path.write_text(json.dumps(report), encoding="utf-8")
        return directory, path

    def test_complete_report_uses_equal_held_out_denominators(self):
        paths = [f"held-out-{index}.sol" for index in range(17)]
        directory, path = self.write_report(self.make_report(paths))
        self.addCleanup(directory.cleanup)

        with patch(
            "stats.rq3_distill_verify_eval_statistics.held_out_paths",
            return_value=paths,
        ):
            rows = load_rows(path)

        self.assertEqual(len(rows), 4)
        self.assertTrue(all(row.attempted == 17 for row in rows))
        self.assertTrue(all(row.expected_tests == 373 for row in rows))

    def test_incomplete_model_group_is_rejected(self):
        paths = [f"held-out-{index}.sol" for index in range(17)]
        report = self.make_report(paths)
        report["results"] = [
            row
            for row in report["results"]
            if not (
                row["model"] == MODELS[-1]
                and row["sol_path"] == paths[-1]
            )
        ]
        directory, path = self.write_report(report)
        self.addCleanup(directory.cleanup)

        with patch(
            "stats.rq3_distill_verify_eval_statistics.held_out_paths",
            return_value=paths,
        ):
            with self.assertRaises(DistillEvalError):
                load_rows(path)


if __name__ == "__main__":
    unittest.main()
