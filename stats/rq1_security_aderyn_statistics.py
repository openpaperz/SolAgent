#!/usr/bin/env python3
"""RQ1 SecurePass statistics computed from Aderyn per-sample results."""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Mapping, Sequence, Tuple

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from stats.rq1_security_statistics import (
    AGENT_DISPLAY_NAMES,
    AGENT_TYPES,
    RAW_MODEL,
    SOLAGENT,
    TARGET_MODELS,
    FileSecurityRecord,
    build_pairwise_results,
    print_table,
    summarize_condition,
    summarize_primary,
)


SOURCE_METHODS = {
    "rawmodel": RAW_MODEL,
    "solagent": SOLAGENT,
    **{agent: AGENT_DISPLAY_NAMES[agent] for agent in AGENT_TYPES},
}
DEFAULT_OUTPUT = Path("stats/aderyn") / f"{Path(__file__).stem}.csv"


def load_groups(
    summary_path: Path,
) -> Dict[Tuple[str, str], List[FileSecurityRecord]]:
    data = json.loads(summary_path.read_text(encoding="utf-8"))
    groups: Dict[Tuple[str, str], List[FileSecurityRecord]] = {}
    for item in data.get("records", []):
        method = SOURCE_METHODS.get(item.get("source"))
        if method is None:
            continue
        model = str(item.get("model") or "")
        count = item.get("aderyn_count") if item.get("status") == "analyzed" else None
        sloc = item.get("aderyn_sloc")
        record = FileSecurityRecord(
            method=method,
            model=model,
            file_path=str(item.get("file_path") or ""),
            test_pass=int(item.get("test_pass") or 0),
            test_total=int(item.get("test_total") or 0),
            vuln_count=count if isinstance(count, int) and count >= 0 else None,
            sloc=sloc if isinstance(sloc, int) and sloc > 0 else None,
        )
        groups.setdefault((method, model), []).append(record)
    return groups


def primary_to_dict(summary: Any) -> Dict[str, Any]:
    return {
        "attempted": summary.attempted,
        "compiled": summary.compiled,
        "full_pass": summary.full_pass,
        "safe_full_pass": summary.safe_full_pass,
        "secure_pass_at_1": summary.secure_pass_rate,
        "safe_at_full_pass": summary.safe_given_full_pass_rate,
        "wilson_ci": [summary.ci_low, summary.ci_high],
    }


def conditional_to_dict(summary: Any) -> Dict[str, Any]:
    return {
        "eligible": summary.eligible,
        "scanned": summary.scanned,
        "vulnerable_files": summary.vulnerable_files,
        "vulnerable_file_rate": summary.vulnerable_file_rate,
        "loc_covered": summary.loc_covered,
        "total_vulnerabilities": summary.total_vulnerabilities,
        "total_sloc": summary.total_sloc,
        "vulnerabilities_per_kloc": summary.vulnerabilities_per_kloc,
    }


