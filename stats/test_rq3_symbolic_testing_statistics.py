#!/usr/bin/env python3
"""Tests for the RQ3 symbolic-testing statistics."""

import unittest

from stats.rq3_symbolic_testing_statistics import summarize_group
from testing.rq3_verify_symbolic_models import DEFAULT_SELECTION_POLICY


def result(**updates):
    value = {
        "sol_path": "Foo.sol",
        "expected_checks": 3,
        "proved_checks": 2,
        "ok": False,
        "compile_error": None,
        "extract_error": None,
        "missing_row": False,
    }
    value.update(updates)
    return value


class SymbolicAggregationTests(unittest.TestCase):
    def test_selection_policy_matches_rq1_and_rq2(self):
        self.assertEqual(DEFAULT_SELECTION_POLICY, "test-first-security-second")

    def test_compile_failure_keeps_checks_in_denominator(self):
        row = summarize_group(
            "model",
            "method",
            [result(), result(proved_checks=0, compile_error="failed")],
        )
        self.assertEqual(row.compiled, 1)
        self.assertEqual(row.passed_checks, 2)
        self.assertEqual(row.expected_checks, 6)
        self.assertAlmostEqual(row.symbolic_check_pass_rate, 1 / 3)

    def test_pass_at_1_requires_all_checks_to_pass(self):
        row = summarize_group(
            "model",
            "method",
            [result(proved_checks=3, ok=True)],
        )
        self.assertEqual(row.symbolic_pass_at_1_count, 1)
        self.assertEqual(row.symbolic_pass_at_1, 1.0)


if __name__ == "__main__":
    unittest.main()
