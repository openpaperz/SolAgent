#!/usr/bin/env python3
"""RQ2 paired analysis for iterative Slither feedback.

Both Full SolAgent and the w/o Slither-feedback variant use the same
lexicographic checkpoint selector:

1. maximize the number of passed tests;
2. among rounds with the same ``(passed, total)`` result, minimize the sum of
   High-, Medium-, and Low-impact Slither findings;
3. keep the earliest round for any remaining tie.

The no-Slither experiment still records Slither results for offline
evaluation, but those results are not exposed to the refinement agent.

Usage:
    python stats/rq2_slither_feedback_statistics.py --db output/progress.db
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import sqlite3
import sys
from collections import Counter
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Tuple

from testing.rq1_verify_eval_models import _select_solagent_code


TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
IMPACT_LEVELS = ("High", "Medium", "Low")
DEFAULT_SUPPLEMENTAL_SLITHER_DIR = Path("stats/slither/rq2/supplemental")


class StatisticsError(RuntimeError):
    """Raised when the experiment database cannot support this analysis."""


@dataclass(frozen=True)
class SelectedRound:
    file_path: str
    round_index: Optional[int]
    passed: int
    total: int
    vuln_count: Optional[int]
    severity: Optional[Mapping[str, int]]

    @property
    def compiled(self) -> bool:
        return self.total > 0

    @property
    def full_pass(self) -> bool:
        return self.compiled and self.passed == self.total

    @property
    def scan_valid(self) -> bool:
        return self.vuln_count is not None

    @property
    def safe_full_pass(self) -> bool:
        return self.full_pass and self.vuln_count == 0


@dataclass(frozen=True)
class SupplementalScan:
    source: str
    model: str
    file_path: str
    row_id: int
    round_index: int
    finding_count: int
    finding_summary: Mapping[str, int]
    code_sha256: str
    result_path: str


@dataclass(frozen=True)
class GroupSummary:
    attempted: int
    compiled: int
    full_pass: int
    safe_full_pass: int
    scanned_compiled: int
    compiled_findings: int


@dataclass(frozen=True)
class PairedResult:
    files: int
    full_findings: int
    no_slither_findings: int
    full_lower: int
    equal: int
    full_higher: int
    p_value: float
    adjusted_p_value: float = 1.0


def paired_result_rows(
    models: Sequence[str],
    modes: Sequence[Tuple[str, Sequence[PairedResult]]],
) -> List[Dict[str, object]]:
    """Return the common CSV schema used by all RQ2 security entry points."""
    rows: List[Dict[str, object]] = []
    for mode, results in modes:
        adjusted = holm_adjust([result.p_value for result in results])
        for model, result, holm_p in zip(models, results, adjusted):
            reduction = (
                (result.no_slither_findings - result.full_findings)
                / result.no_slither_findings
                if result.no_slither_findings
                else None
            )
            rows.append(
                {
                    "analyzer": "slither",
                    "analyzer_name": "Slither",
                    "model": model,
                    "mode": mode,
                    "files": result.files,
                    "full_findings": result.full_findings,
                    "no_slither_findings": result.no_slither_findings,
                    "finding_reduction": reduction,
                    "full_lower": result.full_lower,
                    "equal": result.equal,
                    "full_higher": result.full_higher,
                    "discordant": result.full_lower + result.full_higher,
                    "p_value": result.p_value,
                    "holm_p_within_analyzer": holm_p,
                }
            )
    return rows


def write_paired_csv(path: Path, rows: Sequence[Mapping[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0]) if rows else []
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


@dataclass(frozen=True)
class SeverityResult:
    impact: str
    files: int
    full_findings: int
    no_slither_findings: int
    full_lower: int
    equal: int
    full_higher: int
    p_value: float


def safe_json_loads(value, default):
    if isinstance(value, (dict, list)):
        return value
    if not value:
        return default
    try:
        return json.loads(value)
    except (json.JSONDecodeError, TypeError, ValueError):
        return default


def nonnegative_int(value) -> Optional[int]:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    integer = int(value)
    return integer if integer >= 0 and integer == value else None


def severity_counts(slither_raw) -> Optional[Mapping[str, int]]:
    """Extract H/M/L detector counts from a successful Slither result."""
    if not isinstance(slither_raw, dict) or slither_raw.get("success") is not True:
        return None
    detectors = (slither_raw.get("results") or {}).get("detectors") or []
    counts = Counter(
        detector.get("impact")
        for detector in detectors
        if isinstance(detector, dict) and detector.get("impact") in IMPACT_LEVELS
    )
    return {impact: counts[impact] for impact in IMPACT_LEVELS}


def load_supplemental_scans(
    directory: Path,
) -> Dict[Tuple[str, str, str, int], SupplementalScan]:
    if not directory.exists():
        return {}
    scans: Dict[Tuple[str, str, str, int], SupplementalScan] = {}
    for path in sorted(directory.rglob("*.json")):
        try:
            item = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise StatisticsError(
                f"Cannot read supplemental Slither result {path}: {error}"
            ) from error
        if item.get("success") is not True:
            raise StatisticsError(
                f"Supplemental Slither result is not successful: {path}"
            )
        summary_raw = item.get("finding_summary")
        if not isinstance(summary_raw, dict):
            raise StatisticsError(
                f"Supplemental Slither result has no finding_summary: {path}"
            )
        summary = {
            impact: nonnegative_int(summary_raw.get(impact)) for impact in IMPACT_LEVELS
        }
        if any(value is None for value in summary.values()):
            raise StatisticsError(
                f"Supplemental Slither result has invalid severity counts: {path}"
            )
        finding_count = nonnegative_int(item.get("finding_count"))
        if finding_count is None or finding_count != sum(summary.values()):
            raise StatisticsError(
                f"Supplemental Slither finding count mismatch: {path}"
            )
        try:
            scan = SupplementalScan(
                source=str(item["source"]),
                model=str(item["model"]),
                file_path=str(item["file_path"]),
                row_id=int(item["id"]),
                round_index=int(item["best_round"]),
                finding_count=finding_count,
                finding_summary={
                    impact: int(summary[impact]) for impact in IMPACT_LEVELS
                },
                code_sha256=str(item["code_sha256"]),
                result_path=str(path),
            )
        except (KeyError, TypeError, ValueError) as error:
            raise StatisticsError(
                f"Incomplete supplemental Slither result {path}: {error}"
            ) from error
        if not scan.code_sha256:
            raise StatisticsError(
                f"Supplemental Slither result has no code hash: {path}"
            )
        key = (scan.source, scan.model, scan.file_path, scan.round_index)
        if key in scans:
            raise StatisticsError(f"Duplicate supplemental Slither result for {key}")
        scans[key] = scan
    return scans


def select_persisted_round(row: Mapping) -> SelectedRound:
    """Select a round while treating failed/missing Slither output as unscanned."""
    vulnerabilities = safe_json_loads(row.get("round_vuln_count"), {})
    slither_by_round = safe_json_loads(row.get("round_slither_raw"), {})
    if not isinstance(vulnerabilities, dict):
        vulnerabilities = {}
    if not isinstance(slither_by_round, dict):
        slither_by_round = {}
    valid_vulnerabilities = {
        str(round_key): value
        for round_key, value in vulnerabilities.items()
        if severity_counts(slither_by_round.get(str(round_key))) is not None
    }
    sanitized = dict(row)
    sanitized["round_vuln_count"] = valid_vulnerabilities
    return select_test_first_security_second(sanitized)


def select_test_first_security_second(row: Mapping) -> SelectedRound:
    """Select one round using the symmetric RQ2 lexicographic policy."""
    tests = safe_json_loads(row.get("test_json"), {})
    vulnerabilities = safe_json_loads(row.get("round_vuln_count"), {})
    slither_by_round = safe_json_loads(row.get("round_slither_raw"), {})
    candidates = []

    if isinstance(tests, dict):
        for order, (round_key, test_result) in enumerate(tests.items()):
            if not isinstance(test_result, dict):
                continue
            try:
                round_index = int(round_key)
            except (TypeError, ValueError):
                continue
            passed = int(test_result.get("pass", test_result.get("passed", 0)) or 0)
            total = int(test_result.get("total", 0) or 0)
            vuln_count = nonnegative_int(vulnerabilities.get(str(round_index)))
            candidates.append(
                {
                    "order": order,
                    "round_index": round_index,
                    "passed": passed,
                    "total": total,
                    "vuln_count": vuln_count,
                    "severity": severity_counts(slither_by_round.get(str(round_index))),
                }
            )

    if not candidates:
        return SelectedRound(
            file_path=row.get("file_path", "unknown"),
            round_index=None,
            passed=0,
            total=0,
            vuln_count=None,
            severity=None,
        )

    max_passed = max(candidate["passed"] for candidate in candidates)
    first_best = next(
        candidate for candidate in candidates if candidate["passed"] == max_passed
    )
    exact_test_ties = [
        candidate
        for candidate in candidates
        if (candidate["passed"], candidate["total"])
        == (first_best["passed"], first_best["total"])
    ]
    scanned_ties = [
        candidate for candidate in exact_test_ties if candidate["vuln_count"] is not None
    ]
    if scanned_ties:
        selected = min(
            scanned_ties,
            key=lambda candidate: (candidate["vuln_count"], candidate["order"]),
        )
    else:
        selected = min(exact_test_ties, key=lambda candidate: candidate["order"])

    return SelectedRound(
        file_path=row.get("file_path", "unknown"),
        round_index=selected["round_index"],
        passed=selected["passed"],
        total=selected["total"],
        vuln_count=selected["vuln_count"],
        severity=selected["severity"],
    )


def exact_sign_test_p_value(full_lower: int, full_higher: int) -> float:
    """Two-sided exact sign test over non-tied file pairs."""
    discordant = full_lower + full_higher
    if discordant == 0:
        return 1.0
    tail = min(full_lower, full_higher)
    probability = 2.0 * sum(
        math.comb(discordant, index) for index in range(tail + 1)
    ) / (2 ** discordant)
    return min(1.0, probability)


def holm_adjust(p_values: Sequence[float]) -> List[float]:
    """Apply Holm's step-down family-wise error correction."""
    ordered = sorted(enumerate(p_values), key=lambda item: item[1])
    adjusted = [1.0] * len(p_values)
    running_max = 0.0
    family_size = len(p_values)
    for rank, (original_index, p_value) in enumerate(ordered):
        corrected = min(1.0, (family_size - rank) * p_value)
        running_max = max(running_max, corrected)
        adjusted[original_index] = running_max
    return adjusted


