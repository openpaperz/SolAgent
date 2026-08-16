#!/usr/bin/env python3
"""Unit tests for the standalone RQ2 Aderyn statistics."""

import json
import tempfile
import unittest
from pathlib import Path

from stats.rq2_security_aderyn_statistics import (
    analyze_aderyn,
    load_aderyn_groups,
)
from stats.rq2_slither_feedback_statistics import SelectedRound, StatisticsError


class AderynStatisticsTests(unittest.TestCase):
    def test_validates_selection_and_computes_normalized_comparison(self):
        model = "gpt-5.1"
        full = SelectedRound("A.sol", 1, 1, 1, 1, None)
        no_slither = SelectedRound("A.sol", 2, 1, 1, 2, None)
        database_groups = {
            model: (
                {"A.sol": full},
                {"A.sol": no_slither},
            )
        }
        payload = {
            "selection_policy": "test-first-security-second",
            "records": [
                {
                    "source": "full",
                    "model": model,
                    "file_path": "A.sol",
                    "status": "analyzed",
                    "test_pass": 1,
                    "test_total": 1,
                    "best_round": 1,
                    "slither_count": 1,
                    "code_sha256": "full-sha",
                    "aderyn_count": 0,
                    "aderyn_summary": {"High": 0, "Low": 0},
                    "aderyn_sloc": 100,
                },
                {
                    "source": "no_slither",
                    "model": model,
                    "file_path": "A.sol",
                    "status": "analyzed",
                    "test_pass": 1,
                    "test_total": 1,
                    "best_round": 2,
                    "slither_count": 2,
                    "code_sha256": "no-slither-sha",
                    "aderyn_count": 2,
                    "aderyn_summary": {"High": 1, "Low": 1},
                    "aderyn_sloc": 200,
                },
            ],
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            summary_path = Path(temp_dir) / "summary.json"
            summary_path.write_text(json.dumps(payload), encoding="utf-8")
            groups = load_aderyn_groups(summary_path, database_groups)

            payload["records"][0]["best_round"] = 9
            summary_path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaises(StatisticsError):
                load_aderyn_groups(summary_path, database_groups)

        result = analyze_aderyn(groups, [model])
        full_row, no_slither_row = result["main_table"]
        self.assertEqual(full_row["safe_full_pass"], 1)
        self.assertEqual(no_slither_row["safe_full_pass"], 0)
        self.assertEqual(no_slither_row["compiled_findings_per_kloc"], 10.0)
        self.assertEqual(no_slither_row["full_pass_findings_per_kloc"], 10.0)
        self.assertEqual(no_slither_row["full_pass_scanned"], 1)
        paired = result["functionality_matched"][0]
        self.assertEqual(
            (paired["full_lower"], paired["equal"], paired["full_higher"]),
            (1, 0, 0),
        )


if __name__ == "__main__":
    unittest.main()
