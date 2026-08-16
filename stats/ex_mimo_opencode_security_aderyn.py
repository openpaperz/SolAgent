#!/usr/bin/env python3
"""Run Aderyn on eval-FullPass Mimo SolAgent and OpenCode outputs.

This scanner is intentionally separate from the statistics script so scans can
be run on the machine that has Aderyn installed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.ex_rq1_security_mythril import (  # noqa: E402
    nearest_project_root,
    temporary_generated_file,
)
from stats.mimo_opencode_utils import (  # noqa: E402
    DEFAULT_ARTIFACT_DIR,
    DEFAULT_DB,
    DEFAULT_OPENCODE_EVAL,
    DEFAULT_SOLAGENT_EVAL,
    METHODS,
    MimoComparisonError,
    SecuritySample,
    load_security_samples,
)
from utils.aderyn_utils import (  # noqa: E402
    DEFAULT_ADERYN_TIMEOUT,
    count_vulnerabilities,
    get_sloc,
    get_vulnerability_summary,
    resolve_aderyn_bin,
    run_aderyn,
)


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT_DIR = Path("stats/aderyn/mimo_opencode")


def slug(value: str) -> str:
    return value.replace("/", "__")


def output_path(out_dir: Path, sample: SecuritySample) -> Path:
    return out_dir / sample.method.lower() / f"{slug(sample.file_path)}.json"


def code_hash(code: str | None) -> str | None:
    return hashlib.sha256(code.encode("utf-8")).hexdigest() if code else None


def scan_sample(
    sample: SecuritySample,
    aderyn_bin: str,
    timeout: int,
) -> dict[str, Any]:
    record: dict[str, Any] = {
        "model": sample.model,
        "method": sample.method,
        "file_path": sample.file_path,
        "eval_full_pass": sample.eval_full_pass,
        "code_sha256": code_hash(sample.code),
        "status": "pending",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    if not sample.eval_full_pass:
        record.update(status="skipped", skip_reason="not eval FullPass")
        return record
    if not sample.code:
        record.update(status="skipped", skip_reason="selected code unavailable")
        return record

    target = ROOT / sample.file_path
    if not target.is_file():
        record.update(status="error", error=f"Target file not found: {target}")
        return record
    project_root = nearest_project_root(target)
    try:
        with temporary_generated_file(target, sample.code):
            raw = run_aderyn(
                str(target),
                project_root=str(project_root),
                aderyn_bin=aderyn_bin,
                timeout=timeout,
            )
    except Exception as error:  # pragma: no cover - external tool boundary
        raw = {"error": f"Unexpected Aderyn runner failure: {error}"}
    if raw.get("error"):
        record.update(status="error", error=raw["error"], aderyn_raw=raw)
    else:
        record.update(
            status="analyzed",
            finding_count=count_vulnerabilities(raw),
            finding_summary=get_vulnerability_summary(raw),
            sloc=get_sloc(raw),
            aderyn_raw=raw,
        )
    return record


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--artifact-dir", type=Path, default=DEFAULT_ARTIFACT_DIR)
    parser.add_argument("--solagent-report", type=Path, default=DEFAULT_SOLAGENT_EVAL)
    parser.add_argument("--opencode-report", type=Path, default=DEFAULT_OPENCODE_EVAL)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--aderyn-bin")
    parser.add_argument("--timeout", type=int, default=DEFAULT_ADERYN_TIMEOUT)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    try:
        groups = load_security_samples(
            args.db,
            args.artifact_dir,
            args.solagent_report,
            args.opencode_report,
        )
        aderyn_bin = resolve_aderyn_bin(args.aderyn_bin)
        records: list[dict[str, Any]] = []
        total = sum(len(groups[method]) for method in METHODS)
        ordinal = 0
        for method in METHODS:
            for sample in groups[method].values():
                ordinal += 1
                path = output_path(args.out_dir, sample)
                if args.resume and path.is_file():
                    cached = json.loads(path.read_text(encoding="utf-8"))
                    if cached.get("code_sha256") == code_hash(sample.code):
                        records.append(cached)
                        print(f"[{ordinal}/{total}] cached {method} {sample.file_path}", flush=True)
                        continue
                print(f"[{ordinal}/{total}] {method} {sample.file_path}", flush=True)
                record = scan_sample(sample, aderyn_bin, args.timeout)
                write_json(path, record)
                records.append(record)
        summary = {
            "created_at": datetime.now(timezone.utc).isoformat(),
            "analyzer": "Aderyn",
            "aderyn_bin": aderyn_bin,
            "scope": "independent-eval FullPass",
            "records": records,
        }
        write_json(args.out_dir / "summary.json", summary)
        print(f"Wrote: {args.out_dir / 'summary.json'}")
        return 0
    except (OSError, json.JSONDecodeError, MimoComparisonError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
