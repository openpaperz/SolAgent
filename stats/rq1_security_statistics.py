#!/usr/bin/env python3
"""RQ1 security statistics for generated Solidity files.

The primary metric is SecurePass@1: the share of attempted files that both
pass every test and have a valid zero-vulnerability Slither result. Conditional
tables retain vulnerability prevalence and vulnerability density for compiled
and fully-passing files.

Usage:
    python stats/rq1_security_statistics.py --db output/progress.db
"""

import argparse
import json
import math
import os
import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.code_metrics import count_loc, extract_code_from_messages


TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
AGENT_TYPES = ["metagpt", "deepcode", "qwenagent", "copilot"]

RAW_MODEL = "RawModel"
SOLAGENT = "SolAgent"
AGENT_DISPLAY_NAMES = {
    "metagpt": "MetaGPT",
    "deepcode": "DeepCode",
    "qwenagent": "QwenAgent",
    "copilot": "Copilot",
}


class SecurityStatisticsError(RuntimeError):
    """Raised when the database cannot support the requested analysis."""


@dataclass(frozen=True)
class FileSecurityRecord:
    """Normalized security and functionality result for one generated file."""

    method: str
    model: str
    file_path: str
    test_pass: int
    test_total: int
    vuln_count: Optional[int]
    sloc: Optional[int]

    @property
    def compiled(self) -> bool:
        return self.test_total > 0

    @property
    def full_pass(self) -> bool:
        return self.compiled and self.test_pass == self.test_total

    @property
    def scan_valid(self) -> bool:
        return self.vuln_count is not None

    @property
    def vulnerable(self) -> bool:
        return self.scan_valid and self.vuln_count > 0

    @property
    def safe(self) -> bool:
        return self.scan_valid and self.vuln_count == 0

    @property
    def safe_full_pass(self) -> bool:
        return self.full_pass and self.safe


@dataclass(frozen=True)
class PrimarySummary:
    attempted: int
    compiled: int
    full_pass: int
    safe_full_pass: int
    secure_pass_rate: float
    safe_given_full_pass_rate: Optional[float]
    ci_low: float
    ci_high: float


@dataclass(frozen=True)
class ConditionalSummary:
    eligible: int
    scanned: int
    vulnerable_files: int
    vulnerable_file_rate: Optional[float]
    loc_covered: int
    total_vulnerabilities: int
    total_sloc: int
    vulnerabilities_per_kloc: Optional[float]


@dataclass
class PairwiseResult:
    model: str
    baseline: str
    common_files: int
    solagent_only: int
    baseline_only: int
    net_gain: int
    delta_percentage_points: float
    p_value: float
    adjusted_p_value: float = 1.0


def safe_json_loads(value: Any, default: Any) -> Any:
    """Decode JSON without allowing malformed stored values to abort analysis."""
    if isinstance(value, (dict, list)):
        return value
    if not value:
        return default
    try:
        return json.loads(value)
    except (json.JSONDecodeError, TypeError):
        return default


