#!/usr/bin/env python3
"""Run the fixed-seed independent eval suite for Mimo SolAgent outputs."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL = "mimo-v2.5-pro"
FUZZ_SEED = "0x" + "0" * 63 + "1"
SELECTION_POLICY = "test-first-security-second"
DEFAULT_REPORT = Path("testing/eval/mimo_solagent_verify_eval_seed1.json")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    command = [
        sys.executable,
        str(ROOT / "testing/rq1_verify_eval_models.py"),
        "--db",
        args.db,
        "--source",
        "solagent",
        "--model",
        MODEL,
        "--selection-policy",
        SELECTION_POLICY,
        "--fuzz-seed",
        FUZZ_SEED,
        "--report",
        str(args.report),
    ]
    return subprocess.call(command, cwd=ROOT)


if __name__ == "__main__":
    raise SystemExit(main())
