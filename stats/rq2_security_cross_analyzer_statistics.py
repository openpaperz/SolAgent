#!/usr/bin/env python3
"""Compare Slither, Aderyn, Wake, and Decurity on the RQ2 selected code."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from statistics import median
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from stats.rq2_security_scan_utils import (  # noqa: E402
    DEFAULT_EVAL_REPORT,
    DEFAULT_SOURCES,
    SELECTION_POLICY,
    fetch_entries,
    load_eval_results,
    prepare_entry,
    solidity_sloc,
)
from stats.rq2_slither_feedback_statistics import (  # noqa: E402
    TARGET_MODELS,
    StatisticsError,
    exact_sign_test_p_value,
    holm_adjust,
    print_table,
)


ANALYZER_LABELS = {
    "slither": "Slither",
    "aderyn": "Aderyn",
    "wake": "Wake (Low+)",
    "semgrep": "Semgrep + Decurity",
}
VARIANT_LABELS = {
    "full": "Full",
    "no_slither": "w/o Slither",
}
EXTERNAL_SUMMARIES = {
    "aderyn": Path("stats/aderyn/rq2/summary.json"),
    "wake": Path("stats/wake/rq2/summary.json"),
    "semgrep": Path("stats/semgrep/rq2/summary.json"),
}
Key = Tuple[str, str, str]


@dataclass(frozen=True)
class ExpectedSample:
    source: str
    model: str
    file_path: str
    row_id: int
    best_round: Optional[int]
    code_sha256: Optional[str]
    code_sloc: Optional[int]
    eval_compiled: bool
    eval_full_pass: bool
    passed: int
    total: int
    feedback_compiled: bool
    feedback_full_pass: bool
    feedback_passed: int
    feedback_total: int
    slither_count: Optional[int]
    slither_summary: Optional[Mapping[str, int]]


@dataclass(frozen=True)
class ScanRecord:
    analyzer: str
    source: str
    model: str
    file_path: str
    best_round: Optional[int]
    code_sha256: Optional[str]
    sloc: Optional[int]
    eval_compiled: bool
    eval_full_pass: bool
    passed: int
    total: int
    feedback_compiled: bool
    feedback_full_pass: bool
    feedback_passed: int
    feedback_total: int
    status: str
    finding_count: Optional[int]
    finding_summary: Optional[Mapping[str, int]]

    @property
    def complete_scan(self) -> bool:
        return self.status == "analyzed" and self.finding_count is not None

    @property
    def observed_scan(self) -> bool:
        return self.status in {"analyzed", "partial"} and self.finding_count is not None

    @property
    def safe_full_pass(self) -> bool:
        return self.eval_full_pass and self.complete_scan and self.finding_count == 0


def nonnegative_int(value: Any) -> Optional[int]:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    parsed = int(value)
    return parsed if parsed >= 0 and parsed == value else None


def sample_key(source: str, model: str, file_path: str) -> Key:
    return source, model, file_path


def load_expected_samples(
    db_path: str,
    eval_report: Path,
    models: Sequence[str],
) -> Tuple[Dict[Key, ExpectedSample], Mapping[str, Any]]:
    eval_results, eval_meta = load_eval_results(eval_report)
    entries = fetch_entries(db_path, list(DEFAULT_SOURCES), list(models))
    expected: Dict[Key, ExpectedSample] = {}
    for entry in entries:
        code, code_meta, tests, result_meta, slither = prepare_entry(
            entry, eval_results
        )
        key = sample_key(
            str(entry["_source"]),
            str(entry["_model"]),
            str(entry["file_path"]),
        )
        if key in expected:
            raise StatisticsError(f"Duplicate expected RQ2 sample: {key}")
        expected[key] = ExpectedSample(
            source=key[0],
            model=key[1],
            file_path=key[2],
            row_id=int(entry["id"]),
            best_round=nonnegative_int(code_meta.get("best_round")),
            code_sha256=code_meta.get("sha256"),
            code_sloc=solidity_sloc(code) if code else None,
            eval_compiled=bool(result_meta.get("compiled")),
            eval_full_pass=bool(result_meta.get("full_pass")),
            passed=int(tests["test_pass"]),
            total=int(tests["test_total"]),
            feedback_compiled=bool(code_meta.get("feedback_compiled")),
            feedback_full_pass=(
                bool(code_meta.get("feedback_compiled"))
                and int(code_meta.get("best_pass") or 0)
                == int(code_meta.get("best_total") or 0)
            ),
            feedback_passed=int(code_meta.get("best_pass") or 0),
            feedback_total=int(code_meta.get("best_total") or 0),
            slither_count=nonnegative_int(slither.get("count")),
            slither_summary=(
                dict(slither["summary"])
                if isinstance(slither.get("summary"), dict)
                else None
            ),
        )
    wanted = len(DEFAULT_SOURCES) * len(models) * 81
    if len(expected) != wanted:
        raise StatisticsError(
            f"Expected {wanted} Full/no-Slither samples, loaded {len(expected)}"
        )
    return expected, eval_meta


def slither_records(expected: Mapping[Key, ExpectedSample]) -> Dict[Key, ScanRecord]:
    records: Dict[Key, ScanRecord] = {}
    for key, sample in expected.items():
        status = "analyzed" if sample.slither_count is not None else "error"
        records[key] = ScanRecord(
            analyzer="slither",
            source=sample.source,
            model=sample.model,
            file_path=sample.file_path,
            best_round=sample.best_round,
            code_sha256=sample.code_sha256,
            sloc=sample.code_sloc,
            eval_compiled=sample.eval_compiled,
            eval_full_pass=sample.eval_full_pass,
            passed=sample.passed,
            total=sample.total,
            feedback_compiled=sample.feedback_compiled,
            feedback_full_pass=sample.feedback_full_pass,
            feedback_passed=sample.feedback_passed,
            feedback_total=sample.feedback_total,
            status=status,
            finding_count=sample.slither_count,
            finding_summary=sample.slither_summary,
        )
    return records


def _summary_mapping(value: Any, label: str) -> Optional[Mapping[str, int]]:
    if value is None:
        return None
    if not isinstance(value, dict):
        raise StatisticsError(f"Invalid {label} finding summary: {value!r}")
    result: Dict[str, int] = {}
    for impact, raw_count in value.items():
        count = nonnegative_int(raw_count)
        if count is None:
            raise StatisticsError(
                f"Invalid {label} finding count for {impact}: {raw_count!r}"
            )
        result[str(impact)] = count
    return result


def load_external_records(
    analyzer: str,
    summary_path: Path,
    expected: Mapping[Key, ExpectedSample],
) -> Dict[Key, ScanRecord]:
    try:
        payload = json.loads(summary_path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise StatisticsError(
            f"{analyzer} summary not found: {summary_path}"
        ) from error
    except json.JSONDecodeError as error:
        raise StatisticsError(f"Invalid {analyzer} summary JSON: {error}") from error
    if payload.get("selection_policy") != SELECTION_POLICY:
        raise StatisticsError(
            f"{analyzer} selection policy is {payload.get('selection_policy')!r}, "
            f"expected {SELECTION_POLICY!r}"
        )

    records: Dict[Key, ScanRecord] = {}
    raw_records: Dict[Key, Mapping[str, Any]] = {}
    for item in payload.get("records") or []:
        if not isinstance(item, dict):
            raise StatisticsError(f"{analyzer} summary contains a non-object record")
        key = sample_key(
            str(item.get("source") or ""),
            str(item.get("model") or ""),
            str(item.get("file_path") or ""),
        )
        if key not in expected:
            continue
        if key in records:
            raise StatisticsError(f"Duplicate {analyzer} record: {key}")
        status = str(item.get("status") or "")
        allowed = {"analyzed", "partial", "error", "skipped"}
        if status not in allowed:
            raise StatisticsError(f"Invalid {analyzer} status for {key}: {status!r}")
        finding_count = (
            nonnegative_int(item.get("finding_count"))
            if status in {"analyzed", "partial"}
            else None
        )
        if status in {"analyzed", "partial"} and finding_count is None:
            raise StatisticsError(f"{analyzer} scanned record has no count: {key}")
        summary = (
            _summary_mapping(item.get("finding_summary") or {}, analyzer)
            if status in {"analyzed", "partial"}
            else None
        )
        records[key] = ScanRecord(
            analyzer=analyzer,
            source=key[0],
            model=key[1],
            file_path=key[2],
            best_round=nonnegative_int(item.get("best_round")),
            code_sha256=item.get("code_sha256"),
            sloc=nonnegative_int(item.get("code_sloc")),
            eval_compiled=bool(item.get("eval_compiled")),
            eval_full_pass=bool(item.get("eval_full_pass")),
            passed=int(item.get("test_pass") or 0),
            total=int(item.get("test_total") or 0),
            feedback_compiled=expected[key].feedback_compiled,
            feedback_full_pass=expected[key].feedback_full_pass,
            feedback_passed=expected[key].feedback_passed,
            feedback_total=expected[key].feedback_total,
            status=status,
            finding_count=finding_count,
            finding_summary=summary,
        )
        raw_records[key] = item

    missing = sorted(set(expected) - set(records))
    extra = sorted(set(records) - set(expected))
    if missing or extra:
        raise StatisticsError(
            f"{analyzer} coverage mismatch: missing={len(missing)}, extra={len(extra)}"
        )

    for key, wanted in expected.items():
        actual = records[key]
        raw = raw_records[key]
        checks = {
            "row_id": (raw.get("id"), wanted.row_id),
            "best_round": (actual.best_round, wanted.best_round),
            "code_sha256": (actual.code_sha256, wanted.code_sha256),
            "code_sloc": (actual.sloc, wanted.code_sloc),
            "eval_compiled": (actual.eval_compiled, wanted.eval_compiled),
            "eval_full_pass": (actual.eval_full_pass, wanted.eval_full_pass),
            "test_pass": (actual.passed, wanted.passed),
            "test_total": (actual.total, wanted.total),
            "feedback_compiled": (
                raw.get("feedback_compiled"),
                wanted.feedback_compiled,
            ),
            "feedback_full_pass": (
                raw.get("feedback_full_pass"),
                wanted.feedback_full_pass,
            ),
            "feedback_test_pass": (
                raw.get("feedback_test_pass"),
                wanted.feedback_passed,
            ),
            "feedback_test_total": (
                raw.get("feedback_test_total"),
                wanted.feedback_total,
            ),
            "slither_count": (raw.get("slither_count"), wanted.slither_count),
        }
        mismatches = {
            name: values for name, values in checks.items() if values[0] != values[1]
        }
        if mismatches:
            raise StatisticsError(f"{analyzer} sample mismatch for {key}: {mismatches}")
        analysis_eligible = wanted.eval_compiled or wanted.feedback_compiled
        if analysis_eligible and actual.status == "skipped":
            raise StatisticsError(
                f"{analyzer} skipped feedback/eval-compiled sample: {key}"
            )
        if not analysis_eligible and actual.status != "skipped":
            raise StatisticsError(
                f"{analyzer} did not skip ineligible sample {key}: {actual.status}"
            )
    return records


def findings_per_kloc(findings: int, records: Sequence[ScanRecord]) -> Optional[float]:
    if not records or any(record.sloc is None for record in records):
        return None
    sloc = sum(int(record.sloc) for record in records if record.sloc is not None)
    return findings / (sloc / 1000.0) if sloc else None


def _main_row(
    analyzer: str,
    source: str,
    model: str,
    records: Mapping[Key, ScanRecord],
) -> Dict[str, Any]:
    values = [
        record
        for record in records.values()
        if record.source == source and record.model == model
    ]
    compiled = [record for record in values if record.eval_compiled]
    observed = [record for record in compiled if record.observed_scan]
    complete = [record for record in compiled if record.complete_scan]
    partial = [record for record in compiled if record.status == "partial"]
    full_pass = [record for record in compiled if record.eval_full_pass]
    fp_observed = [record for record in full_pass if record.observed_scan]
    fp_complete = [record for record in full_pass if record.complete_scan]
    fp_partial = [record for record in full_pass if record.status == "partial"]
    safe = [record for record in full_pass if record.safe_full_pass]

    compiled_findings = sum(int(record.finding_count or 0) for record in observed)
    compiled_complete_findings = sum(
        int(record.finding_count or 0) for record in complete
    )
    full_pass_findings = sum(int(record.finding_count or 0) for record in fp_observed)
    full_pass_complete_findings = sum(
        int(record.finding_count or 0) for record in fp_complete
    )
    return {
        "analyzer": analyzer,
        "analyzer_name": ANALYZER_LABELS[analyzer],
        "variant": source,
        "variant_name": VARIANT_LABELS[source],
        "model": model,
        "attempted": len(values),
        "compiled": len(compiled),
        "compilation_rate": len(compiled) / len(values) if values else None,
        "compiled_observed": len(observed),
        "compiled_complete": len(complete),
        "compiled_partial": len(partial),
        "compiled_errors": sum(record.status == "error" for record in compiled),
        "compiled_findings": compiled_findings,
        "compiled_findings_per_kloc": findings_per_kloc(compiled_findings, observed),
        "compiled_complete_findings": compiled_complete_findings,
        "compiled_complete_findings_per_kloc": findings_per_kloc(
            compiled_complete_findings, complete
        ),
        "full_pass": len(full_pass),
        "full_pass_rate": len(full_pass) / len(values) if values else None,
        "full_pass_observed": len(fp_observed),
        "full_pass_complete": len(fp_complete),
        "full_pass_partial": len(fp_partial),
        "full_pass_errors": sum(record.status == "error" for record in full_pass),
        "full_pass_findings": full_pass_findings,
        "full_pass_findings_per_kloc": findings_per_kloc(
            full_pass_findings, fp_observed
        ),
        "full_pass_complete_findings": full_pass_complete_findings,
        "full_pass_complete_findings_per_kloc": findings_per_kloc(
            full_pass_complete_findings, fp_complete
        ),
        "safe_full_pass": len(safe),
        "secure_pass_at_1": len(safe) / len(values) if values else None,
        "safe_at_full_pass": len(safe) / len(full_pass) if full_pass else None,
        "safe_at_complete_full_pass": (
            len(safe) / len(fp_complete) if fp_complete else None
        ),
    }


def _eligible_pairs(
    records: Mapping[Key, ScanRecord],
    model: Optional[str],
    mode: str,
) -> List[Tuple[ScanRecord, ScanRecord]]:
    def pair_key(record: ScanRecord) -> Any:
        return (record.model, record.file_path) if model is None else record.file_path

    full = {
        pair_key(record): record
        for record in records.values()
        if record.source == "full" and (model is None or record.model == model)
    }
    no_slither = {
        pair_key(record): record
        for record in records.values()
        if record.source == "no_slither" and (model is None or record.model == model)
    }

    pairs: List[Tuple[ScanRecord, ScanRecord]] = []
    for key in sorted(set(full) & set(no_slither), key=str):
        left = full[key]
        right = no_slither[key]
        feedback_mode = mode.startswith("feedback_")
        left_compiled = left.feedback_compiled if feedback_mode else left.eval_compiled
        right_compiled = (
            right.feedback_compiled if feedback_mode else right.eval_compiled
        )
        if not (
            left_compiled
            and right_compiled
            and left.complete_scan
            and right.complete_scan
        ):
            continue
        if mode == "feedback_functionality_matched" and (
            left.feedback_passed,
            left.feedback_total,
        ) != (
            right.feedback_passed,
            right.feedback_total,
        ):
            continue
        if mode == "feedback_both_full_pass" and not (
            left.feedback_full_pass and right.feedback_full_pass
        ):
            continue
        if mode == "functionality_matched" and (left.passed, left.total) != (
            right.passed,
            right.total,
        ):
            continue
        if mode == "both_full_pass" and not (
            left.eval_full_pass and right.eval_full_pass
        ):
            continue
        pairs.append((left, right))
    return pairs


def _paired_row(
    analyzer: str,
    model: str,
    mode: str,
    pairs: Sequence[Tuple[ScanRecord, ScanRecord]],
) -> Dict[str, Any]:
    full_counts = [int(left.finding_count or 0) for left, _ in pairs]
    no_counts = [int(right.finding_count or 0) for _, right in pairs]
    lower = sum(left < right for left, right in zip(full_counts, no_counts))
    higher = sum(left > right for left, right in zip(full_counts, no_counts))
    equal = len(pairs) - lower - higher
    full_findings = sum(full_counts)
    no_findings = sum(no_counts)
    reduction = (no_findings - full_findings) / no_findings if no_findings else None
    return {
        "analyzer": analyzer,
        "analyzer_name": ANALYZER_LABELS[analyzer],
        "model": model,
        "mode": mode,
        "files": len(pairs),
        "full_findings": full_findings,
        "no_slither_findings": no_findings,
        "finding_reduction": reduction,
        "full_findings_per_kloc": findings_per_kloc(
            full_findings, [left for left, _ in pairs]
        ),
        "no_slither_findings_per_kloc": findings_per_kloc(
            no_findings, [right for _, right in pairs]
        ),
        "full_lower": lower,
        "equal": equal,
        "full_higher": higher,
        "discordant": lower + higher,
        "full_lower_among_discordant": (
            lower / (lower + higher) if lower + higher else None
        ),
        "median_difference": (
            median(left - right for left, right in zip(full_counts, no_counts))
            if pairs
            else None
        ),
        "p_value": exact_sign_test_p_value(lower, higher),
    }


def _add_holm(rows: List[Dict[str, Any]]) -> None:
    by_analyzer: Dict[str, List[Dict[str, Any]]] = {}
    for row in rows:
        if row["model"] != "ALL":
            by_analyzer.setdefault(row["analyzer"], []).append(row)
    for analyzer_rows in by_analyzer.values():
        adjusted = holm_adjust([float(row["p_value"]) for row in analyzer_rows])
        for row, value in zip(analyzer_rows, adjusted):
            row["holm_p_within_analyzer"] = value

    model_rows = [row for row in rows if row["model"] != "ALL"]
    global_adjusted = holm_adjust([float(row["p_value"]) for row in model_rows])
    for row, value in zip(model_rows, global_adjusted):
        row["holm_p_all_analyzers_models"] = value

    all_rows = [row for row in rows if row["model"] == "ALL"]
    all_adjusted = holm_adjust([float(row["p_value"]) for row in all_rows])
    for row, value in zip(all_rows, all_adjusted):
        row["holm_p_across_analyzers"] = value


def paired_rows(
    analyzers: Mapping[str, Mapping[Key, ScanRecord]],
    models: Sequence[str],
    mode: str,
) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for analyzer, records in analyzers.items():
        for model in models:
            rows.append(
                _paired_row(
                    analyzer,
                    model,
                    mode,
                    _eligible_pairs(records, model, mode),
                )
            )
        rows.append(
            _paired_row(
                analyzer,
                "ALL",
                mode,
                _eligible_pairs(records, None, mode),
            )
        )
    _add_holm(rows)
    return rows


def severity_rows(
    analyzers: Mapping[str, Mapping[Key, ScanRecord]],
    models: Sequence[str],
) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for analyzer, records in analyzers.items():
        for model in models:
            pairs = _eligible_pairs(records, model, "functionality_matched")
            impacts = sorted(
                {
                    impact
                    for left, right in pairs
                    for record in (left, right)
                    for impact in (record.finding_summary or {})
                }
            )
            for impact in impacts:
                full_values = [
                    int((left.finding_summary or {}).get(impact, 0))
                    for left, _ in pairs
                ]
                no_values = [
                    int((right.finding_summary or {}).get(impact, 0))
                    for _, right in pairs
                ]
                lower = sum(left < right for left, right in zip(full_values, no_values))
                higher = sum(
                    left > right for left, right in zip(full_values, no_values)
                )
                rows.append(
                    {
                        "analyzer": analyzer,
                        "analyzer_name": ANALYZER_LABELS[analyzer],
                        "model": model,
                        "impact": impact,
                        "files": len(pairs),
                        "full_findings": sum(full_values),
                        "no_slither_findings": sum(no_values),
                        "full_lower": lower,
                        "equal": len(pairs) - lower - higher,
                        "full_higher": higher,
                        "p_value": exact_sign_test_p_value(lower, higher),
                    }
                )
    return rows


def coverage_issue_rows(
    expected: Mapping[Key, ExpectedSample],
    analyzers: Mapping[str, Mapping[Key, ScanRecord]],
) -> List[Dict[str, Any]]:
    """List eval-compiled samples without a complete analyzer result."""
    rows: List[Dict[str, Any]] = []
    for analyzer, records in analyzers.items():
        for key, record in records.items():
            if (
                not (record.eval_compiled or record.feedback_compiled)
                or record.complete_scan
            ):
                continue
            sample = expected[key]
            rows.append(
                {
                    "analyzer": analyzer,
                    "analyzer_name": ANALYZER_LABELS[analyzer],
                    "source": record.source,
                    "variant_name": VARIANT_LABELS[record.source],
                    "model": record.model,
                    "row_id": sample.row_id,
                    "file_path": record.file_path,
                    "eval_full_pass": record.eval_full_pass,
                    "feedback_compiled": record.feedback_compiled,
                    "feedback_full_pass": record.feedback_full_pass,
                    "status": record.status,
                    "observed_findings": record.finding_count,
                }
            )
    return sorted(
        rows,
        key=lambda row: (
            row["analyzer"],
            row["source"],
            row["model"],
            row["row_id"],
        ),
    )


def _format_optional(value: Optional[float], digits: int = 2) -> str:
    return "N/A" if value is None else f"{value:.{digits}f}"


def print_main_table(rows: Sequence[Mapping[str, Any]]) -> None:
    print("\n[RQ2 cross-analyzer main table: eval functionality]")
    print_table(
        [
            "Analyzer",
            "Variant",
            "Model",
            "Compiled",
            "C.Scan",
            "Part",
            "C.Find",
            "C.F/KLOC",
            "FullPass",
            "FP.Scan",
            "Part",
            "FP.Find",
            "FP.F/KLOC",
            "SafeFull",
            "Secure@1",
            "Safe@Full",
        ],
        [
            [
                row["analyzer_name"],
                row["variant_name"],
                row["model"],
                f"{row['compiled']}/{row['attempted']}",
                f"{row['compiled_observed']}/{row['compiled']}",
                row["compiled_partial"],
                row["compiled_findings"],
                _format_optional(row["compiled_findings_per_kloc"]),
                f"{row['full_pass']}/{row['attempted']}",
                f"{row['full_pass_observed']}/{row['full_pass']}",
                row["full_pass_partial"],
                row["full_pass_findings"],
                _format_optional(row["full_pass_findings_per_kloc"]),
                row["safe_full_pass"],
                (
                    "N/A"
                    if row["secure_pass_at_1"] is None
                    else f"{row['secure_pass_at_1'] * 100:.2f}%"
                ),
                (
                    "N/A"
                    if row["safe_at_full_pass"] is None
                    else f"{row['safe_at_full_pass'] * 100:.2f}%"
                ),
            ]
            for row in rows
        ],
    )
    print("C = eval-compiled selected code; FP = eval FullPass; Part = partial parse.")
    print("SafeFull requires a complete scan and zero findings.")


def print_paired_table(rows: Sequence[Mapping[str, Any]], title: str) -> None:
    print(f"\n[{title}]")
    print_table(
        [
            "Analyzer",
            "Model",
            "N",
            "Full/No Find",
            "Reduction",
            "Lower/Equal/Higher",
            "p",
            "Holm",
        ],
        [
            [
                row["analyzer_name"],
                row["model"],
                row["files"],
                f"{row['full_findings']}/{row['no_slither_findings']}",
                (
                    "N/A"
                    if row["finding_reduction"] is None
                    else f"{row['finding_reduction'] * 100:.2f}%"
                ),
                f"{row['full_lower']}/{row['equal']}/{row['full_higher']}",
                f"{row['p_value']:.6f}",
                f"{row.get('holm_p_across_analyzers', row.get('holm_p_within_analyzer', 1.0)):.6f}",
            ]
            for row in rows
        ],
    )
    print("Lower/equal/higher is Full relative to w/o Slither feedback.")


def print_per_model_paired_table(rows: Sequence[Mapping[str, Any]], title: str) -> None:
    print(f"\n[{title}]")
    print_table(
        [
            "Analyzer",
            "Model",
            "N",
            "Full/No Find",
            "Reduction",
            "Lower/Equal/Higher",
            "Holm p",
        ],
        [
            [
                row["analyzer_name"],
                row["model"],
                row["files"],
                f"{row['full_findings']}/{row['no_slither_findings']}",
                (
                    "N/A"
                    if row["finding_reduction"] is None
                    else f"{row['finding_reduction'] * 100:.2f}%"
                ),
                f"{row['full_lower']}/{row['equal']}/{row['full_higher']}",
                f"{row.get('holm_p_within_analyzer', 1.0):.6f}",
            ]
            for row in rows
            if row["model"] != "ALL"
        ],
    )
    print("Holm correction is applied across the three models within each analyzer.")


def write_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames: List[str] = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def analyzer_ranking(
    functionality_rows: Sequence[Mapping[str, Any]],
    main_rows: Sequence[Mapping[str, Any]],
) -> List[Dict[str, Any]]:
    ranking: List[Dict[str, Any]] = []
    for row in functionality_rows:
        if row["model"] != "ALL" or row["analyzer"] == "slither":
            continue
        analyzer_main = [
            item for item in main_rows if item["analyzer"] == row["analyzer"]
        ]
        compiled = sum(int(item["compiled"]) for item in analyzer_main)
        complete = sum(int(item["compiled_complete"]) for item in analyzer_main)
        direction_score = row["full_lower"] - row["full_higher"]
        supports_full = (
            direction_score > 0
            and row["finding_reduction"] is not None
            and row["finding_reduction"] > 0
        )
        ranking.append(
            {
                "analyzer": row["analyzer"],
                "analyzer_name": row["analyzer_name"],
                "supports_full": supports_full,
                "complete_compiled_coverage": complete / compiled if compiled else None,
                "functionality_matched_pairs": row["files"],
                "full_findings": row["full_findings"],
                "no_slither_findings": row["no_slither_findings"],
                "finding_reduction": row["finding_reduction"],
                "full_lower": row["full_lower"],
                "equal": row["equal"],
                "full_higher": row["full_higher"],
                "p_value": row["p_value"],
                "holm_p_across_analyzers": row.get("holm_p_across_analyzers"),
                "direction_score": direction_score,
            }
        )
    return sorted(
        ranking,
        key=lambda row: (
            not row["supports_full"],
            -(row["complete_compiled_coverage"] or 0.0),
            -(row["direction_score"] or 0),
            row["holm_p_across_analyzers"] or 1.0,
        ),
    )


def run_statistics(
    db_path: str,
    eval_report: Path,
    summaries: Mapping[str, Path],
    models: Sequence[str],
    out_dir: Path,
) -> Dict[str, Any]:
    expected, eval_meta = load_expected_samples(db_path, eval_report, models)
    analyzers: Dict[str, Dict[Key, ScanRecord]] = {"slither": slither_records(expected)}
    for analyzer, path in summaries.items():
        analyzers[analyzer] = load_external_records(analyzer, path, expected)

    main_rows = [
        _main_row(analyzer, source, model, records)
        for analyzer, records in analyzers.items()
        for source in DEFAULT_SOURCES
        for model in models
    ]
    common = paired_rows(analyzers, models, "common_compiled")
    feedback_functionality = paired_rows(
        analyzers, models, "feedback_functionality_matched"
    )
    feedback_both_full_pass = paired_rows(analyzers, models, "feedback_both_full_pass")
    functionality = paired_rows(analyzers, models, "functionality_matched")
    both_full_pass = paired_rows(analyzers, models, "both_full_pass")
    severity = severity_rows(analyzers, models)
    coverage_issues = coverage_issue_rows(expected, analyzers)
    ranking = analyzer_ranking(functionality, main_rows)

    result = {
        "db_path": db_path,
        "eval_report": str(eval_report),
        "eval_meta": dict(eval_meta),
        "selection_policy": SELECTION_POLICY,
        "analyzers": list(analyzers),
        "summaries": {key: str(value) for key, value in summaries.items()},
        "main_table": main_rows,
        "paired_common_compiled_complete": common,
        "paired_feedback_functionality_matched_complete": feedback_functionality,
        "paired_feedback_both_full_pass_complete": feedback_both_full_pass,
        "paired_eval_functionality_matched_complete": functionality,
        "paired_eval_both_full_pass_complete": both_full_pass,
        "paired_functionality_matched_complete": functionality,
        "paired_both_full_pass_complete": both_full_pass,
        "severity_functionality_matched_complete": severity,
        "coverage_issues": coverage_issues,
        "cross_analyzer_ranking": ranking,
        "notes": [
            "Checkpoint selection is reconstructed from the database using the experiment-time test-first-security-second rule.",
            "Compilation, test passes, and FullPass come from the regenerated RQ2 eval report.",
            "Feedback-test paired tables use the selected-round feedback (passed,total) stored in the database.",
            "Semgrep partial parses retain observed findings but are never classified as safe.",
            "Strict paired tests require complete scans on both Full and no-Slither outputs.",
            "Analyzer choice should be justified by independence, coverage, and statistical consistency rather than the most favorable post-hoc result alone.",
            "The descriptive analyzer ranking places directionally supportive results first; it is not a statistical model-selection procedure.",
        ],
    }

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "comparison.json").write_text(
        json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False),
        encoding="utf-8",
    )
    write_csv(out_dir / "main_table.csv", main_rows)
    write_csv(out_dir / "paired_common_compiled.csv", common)
    write_csv(
        out_dir / "paired_feedback_functionality_matched.csv",
        feedback_functionality,
    )
    write_csv(
        out_dir / "paired_feedback_both_full_pass.csv",
        feedback_both_full_pass,
    )
    write_csv(out_dir / "paired_functionality_matched.csv", functionality)
    write_csv(out_dir / "paired_both_full_pass.csv", both_full_pass)
    write_csv(out_dir / "paired_eval_functionality_matched.csv", functionality)
    write_csv(out_dir / "paired_eval_both_full_pass.csv", both_full_pass)
    write_csv(
        out_dir / "paired_feedback_eval_per_model.csv",
        [
            row
            for rows in (
                feedback_functionality,
                feedback_both_full_pass,
                functionality,
                both_full_pass,
            )
            for row in rows
            if row["model"] != "ALL"
        ],
    )
    write_csv(out_dir / "severity_functionality_matched.csv", severity)
    write_csv(out_dir / "coverage_issues.csv", coverage_issues)
    write_csv(out_dir / "analyzer_ranking.csv", ranking)

    print_main_table(main_rows)
    print_per_model_paired_table(
        feedback_functionality,
        "Feedback tests: identical selected (passed,total)",
    )
    print_per_model_paired_table(
        feedback_both_full_pass,
        "Feedback tests: both selected outputs pass all tests",
    )
    print_per_model_paired_table(
        functionality,
        "Independent eval: identical (passed,expected_tests)",
    )
    print_per_model_paired_table(
        both_full_pass,
        "Independent eval: both selected outputs pass all tests",
    )
    print_paired_table(
        [row for row in functionality if row["model"] == "ALL"],
        "Strict functionality-matched complete scans, pooled across models",
    )
    print_paired_table(
        [row for row in both_full_pass if row["model"] == "ALL"],
        "Strict pairs where both variants pass every eval test",
    )
    print(f"\nWrote cross-analyzer results under: {out_dir}")
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="RQ2 cross-analyzer security statistics"
    )
    parser.add_argument("--db", default="output/progress.db")
    parser.add_argument("--eval-report", default=DEFAULT_EVAL_REPORT)
    parser.add_argument("--aderyn-summary", default=str(EXTERNAL_SUMMARIES["aderyn"]))
    parser.add_argument("--wake-summary", default=str(EXTERNAL_SUMMARIES["wake"]))
    parser.add_argument("--semgrep-summary", default=str(EXTERNAL_SUMMARIES["semgrep"]))
    parser.add_argument("--models", default=",".join(TARGET_MODELS))
    parser.add_argument("--out-dir", default="stats/rq2_cross_analyzer")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    models = [item.strip() for item in args.models.split(",") if item.strip()]
    summaries = {
        "aderyn": Path(args.aderyn_summary),
        "wake": Path(args.wake_summary),
        "semgrep": Path(args.semgrep_summary),
    }
    try:
        run_statistics(
            args.db,
            Path(args.eval_report),
            summaries,
            models,
            Path(args.out_dir),
        )
    except (OSError, StatisticsError, ValueError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