def as_nonnegative_int(value: Any) -> Optional[int]:
    """Return a non-negative integral value, otherwise mark it missing."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    if not math.isfinite(float(value)) or float(value) < 0 or not float(value).is_integer():
        return None
    return int(value)


def as_count(value: Any) -> int:
    normalized = as_nonnegative_int(value)
    return normalized if normalized is not None else 0


def get_best_pass_round(
    round_test_json: Any, round_vuln_json: Any = None
) -> Tuple[int, int, int]:
    """Select the best functional round, then the least vulnerable version.

    Selection is deterministic and lexicographic:
    1. Maximize the number of passed tests.
    2. Starting from the earliest max-pass round, only compare rounds with the
       exact same ``passed/total`` result.
    3. Prefer the smallest valid non-negative Slither finding count. A missing
       or invalid scan never beats a valid scan.
    4. If still tied, prefer the earliest round number.
    """
    if not isinstance(round_test_json, dict):
        return (0, 0, 0)

    candidates: List[Tuple[int, int, int]] = []
    for round_idx, test_info in round_test_json.items():
        if not isinstance(test_info, dict):
            continue
        pass_count = as_count(test_info.get("pass", test_info.get("passed", 0)))
        total_count = as_count(test_info.get("total", 0))
        try:
            normalized_round = int(round_idx)
        except (TypeError, ValueError):
            continue
        candidates.append((normalized_round, pass_count, total_count))

    if not candidates:
        return (0, 0, 0)

    max_pass = max(candidate[1] for candidate in candidates)
    max_pass_candidates = [
        candidate for candidate in candidates if candidate[1] == max_pass
    ]
    earliest_max_pass = min(max_pass_candidates, key=lambda candidate: candidate[0])
    target_total = earliest_max_pass[2]
    comparable_candidates = [
        candidate
        for candidate in max_pass_candidates
        if candidate[2] == target_total
    ]

    vulnerabilities = round_vuln_json if isinstance(round_vuln_json, dict) else {}

    def selection_key(candidate: Tuple[int, int, int]) -> Tuple[bool, float, int]:
        round_idx = candidate[0]
        vuln_count = as_nonnegative_int(vulnerabilities.get(str(round_idx)))
        return (
            vuln_count is None,
            float(vuln_count) if vuln_count is not None else math.inf,
            round_idx,
        )

    best_round, best_pass, best_total = min(
        comparable_candidates, key=selection_key
    )
    return (best_round, best_pass, best_total)


def _sloc_from_messages(
    messages: Any, file_path: str, agent_type: str = ""
) -> Optional[int]:
    code = extract_code_from_messages(messages, file_path, agent_type=agent_type)
    if not code:
        return None
    sloc = count_loc(code)
    return sloc if sloc > 0 else None


def record_from_final_row(
    row: Mapping[str, Any], method: str, model: str, agent_type: str = ""
) -> FileSecurityRecord:
    """Normalize a RawModel or single-shot agent database row."""
    test_pass = as_count(row.get("test_pass"))
    test_total = as_count(row.get("test_total"))
    file_path = str(row.get("file_path") or "")
    vuln_count = as_nonnegative_int(row.get("vuln_count"))
    sloc = None
    if test_total > 0:
        messages = safe_json_loads(row.get("coding_messages"), [])
        sloc = _sloc_from_messages(messages, file_path, agent_type=agent_type)

    return FileSecurityRecord(
        method=method,
        model=model,
        file_path=file_path,
        test_pass=test_pass,
        test_total=test_total,
        vuln_count=vuln_count,
        sloc=sloc,
    )


def record_from_round_row(
    row: Mapping[str, Any], method: str, model: str
) -> FileSecurityRecord:
    """Normalize a SolAgent row using one best-test round for all metrics."""
    round_tests = safe_json_loads(row.get("test_json"), {})
    round_vulns = safe_json_loads(row.get("round_vuln_count"), {})
    best_round, test_pass, test_total = get_best_pass_round(
        round_tests, round_vulns
    )
    file_path = str(row.get("file_path") or "")

    raw_vuln = round_vulns.get(str(best_round)) if isinstance(round_vulns, dict) else None
    vuln_count = as_nonnegative_int(raw_vuln)

    sloc = None
    if test_total > 0:
        round_messages = safe_json_loads(row.get("round_messages"), {})
        messages = (
            round_messages.get(str(best_round), [])
            if isinstance(round_messages, dict)
            else []
        )
        sloc = _sloc_from_messages(messages, file_path)

    return FileSecurityRecord(
        method=method,
        model=model,
        file_path=file_path,
        test_pass=test_pass,
        test_total=test_total,
        vuln_count=vuln_count,
        sloc=sloc,
    )


def wilson_interval(successes: int, total: int, z: float = 1.959963984540054) -> Tuple[float, float]:
    """Compute a two-sided Wilson score interval for a binomial proportion."""
    if total <= 0:
        return (0.0, 0.0)
    proportion = successes / total
    z_squared = z * z
    denominator = 1.0 + z_squared / total
    center = (proportion + z_squared / (2.0 * total)) / denominator
    margin = (
        z
        * math.sqrt(
            proportion * (1.0 - proportion) / total
            + z_squared / (4.0 * total * total)
        )
        / denominator
    )
    return (max(0.0, center - margin), min(1.0, center + margin))


def summarize_primary(records: Sequence[FileSecurityRecord]) -> PrimarySummary:
    attempted = len(records)
    compiled = sum(record.compiled for record in records)
    full_pass = sum(record.full_pass for record in records)
    safe_full_pass = sum(record.safe_full_pass for record in records)
    rate = safe_full_pass / attempted if attempted else 0.0
    safe_given_full_pass_rate = safe_full_pass / full_pass if full_pass else None
    ci_low, ci_high = wilson_interval(safe_full_pass, attempted)
    return PrimarySummary(
        attempted=attempted,
        compiled=compiled,
        full_pass=full_pass,
        safe_full_pass=safe_full_pass,
        secure_pass_rate=rate,
        safe_given_full_pass_rate=safe_given_full_pass_rate,
        ci_low=ci_low,
        ci_high=ci_high,
    )


def summarize_condition(
    records: Sequence[FileSecurityRecord], condition: str
) -> ConditionalSummary:
    if condition == "compiled":
        eligible_records = [record for record in records if record.compiled]
    elif condition == "full_pass":
        eligible_records = [record for record in records if record.full_pass]
    else:
        raise ValueError(f"Unsupported condition: {condition}")

    scanned_records = [record for record in eligible_records if record.scan_valid]
    vulnerable_files = sum(record.vulnerable for record in scanned_records)
    vulnerable_rate = (
        vulnerable_files / len(scanned_records) if scanned_records else None
    )

    loc_records = [
        record
        for record in scanned_records
        if record.sloc is not None and record.sloc > 0
    ]
    total_vulnerabilities = sum(record.vuln_count or 0 for record in loc_records)
    total_sloc = sum(record.sloc or 0 for record in loc_records)
    density = (
        total_vulnerabilities * 1000.0 / total_sloc if total_sloc > 0 else None
    )

    return ConditionalSummary(
        eligible=len(eligible_records),
        scanned=len(scanned_records),
        vulnerable_files=vulnerable_files,
        vulnerable_file_rate=vulnerable_rate,
        loc_covered=len(loc_records),
        total_vulnerabilities=total_vulnerabilities,
        total_sloc=total_sloc,
        vulnerabilities_per_kloc=density,
    )


def exact_mcnemar_p_value(solagent_only: int, baseline_only: int) -> float:
    """Two-sided exact McNemar p-value via the conditional binomial test."""
    discordant = solagent_only + baseline_only
    if discordant == 0:
        return 1.0
    lower_tail = min(solagent_only, baseline_only)
    probability = sum(
        math.comb(discordant, value) for value in range(lower_tail + 1)
    ) / (2 ** discordant)
    return min(1.0, 2.0 * probability)


def apply_holm_correction(results: Sequence[PairwiseResult]) -> None:
    """Apply Holm's step-down correction in place to one model family."""
    ordered = sorted(enumerate(results), key=lambda item: item[1].p_value)
    running_max = 0.0
    count = len(ordered)
    for rank, (_, result) in enumerate(ordered):
        adjusted = min(1.0, (count - rank) * result.p_value)
        running_max = max(running_max, adjusted)
        result.adjusted_p_value = running_max


