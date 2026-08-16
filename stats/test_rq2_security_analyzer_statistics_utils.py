#!/usr/bin/env python3
"""Tests for the per-analyzer RQ2 statistics entry points."""

import unittest

from stats.rq2_security_analyzer_statistics_utils import REGIMES, model_rows


class AnalyzerStatisticsRunnerTests(unittest.TestCase):
    def test_feedback_and_eval_regimes_have_separate_pairing_modes(self):
        self.assertEqual(
            [mode for mode, _ in REGIMES["feedback"]],
            ["feedback_functionality_matched", "feedback_both_full_pass"],
        )
        self.assertEqual(
            [mode for mode, _ in REGIMES["eval"]],
            ["functionality_matched", "both_full_pass"],
        )

    def test_regime_modes_match_slither_csv_mode_names(self):
        self.assertEqual(REGIMES["eval"][0][0], "functionality_matched")
        self.assertEqual(REGIMES["eval"][1][0], "both_full_pass")
        self.assertEqual(
            REGIMES["feedback"][0][0], "feedback_functionality_matched"
        )
        self.assertEqual(REGIMES["feedback"][1][0], "feedback_both_full_pass")

    def test_csv_rows_exclude_pooled_all_row(self):
        rows = model_rows(
            [
                {"model": "gpt-5.1", "files": 10},
                {"model": "ALL", "files": 30},
            ]
        )
        self.assertEqual(rows, [{"model": "gpt-5.1", "files": 10}])


if __name__ == "__main__":
    unittest.main()