def summarize(records: Mapping[str, SelectedRound]) -> GroupSummary:
    values = list(records.values())
    compiled = [record for record in values if record.compiled]
    scanned = [record for record in compiled if record.scan_valid]
    return GroupSummary(
        attempted=len(values),
        compiled=len(compiled),
        full_pass=sum(record.full_pass for record in values),
        safe_full_pass=sum(record.safe_full_pass for record in values),
        scanned_compiled=len(scanned),
        compiled_findings=sum(record.vuln_count or 0 for record in scanned),
    )


def compare_pairs(
    full: Mapping[str, SelectedRound],
    no_slither: Mapping[str, SelectedRound],
    require_same_tests: bool,
) -> PairedResult:
    common_paths = set(full) & set(no_slither)
    pairs: List[Tuple[SelectedRound, SelectedRound]] = []
    for file_path in common_paths:
        full_record = full[file_path]
        no_slither_record = no_slither[file_path]
        if not (
            full_record.compiled
            and no_slither_record.compiled
            and full_record.scan_valid
            and no_slither_record.scan_valid
        ):
            continue
        if require_same_tests and (
            full_record.passed,
            full_record.total,
        ) != (no_slither_record.passed, no_slither_record.total):
            continue
        pairs.append((full_record, no_slither_record))

    full_lower = sum(left.vuln_count < right.vuln_count for left, right in pairs)
    full_higher = sum(left.vuln_count > right.vuln_count for left, right in pairs)
    equal = len(pairs) - full_lower - full_higher
    return PairedResult(
        files=len(pairs),
        full_findings=sum(left.vuln_count for left, _ in pairs),
        no_slither_findings=sum(right.vuln_count for _, right in pairs),
        full_lower=full_lower,
        equal=equal,
        full_higher=full_higher,
        p_value=exact_sign_test_p_value(full_lower, full_higher),
    )


