#!/usr/bin/env python3
"""Unit tests for the RQ1 selected-candidate round statistics."""

import json
import os
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.rq1_selected_round_statistics import (
    SelectedRoundStatisticsError,
    build_distributions,
    collect_selected_rounds,
    linear_percentile,
    summarize_rounds,
)


class PercentileTests(unittest.TestCase):
    def test_linear_percentile_interpolates_between_adjacent_values(self):
        self.assertAlmostEqual(linear_percentile([1, 2, 3, 4], 0.9), 3.7)

    def test_linear_percentile_rejects_empty_input(self):
        with self.assertRaises(ValueError):
            linear_percentile([], 0.9)


class DistributionTests(unittest.TestCase):
    def test_summarize_rounds(self):
        summary = summarize_rounds("model-a", [1, 2, 2, 5])
        self.assertEqual(summary.count, 4)
        self.assertAlmostEqual(summary.mean, 2.5)
        self.assertAlmostEqual(summary.median, 2.0)
        self.assertAlmostEqual(summary.p90, 4.1)
        self.assertEqual(summary.maximum, 5)

    def test_all_models_uses_the_pooled_rounds(self):
        summaries = build_distributions(
            {"model-a": [1, 2], "model-b": [10]},
            ["model-a", "model-b"],
        )
        pooled = summaries[-1]
        self.assertEqual(pooled.model, "all")
        self.assertEqual(pooled.count, 3)
        self.assertAlmostEqual(pooled.mean, 13 / 3)
        self.assertAlmostEqual(pooled.median, 2.0)
        self.assertAlmostEqual(pooled.p90, 8.4)
        self.assertEqual(pooled.maximum, 10)

    def test_empty_model_group_is_rejected(self):
        with self.assertRaises(SelectedRoundStatisticsError):
            build_distributions({"model-a": []}, ["model-a"])


class DatabaseCollectionTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "progress.db"
        connection = sqlite3.connect(self.db_path)
        connection.execute(
            """
            CREATE TABLE process_tracking (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                model_coding TEXT,
                status INTEGER,
                test_json TEXT,
                round_vuln_count TEXT
            )
            """
        )
        self.connection = connection

    def tearDown(self):
        self.connection.close()
        self.temp_dir.cleanup()

    def insert_row(self, model, status, tests, vulnerabilities=None):
        self.connection.execute(
            """
            INSERT INTO process_tracking (
                model_coding, status, test_json, round_vuln_count
            ) VALUES (?, ?, ?, ?)
            """,
            (
                model,
                status,
                json.dumps(tests) if tests is not None else None,
                json.dumps(vulnerabilities) if vulnerabilities is not None else None,
            ),
        )
        self.connection.commit()

    def test_collects_selected_rounds_and_excludes_ineligible_rows(self):
        self.insert_row(
            "model-a",
            1,
            {
                "1": {"passed": 4, "total": 4},
                "2": {"passed": 4, "total": 4},
            },
            {"1": 3, "2": 0},
        )
        self.insert_row("model-a", 1, None)
        self.insert_row(
            "model-a",
            1,
            {"7": {"passed": 0, "total": 0}},
        )
        self.insert_row(
            "model-a",
            0,
            {"9": {"passed": 1, "total": 1}},
        )
        self.insert_row(
            "model-b",
            2,
            {"3": {"passed": 1, "total": 2}},
        )

        result = collect_selected_rounds(self.db_path, ["model-a", "model-b"])

        self.assertEqual(result["model-a"], [2])
        self.assertEqual(result["model-b"], [3])


if __name__ == "__main__":
    unittest.main()
