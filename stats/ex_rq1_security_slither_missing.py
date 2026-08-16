#!/usr/bin/env python3
"""Rescan RQ1 eval-FullPass outputs missing historical Slither results.

The scanner reconstructs the exact code used by the fixed-seed RQ1 eval
reports and analyzes it as a sibling ``.solagent_gen.sol`` source unit. It
does not update progress.db. Results are checkpointed after every sample.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Sequence, Tuple

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover
    load_dotenv = None

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from stats.rq1_eval_utils import (  # noqa: E402
    DEFAULT_EVAL_RESULT_PATHS,
    entry_eval_key,
    load_eval_results,
    select_eval_code,
)
from stats.rq1_security_slither_statistics import (  # noqa: E402
    DEFAULT_MODELS,
    GENERATED_SOURCES,
    fetch_entries,
)
from testing.eval_overlay_utils import locked_path_replacements  # noqa: E402
from testing.rq1_verify_eval_models import _gen_copy_path  # noqa: E402
from utils.slither_utils import run_slither  # noqa: E402


DEFAULT_OUTPUT = ROOT / "stats" / "slither" / f"{Path(__file__).stem}.json"
IMPACTS = ("High", "Medium", "Low")
EvalKey = Tuple[str, str, str]


def normalize_csv(value: str) -> List[str]:
    return list(dict.fromkeys(item.strip() for item in value.split(",") if item.strip()))


def write_output(path: Path, records: Sequence[Mapping[str, Any]]) -> None:
    payload = {
        "scope": "RQ1 seed1 eval FullPass files with invalid historical Slither",
        "scan_target": "exact eval-selected code in sibling .solagent_gen.sol",
        "records": list(records),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")


def parsed_result(raw: Mapping[str, Any]) -> Tuple[bool, Counter, List[Dict[str, Any]]]:
    success = raw.get("success") is True and not raw.get("error")
    detectors = (raw.get("results") or {}).get("detectors") or [] if success else []
    counts = Counter(
        detector.get("impact")
        for detector in detectors
        if isinstance(detector, dict) and detector.get("impact") in IMPACTS
    )
    findings = [
        {
            "impact": detector.get("impact"),
            "confidence": detector.get("confidence"),
            "check": detector.get("check"),
        }
        for detector in detectors
        if isinstance(detector, dict) and detector.get("impact") in IMPACTS
    ]
    return success, counts, findings


def historical_slither_valid(
    key: EvalKey, entry: Mapping[str, Any], result: Mapping[str, Any]
) -> bool:
    if key[0] == "solagent":
        try:
            by_round = json.loads(entry.get("round_vuln_count") or "{}")
        except (json.JSONDecodeError, TypeError):
            by_round = {}
        value = by_round.get(str(result.get("best_round")))
    else:
        value = entry.get("vuln_count")
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and value >= 0
        and int(value) == value
    )


def select_tasks(
    eval_results: Mapping[EvalKey, Mapping[str, Any]],
    entries: Mapping[EvalKey, Mapping[str, Any]],
) -> List[Tuple[EvalKey, Mapping[str, Any], Mapping[str, Any]]]:
    tasks = []
    for key, result in sorted(eval_results.items()):
        if not result.get("ok"):
            continue
        entry = entries.get(key)
        if entry is None:
            raise ValueError(f"Missing database row for eval result: {key}")
        if not historical_slither_valid(key, entry, result):
            tasks.append((key, entry, result))
    return tasks


def load_cached(path: Path) -> List[Dict[str, Any]]:
    if not path.is_file():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    records = data.get("records", [])
    if not isinstance(records, list):
        raise ValueError(f"Cached output has no records list: {path}")
    return records


def run_task(
    key: EvalKey,
    entry: Mapping[str, Any],
    result: Mapping[str, Any],
) -> Dict[str, Any]:
    code, code_meta = select_eval_code(dict(entry), dict(result))
    if not code:
        return {
            "source": key[0],
            "model": key[1],
            "file_path": key[2],
            "status": "error",
            "error": "eval code could not be reconstructed",
        }

    sol_abs = ROOT / key[2]
    gen_abs = _gen_copy_path(sol_abs)
    feedback_abs = ROOT / str(result["feedback_test_path"])
    with tempfile.TemporaryDirectory(prefix="rq1_slither_missing_") as temp:
        temp_dir = Path(temp)
        temp_gen = temp_dir / gen_abs.name
        temp_gen.write_text(code.rstrip() + "\n", encoding="utf-8")
        try:
            with locked_path_replacements(
                ROOT, feedback_abs, [(gen_abs, temp_gen)], temp_dir
            ):
                raw = run_slither(str(gen_abs))
        except Exception as error:  # noqa: BLE001
            raw = {"error": str(error)}

    success, counts, findings = parsed_result(raw)
    return {
        "source": key[0],
        "model": key[1],
        "file_path": key[2],
        "row_id": entry.get("id"),
        "status": "analyzed" if success else "error",
        "code_sha256": hashlib.sha256(code.encode()).hexdigest(),
        "code_bytes": len(code.encode()),
        "code_selection": code_meta,
        "counts": {impact: counts[impact] for impact in IMPACTS},
        "vuln_count": sum(counts.values()) if success else None,
        "findings": findings,
        "error": None if success else raw.get("error") or raw.get("raw_stderr") or raw,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Rescan missing RQ1 Slither results for seed1 eval FullPass code"
    )
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--env", default=".env")
    parser.add_argument("--models", default=",".join(DEFAULT_MODELS))
    parser.add_argument("--sources", default=",".join(GENERATED_SOURCES))
    parser.add_argument("--eval-files", default=",".join(DEFAULT_EVAL_RESULT_PATHS))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    args = parser.parse_args()

    if load_dotenv is not None:
        load_dotenv(args.env)
    if not os.environ.get("SLITHER_PATH"):
        print("[ERROR] SLITHER_PATH is not configured", file=sys.stderr)
        return 2

    models = normalize_csv(args.models)
    sources = normalize_csv(args.sources)
    eval_paths = [Path(item) for item in normalize_csv(args.eval_files)]
    output = Path(args.output)
    eval_results = load_eval_results(eval_paths)
    entries = {
        entry_eval_key(entry): entry
        for entry in fetch_entries(args.db, sources, models)
    }
    tasks = select_tasks(eval_results, entries)
    records = load_cached(output)
    done = {
        (record["source"], record["model"], record["file_path"])
        for record in records
    }
    print(f"tasks={len(tasks)} cached={len(done)} output={output}", flush=True)

    for index, (key, entry, result) in enumerate(tasks, 1):
        if key in done:
            print(f"[{index}/{len(tasks)}] cached {key}", flush=True)
            continue
        print(f"[{index}/{len(tasks)}] slither {key}", flush=True)
        record = run_task(key, entry, result)
        records.append(record)
        write_output(output, records)
        counts = record.get("counts") or {}
        print(
            f"  -> {record['status']} vuln={record.get('vuln_count')} "
            f"H/M/L={counts.get('High', 0)}/{counts.get('Medium', 0)}/{counts.get('Low', 0)}",
            flush=True,
        )

    analyzed = [record for record in records if record.get("status") == "analyzed"]
    errors = [record for record in records if record.get("status") != "analyzed"]
    print(
        f"done analyzed={len(analyzed)} errors={len(errors)} "
        f"vulns={sum(record['vuln_count'] for record in analyzed)}",
        flush=True,
    )
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