def compare_severity(
    full: Mapping[str, SelectedRound],
    no_slither: Mapping[str, SelectedRound],
) -> List[SeverityResult]:
    pairs = []
    for file_path in set(full) & set(no_slither):
        left = full[file_path]
        right = no_slither[file_path]
        if not (
            left.compiled
            and right.compiled
            and left.scan_valid
            and right.scan_valid
            and left.severity is not None
            and right.severity is not None
            and (left.passed, left.total) == (right.passed, right.total)
        ):
            continue
        pairs.append((left, right))

    results = []
    for impact in IMPACT_LEVELS:
        full_lower = sum(left.severity[impact] < right.severity[impact] for left, right in pairs)
        full_higher = sum(left.severity[impact] > right.severity[impact] for left, right in pairs)
        equal = len(pairs) - full_lower - full_higher
        results.append(
            SeverityResult(
                impact=impact,
                files=len(pairs),
                full_findings=sum(left.severity[impact] for left, _ in pairs),
                no_slither_findings=sum(right.severity[impact] for _, right in pairs),
                full_lower=full_lower,
                equal=equal,
                full_higher=full_higher,
                p_value=exact_sign_test_p_value(full_lower, full_higher),
            )
        )
    return results


def with_adjusted_p_values(results: Sequence[PairedResult]) -> List[PairedResult]:
    adjusted = holm_adjust([result.p_value for result in results])
    return [
        PairedResult(**{**result.__dict__, "adjusted_p_value": adjusted[index]})
        for index, result in enumerate(results)
    ]


