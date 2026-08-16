#!/usr/bin/env python3
"""Tests for the RQ2 cross-analyzer comparison rules."""

import unittest

from stats.rq2_security_cross_analyzer_statistics import (
    ExpectedSample,
    ScanRecord,
    _eligible_pairs,
    _main_row,
    analyzer_ranking,
    coverage_issue_rows,
    sample_key,
    slither_records,
)


def scan_record(
    source: str,
    model: str,
    file_path: str,
    *,
    status: str = "analyzed",
    findings: int | None = 0,
    passed: int = 1,
    total: int = 1,
    full_pass: bool = True,
    eval_compiled: bool = True,
    feedback_passed: int = 1,
    feedback_total: int = 1,
    feedback_compiled: bool = True,
) -> ScanRecord:
    return ScanRecord(
        analyzer="aderyn",
        source=source,
        model=model,
        file_path=file_path,
        best_round=1,
        code_sha256=f"{source}-{model}-{file_path}",
        sloc=100,
        eval_compiled=eval_compiled,
        eval_full_pass=full_pass,
        passed=passed,
        total=total,
        feedback_compiled=feedback_compiled,
        feedback_full_pass=(feedback_compiled and feedback_passed == feedback_total),
        feedback_passed=feedback_passed,
        feedback_total=feedback_total,
        status=status,
        finding_count=findings,
        finding_summary={"High": findings or 0},
    )


class MainTableTests(unittest.TestCase):
    def test_partial_zero_findings_is_observed_but_never_safe(self):
        record = scan_record(
            "full",
            "gpt-5.1",
            "A.sol",
            status="partial",
            findings=0,
        )
        records = {sample_key("full", "gpt-5.1", "A.sol"): record}

        row = _main_row("aderyn", "full", "gpt-5.1", records)

        self.assertEqual(row["compiled_observed"], 1)
        self.assertEqual(row["compiled_complete"], 0)
        self.assertEqual(row["compiled_partial"], 1)
        self.assertEqual(row["safe_full_pass"], 0)
        self.assertEqual(row["safe_at_full_pass"], 0.0)


class PairingTests(unittest.TestCase):
    def test_pooled_pairing_keeps_same_path_from_each_model(self):
        records = {}
        for model in ("gpt-5-mini", "gpt-5.1"):
            for source in ("full", "no_slither"):
                record = scan_record(source, model, "A.sol")
                records[sample_key(source, model, "A.sol")] = record

        pairs = _eligible_pairs(records, None, "functionality_matched")

        self.assertEqual(len(pairs), 2)

    def test_strict_pairing_excludes_partial_and_mismatched_tests(self):
        full = scan_record("full", "gpt-5.1", "A.sol", passed=2, total=3)
        partial = scan_record(
            "no_slither",
            "gpt-5.1",
            "A.sol",
            status="partial",
            findings=1,
            passed=2,
            total=3,
        )
        records = {
            sample_key("full", "gpt-5.1", "A.sol"): full,
            sample_key("no_slither", "gpt-5.1", "A.sol"): partial,
        }
        self.assertEqual(
            _eligible_pairs(records, "gpt-5.1", "functionality_matched"), []
        )

    def test_feedback_pairing_includes_feedback_compiled_eval_failure(self):
        records = {}
        for source in ("full", "no_slither"):
            record = scan_record(
                source,
                "gpt-5.1",
                "A.sol",
                eval_compiled=False,
                full_pass=False,
                feedback_passed=2,
                feedback_total=3,
            )
            records[sample_key(source, "gpt-5.1", "A.sol")] = record

        self.assertEqual(
            len(
                _eligible_pairs(
                    records,
                    "gpt-5.1",
                    "feedback_functionality_matched",
                )
            ),
            1,
        )
        self.assertEqual(
            _eligible_pairs(records, "gpt-5.1", "functionality_matched"), []
        )

        complete = scan_record(
            "no_slither",
            "gpt-5.1",
            "A.sol",
            findings=1,
            passed=1,
            total=3,
            full_pass=False,
        )
        records[sample_key("no_slither", "gpt-5.1", "A.sol")] = complete
        self.assertEqual(
            _eligible_pairs(records, "gpt-5.1", "functionality_matched"), []
        )


class CoverageTests(unittest.TestCase):
    def test_missing_slither_scan_is_reported_as_coverage_issue(self):
        key = sample_key("full", "gpt-5-mini", "A.sol")
        expected = {
            key: ExpectedSample(
                source="full",
                model="gpt-5-mini",
                file_path="A.sol",
                row_id=7,
                best_round=1,
                code_sha256="sha",
                code_sloc=100,
                eval_compiled=True,
                eval_full_pass=True,
                passed=1,
                total=1,
                feedback_compiled=True,
                feedback_full_pass=True,
                feedback_passed=1,
                feedback_total=1,
                slither_count=None,
                slither_summary=None,
            )
        }
        analyzers = {"slither": slither_records(expected)}

        rows = coverage_issue_rows(expected, analyzers)

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["row_id"], 7)
        self.assertEqual(rows[0]["status"], "error")
        self.assertIsNone(rows[0]["observed_findings"])


class RankingTests(unittest.TestCase):
    def test_supportive_direction_ranks_ahead_of_smaller_opposing_p_value(self):
        functionality_rows = [
            {
                "analyzer": "aderyn",
                "analyzer_name": "Aderyn",
                "model": "ALL",
                "files": 10,
                "full_findings": 10,
                "no_slither_findings": 12,
                "finding_reduction": 2 / 12,
                "full_lower": 4,
                "equal": 5,
                "full_higher": 1,
                "p_value": 0.3,
                "holm_p_across_analyzers": 0.9,
            },
            {
                "analyzer": "wake",
                "analyzer_name": "Wake (Low+)",
                "model": "ALL",
                "files": 10,
                "full_findings": 4,
                "no_slither_findings": 5,
                "finding_reduction": 0.2,
                "full_lower": 2,
                "equal": 7,
                "full_higher": 1,
                "p_value": 1.0,
                "holm_p_across_analyzers": 1.0,
            },
            {
                "analyzer": "semgrep",
                "analyzer_name": "Semgrep + Decurity",
                "model": "ALL",
                "files": 10,
                "full_findings": 8,
                "no_slither_findings": 4,
                "finding_reduction": -1.0,
                "full_lower": 0,
                "equal": 6,
                "full_higher": 4,
                "p_value": 0.01,
                "holm_p_across_analyzers": 0.03,
            },
        ]
        main_rows = [
            {
                "analyzer": analyzer,
                "compiled": 10,
                "compiled_complete": 10,
            }
            for analyzer in ("aderyn", "wake", "semgrep")
        ]

        rows = analyzer_ranking(functionality_rows, main_rows)

        self.assertEqual(
            [row["analyzer"] for row in rows], ["aderyn", "wake", "semgrep"]
        )
        self.assertEqual([row["supports_full"] for row in rows], [True, True, False])


if __name__ == "__main__":
    unittest.main()
