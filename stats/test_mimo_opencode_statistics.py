#!/usr/bin/env python3
"""Tests for Mimo SolAgent versus OpenCode statistics."""

import unittest

from stats.mimo_opencode_security_slither_statistics import build_rows
from stats.mimo_opencode_utils import MODEL, SecuritySample
from stats.mimo_opencode_verify_eval_statistics import summarize


def eval_result(path: str, *, ok: bool, passed: int = 1, expected: int = 2):
    return {
        "sol_path": path,
        "ok": ok,
        "passed": expected if ok else passed,
        "expected_tests": expected,
        "forge_total": expected,
        "compile_error": None,
        "extract_error": None,
    }


class CorrectnessTests(unittest.TestCase):
    def test_test_and_file_denominators_are_separate(self):
        row = summarize(
            "SolAgent",
            {
                "A.sol": eval_result("A.sol", ok=True),
                "B.sol": eval_result("B.sol", ok=False),
            },
        )
        self.assertEqual((row["passed_tests"], row["expected_tests"]), (3, 4))
        self.assertEqual((row["pass_at_1_count"], row["attempted"]), (1, 2))


class SecurityTests(unittest.TestCase):
    def test_findings_use_same_full_pass_pairs(self):
        sol_eval = eval_result("A.sol", ok=True)
        open_eval = eval_result("A.sol", ok=True)
        groups = {
            "SolAgent": {
                "A.sol": SecuritySample(MODEL, "SolAgent", "A.sol", "code", 20, 2, sol_eval),
            },
            "OpenCode": {
                "A.sol": SecuritySample(MODEL, "OpenCode", "A.sol", "code", 10, 4, open_eval),
            },
        }
        rows = build_rows(groups)
        baseline = rows[1]
        self.assertEqual(baseline["baseline_solagent_findings_with_n"], "4/2 (n=1)")
        self.assertEqual(baseline["finding_count_reduction"], 0.5)
        self.assertEqual(baseline["baseline_solagent_findings_per_kloc"], "400.00/100.00")


if __name__ == "__main__":
    unittest.main()
