#!/usr/bin/env python3
"""RQ2 Aderyn statistics matched on independent eval-test outcomes."""

from rq2_security_analyzer_statistics_utils import analyzer_cli


if __name__ == "__main__":
    raise SystemExit(
        analyzer_cli(
            "aderyn",
            "eval",
            "stats/aderyn/rq2/summary.json",
            "stats/aderyn/rq2/rq2_security_aderyn_statistics_eval.csv",
        )
    )