def analyze(
    groups: Mapping[Tuple[str, str], Sequence[FileSecurityRecord]],
    models: Sequence[str],
) -> Dict[str, Any]:
    method_order = [RAW_MODEL, SOLAGENT, *(AGENT_DISPLAY_NAMES[a] for a in AGENT_TYPES)]
    primary: List[Dict[str, Any]] = []
    conditional_compiled: List[Dict[str, Any]] = []
    conditional_full_pass: List[Dict[str, Any]] = []

    for model in models:
        for method in method_order:
            records = groups.get((method, model))
            if not records:
                continue
            primary.append(
                {
                    "method": method,
                    "model": model,
                    **primary_to_dict(summarize_primary(records)),
                }
            )
            conditional_compiled.append(
                {
                    "method": method,
                    "model": model,
                    **conditional_to_dict(summarize_condition(records, "compiled")),
                }
            )
            conditional_full_pass.append(
                {
                    "method": method,
                    "model": model,
                    **conditional_to_dict(summarize_condition(records, "full_pass")),
                }
            )

    primary_by_group = {(row["method"], row["model"]): row for row in primary}
    compiled_by_group = {
        (row["method"], row["model"]): row for row in conditional_compiled
    }
    full_pass_by_group = {
        (row["method"], row["model"]): row for row in conditional_full_pass
    }
    main_table: List[Dict[str, Any]] = []
    for method in method_order:
        for model in models:
            key = (method, model)
            if key not in primary_by_group:
                continue
            primary_row = primary_by_group[key]
            compiled_row = compiled_by_group[key]
            full_pass_row = full_pass_by_group[key]
            attempted = primary_row["attempted"]
            main_table.append(
                {
                    "method": method,
                    "model": model,
                    "attempted": attempted,
                    "compiled": primary_row["compiled"],
                    "compile_rate": (
                        primary_row["compiled"] / attempted if attempted else 0.0
                    ),
                    "full_pass": primary_row["full_pass"],
                    "full_pass_rate": (
                        primary_row["full_pass"] / attempted if attempted else 0.0
                    ),
                    "safe_full_pass": primary_row["safe_full_pass"],
                    "secure_pass_at_1": primary_row["secure_pass_at_1"],
                    "safe_at_full_pass": primary_row["safe_at_full_pass"],
                    "wilson_ci": primary_row["wilson_ci"],
                    "compiled_scanned": compiled_row["scanned"],
                    "compiled_scan_coverage": (
                        compiled_row["scanned"] / compiled_row["eligible"]
                        if compiled_row["eligible"]
                        else None
                    ),
                    "compiled_findings": compiled_row["total_vulnerabilities"],
                    "compiled_sloc": compiled_row["total_sloc"],
                    "compiled_findings_per_kloc": compiled_row[
                        "vulnerabilities_per_kloc"
                    ],
                    "full_pass_scanned": full_pass_row["scanned"],
                    "full_pass_scan_coverage": (
                        full_pass_row["scanned"] / full_pass_row["eligible"]
                        if full_pass_row["eligible"]
                        else None
                    ),
                    "full_pass_findings": full_pass_row["total_vulnerabilities"],
                    "full_pass_sloc": full_pass_row["total_sloc"],
                    "full_pass_findings_per_kloc": full_pass_row[
                        "vulnerabilities_per_kloc"
                    ],
                }
            )

    baseline_methods = [RAW_MODEL, *(AGENT_DISPLAY_NAMES[a] for a in AGENT_TYPES)]
    pairwise = build_pairwise_results(groups, models, baseline_methods)
    pairwise_json = [
        {
            "model": row.model,
            "baseline": row.baseline,
            "common_files": row.common_files,
            "solagent_only": row.solagent_only,
            "baseline_only": row.baseline_only,
            "net_gain": row.net_gain,
            "delta_percentage_points": row.delta_percentage_points,
            "mcnemar_p": row.p_value,
            "holm_p": row.adjusted_p_value,
            "holm_significant_0_05": row.adjusted_p_value < 0.05,
        }
        for row in pairwise
    ]

    advantages: List[Dict[str, Any]] = []
    for model in models:
        rows = [row for row in primary if row["model"] == model]
        solagent = next((row for row in rows if row["method"] == SOLAGENT), None)
        baselines = [row for row in rows if row["method"] != SOLAGENT]
        if solagent is None or not baselines:
            continue
        best = max(baselines, key=lambda row: row["secure_pass_at_1"])
        advantages.append(
            {
                "model": model,
                "solagent_full_pass": solagent["full_pass"],
                "solagent_safe_full_pass": solagent["safe_full_pass"],
                "solagent_secure_pass_at_1": solagent["secure_pass_at_1"],
                "solagent_safe_at_full_pass": solagent["safe_at_full_pass"],
                "best_baseline": best["method"],
                "best_baseline_full_pass": best["full_pass"],
                "best_baseline_safe_full_pass": best["safe_full_pass"],
                "best_baseline_secure_pass_at_1": best["secure_pass_at_1"],
                "best_baseline_safe_at_full_pass": best["safe_at_full_pass"],
                "absolute_safe_full_pass_gain": (
                    solagent["safe_full_pass"] - best["safe_full_pass"]
                ),
                "secure_pass_gain_percentage_points": 100.0
                * (solagent["secure_pass_at_1"] - best["secure_pass_at_1"]),
                "safe_at_full_pass_gain_percentage_points": (
                    100.0 * (solagent["safe_at_full_pass"] - best["safe_at_full_pass"])
                    if solagent["safe_at_full_pass"] is not None
                    and best["safe_at_full_pass"] is not None
                    else None
                ),
            }
        )

    return {
        "main_table": main_table,
        "primary": primary,
        "conditional_compiled": conditional_compiled,
        "conditional_full_pass": conditional_full_pass,
        "paired_solagent_vs_baselines": pairwise_json,
        "solagent_advantage_vs_best_baseline": advantages,
    }


