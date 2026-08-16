#!/usr/bin/env python3
"""Unit tests for seed1-eval RQ1 Slither statistics."""

import unittest
import hashlib

from stats.rq1_security_slither_statistics import (
    FIXED_FUZZ_SEED,
    SlitherEvalStatisticsError,
    missing_slither_count_for_code,
    slither_count_for_eval_entry,
    validate_eval_configuration,
)


class SlitherCountTests(unittest.TestCase):
    def test_solagent_uses_eval_selected_round(self):
        entry = {
            "_source": "solagent",
            "_model": "model",
            "file_path": "Foo.sol",
            "round_vuln_count": '{"1": 7, "2": 2}',
        }
        result = {"best_round": 2, "best_vuln": 2}
        self.assertEqual(slither_count_for_eval_entry(entry, result), 2)

    def test_negative_single_shot_count_is_unscanned(self):
        entry = {"_source": "rawmodel", "vuln_count": -1}
        self.assertIsNone(slither_count_for_eval_entry(entry, {}))

    def test_selected_round_mismatch_is_rejected(self):
        entry = {
            "_source": "solagent",
            "_model": "model",
            "file_path": "Foo.sol",
            "round_vuln_count": '{"2": 3}',
        }
        with self.assertRaises(SlitherEvalStatisticsError):
            slither_count_for_eval_entry(entry, {"best_round": 2, "best_vuln": 1})

    def test_missing_scan_must_match_exact_eval_code(self):
        code = "pragma solidity ^0.8.20; contract Foo {}"
        record = {
            "status": "analyzed",
            "code_sha256": hashlib.sha256(code.encode()).hexdigest(),
            "code_bytes": len(code.encode()),
            "vuln_count": 3,
        }
        key = ("rawmodel", "model", "Foo.sol")
        self.assertEqual(missing_slither_count_for_code(key, code, record), 3)

    def test_missing_scan_rejects_different_code(self):
        record = {
            "status": "analyzed",
            "code_sha256": hashlib.sha256(b"other").hexdigest(),
            "code_bytes": 5,
            "vuln_count": 0,
        }
        with self.assertRaises(SlitherEvalStatisticsError):
            missing_slither_count_for_code(
                ("rawmodel", "model", "Foo.sol"),
                "pragma solidity ^0.8.20; contract Foo {}",
                record,
            )


class EvalConfigurationTests(unittest.TestCase):
    def test_seed1_security_selected_configuration(self):
        validate_eval_configuration(
            {
                ("solagent", "model", "Foo.sol"): {
                    "fuzz_seed": FIXED_FUZZ_SEED,
                    "selection_policy": "test-first-security-second",
                },
                ("rawmodel", "model", "Foo.sol"): {
                    "fuzz_seed": FIXED_FUZZ_SEED,
                    "selection_policy": "best-pass-first",
                },
            }
        )

    def test_non_seed1_report_is_rejected(self):
        with self.assertRaises(SlitherEvalStatisticsError):
            validate_eval_configuration(
                {
                    ("rawmodel", "model", "Foo.sol"): {
                        "fuzz_seed": "0x2",
                        "selection_policy": "best-pass-first",
                    }
                }
            )


if __name__ == "__main__":
    unittest.main()
