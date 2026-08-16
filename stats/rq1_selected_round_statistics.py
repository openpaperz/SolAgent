#!/usr/bin/env python3
"""Reproduce the selected-candidate round distribution reported in RQ1.

For each completed SolAgent task, the script applies the same Best Code
Tracking rule used by the RQ1 security statistics. It then reports the mean,
median, linear 90th percentile, and maximum selected round by model and across
all requested models.

Usage:
    python stats/rq1_selected_round_statistics.py
    python stats/rq1_selected_round_statistics.py --format latex
    python stats/rq1_selected_round_statistics.py --format json
"""

import argparse
import json
import math
import sqlite3
import statistics
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, List, Mapping, Sequence


STATS_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = STATS_DIR.parent
sys.path.insert(0, str(PROJECT_ROOT))

from stats.rq1_security_statistics import (  # noqa: E402
    TARGET_MODELS,
    get_best_pass_round,
    safe_json_loads,
)


DEFAULT_DB_PATH = PROJECT_ROOT / "output" / "progress.db"
MODEL_DISPLAY_NAMES = {
    "claude-sonnet-4-5": "Claude-Sonnet-4.5",
    "gpt-5-mini": "GPT-5-Mini",
    "gpt-5.1": "GPT-5.1",
}


class SelectedRoundStatisticsError(RuntimeError):
    """Raised when selected-round statistics cannot be computed."""


@dataclass(frozen=True)
class RoundDistribution:
    """Summary of selected candidate rounds for one model group."""

    model: str
    count: int
    mean: float
    median: float
    p90: float
    maximum: int


def linear_percentile(values: Sequence[int], quantile: float) -> float:
    """Return a linearly interpolated percentile at ``quantile`` in [0, 1]."""
    if not values:
        raise ValueError("percentile requires at least one value")
    if not 0.0 <= quantile <= 1.0:
        raise ValueError("quantile must be between 0 and 1")

    ordered = sorted(values)
    position = quantile * (len(ordered) - 1)
    lower_index = math.floor(position)
    upper_index = math.ceil(position)
    if lower_index == upper_index:
        return float(ordered[lower_index])

    fraction = position - lower_index
    lower = ordered[lower_index]
    upper = ordered[upper_index]
    return lower + (upper - lower) * fraction


def summarize_rounds(model: str, rounds: Sequence[int]) -> RoundDistribution:
    """Compute the Table 8 statistics for one non-empty round sequence."""
    if not rounds:
        raise SelectedRoundStatisticsError(
            f"No eligible selected candidate rounds for model: {model}"
        )
    return RoundDistribution(
        model=model,
        count=len(rounds),
        mean=statistics.fmean(rounds),
        median=float(statistics.median(rounds)),
        p90=linear_percentile(rounds, 0.9),
        maximum=max(rounds),
    )


def collect_selected_rounds(
    db_path: Path, models: Sequence[str]
) -> Dict[str, List[int]]:
    """Load selected rounds for completed tasks with an executable candidate."""
    path = Path(db_path)
    if not path.is_file():
        raise SelectedRoundStatisticsError(f"Database file not found: {path}")
    if not models:
        raise SelectedRoundStatisticsError("At least one model is required")

    connection = None
    try:
        connection = sqlite3.connect(
            f"{path.resolve().as_uri()}?mode=ro", uri=True
        )
        connection.row_factory = sqlite3.Row

        available_tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }
        if "process_tracking" not in available_tables:
            raise SelectedRoundStatisticsError(
                "Database is missing required table: process_tracking"
            )

        available_columns = {
            row[1]
            for row in connection.execute(
                "PRAGMA table_info(process_tracking)"
            ).fetchall()
        }
        required_columns = {
            "id",
            "model_coding",
            "status",
            "test_json",
            "round_vuln_count",
        }
        missing_columns = sorted(required_columns - available_columns)
        if missing_columns:
            raise SelectedRoundStatisticsError(
                "process_tracking is missing required column(s): "
                + ", ".join(missing_columns)
            )

        placeholders = ", ".join("?" for _ in models)
        query = f"""
            SELECT model_coding, test_json, round_vuln_count
            FROM process_tracking
            WHERE status IN (1, 2)
              AND model_coding IN ({placeholders})
            ORDER BY id
        """
        rows = connection.execute(query, tuple(models)).fetchall()
    except sqlite3.Error as exc:
        raise SelectedRoundStatisticsError(
            f"Unable to read selected-round data: {exc}"
        ) from exc
    finally:
        if connection is not None:
            connection.close()

    rounds_by_model: Dict[str, List[int]] = {model: [] for model in models}
    for row in rows:
        round_tests = safe_json_loads(row["test_json"], {})
        round_vulnerabilities = safe_json_loads(row["round_vuln_count"], {})
        best_round, _, best_total = get_best_pass_round(
            round_tests, round_vulnerabilities
        )
        if best_round > 0 and best_total > 0:
            rounds_by_model[row["model_coding"]].append(best_round)

    return rounds_by_model


