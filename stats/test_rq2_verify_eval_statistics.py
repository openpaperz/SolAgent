#!/usr/bin/env python3
"""Tests for RQ2 fixed-seed ablation correctness statistics."""

import unittest

from stats.rq1_verify_eval_statistics import FIXED_FUZZ_SEED
from stats.rq2_verify_eval_statistics import (
    RQ2EvalStatisticsError,
    build_row,
    normalize_configurations,
    validate_eval_result,
)


def result(**updates):
    value = {
        "source": "no_forge",
        "source_name": "Ablation-no_forge",
        "model": "model",
        "sol_path": "Foo.sol",
        "ablation_type": 2,
        "fuzz_seed": FIXED_FUZZ_SEED,
        "selection_policy": "test-first-security-second",
        "code_selection": "round_messages",
        "best_round": 1,
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


class RQ2ValidationTests(unittest.TestCase):
    def test_configuration_aliases(self):
        self.assertEqual(
            normalize_configurations("full,w/o Forge,w/o Tools"),
            ["full", "no_forge", "no_tools"],
        )

    def test_ablation_type_mismatch_is_rejected(self):
        with self.assertRaises(RQ2EvalStatisticsError):
            validate_eval_result(result(ablation_type=4))

    def test_non_seed1_is_rejected(self):
        with self.assertRaises(RQ2EvalStatisticsError):
            validate_eval_result(result(fuzz_seed="0x2"))

    def test_wrong_selection_policy_is_rejected(self):
        with self.assertRaises(RQ2EvalStatisticsError):
            validate_eval_result(result(selection_policy="best-pass-first"))

    def test_row_uses_same_correctness_metrics_as_rq1(self):
        row = build_row("model", "no_forge", [result()])
        self.assertEqual(row.ablation_configuration, "w/o Forge")
        self.assertEqual(row.compiled, 1)
        self.assertEqual(row.passed_tests, 1)
        self.assertEqual(row.expected_tests, 2)
        self.assertEqual(row.test_pass_rate, 0.5)
        self.assertEqual(row.pass_at_1, 0)


if __name__ == "__main__":
    unittest.main()
