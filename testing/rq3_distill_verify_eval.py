#!/usr/bin/env python3
"""Run seed-1 independent eval tests for the distillation held-out split."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODELS = [
    "Qwen/Qwen3-8B",
    "Qwen/Qwen3-32B",
    "solagent-4k-tracker-v1",
    "solagent-4k-tracker-v2",
]
TRAINING_SET = ROOT / "z0train/train_files/solagent-4k-tracker-v1.json"
DATASET = ROOT / "data/dataset.json"
REPORT = Path("testing/eval/rq3_distill_verify_eval_seed1.json")
FUZZ_SEED = "0x" + "0" * 63 + "1"


def held_out_paths() -> list[str]:
    training = set(json.loads(TRAINING_SET.read_text(encoding="utf-8")))
    dataset = json.loads(DATASET.read_text(encoding="utf-8"))
    return [path for path in dataset if path not in training]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--report", type=Path, default=REPORT)
    args = parser.parse_args()
    paths = held_out_paths()
    if len(paths) != 17:
        print(f"[error] expected 17 held-out files, got {len(paths)}", file=sys.stderr)
        return 2
    command = [
        sys.executable,
        str(ROOT / "testing/rq1_verify_eval_models.py"),
        "--db",
        args.db,
        "--source",
        "solagent",
        "--model",
        ",".join(MODELS),
        "--sol",
        ",".join(paths),
        "--selection-policy",
        "test-first-security-second",
        "--fuzz-seed",
        FUZZ_SEED,
        "--report",
        str(args.report),
    ]
    return subprocess.call(command, cwd=ROOT)


if __name__ == "__main__":
    raise SystemExit(main())