def build_pairwise_results(
    grouped_records: Mapping[Tuple[str, str], Sequence[FileSecurityRecord]],
    models: Sequence[str],
    baseline_methods: Sequence[str],
) -> List[PairwiseResult]:
    """Pair SolAgent and baselines by file path, correcting within each model."""
    output: List[PairwiseResult] = []
    for model in models:
        solagent_records = grouped_records.get((SOLAGENT, model))
        if not solagent_records:
            continue
        solagent_by_file = {record.file_path: record for record in solagent_records}
        model_results: List[PairwiseResult] = []

        for baseline in baseline_methods:
            baseline_records = grouped_records.get((baseline, model))
            if not baseline_records:
                continue
            baseline_by_file = {record.file_path: record for record in baseline_records}
            common_files = sorted(set(solagent_by_file) & set(baseline_by_file))
            if not common_files:
                continue

            solagent_only = sum(
                solagent_by_file[path].safe_full_pass
                and not baseline_by_file[path].safe_full_pass
                for path in common_files
            )
            baseline_only = sum(
                baseline_by_file[path].safe_full_pass
                and not solagent_by_file[path].safe_full_pass
                for path in common_files
            )
            net_gain = solagent_only - baseline_only
            result = PairwiseResult(
                model=model,
                baseline=baseline,
                common_files=len(common_files),
                solagent_only=solagent_only,
                baseline_only=baseline_only,
                net_gain=net_gain,
                delta_percentage_points=net_gain / len(common_files) * 100.0,
                p_value=exact_mcnemar_p_value(solagent_only, baseline_only),
            )
            model_results.append(result)

        apply_holm_correction(model_results)
        output.extend(model_results)

    return output


def _connect_readonly(db_path: str) -> sqlite3.Connection:
    path = Path(db_path)
    if not path.is_file():
        raise SecurityStatisticsError(f"Database file not found: {db_path}")
    try:
        connection = sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True)
    except sqlite3.Error as exc:
        raise SecurityStatisticsError(f"Unable to open database: {exc}") from exc
    connection.row_factory = sqlite3.Row
    return connection


def _validate_tables(connection: sqlite3.Connection) -> None:
    required = {
        "progress_tracker_rawmodel",
        "process_tracking",
        "progress_tracker_agent",
    }
    available = {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        ).fetchall()
    }
    missing = sorted(required - available)
    if missing:
        raise SecurityStatisticsError(
            "Database is missing required table(s): " + ", ".join(missing)
        )


