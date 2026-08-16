#!/usr/bin/env python3
"""Unit tests for RQ1 generated-code security statistics."""

import json
import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.code_metrics import count_loc, extract_code_from_messages
from stats.rq1_security_statistics import (
    FileSecurityRecord,
    PairwiseResult,
    SOLAGENT,
    apply_holm_correction,
    build_pairwise_results,
    exact_mcnemar_p_value,
    get_best_pass_round,
    record_from_final_row,
    record_from_round_row,
    summarize_condition,
    summarize_primary,
    wilson_interval,
)


def make_record(
    file_path: str,
    test_pass: int,
    test_total: int,
    vuln_count,
    sloc,
    method: str = "Method",
) -> FileSecurityRecord:
    return FileSecurityRecord(
        method=method,
        model="model",
        file_path=file_path,
        test_pass=test_pass,
        test_total=test_total,
        vuln_count=vuln_count,
        sloc=sloc,
    )


class MetricTests(unittest.TestCase):
    def test_primary_metric_and_missing_scan(self):
        records = [
            make_record("safe.sol", 2, 2, 0, 100),
            make_record("vulnerable.sol", 2, 2, 1, 100),
            make_record("unscanned.sol", 2, 2, None, 100),
            make_record("partial.sol", 1, 2, 0, 100),
            make_record("compile-fail.sol", 0, 0, None, None),
        ]

        summary = summarize_primary(records)
        self.assertEqual(summary.attempted, 5)
        self.assertEqual(summary.compiled, 4)
        self.assertEqual(summary.full_pass, 3)
        self.assertEqual(summary.safe_full_pass, 1)
        self.assertAlmostEqual(summary.secure_pass_rate, 0.2)
        self.assertAlmostEqual(summary.safe_given_full_pass_rate, 1 / 3)

    def test_conditional_rates_and_micro_density(self):
        records = [
            make_record("vulnerable.sol", 2, 2, 2, 100),
            make_record("safe.sol", 2, 2, 0, 100),
            make_record("missing-scan.sol", 2, 2, None, 100),
            make_record("missing-loc.sol", 2, 2, 3, None),
            make_record("partial.sol", 1, 2, 5, 200),
        ]

        full_pass = summarize_condition(records, "full_pass")
        self.assertEqual(full_pass.eligible, 4)
        self.assertEqual(full_pass.scanned, 3)
        self.assertEqual(full_pass.vulnerable_files, 2)
        self.assertAlmostEqual(full_pass.vulnerable_file_rate, 2 / 3)
        self.assertEqual(full_pass.loc_covered, 2)
        self.assertEqual(full_pass.total_vulnerabilities, 2)
        self.assertEqual(full_pass.total_sloc, 200)
        self.assertAlmostEqual(full_pass.vulnerabilities_per_kloc, 10.0)

        compiled = summarize_condition(records, "compiled")
        self.assertEqual(compiled.eligible, 5)
        self.assertEqual(compiled.total_vulnerabilities, 7)
        self.assertEqual(compiled.total_sloc, 400)
        self.assertAlmostEqual(compiled.vulnerabilities_per_kloc, 17.5)

    def test_wilson_interval_contains_observed_rate(self):
        low, high = wilson_interval(21, 81)
        self.assertLess(low, 21 / 81)
        self.assertGreater(high, 21 / 81)
        self.assertAlmostEqual(low, 0.1763, places=3)
        self.assertAlmostEqual(high, 0.3640, places=3)

    def test_invalid_final_vulnerability_is_not_safe(self):
        row = {
            "file_path": "Foo.sol",
            "test_pass": 1,
            "test_total": 1,
            "vuln_count": -1,
            "coding_messages": None,
        }
        record = record_from_final_row(row, "RawModel", "model")
        self.assertFalse(record.scan_valid)
        self.assertFalse(record.safe_full_pass)


