#!/usr/bin/env python3
"""Tests for the fixed-seed RQ1 eval correctness statistics."""

import unittest

from stats.rq1_verify_eval_statistics import (
    FIXED_FUZZ_SEED,
    RQ1EvalStatisticsError,
    summarize_group,
    validate_result_selection,
)


def result(**updates):
    value = {
        "source": "rawmodel",
        "model": "model",
        "sol_path": "Foo.sol",
        "fuzz_seed": FIXED_FUZZ_SEED,
        "selection_policy": "best-pass-first",
        "code_selection": "coding_messages",
        "best_round": None,
        "expected_tests": 2,
        "passed": 1,
        "forge_total": 2,
        "forge_failed": 1,
        "ok": False,
        "compile_error": None,
        "extract_error": None,
        "error": None,
        "missing_row": False,
    }
    value.update(updates)
    return value


class SelectionValidationTests(unittest.TestCase):
    def test_single_shot_policy_label_is_ignored(self):
        row = result(selection_policy="test-first-security-second")
        validate_result_selection(row, "RawModel")

    def test_single_shot_best_round_is_rejected(self):
        with self.assertRaises(RQ1EvalStatisticsError):
            validate_result_selection(result(best_round=2), "RawModel")

    def test_solagent_requires_security_tiebreak_policy(self):
        row = result(source="solagent", best_round=2, code_selection="round_messages")
        with self.assertRaises(RQ1EvalStatisticsError):
            validate_result_selection(row, "SolAgent")

    def test_non_seed1_result_is_rejected(self):
        with self.assertRaises(RQ1EvalStatisticsError):
            validate_result_selection(result(fuzz_seed="0x2"), "RawModel")


class AggregationTests(unittest.TestCase):
    def test_test_failures_remain_in_expected_denominator(self):
        compiled = result(sol_path="A.sol", passed=1)
        compile_error = result(
            sol_path="B.sol",
            passed=0,
            forge_total=0,
            forge_failed=0,
            compile_error="failed",
        )
        row = summarize_group("model", "RawModel", [compiled, compile_error])
        self.assertEqual(row.attempted, 2)
        self.assertEqual(row.compiled, 1)
        self.assertEqual(row.passed_tests, 1)
        self.assertEqual(row.expected_tests, 4)
        self.assertEqual(row.test_level_correctness, 0.25)
        self.assertEqual(row.full_pass, 0)

    def test_full_pass_is_counted_at_file_level(self):
        full_pass = result(
            passed=2,
            forge_failed=0,
            ok=True,
        )
        row = summarize_group("model", "RawModel", [full_pass])
        self.assertEqual(row.passed_tests, 2)
        self.assertEqual(row.full_pass, 1)
        self.assertEqual(row.full_pass_rate, 1.0)


if __name__ == "__main__":
    unittest.main()