def percentage(value: Any) -> str:
    return "N/A" if value is None else f"{float(value) * 100:.2f}%"


def coverage(numerator: int, denominator: int) -> str:
    if denominator <= 0:
        return f"{numerator}/{denominator} (N/A)"
    return f"{numerator}/{denominator} ({numerator / denominator * 100:.1f}%)"


def number(value: Any) -> str:
    return "N/A" if value is None else f"{float(value):.2f}"


def print_results(result: Dict[str, Any]) -> None:
    print("\n" + "=" * 120)
    print("RQ-1 Aderyn Security Statistics for Generated Code")
    print("=" * 120)

    print("\nMain Table: Eval Functionality + Aderyn Security")
    print_table(
        [
            "Method",
            "Model",
            "Compiled",
            "FullPass",
            "Aderyn-clean",
            "SecurePass@1",
            "Safe@FullPass",
            "Compiled F/KLOC",
            "FullPass F/KLOC",
        ],
        [
            [
                row["method"],
                row["model"],
                f"{row['compiled']}/{row['attempted']}",
                f"{row['full_pass']}/{row['attempted']}",
                row["safe_full_pass"],
                percentage(row["secure_pass_at_1"]),
                percentage(row["safe_at_full_pass"]),
                number(row["compiled_findings_per_kloc"]),
                number(row["full_pass_findings_per_kloc"]),
            ]
            for row in result["main_table"]
        ],
    )

    print("\nPaired SecurePass@1: SolAgent vs. Baselines")
    paired_rows = [
        [
            row["model"],
            row["baseline"],
            row["common_files"],
            row["solagent_only"],
            row["baseline_only"],
            f"{row['net_gain']:+d}",
            f"{row['delta_percentage_points']:+.2f} pp",
            f"{row['mcnemar_p']:.4g}",
            f"{row['holm_p']:.4g}",
        ]
        for row in result["paired_solagent_vs_baselines"]
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

    conditional_sections = (
        ("Compiled Files", result["conditional_compiled"]),
        ("Full-Test-Pass Files", result["conditional_full_pass"]),
    )
    for label, rows in conditional_sections:
        print(f"\nConditional Security: {label}")
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
            [
                [
                    row["method"],
                    row["model"],
                    row["eligible"],
                    coverage(row["scanned"], row["eligible"]),
                    row["vulnerable_files"],
                    percentage(row["vulnerable_file_rate"]),
                    coverage(row["loc_covered"], row["scanned"]),
                    row["total_vulnerabilities"],
                    f"{row['total_sloc'] / 1000.0:.3f}",
                    number(row["vulnerabilities_per_kloc"]),
                ]
                for row in rows
            ],
        )

    print("\nSolAgent advantage over the best generated-code baseline")
    print_table(
        [
            "Model",
            "SolAgent",
            "Best baseline",
            "Baseline",
            "Secure gain",
            "SafeFull gain",
            "Safe@Full gain",
        ],
        [
            [
                row["model"],
                percentage(row["solagent_secure_pass_at_1"]),
                row["best_baseline"],
                percentage(row["best_baseline_secure_pass_at_1"]),
                f"{row['secure_pass_gain_percentage_points']:+.2f} pp",
                f"{row['absolute_safe_full_pass_gain']:+d}",
                (
                    "N/A"
                    if row["safe_at_full_pass_gain_percentage_points"] is None
                    else f"{row['safe_at_full_pass_gain_percentage_points']:+.2f} pp"
                ),
            ]
            for row in result["solagent_advantage_vs_best_baseline"]
        ],
    )

    print("\nNotes:")
    print("- SecurePass@1 = full-test-pass and zero-finding files / attempted files.")
    print(
        "- Safe@FullPass = full-test-pass and zero-finding files / full-test-pass files."
    )
    print(
        "- A full-test-pass file without a valid Aderyn scan is conservatively not safe."
    )
    print("- Conditional finding rates use valid scans as their denominator.")
    print("- Finding density is a micro-average over files with valid scans and SLOC.")
    print("- Holm correction is applied to all SolAgent comparisons within each model.")