def build_distributions(
    rounds_by_model: Mapping[str, Sequence[int]], models: Sequence[str]
) -> List[RoundDistribution]:
    """Build per-model distributions followed by a pooled all-model summary."""
    distributions = [
        summarize_rounds(model, rounds_by_model.get(model, [])) for model in models
    ]
    pooled_rounds = [
        round_number
        for model in models
        for round_number in rounds_by_model.get(model, [])
    ]
    distributions.append(summarize_rounds("all", pooled_rounds))
    return distributions


def display_model(model: str) -> str:
    if model == "all":
        return "All models"
    return MODEL_DISPLAY_NAMES.get(model, model)


def compact_number(value: float) -> str:
    if math.isclose(value, round(value), abs_tol=1e-9):
        return str(round(value))
    return f"{value:.2f}".rstrip("0").rstrip(".")


def print_text(distributions: Sequence[RoundDistribution]) -> None:
    headers = ["Model", "Mean", "Median", "P90", "Max"]
    rows = [
        [
            display_model(item.model),
            f"{item.mean:.2f}",
            compact_number(item.median),
            compact_number(item.p90),
            str(item.maximum),
        ]
        for item in distributions
    ]
    widths = [len(header) for header in headers]
    for row in rows:
        for index, value in enumerate(row):
            widths[index] = max(widths[index], len(value))

    print("Selected candidate round distribution")
    print("  ".join(header.ljust(widths[index]) for index, header in enumerate(headers)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        print("  ".join(value.ljust(widths[index]) for index, value in enumerate(row)))


def print_latex(distributions: Sequence[RoundDistribution]) -> None:
    for item in distributions:
        print(
            f"{display_model(item.model)} & {item.mean:.2f} & "
            f"{compact_number(item.median)} & {compact_number(item.p90)} & "
            f"{item.maximum} \\\\"
        )


def print_json(distributions: Sequence[RoundDistribution]) -> None:
    output = []
    for item in distributions:
        record = asdict(item)
        record["model"] = display_model(item.model)
        output.append(record)
    print(json.dumps(output, indent=2))


def parse_models(value: str) -> List[str]:
    """Parse a comma-separated model list while preserving its order."""
    models = []
    for candidate in value.split(","):
        model = candidate.strip()
        if model and model not in models:
            models.append(model)
    return models


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Report RQ1 selected-candidate round statistics"
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=DEFAULT_DB_PATH,
        help=f"Path to progress database (default: {DEFAULT_DB_PATH})",
    )
    parser.add_argument(
        "--models",
        default=",".join(TARGET_MODELS),
        help="Comma-separated model names",
    )
    parser.add_argument(
        "--format",
        choices=("text", "latex", "json"),
        default="text",
        help="Output format",
    )
    args = parser.parse_args()

    models = parse_models(args.models)
    try:
        rounds_by_model = collect_selected_rounds(args.db, models)
        distributions = build_distributions(rounds_by_model, models)
    except SelectedRoundStatisticsError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    if args.format == "latex":
        print_latex(distributions)
    elif args.format == "json":
        print_json(distributions)
    else:
        print_text(distributions)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