def connect_read_only(db_path: str) -> sqlite3.Connection:
    path = Path(db_path)
    if not path.is_file():
        raise StatisticsError(f"Database file not found: {db_path}")
    connection = sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def validate_tables(connection: sqlite3.Connection) -> None:
    required = {"process_tracking", "process_tracking_ablation"}
    available = {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }
    missing = required - available
    if missing:
        raise StatisticsError(f"Missing required tables: {', '.join(sorted(missing))}")


def load_group(
    connection: sqlite3.Connection,
    table: str,
    model: str,
    ablation_type: Optional[int] = None,
    supplemental_scans: Optional[
        Mapping[Tuple[str, str, str, int], SupplementalScan]
    ] = None,
) -> Dict[str, SelectedRound]:
    if table not in {"process_tracking", "process_tracking_ablation"}:
        raise ValueError(f"Unsupported table: {table}")
    sql = f"SELECT * FROM {table} WHERE status IN (1, 2) AND model_coding = ?"
    parameters: List[object] = [model]
    if ablation_type is not None:
        sql += " AND ablation_type = ?"
        parameters.append(ablation_type)
    source = "full" if table == "process_tracking" else "no_slither"
    records: Dict[str, SelectedRound] = {}
    for row in connection.execute(sql, parameters):
        item = dict(row)
        selected = select_persisted_round(item)
        if selected.round_index is not None and supplemental_scans:
            key = (source, model, selected.file_path, selected.round_index)
            supplemental = supplemental_scans.get(key)
            if supplemental is not None:
                if supplemental.row_id != int(item["id"]):
                    raise StatisticsError(
                        f"Supplemental Slither row mismatch for {key}: "
                        f"database={item['id']}, supplemental={supplemental.row_id}"
                    )
                code_selection, code_error = _select_solagent_code(
                    item,
                    selected.file_path,
                    "test-first-security-second",
                )
                if code_selection is None:
                    raise StatisticsError(
                        f"Cannot reconstruct supplemental Slither code for {key}: "
                        f"{code_error}"
                    )
                code_sha256 = hashlib.sha256(code_selection.code.encode()).hexdigest()
                if code_sha256 != supplemental.code_sha256:
                    raise StatisticsError(
                        f"Supplemental Slither code hash mismatch for {key}: "
                        f"database={code_sha256}, supplemental={supplemental.code_sha256}"
                    )
                selected = replace(
                    selected,
                    vuln_count=supplemental.finding_count,
                    severity=supplemental.finding_summary,
                )
        records[selected.file_path] = selected
    return records


def print_table(headers: Sequence[str], rows: Iterable[Sequence[object]]) -> None:
    rendered = [[str(value) for value in row] for row in rows]
    widths = [len(header) for header in headers]
    for row in rendered:
        for index, value in enumerate(row):
            widths[index] = max(widths[index], len(value))
    line = "  ".join(header.ljust(widths[index]) for index, header in enumerate(headers))
    print(line)
    print("=" * len(line))
    for row in rendered:
        print("  ".join(value.ljust(widths[index]) for index, value in enumerate(row)))


