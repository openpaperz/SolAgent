#!/usr/bin/env python3
"""RQ2 Aderyn cross-validation for Full vs. no-Slither feedback."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from stats.rq2_slither_feedback_statistics import (  # noqa: E402
    TARGET_MODELS,
    PairedResult,
    SelectedRound,
    StatisticsError,
    compare_pairs,
    connect_read_only,
    exact_sign_test_p_value,
    load_group,
    print_table,
    validate_tables,
    with_adjusted_p_values,
)


VARIANT_LABELS = {
    "full": "Full",
    "no_slither": "w/o Slither feedback",
}
ADERYN_IMPACT_LEVELS = ("High", "Low")
ADERYN_SELECTION_POLICY = "test-first-security-second"


@dataclass(frozen=True)
class AderynSelectedRound:
    file_path: str
    round_index: Optional[int]
    passed: int
    total: int
    vuln_count: Optional[int]
    severity: Optional[Mapping[str, int]]
    sloc: Optional[int]
    status: str

    @property
    def compiled(self) -> bool:
        return self.total > 0

    @property
    def full_pass(self) -> bool:
        return self.compiled and self.passed == self.total

    @property
    def scan_valid(self) -> bool:
        return self.status == "analyzed" and self.vuln_count is not None

    @property
    def safe_full_pass(self) -> bool:
        return self.full_pass and self.scan_valid and self.vuln_count == 0


DatabaseGroups = Mapping[
    str,
    Tuple[Mapping[str, SelectedRound], Mapping[str, SelectedRound]],
]
AderynGroups = Dict[
    str,
    Tuple[Dict[str, AderynSelectedRound], Dict[str, AderynSelectedRound]],
]


def nonnegative_int(value: Any) -> Optional[int]:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    parsed = int(value)
    return parsed if parsed >= 0 and parsed == value else None


def _severity(value: Any, status: str) -> Optional[Mapping[str, int]]:
    if status != "analyzed":
        return None
    raw = value if isinstance(value, dict) else {}
    result: Dict[str, int] = {}
    for impact in ADERYN_IMPACT_LEVELS:
        count = nonnegative_int(raw.get(impact, 0))
        if count is None:
            raise StatisticsError(f"Invalid Aderyn {impact} count: {raw.get(impact)!r}")
        result[impact] = count
    return result


def _record_from_json(item: Mapping[str, Any]) -> AderynSelectedRound:
    status = str(item.get("status") or "")
    if status not in {"analyzed", "error", "skipped"}:
        raise StatisticsError(
            f"Invalid Aderyn status for {item.get('file_path')}: {status!r}"
        )
    count = nonnegative_int(item.get("aderyn_count")) if status == "analyzed" else None
    if status == "analyzed" and count is None:
        raise StatisticsError(
            f"Analyzed Aderyn record has no valid count: {item.get('file_path')}"
        )
    sloc = nonnegative_int(item.get("aderyn_sloc")) if status == "analyzed" else None
    if sloc == 0:
        sloc = None
    return AderynSelectedRound(
        file_path=str(item.get("file_path") or ""),
        round_index=nonnegative_int(item.get("best_round")),
        passed=int(item.get("test_pass") or 0),
        total=int(item.get("test_total") or 0),
        vuln_count=count,
        severity=_severity(item.get("aderyn_summary"), status),
        sloc=sloc,
        status=status,
    )


def load_aderyn_groups(
    summary_path: Path,
    database_groups: DatabaseGroups,
) -> AderynGroups:
    try:
        payload = json.loads(summary_path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise StatisticsError(f"Aderyn summary not found: {summary_path}") from error
    except json.JSONDecodeError as error:
        raise StatisticsError(f"Invalid Aderyn summary JSON: {error}") from error

    if payload.get("selection_policy") != ADERYN_SELECTION_POLICY:
        raise StatisticsError(
            "Aderyn selection policy mismatch: "
            f"{payload.get('selection_policy')!r}, expected {ADERYN_SELECTION_POLICY!r}"
        )

    by_model_source: Dict[Tuple[str, str], Dict[str, AderynSelectedRound]] = {}
    raw_by_model_source: Dict[Tuple[str, str, str], Mapping[str, Any]] = {}
    for item in payload.get("records") or []:
        if not isinstance(item, dict):
            raise StatisticsError("Aderyn summary contains a non-object record")
        source = str(item.get("source") or "")
        model = str(item.get("model") or "")
        file_path = str(item.get("file_path") or "")
        if source not in VARIANT_LABELS or model not in database_groups:
            continue
        if not file_path:
            raise StatisticsError(f"Aderyn record has no file_path: {item}")
        key = (model, source)
        group = by_model_source.setdefault(key, {})
        if file_path in group:
            raise StatisticsError(
                f"Duplicate Aderyn record: {model}/{source}/{file_path}"
            )
        group[file_path] = _record_from_json(item)
        raw_by_model_source[(model, source, file_path)] = item

    result: AderynGroups = {}
    for model, (db_full, db_no_slither) in database_groups.items():
        loaded_variants: List[Dict[str, AderynSelectedRound]] = []
        for source, expected in (
            ("full", db_full),
            ("no_slither", db_no_slither),
        ):
            loaded = by_model_source.get((model, source), {})
            missing = sorted(set(expected) - set(loaded))
            extra = sorted(set(loaded) - set(expected))
            if missing or extra:
                raise StatisticsError(
                    f"Aderyn coverage mismatch for {model}/{source}: "
                    f"missing={len(missing)}, extra={len(extra)}"
                )
            for file_path, selected in expected.items():
                scanned = loaded[file_path]
                raw = raw_by_model_source[(model, source, file_path)]
                if scanned.round_index != selected.round_index:
                    raise StatisticsError(
                        f"Aderyn checkpoint mismatch for {model}/{source}/{file_path}: "
                        f"summary={scanned.round_index}, "
                        f"database={selected.round_index}"
                    )
                if raw.get("slither_count") != selected.vuln_count:
                    raise StatisticsError(
                        f"Aderyn summary Slither tie-break mismatch for "
                        f"{model}/{source}/{file_path}: "
                        f"summary={raw.get('slither_count')}, "
                        f"database={selected.vuln_count}"
                    )
                if scanned.compiled and not raw.get("code_sha256"):
                    raise StatisticsError(
                        f"Compiled Aderyn record has no code SHA: "
                        f"{model}/{source}/{file_path}"
                    )
            loaded_variants.append(loaded)
        result[model] = (loaded_variants[0], loaded_variants[1])
    return result


def _findings_per_kloc(
    findings: int, records: Sequence[AderynSelectedRound]
) -> Optional[float]:
    if not records or any(record.sloc is None for record in records):
        return None
    sloc = sum(int(record.sloc) for record in records if record.sloc is not None)
    return findings / (sloc / 1000.0) if sloc else None


def _overall_row(
    source: str,
    model: str,
    records: Mapping[str, AderynSelectedRound],
) -> Dict[str, Any]:
    values = list(records.values())
    compiled = [record for record in values if record.compiled]
    scanned = [record for record in compiled if record.scan_valid]
    full_pass = [record for record in compiled if record.full_pass]
    full_pass_scanned = [record for record in full_pass if record.scan_valid]
    safe_full_pass = [record for record in full_pass if record.safe_full_pass]
    compiled_findings = sum(
        int(record.vuln_count) for record in scanned if record.vuln_count is not None
    )
    compiled_sloc_complete = bool(scanned) and all(
        record.sloc is not None for record in scanned
    )
    compiled_sloc = (
        sum(int(record.sloc) for record in scanned if record.sloc is not None)
        if compiled_sloc_complete
        else None
    )
    full_pass_findings = sum(
        int(record.vuln_count)
        for record in full_pass_scanned
        if record.vuln_count is not None
    )
    full_pass_sloc_complete = bool(full_pass_scanned) and all(
        record.sloc is not None for record in full_pass_scanned
    )
    full_pass_sloc = (
        sum(int(record.sloc) for record in full_pass_scanned if record.sloc is not None)
        if full_pass_sloc_complete
        else None
    )
    return {
        "variant": source,
        "variant_name": VARIANT_LABELS[source],
        "model": model,
        "attempted": len(values),
        "compiled": len(compiled),
        "compilation_rate": len(compiled) / len(values) if values else 0.0,
        "full_pass": len(full_pass),
        "full_pass_rate": len(full_pass) / len(values) if values else 0.0,
        "compiled_scanned": len(scanned),
        "compiled_scan_coverage": len(scanned) / len(compiled) if compiled else None,
        "compiled_scan_errors": sum(record.status == "error" for record in compiled),
        "compiled_findings": compiled_findings,
        "compiled_sloc": compiled_sloc,
        "compiled_findings_per_kloc": (
            compiled_findings / (compiled_sloc / 1000.0)
            if isinstance(compiled_sloc, int) and compiled_sloc
            else None
        ),
        "full_pass_scanned": len(full_pass_scanned),
        "full_pass_scan_coverage": (
            len(full_pass_scanned) / len(full_pass) if full_pass else None
        ),
        "full_pass_scan_errors": sum(record.status == "error" for record in full_pass),
        "full_pass_findings": full_pass_findings,
        "full_pass_sloc": full_pass_sloc,
        "full_pass_findings_per_kloc": (
            full_pass_findings / (full_pass_sloc / 1000.0)
            if isinstance(full_pass_sloc, int) and full_pass_sloc
            else None
        ),
        "safe_full_pass": len(safe_full_pass),
        "secure_pass_at_1": len(safe_full_pass) / len(values) if values else 0.0,
        "safe_at_full_pass": (
            len(safe_full_pass) / len(full_pass) if full_pass else None
        ),
    }


def _eligible_pairs(
    full: Mapping[str, AderynSelectedRound],
    no_slither: Mapping[str, AderynSelectedRound],
    require_same_tests: bool,
) -> List[Tuple[AderynSelectedRound, AderynSelectedRound]]:
    pairs: List[Tuple[AderynSelectedRound, AderynSelectedRound]] = []
    for file_path in sorted(set(full) & set(no_slither)):
        left = full[file_path]
        right = no_slither[file_path]
        if not (
            left.compiled and right.compiled and left.scan_valid and right.scan_valid
        ):
            continue
        if require_same_tests and (left.passed, left.total) != (
            right.passed,
            right.total,
        ):
            continue
        pairs.append((left, right))
    return pairs


def _severity_rows(
    model: str,
    full: Mapping[str, AderynSelectedRound],
    no_slither: Mapping[str, AderynSelectedRound],
) -> List[Dict[str, Any]]:
    pairs = _eligible_pairs(full, no_slither, require_same_tests=True)
    rows: List[Dict[str, Any]] = []
    for impact in ADERYN_IMPACT_LEVELS:
        full_values = [int((left.severity or {}).get(impact, 0)) for left, _ in pairs]
        no_slither_values = [
            int((right.severity or {}).get(impact, 0)) for _, right in pairs
        ]
        lower = sum(left < right for left, right in zip(full_values, no_slither_values))
        higher = sum(
            left > right for left, right in zip(full_values, no_slither_values)
        )
        rows.append(
            {
                "model": model,
                "impact": impact,
                "files": len(pairs),
                "full_findings": sum(full_values),
                "no_slither_findings": sum(no_slither_values),
                "full_lower": lower,
                "equal": len(pairs) - lower - higher,
                "full_higher": higher,
                "p_value": exact_sign_test_p_value(lower, higher),
            }
        )
    return rows


def _paired_row(
    model: str,
    result: PairedResult,
    pairs: Sequence[Tuple[AderynSelectedRound, AderynSelectedRound]],
) -> Dict[str, Any]:
    full_records = [left for left, _ in pairs]
    no_slither_records = [right for _, right in pairs]
    return {
        "model": model,
        "files": result.files,
        "full_findings": result.full_findings,
        "no_slither_findings": result.no_slither_findings,
        "full_findings_per_kloc": _findings_per_kloc(
            result.full_findings, full_records
        ),
        "no_slither_findings_per_kloc": _findings_per_kloc(
            result.no_slither_findings, no_slither_records
        ),
        "full_lower": result.full_lower,
        "equal": result.equal,
        "full_higher": result.full_higher,
        "p_value": result.p_value,
        "holm_adjusted_p_value": result.adjusted_p_value,
    }


def analyze_aderyn(
    groups: AderynGroups,
    models: Sequence[str],
) -> Dict[str, Any]:
    overall: List[Dict[str, Any]] = []
    common_raw: List[PairedResult] = []
    matched_raw: List[PairedResult] = []

    for model in models:
        full, no_slither = groups[model]
        overall.append(_overall_row("full", model, full))
        overall.append(_overall_row("no_slither", model, no_slither))
        common_raw.append(compare_pairs(full, no_slither, require_same_tests=False))
        matched_raw.append(compare_pairs(full, no_slither, require_same_tests=True))

    common_adjusted = with_adjusted_p_values(common_raw)
    matched_adjusted = with_adjusted_p_values(matched_raw)
    common = [
        _paired_row(
            model,
            result,
            _eligible_pairs(groups[model][0], groups[model][1], False),
        )
        for model, result in zip(models, common_adjusted)
    ]
    matched = [
        _paired_row(
            model,
            result,
            _eligible_pairs(groups[model][0], groups[model][1], True),
        )
        for model, result in zip(models, matched_adjusted)
    ]

    severity: List[Dict[str, Any]] = []
    for model in models:
        full, no_slither = groups[model]
        severity.extend(_severity_rows(model, full, no_slither))

    return {
        "tool": "Aderyn",
        "selection_policy": ADERYN_SELECTION_POLICY,
        "main_table": overall,
        "common_compiled": common,
        "functionality_matched": matched,
        "functionality_matched_by_severity": severity,
        "notes": [
            "Full and no-Slither use the same selected-checkpoint rule.",
            "Compilation and FullPass come from the regenerated RQ2 eval report.",
            "SafeFullPass requires eval FullPass and zero Aderyn findings.",
            "Findings/KLOC is computed over successfully scanned compiled code.",
            "Lower/equal/higher is Full relative to w/o Slither feedback.",
        ],
    }


def _format_optional(value: Optional[float], digits: int = 2) -> str:
    return "N/A" if value is None else f"{value:.{digits}f}"


def print_aderyn_results(result: Mapping[str, Any]) -> None:
    print("\nRQ2 Aderyn Cross-Validation")
    print(
        "Selection: max passed -> min H+M+L among identical (passed,total) -> earliest"
    )

    print("\n[Overall selected-output summary]")
    print_table(
        [
            "Variant",
            "Model",
            "N",
            "Compiled",
            "C.Scan",
            "C.Find",
            "C.F/KLOC",
            "FullPass",
            "FP.Scan",
            "FP.Find",
            "FP.F/KLOC",
            "SafeFull",
            "Secure@1",
            "Safe@Full",
        ],
        [
            [
                row["variant_name"],
                row["model"],
                row["attempted"],
                row["compiled"],
                row["compiled_scanned"],
                row["compiled_findings"],
                _format_optional(row["compiled_findings_per_kloc"]),
                row["full_pass"],
                row["full_pass_scanned"],
                row["full_pass_findings"],
                _format_optional(row["full_pass_findings_per_kloc"]),
                row["safe_full_pass"],
                f"{row['secure_pass_at_1'] * 100:.2f}%",
                (
                    "N/A"
                    if row["safe_at_full_pass"] is None
                    else f"{row['safe_at_full_pass'] * 100:.2f}%"
                ),
            ]
            for row in result["main_table"]
        ],
    )
    print("C = eval-compiled selected outputs; FP = eval FullPass outputs.")

    for key, title in (
        ("common_compiled", "Common compiled and Aderyn-scanned files"),
        (
            "functionality_matched",
            "Functionality-matched files: identical selected (passed,total)",
        ),
    ):
        print(f"\n[{title}]")
        print_table(
            [
                "Model",
                "Files",
                "Full/No Findings",
                "Full/No F/KLOC",
                "Lower/Equal/Higher",
                "p",
                "Holm p",
            ],
            [
                [
                    row["model"],
                    row["files"],
                    f"{row['full_findings']}/{row['no_slither_findings']}",
                    (
                        f"{_format_optional(row['full_findings_per_kloc'])}/"
                        f"{_format_optional(row['no_slither_findings_per_kloc'])}"
                    ),
                    f"{row['full_lower']}/{row['equal']}/{row['full_higher']}",
                    f"{row['p_value']:.6f}",
                    f"{row['holm_adjusted_p_value']:.6f}",
                ]
                for row in result[key]
            ],
        )

    print("\n[Functionality-matched findings by Aderyn severity]")
    print_table(
        [
            "Model",
            "Impact",
            "Files",
            "Full/No Findings",
            "Lower/Equal/Higher",
            "p",
        ],
        [
            [
                row["model"],
                row["impact"],
                row["files"],
                f"{row['full_findings']}/{row['no_slither_findings']}",
                f"{row['full_lower']}/{row['equal']}/{row['full_higher']}",
                f"{row['p_value']:.6f}",
            ]
            for row in result["functionality_matched_by_severity"]
        ],
    )
    print("\nNote: lower/equal/higher is Full relative to w/o Slither feedback.")


def write_aderyn_results(
    result: Mapping[str, Any],
    output_path: Path,
    csv_path: Path,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False),
        encoding="utf-8",
    )
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    rows = list(result["main_table"])
    fieldnames = list(rows[0]) if rows else []
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def run_aderyn_statistics(
    summary_path: Path,
    database_groups: DatabaseGroups,
    models: Sequence[str],
    output_path: Path,
    csv_path: Path,
) -> Dict[str, Any]:
    groups = load_aderyn_groups(summary_path, database_groups)
    missing_models = [model for model in models if model not in groups]
    if missing_models:
        raise StatisticsError(
            f"Aderyn summary missing models: {', '.join(missing_models)}"
        )
    result = analyze_aderyn(groups, models)
    result["summary_path"] = str(summary_path)
    print_aderyn_results(result)
    write_aderyn_results(result, output_path, csv_path)
    print(f"\nWrote: {output_path}")
    print(f"Wrote: {csv_path}")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="RQ2 Aderyn cross-validation statistics"
    )
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--summary", default="stats/aderyn/rq2/summary.json")
    parser.add_argument("--output", default="stats/aderyn/rq2/comparison.json")
    parser.add_argument("--csv", default="stats/aderyn/rq2/main_table.csv")
    parser.add_argument("--models", default=",".join(TARGET_MODELS))
    args = parser.parse_args()
    models = [item.strip() for item in args.models.split(",") if item.strip()]

    try:
        with connect_read_only(args.db) as connection:
            validate_tables(connection)
            database_groups = {}
            for model in models:
                full = load_group(connection, "process_tracking", model)
                no_slither = load_group(
                    connection,
                    "process_tracking_ablation",
                    model,
                    ablation_type=3,
                )
                if not full or not no_slither:
                    raise StatisticsError(
                        f"Missing Full/no-Slither rows for {model}: "
                        f"{len(full)}/{len(no_slither)}"
                    )
                database_groups[model] = (full, no_slither)
        run_aderyn_statistics(
            Path(args.summary),
            database_groups,
            models,
            Path(args.output),
            Path(args.csv),
        )
        return 0
    except (OSError, StatisticsError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
