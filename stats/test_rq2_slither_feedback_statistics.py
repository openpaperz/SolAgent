#!/usr/bin/env python3
"""Unit tests for the RQ2 Slither-feedback analysis."""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.rq2_slither_feedback_statistics import (
    exact_sign_test_p_value,
    holm_adjust,
    load_supplemental_scans,
    select_persisted_round,
    select_test_first_security_second,
)


class SelectionTests(unittest.TestCase):
    def test_failed_slither_result_is_not_treated_as_zero_findings(self):
        row = {
            "file_path": "Foo.sol",
            "test_json": json.dumps({"1": {"passed": 5, "total": 5}}),
            "round_vuln_count": json.dumps({"1": 0}),
            "round_slither_raw": json.dumps(
                {"1": {"error": "Slither produced no output"}}
            ),
        }
        selected = select_persisted_round(row)
        self.assertEqual(selected.round_index, 1)
        self.assertIsNone(selected.vuln_count)
        self.assertFalse(selected.scan_valid)

    def test_security_breaks_only_exact_test_ties(self):
        row = {
            "file_path": "Foo.sol",
            "test_json": json.dumps(
                {
                    "1": {"passed": 5, "total": 6},
                    "2": {"passed": 5, "total": 6},
                    "3": {"passed": 4, "total": 6},
                }
            ),
            "round_vuln_count": json.dumps({"1": 4, "2": 1, "3": 0}),
            "round_slither_raw": json.dumps({}),
        }
        selected = select_test_first_security_second(row)
        self.assertEqual(selected.round_index, 2)
        self.assertEqual((selected.passed, selected.total, selected.vuln_count), (5, 6, 1))

    def test_earliest_round_breaks_remaining_tie(self):
        row = {
            "file_path": "Foo.sol",
            "test_json": json.dumps(
                {
                    "1": {"passed": 5, "total": 6},
                    "2": {"passed": 5, "total": 6},
                }
            ),
            "round_vuln_count": json.dumps({"1": 1, "2": 1}),
            "round_slither_raw": json.dumps({}),
        }
        self.assertEqual(select_test_first_security_second(row).round_index, 1)


class StatisticalTests(unittest.TestCase):
    def test_loads_successful_supplemental_scan(self):
        result = {
            "source": "no_slither",
            "model": "gpt-5-mini",
            "id": 472,
            "file_path": "LegacyUpgrades.sol",
            "best_round": 4,
            "code_sha256": "abc",
            "success": True,
            "finding_count": 29,
            "finding_summary": {"High": 3, "Medium": 25, "Low": 1},
        }
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "result.json"
            path.write_text(json.dumps(result), encoding="utf-8")
            scans = load_supplemental_scans(Path(tmp_dir))
        scan = scans[("no_slither", "gpt-5-mini", "LegacyUpgrades.sol", 4)]
        self.assertEqual(scan.finding_count, 29)
        self.assertEqual(scan.finding_summary["High"], 3)

    def test_exact_sign_test(self):
        self.assertAlmostEqual(exact_sign_test_p_value(7, 0), 0.015625)
        self.assertAlmostEqual(exact_sign_test_p_value(9, 1), 0.021484375)
        self.assertEqual(exact_sign_test_p_value(0, 0), 1.0)

    def test_holm_adjustment(self):
        adjusted = holm_adjust([0.015625, 0.021484375, 0.0390625])
        for value in adjusted:
            self.assertAlmostEqual(value, 0.046875)


if __name__ == "__main__":
    unittest.main()