def print_results(
    models: Sequence[str],
    groups: Mapping[str, Tuple[Mapping[str, SelectedRound], Mapping[str, SelectedRound]]],
) -> None:
    print("\nRQ2 Slither-Feedback Analysis")
    print("Selection: max passed -> min H+M+L among identical (passed,total) -> earliest")

    summary_rows = []
    common_results = []
    matched_results = []
    for model in models:
        full, no_slither = groups[model]
        for variant, records in (("Full", full), ("w/o Slither feedback", no_slither)):
            stats = summarize(records)
            summary_rows.append(
                [
                    variant,
                    model,
                    stats.attempted,
                    stats.compiled,
                    stats.full_pass,
                    stats.safe_full_pass,
                    f"{stats.compiled_findings}/{stats.scanned_compiled}",
                ]
            )
        common_results.append(compare_pairs(full, no_slither, require_same_tests=False))
        matched_results.append(compare_pairs(full, no_slither, require_same_tests=True))

    print("\n[Overall selected-output summary]")
    print_table(
        ["Variant", "Model", "N", "Compiled", "FullPass", "SafeFull", "Findings/ScannedC"],
        summary_rows,
    )

    common_results = with_adjusted_p_values(common_results)
    matched_results = with_adjusted_p_values(matched_results)
    print("\n[Common compiled files]")
    print_table(
        ["Model", "Files", "Full/No Findings", "Lower/Equal/Higher", "p", "Holm p"],
        [
            [
                model,
                result.files,
                f"{result.full_findings}/{result.no_slither_findings}",
                f"{result.full_lower}/{result.equal}/{result.full_higher}",
                f"{result.p_value:.6f}",
                f"{result.adjusted_p_value:.6f}",
            ]
            for model, result in zip(models, common_results)
        ],
    )

    print("\n[Functionality-matched files: identical selected (passed,total)]")
    print_table(
        ["Model", "Files", "Full/No Findings", "Lower/Equal/Higher", "p", "Holm p"],
        [
            [
                model,
                result.files,
                f"{result.full_findings}/{result.no_slither_findings}",
                f"{result.full_lower}/{result.equal}/{result.full_higher}",
                f"{result.p_value:.6f}",
                f"{result.adjusted_p_value:.6f}",
            ]
            for model, result in zip(models, matched_results)
        ],
    )

    print("\n[Functionality-matched findings by Slither impact]")
    severity_rows = []
    for model in models:
        full, no_slither = groups[model]
        for result in compare_severity(full, no_slither):
            severity_rows.append(
                [
                    model,
                    result.impact,
                    result.files,
                    f"{result.full_findings}/{result.no_slither_findings}",
                    f"{result.full_lower}/{result.equal}/{result.full_higher}",
                    f"{result.p_value:.6f}",
                ]
            )
    print_table(
        ["Model", "Impact", "Files", "Full/No Findings", "Lower/Equal/Higher", "p"],
        severity_rows,
    )
    print("\nNote: lower/equal/higher is Full relative to w/o Slither feedback.")


def main() -> int:
    parser = argparse.ArgumentParser(description="RQ2 paired Slither-feedback statistics")
    parser.add_argument("--db", default="output/progress.db", help="SQLite experiment database")
    parser.add_argument(
        "--models",
        default=",".join(TARGET_MODELS),
        help="Comma-separated model names",
    )
    parser.add_argument(
        "--supplemental-slither-dir",
        default=str(DEFAULT_SUPPLEMENTAL_SLITHER_DIR),
        help="Directory containing successful exact-code Slither rescans",
    )
    args = parser.parse_args()
    models = [model.strip() for model in args.models.split(",") if model.strip()]

    try:
        supplemental_scans = load_supplemental_scans(
            Path(args.supplemental_slither_dir)
        )
        connection = connect_read_only(args.db)
        validate_tables(connection)
        groups = {}
        for model in models:
            full = load_group(
                connection,
                "process_tracking",
                model,
                supplemental_scans=supplemental_scans,
            )
            no_slither = load_group(
                connection,
                "process_tracking_ablation",
                model,
                ablation_type=3,
                supplemental_scans=supplemental_scans,
            )
            if not full or not no_slither:
                print(
                    f"[WARNING] Skipping {model}: Full={len(full)}, "
                    f"w/o Slither feedback={len(no_slither)}",
                    file=sys.stderr,
                )
                continue
            groups[model] = (full, no_slither)
        selected_models = [model for model in models if model in groups]
        if not selected_models:
            raise StatisticsError("No complete Full/No-Slither model groups found")
        print_results(selected_models, groups)
        connection.close()
        return 0
    except (sqlite3.Error, StatisticsError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