def write_main_table_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "method",
        "model",
        "attempted",
        "compiled",
        "compile_rate",
        "full_pass",
        "full_pass_rate",
        "safe_full_pass",
        "secure_pass_at_1",
        "safe_at_full_pass",
        "compiled_scanned",
        "compiled_scan_coverage",
        "compiled_findings",
        "compiled_sloc",
        "compiled_findings_per_kloc",
        "full_pass_scanned",
        "full_pass_scan_coverage",
        "full_pass_findings",
        "full_pass_sloc",
        "full_pass_findings_per_kloc",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key) for key in fieldnames})


def build_paper_table(
    result: Mapping[str, Any],
    groups: Mapping[Tuple[str, str], Sequence[FileSecurityRecord]],
    models: Sequence[str],
) -> List[Dict[str, Any]]:
    """Build the same compact, paired security table used for RQ1 Slither."""
    primary = {
        (row["method"], row["model"]): row for row in result["primary"]
    }
    baseline_methods = [RAW_MODEL, *(AGENT_DISPLAY_NAMES[a] for a in AGENT_TYPES)]
    rows: List[Dict[str, Any]] = []
    for model in models:
        if (SOLAGENT, model) not in primary:
            continue
        sol_primary = primary[(SOLAGENT, model)]
        rows.append(
            {
                "model": model,
                "method": SOLAGENT,
                "attempted": sol_primary["attempted"],
                "safe_full_pass": sol_primary["safe_full_pass"],
                "secure_pass_at_1": sol_primary["secure_pass_at_1"],
                "safe_at_full_pass": sol_primary["safe_at_full_pass"],
                "safe_at_full_pass_denominator": sol_primary["full_pass"],
                "baseline_solagent_findings_with_n": None,
                "baseline_solagent_findings_per_kloc": None,
                "solagent_finding_count_reduction": None,
            }
        )
        for baseline in baseline_methods:
            if (baseline, model) not in primary:
                continue
            sol_records = {
                record.file_path: record
                for record in groups.get((SOLAGENT, model), [])
            }
            baseline_records = {
                record.file_path: record
                for record in groups.get((baseline, model), [])
            }
            pairs = [
                (sol_records[file_path], baseline_records[file_path])
                for file_path in sorted(set(sol_records) & set(baseline_records))
                if sol_records[file_path].full_pass
                and baseline_records[file_path].full_pass
                and sol_records[file_path].scan_valid
                and baseline_records[file_path].scan_valid
                and sol_records[file_path].sloc is not None
                and baseline_records[file_path].sloc is not None
            ]
            sol_findings = sum(left.vuln_count for left, _ in pairs)
            baseline_findings = sum(right.vuln_count for _, right in pairs)
            sol_sloc = sum(left.sloc for left, _ in pairs)
            baseline_sloc = sum(right.sloc for _, right in pairs)
            sol_density = sol_findings / sol_sloc * 1000.0 if sol_sloc else None
            baseline_density = (
                baseline_findings / baseline_sloc * 1000.0
                if baseline_sloc
                else None
            )
            baseline_primary = primary[(baseline, model)]
            rows.append(
                {
                    "model": model,
                    "method": baseline,
                    "attempted": baseline_primary["attempted"],
                    "safe_full_pass": baseline_primary["safe_full_pass"],
                    "secure_pass_at_1": baseline_primary["secure_pass_at_1"],
                    "safe_at_full_pass": baseline_primary["safe_at_full_pass"],
                    "safe_at_full_pass_denominator": baseline_primary["full_pass"],
                    "baseline_solagent_findings_with_n": (
                        f"{baseline_findings}/{sol_findings} (n={len(pairs)})"
                    ),
                    "baseline_solagent_findings_per_kloc": (
                        f"{baseline_density:.2f}/{sol_density:.2f}"
                        if baseline_density is not None and sol_density is not None
                        else None
                    ),
                    "solagent_finding_count_reduction": (
                        (baseline_findings - sol_findings) / baseline_findings
                        if baseline_findings
                        else None
                    ),
                }
            )
    return rows