class RoundSelectionTests(unittest.TestCase):
    def test_best_pass_tie_uses_lowest_vulnerability(self):
        tests = {
            "1": {"passed": 5, "total": 5},
            "2": {"passed": 5, "total": 5},
        }
        vulnerabilities = {"1": 4, "2": 1}
        self.assertEqual(get_best_pass_round(tests, vulnerabilities), (2, 5, 5))

    def test_best_pass_tie_uses_earliest_round_after_vulnerability_tie(self):
        tests = {
            "2": {"passed": 5, "total": 5},
            "1": {"passed": 5, "total": 5},
        }
        vulnerabilities = {"1": 1, "2": 1}
        self.assertEqual(get_best_pass_round(tests, vulnerabilities), (1, 5, 5))

    def test_valid_scan_beats_missing_scan(self):
        tests = {
            "1": {"passed": 5, "total": 5},
            "2": {"passed": 5, "total": 5},
        }
        vulnerabilities = {"1": -1, "2": 7}
        self.assertEqual(get_best_pass_round(tests, vulnerabilities), (2, 5, 5))

    def test_more_passed_tests_beat_lower_vulnerability(self):
        tests = {
            "1": {"passed": 5, "total": 5},
            "2": {"passed": 4, "total": 4},
        }
        vulnerabilities = {"1": 9, "2": 0}
        self.assertEqual(get_best_pass_round(tests, vulnerabilities), (1, 5, 5))

    def test_different_total_is_not_a_security_tie(self):
        tests = {
            "1": {"passed": 5, "total": 6},
            "2": {"passed": 5, "total": 5},
        }
        vulnerabilities = {"1": 9, "2": 0}
        self.assertEqual(get_best_pass_round(tests, vulnerabilities), (1, 5, 6))

    def test_round_record_aligns_tests_vulnerability_and_loc(self):
        first_code = "pragma solidity ^0.8.20;\nlibrary Foo {}"
        second_code = "pragma solidity ^0.8.20;\nlibrary Foo {\nfunction f() internal {}\n}"
        row = {
            "file_path": "Foo.sol",
            "test_json": json.dumps(
                {
                    "1": {"passed": 5, "total": 5},
                    "2": {"passed": 5, "total": 5},
                }
            ),
            "round_vuln_count": json.dumps({"1": 9, "2": 0}),
            "round_messages": json.dumps(
                {
                    "1": [
                        {
                            "role": "assistant",
                            "content": f"```solidity:Foo.sol\n{first_code}\n```",
                        }
                    ],
                    "2": [
                        {
                            "role": "assistant",
                            "content": f"```solidity:Foo.sol\n{second_code}\n```",
                        }
                    ],
                }
            ),
        }

        record = record_from_round_row(row, SOLAGENT, "model")
        self.assertEqual(record.test_pass, 5)
        self.assertEqual(record.test_total, 5)
        self.assertEqual(record.vuln_count, 0)
        self.assertEqual(record.sloc, count_loc(second_code))

    def test_missing_vulnerability_at_selected_round_stays_missing(self):
        row = {
            "file_path": "Foo.sol",
            "test_json": json.dumps({"1": {"passed": 1, "total": 1}}),
            "round_vuln_count": json.dumps({"2": 0}),
            "round_messages": json.dumps({}),
        }
        record = record_from_round_row(row, SOLAGENT, "model")
        self.assertIsNone(record.vuln_count)
        self.assertFalse(record.safe_full_pass)


class CodeExtractionTests(unittest.TestCase):
    CODE = "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\nlibrary Foo {}"

    def test_standard_code_block(self):
        messages = [
            {
                "role": "assistant",
                "content": f"```solidity:Foo.sol\n{self.CODE}\n```",
            }
        ]
        self.assertEqual(extract_code_from_messages(messages, "Foo.sol"), self.CODE)

    def test_metagpt_json_response(self):
        payload = [
            {
                "command_name": "RoleZero.reply_to_human",
                "args": {"content": f"```solidity: Foo.sol\n{self.CODE}\n```"},
            }
        ]
        messages = [
            {
                "role": "assistant",
                "content": f"```json\n{json.dumps(payload)}\n```",
            }
        ]
        self.assertEqual(
            extract_code_from_messages(messages, "Foo.sol", agent_type="metagpt"),
            self.CODE,
        )

    def test_deepcode_write_file_tool_call(self):
        messages = [
            {
                "role": "assistant",
                "content": "Implementation completed.",
                "tool_calls": [
                    {
                        "name": "write_file",
                        "input": {"file_path": "Foo.sol", "content": self.CODE},
                    }
                ],
            }
        ]
        self.assertEqual(
            extract_code_from_messages(messages, "Foo.sol", agent_type="deepcode"),
            self.CODE,
        )


class PairwiseTests(unittest.TestCase):
    def test_exact_mcnemar(self):
        self.assertAlmostEqual(exact_mcnemar_p_value(10, 0), 0.001953125)
        self.assertEqual(exact_mcnemar_p_value(0, 0), 1.0)

    def test_holm_correction(self):
        results = [
            PairwiseResult("m", "a", 10, 1, 0, 1, 10.0, 0.01),
            PairwiseResult("m", "b", 10, 1, 0, 1, 10.0, 0.04),
            PairwiseResult("m", "c", 10, 1, 0, 1, 10.0, 0.20),
        ]
        apply_holm_correction(results)
        self.assertAlmostEqual(results[0].adjusted_p_value, 0.03)
        self.assertAlmostEqual(results[1].adjusted_p_value, 0.08)
        self.assertAlmostEqual(results[2].adjusted_p_value, 0.20)

    def test_pairing_uses_common_file_paths_and_skips_missing_groups(self):
        solagent = [
            make_record("a.sol", 1, 1, 0, 10, method=SOLAGENT),
            make_record("b.sol", 1, 1, 0, 10, method=SOLAGENT),
        ]
        baseline = [
            make_record("a.sol", 1, 1, 1, 10, method="RawModel"),
            make_record("c.sol", 1, 1, 0, 10, method="RawModel"),
        ]
        groups = {
            (SOLAGENT, "model"): solagent,
            ("RawModel", "model"): baseline,
        }
        results = build_pairwise_results(
            groups, ["model"], ["RawModel", "MissingMethod"]
        )
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].common_files, 1)
        self.assertEqual(results[0].solagent_only, 1)
        self.assertEqual(results[0].baseline_only, 0)


if __name__ == "__main__":
    unittest.main()