def _fetch_rows(
    connection: sqlite3.Connection,
    table: str,
    model: str,
    agent_type: Optional[str] = None,
) -> List[Dict[str, Any]]:
    allowed_tables = {
        "progress_tracker_rawmodel",
        "process_tracking",
        "progress_tracker_agent",
    }
    if table not in allowed_tables:
        raise SecurityStatisticsError(f"Unsupported table: {table}")

    query = f"SELECT * FROM {table} WHERE model_coding = ? AND status IN (1, 2)"
    params: List[Any] = [model]
    if agent_type is not None:
        query += " AND agent_type = ?"
        params.append(agent_type)
    query += " ORDER BY id"
    return [dict(row) for row in connection.execute(query, params).fetchall()]


def collect_records(
    db_path: str, models: Sequence[str], agents: Sequence[str]
) -> Tuple[Dict[Tuple[str, str], List[FileSecurityRecord]], List[str]]:
    """Load and normalize every requested generated-code method/model group."""
    connection = _connect_readonly(db_path)
    warnings: List[str] = []
    groups: Dict[Tuple[str, str], List[FileSecurityRecord]] = {}
    try:
        _validate_tables(connection)
        for model in models:
            raw_rows = _fetch_rows(connection, "progress_tracker_rawmodel", model)
            if raw_rows:
                groups[(RAW_MODEL, model)] = [
                    record_from_final_row(row, RAW_MODEL, model) for row in raw_rows
                ]
            else:
                warnings.append(f"No {RAW_MODEL} rows for model {model}")

            rows = _fetch_rows(connection, "process_tracking", model)
            if rows:
                groups[(SOLAGENT, model)] = [
                    record_from_round_row(row, SOLAGENT, model) for row in rows
                ]
            else:
                warnings.append(f"No {SOLAGENT} rows for model {model}")

            for agent_type in agents:
                method = AGENT_DISPLAY_NAMES.get(agent_type, agent_type)
                rows = _fetch_rows(
                    connection,
                    "progress_tracker_agent",
                    model,
                    agent_type=agent_type,
                )
                if rows:
                    groups[(method, model)] = [
                        record_from_final_row(
                            row, method, model, agent_type=agent_type
                        )
                        for row in rows
                    ]
                else:
                    warnings.append(f"No {method} rows for model {model}")
    except sqlite3.Error as exc:
        raise SecurityStatisticsError(f"Database query failed: {exc}") from exc
    finally:
        connection.close()

    if not groups:
        raise SecurityStatisticsError("No completed rows found for the requested groups")
    return groups, warnings


def _percentage(value: Optional[float], precision: int = 2) -> str:
    return "N/A" if value is None else f"{value * 100:.{precision}f}%"


def _number(value: Optional[float], precision: int = 2) -> str:
    return "N/A" if value is None else f"{value:.{precision}f}"


def _coverage(numerator: int, denominator: int) -> str:
    if denominator <= 0:
        return f"{numerator}/{denominator} (N/A)"
    return f"{numerator}/{denominator} ({numerator / denominator * 100:.1f}%)"


def print_table(headers: Sequence[str], rows: Sequence[Sequence[Any]]) -> None:
    string_rows = [[str(value) for value in row] for row in rows]
    widths = [len(header) for header in headers]
    for row in string_rows:
        for index, value in enumerate(row):
            widths[index] = max(widths[index], len(value))
    line = "  ".join(header.ljust(widths[index]) for index, header in enumerate(headers))
    print(line)
    print("=" * len(line))
    for row in string_rows:
        print("  ".join(value.ljust(widths[index]) for index, value in enumerate(row)))