def print_paper_table(rows: Sequence[Mapping[str, Any]]) -> None:
    print("\n" + "=" * 120)
    print("RQ-1 Aderyn Security Statistics: Independent Eval Tests, Fixed Fuzz Seed 1")
    print("=" * 120)
    print("\nMain Table")
    print_table(
        [
            "Model",
            "Method",
            "SecurePass@1",
            "Zero-Finding@FullPass",
            "Baseline/SolAgent Findings (n)",
            "Finding Count Reduction ↑",
            "Baseline/SolAgent Findings/KLOC",
        ],
        [
            [
                row["model"],
                row["method"],
                f"{percentage(row['secure_pass_at_1'])} "
                f"({row['safe_full_pass']}/{row['attempted']})",
                (
                    "N/A"
                    if row["safe_at_full_pass"] is None
                    else f"{percentage(row['safe_at_full_pass'])} "
                    f"({row['safe_full_pass']}/{row['safe_at_full_pass_denominator']})"
                ),
                row["baseline_solagent_findings_with_n"] or "—",
                (
                    "—"
                    if row["solagent_finding_count_reduction"] is None
                    else f"{row['solagent_finding_count_reduction'] * 100:+.2f}%"
                ),
                row["baseline_solagent_findings_per_kloc"] or "—",
            ]
            for row in rows
        ],
    )
    print("\nNotes:")
    print("- Functionality comes from the independent seed1 eval reports.")
    print("- SecurePass@1 = eval FullPass and zero Aderyn findings / all 81 tasks.")
    print("- Zero-Finding@FullPass = zero-Aderyn eval FullPass files / eval FullPass files.")
    print("- n is the number of same-task files where both methods eval FullPass with valid Aderyn and SLOC.")
    print("- The same n matched files are used for both finding counts and Findings/KLOC.")
    print("- Findings denote Aderyn High+Low findings.")
    print("- Positive Finding Count Reduction means SolAgent has fewer total findings.")
    print("- SolAgent has no single paired count or density because its paired file set differs by baseline.")


def write_paper_table_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0]) if rows else []
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Analyze RQ1 Aderyn security results")
    parser.add_argument("--summary", default="stats/aderyn/summary.json")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--models", default=",".join(TARGET_MODELS))
    args = parser.parse_args()

    models = [item.strip() for item in args.models.split(",") if item.strip()]
    groups = load_groups(Path(args.summary))
    result = analyze(groups, models)
    paper_table = build_paper_table(result, groups, models)
    output_path = Path(args.output)
    write_paper_table_csv(output_path, paper_table)
    print_paper_table(paper_table)
    print(f"\nWrote: {output_path}")


if __name__ == "__main__":
    main()
