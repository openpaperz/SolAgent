#!/usr/bin/env python3

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from stats.rq1_eval_utils import eval_compiled, eval_test_fields, load_eval_results
from stats.rq1_security_aderyn_statistics import analyze, build_paper_table, load_groups
from utils.aderyn_utils import (
    count_vulnerabilities,
    get_sloc,
    get_vulnerability_summary,
    resolve_aderyn_bin,
)


class AderynUtilsTests(unittest.TestCase):
    def test_resolves_cli_then_environment_then_path_default(self):
        with patch.dict(os.environ, {"ADERYN_BIN": "/env/aderyn"}):
            self.assertEqual(resolve_aderyn_bin(), "/env/aderyn")
            self.assertEqual(resolve_aderyn_bin("/cli/aderyn"), "/cli/aderyn")

        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(resolve_aderyn_bin(), "aderyn")

    def test_counts_high_and_low_issue_groups(self):
        raw = {
            "report": {
                "issue_count": {"high": 2, "low": 3},
                "files_summary": {"total_sloc": 120},
            }
        }
        self.assertEqual(count_vulnerabilities(raw), 5)
        self.assertEqual(get_vulnerability_summary(raw), {"High": 2, "Low": 3})
        self.assertEqual(get_sloc(raw), 120)


class EvalResultTests(unittest.TestCase):
    def test_eval_test_fields_use_eval_compilation_and_full_pass(self):
        full_pass = {
            "source": "rawmodel",
            "model": "gpt-5.1",
            "sol_path": "A.sol",
            "expected_tests": 2,
            "passed": 2,
            "forge_total": 2,
            "ok": True,
        }
        self.assertTrue(eval_compiled(full_pass))
        self.assertEqual(
            eval_test_fields(full_pass),
            {"test_pass": 2, "test_fail": 0, "test_total": 2},
        )

        compile_error = {
            **full_pass,
            "passed": 0,
            "forge_total": 0,
            "ok": False,
            "compile_error": "failed",
        }
        self.assertFalse(eval_compiled(compile_error))
        self.assertEqual(
            eval_test_fields(compile_error),
            {"test_pass": 0, "test_fail": 0, "test_total": 0},
        )

    def test_eval_loader_maps_agent_type_to_method_source(self):
        data = {
            "results": [
                {
                    "source": "agent",
                    "agent_type": "metagpt",
                    "model": "gpt-5.1",
                    "sol_path": "A.sol",
                }
            ]
        }
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "eval.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            results = load_eval_results([path])
        self.assertIn(("metagpt", "gpt-5.1", "A.sol"), results)


class AderynStatisticsTests(unittest.TestCase):
    def test_invalid_scan_is_not_safe(self):
        data = {
            "records": [
                {
                    "source": "solagent",
                    "model": "gpt-5.1",
                    "file_path": "safe.sol",
                    "status": "analyzed",
                    "test_pass": 1,
                    "test_total": 1,
                    "aderyn_count": 0,
                    "aderyn_sloc": 10,
                },
                {
                    "source": "solagent",
                    "model": "gpt-5.1",
                    "file_path": "error.sol",
                    "status": "error",
                    "test_pass": 1,
                    "test_total": 1,
                    "aderyn_count": None,
                    "aderyn_sloc": None,
                },
            ]
        }
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "summary.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            groups = load_groups(path)

        result = analyze(groups, ["gpt-5.1"])
        primary = result["primary"][0]
        self.assertEqual(primary["full_pass"], 2)
        self.assertEqual(primary["safe_full_pass"], 1)
        self.assertEqual(primary["secure_pass_at_1"], 0.5)
        self.assertEqual(primary["safe_at_full_pass"], 0.5)
        main_row = result["main_table"][0]
        self.assertEqual(main_row["compiled_findings_per_kloc"], 0.0)
        self.assertEqual(main_row["full_pass_findings_per_kloc"], 0.0)

    def test_advantage_and_pairwise_use_safe_full_pass(self):
        data = {
            "records": [
                {
                    "source": "solagent",
                    "model": "gpt-5.1",
                    "file_path": "a.sol",
                    "status": "analyzed",
                    "test_pass": 1,
                    "test_total": 1,
                    "aderyn_count": 0,
                    "aderyn_sloc": 10,
                },
                {
                    "source": "solagent",
                    "model": "gpt-5.1",
                    "file_path": "b.sol",
                    "status": "analyzed",
                    "test_pass": 1,
                    "test_total": 1,
                    "aderyn_count": 0,
                    "aderyn_sloc": 10,
                },
                {
                    "source": "rawmodel",
                    "model": "gpt-5.1",
                    "file_path": "a.sol",
                    "status": "analyzed",
                    "test_pass": 1,
                    "test_total": 1,
                    "aderyn_count": 1,
                    "aderyn_sloc": 10,
                },
                {
                    "source": "rawmodel",
                    "model": "gpt-5.1",
                    "file_path": "b.sol",
                    "status": "analyzed",
                    "test_pass": 1,
                    "test_total": 1,
                    "aderyn_count": 0,
                    "aderyn_sloc": 10,
                },
            ]
        }
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "summary.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            groups = load_groups(path)

        result = analyze(groups, ["gpt-5.1"])
        advantage = result["solagent_advantage_vs_best_baseline"][0]
        paired = result["paired_solagent_vs_baselines"][0]
        self.assertEqual(advantage["absolute_safe_full_pass_gain"], 1)
        self.assertEqual(advantage["secure_pass_gain_percentage_points"], 50.0)
        self.assertEqual(paired["solagent_only"], 1)
        self.assertEqual(paired["baseline_only"], 0)
        paper = build_paper_table(result, groups, ["gpt-5.1"])
        self.assertEqual([row["method"] for row in paper], ["SolAgent", "RawModel"])
        self.assertEqual(
            paper[1]["baseline_solagent_findings_with_n"],
            "1/0 (n=2)",
        )
        self.assertEqual(
            paper[1]["baseline_solagent_findings_per_kloc"], "50.00/0.00"
        )
        self.assertEqual(paper[1]["solagent_finding_count_reduction"], 1.0)


if __name__ == "__main__":
    unittest.main()
