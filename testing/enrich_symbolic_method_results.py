#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from testing.generate_eval_tests import DEFAULT_DATASET, _load_dataset  # noqa: E402
from testing.rq3_verify_symbolic_models import (  # noqa: E402
    DEFAULT_MANIFEST,
    REPORT_PATH,
    _attach_method_results,
    _check_method_map,
    _method_level_summary,
)
from testing.symbolic_utils import build_symbolic_summary  # noqa: E402


DEFAULT_OUTPUT = ROOT / "testing" / "symbolic" / "rq3_verify_symbolic_models_method_level.json"
DEFAULT_CSV_OUTPUT = ROOT / "testing" / "symbolic" / "rq3_verify_symbolic_models_method_level_summary.csv"


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def enrich_report(
    report_path: Path,
    manifest_path: Path,
    dataset_path: Path,
    symbolic_dir: Path,
    output_path: Path,
) -> dict[str, Any]:
    report = _load_json(report_path)
    manifest = _load_json(manifest_path)
    dataset = _load_dataset(dataset_path)
    check_method_map = _check_method_map(manifest, dataset, symbolic_dir)
    checks_by_sol: dict[str, list[str]] = {}
    for method in manifest.get("methods", []):
        check_name = str(method.get("check_name") or "")
        sol_path = str(method.get("sol_path") or "")
        if check_name and check_name in check_method_map:
            checks_by_sol.setdefault(sol_path, []).append(check_name)

    results = report.get("results") or []
    if not isinstance(results, list):
        raise ValueError("input report must contain a list field named 'results'")
    for result in results:
        if isinstance(result, dict):
            _attach_method_results(result, check_method_map, checks_by_sol)

    summary = build_symbolic_summary(results)
    summary["method_level"] = _method_level_summary(results)
    report["summary"] = summary
    report.setdefault("metadata", {})
    report["metadata"]["method_level_enriched"] = True
    report["metadata"]["method_level_mapped_unique_methods"] = len(
        {
            (
                item["sol_path"],
                item["class_name"],
                item["method_name"],
                item["full_signature"],
            )
            for item in check_method_map.values()
        }
    )
    report["metadata"]["method_level_mapped_checks"] = len(check_method_map)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return report


def write_method_summary_csv(report: dict[str, Any], csv_path: Path) -> None:
    groups = report["summary"]["method_level"]["groups"]
    statuses = sorted(
        {
            status
            for group in groups
            for status in (group.get("status_counts") or {})
        }
    )
    fieldnames = [
        "source",
        "source_name",
        "model",
        "agent_type",
        "expected_methods",
        "passed_methods",
        "failed_methods",
        "pass_rate",
        *[f"status_{status}" for status in statuses],
    ]
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for group in groups:
            row = {key: group.get(key) for key in fieldnames if not key.startswith("status_")}
            counts = group.get("status_counts") or {}
            for status in statuses:
                row[f"status_{status}"] = counts.get(status, 0)
            writer.writerow(row)


def main() -> int:
    parser = argparse.ArgumentParser(description="Add method-level symbolic results to an existing Halmos report.")
    parser.add_argument("--report", type=Path, default=REPORT_PATH, help="Existing symbolic report JSON")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST, help="symbolic_manifest.json path")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET, help="dataset.json path")
    parser.add_argument("--symbolic-dir", type=Path, help="symbolic test directory; defaults to manifest parent")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Output enriched report path")
    parser.add_argument("--csv-output", type=Path, default=DEFAULT_CSV_OUTPUT, help="Output method-level summary CSV path")
    args = parser.parse_args()

    symbolic_dir = (args.symbolic_dir or args.manifest.resolve().parent).resolve()
    enriched = enrich_report(
        args.report.resolve(),
        args.manifest.resolve(),
        args.dataset.resolve(),
        symbolic_dir,
        args.output.resolve(),
    )
    write_method_summary_csv(enriched, args.csv_output.resolve())
    global_summary = enriched["summary"]["global"]
    method_global = enriched["summary"]["method_level"]["global"]
    print(
        f"[enrich-symbolic] results={len(enriched.get('results') or [])} "
        f"expected_checks={global_summary['expected_checks']} proved_checks={global_summary['proved_checks']} "
        f"expected_methods={method_global['expected_methods']} passed_methods={method_global['passed_methods']} "
        f"failed_methods={method_global['failed_methods']}"
    )
    print(f"report={args.output}")
    print(f"csv={args.csv_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