def print_results(
    grouped_records: Mapping[Tuple[str, str], Sequence[FileSecurityRecord]],
    models: Sequence[str],
    agents: Sequence[str],
) -> None:
    method_order = [
        RAW_MODEL,
        SOLAGENT,
        *(AGENT_DISPLAY_NAMES.get(agent, agent) for agent in agents),
    ]
    ordered_keys = [
        (method, model)
        for model in models
        for method in method_order
        if (method, model) in grouped_records
    ]

    print("\n" + "=" * 120)
    print("RQ-1 Security Statistics for Generated Code")
    print("=" * 120)

    print("\n【Primary Metric: SecurePass@1】")
    primary_rows = []
    for method, model in ordered_keys:
        summary = summarize_primary(grouped_records[(method, model)])
        primary_rows.append(
            [
                method,
                model,
                summary.attempted,
                summary.compiled,
                summary.full_pass,
                summary.safe_full_pass,
                _percentage(summary.secure_pass_rate),
                f"{summary.safe_full_pass}/{summary.full_pass} "
                f"({_percentage(summary.safe_given_full_pass_rate)})",
                f"[{_percentage(summary.ci_low)}, {_percentage(summary.ci_high)}]",
            ]
        )
    print_table(
        [
            "Method",
            "Model",
            "Attempted",
            "Compiled",
            "FullPass",
            "SafeFullPass",
            "SecurePass@1",
            "Safe@FullPass",
            "95% Wilson CI",
        ],
        primary_rows,
    )

    baseline_methods = [
        RAW_MODEL,
        *(AGENT_DISPLAY_NAMES.get(agent, agent) for agent in agents),
    ]
    paired = build_pairwise_results(grouped_records, models, baseline_methods)
    print("\n【Paired SecurePass@1: SolAgent vs. Baselines】")
    paired_rows = [
        [
            result.model,
            result.baseline,
            result.common_files,
            result.solagent_only,
            result.baseline_only,
            f"{result.net_gain:+d}",
            f"{result.delta_percentage_points:+.2f} pp",
            f"{result.p_value:.4g}",
            f"{result.adjusted_p_value:.4g}",
        ]
        for result in paired
    ]
    if paired_rows:
        print_table(
            [
                "Model",
                "Baseline",
                "Common",
                "Sol-only",
                "Base-only",
                "Net",
                "Delta",
                "McNemar p",
                "Holm p",
            ],
            paired_rows,
        )
    else:
        print("No pairwise comparisons available.")

    labels = {
        "compiled": "Compiled Files",
        "full_pass": "Full-Test-Pass Files",
    }
    for condition in ("compiled", "full_pass"):
        print(f"\n【Conditional Security: {labels[condition]}】")
        conditional_rows = []
        for method, model in ordered_keys:
            summary = summarize_condition(grouped_records[(method, model)], condition)
            conditional_rows.append(
                [
                    method,
                    model,
                    summary.eligible,
                    _coverage(summary.scanned, summary.eligible),
                    summary.vulnerable_files,
                    _percentage(summary.vulnerable_file_rate),
                    _coverage(summary.loc_covered, summary.scanned),
                    summary.total_vulnerabilities,
                    f"{summary.total_sloc / 1000.0:.3f}",
                    _number(summary.vulnerabilities_per_kloc),
                ]
            )
        print_table(
            [
                "Method",
                "Model",
                "Eligible",
                "Scan Coverage",
                "Vuln Files",
                "Vuln File %",
                "LOC Coverage",
                "Vulns",
                "KLOC",
                "Vuln/KLOC",
            ],
            conditional_rows,
        )

    print("\nNotes:")
    print("- SecurePass@1 = full-test-pass and zero-vulnerability files / attempted files.")
    print("- Safe@FullPass = full-test-pass and zero-vulnerability files / full-test-pass files.")
    print("  A full-test-pass file without a valid scan is conservatively not counted as safe.")
    print("- Missing or negative vulnerability counts are unscanned, never safe.")
    print("- Conditional vulnerability rates use valid scans as their denominator.")
    print("- Vulnerability density is a micro-average over files with valid scans and SLOC.")
    print("- Holm correction is applied to all SolAgent comparisons within each model.")


def main() -> int:
    parser = argparse.ArgumentParser(description="RQ1 generated-code security statistics")
    parser.add_argument(
        "--db", type=str, default="output/progress.db", help="Path to progress database"
    )
    parser.add_argument(
        "--models",
        type=str,
        default=",".join(TARGET_MODELS),
        help="Comma-separated model names",
    )
    parser.add_argument(
        "--agents",
        type=str,
        default=",".join(AGENT_TYPES),
        help="Comma-separated agent types",
    )
    args = parser.parse_args()

    models = [value.strip() for value in args.models.split(",") if value.strip()]
    agents = [value.strip() for value in args.agents.split(",") if value.strip()]
    unknown_agents = [agent for agent in agents if agent not in AGENT_DISPLAY_NAMES]
    if unknown_agents:
        print(
            "Error: unsupported agent type(s): " + ", ".join(unknown_agents),
            file=sys.stderr,
        )
        return 2
    if not models:
        print("Error: --models must contain at least one model", file=sys.stderr)
        return 2

    try:
        groups, warnings = collect_records(args.db, models, agents)
    except SecurityStatisticsError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    for warning in warnings:
        print(f"Warning: {warning}", file=sys.stderr)
    print_results(groups, models, agents)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
