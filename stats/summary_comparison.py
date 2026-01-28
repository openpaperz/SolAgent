#!/usr/bin/env python3
"""
Summary Version Statistics: Compare SolAgent with and without summary.

Compares process_tracking (no summary) vs process_tracking_summary (with summary).

Usage:
    python stats/summary_comparison.py --db output/progress.db
"""
import argparse
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from stats.common_utils import (
    safe_json_loads, get_best_pass_round,
    get_min_vuln_round, get_gas_at_round, get_test_at_round,
    get_vuln_at_round, compute_pass_rate, aggregate_stats,
    print_table_header, print_table_row, format_stats, format_percentage, format_gas_stats
)
from db.progress_tracker import ProgressTracker
from db.progress_tracker_summary import ProgressTrackerSummary


TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]


def collect_tracking_stats(db_path: str, model: str, table_name: str):
    """
    Collect statistics from process_tracking or process_tracking_summary.
    
    Args:
        table_name: "process_tracking" or "process_tracking_summary"
    """
    # Use appropriate tracker class based on table name
    if "summary" in table_name:
        tracker = ProgressTrackerSummary(db_path)
    else:
        tracker = ProgressTracker(db_path)
    
    all_rows = tracker.get_all_entries(status=1)
    rows = [r for r in all_rows if r['model_coding'] == model]
    
    if not rows:
        return None
    
    total_files = len(rows)
    compiled_files = 0
    pass_rates = []
    gas_values = []
    vuln_best_pass = []
    vuln_min_vuln = []
    pass_at_min_vuln = []
    gas_at_min_vuln = []
    total_pass = 0
    total_tests = 0
    
    for row in rows:
        # Parse per-round data
        round_test_json = safe_json_loads(row['test_json'])
        round_gas_json = safe_json_loads(row['round_gas_fee_json'])
        round_vuln_json = safe_json_loads(row['round_vuln_count'])
        
        # Get best pass round
        best_round, best_pass, best_total = get_best_pass_round(round_test_json)
        
        if best_total > 0:
            compiled_files += 1
            pass_rate = compute_pass_rate(best_pass, best_total)
            pass_rates.append(pass_rate)
            total_pass += best_pass
            total_tests += best_total
            
            # Gas at best pass round
            gas_mean, gas_median = get_gas_at_round(round_gas_json, best_round)
            if gas_mean and gas_mean > 0:
                gas_values.append(gas_mean)
            
            # Vuln at best pass round
            vuln = get_vuln_at_round(round_vuln_json, best_round)
            vuln_best_pass.append(vuln)
        
        # Get min vuln round
        min_vuln_round, min_vuln = get_min_vuln_round(round_vuln_json, round_test_json)
        if min_vuln_round > 0:
            vuln_min_vuln.append(min_vuln)
            
            # Pass rate at min vuln round
            pass_at_min, total_at_min = get_test_at_round(round_test_json, min_vuln_round)
            if total_at_min > 0:
                pass_at_min_vuln.append(compute_pass_rate(pass_at_min, total_at_min))
            
            # Gas at min vuln round
            gas_at_min_mean, gas_at_min_median = get_gas_at_round(round_gas_json, min_vuln_round)
            if gas_at_min_mean and gas_at_min_mean > 0:
                gas_at_min_vuln.append(gas_at_min_mean)
    
    version = "With Summary" if "summary" in table_name else "No Summary"
    
    return {
        'version': version,
        'model': model,
        'total_files': total_files,
        'compiled_files': compiled_files,
        'compilation_rate': compiled_files / total_files if total_files > 0 else 0,
        'total_pass': total_pass,
        'total_tests': total_tests,
        'pass_rate_stats': aggregate_stats(pass_rates),
        'gas_stats': aggregate_stats(gas_values),
        'vuln_best_pass_stats': aggregate_stats(vuln_best_pass),
        'vuln_min_vuln_stats': aggregate_stats(vuln_min_vuln),
        'pass_at_min_vuln_stats': aggregate_stats(pass_at_min_vuln),
        'gas_at_min_vuln_stats': aggregate_stats(gas_at_min_vuln)
    }


def print_summary_comparison(all_stats, test_case_total: int):
    """Print summary vs no-summary comparison."""
    print("\n" + "="*180)
    print("Summary Version Comparison")
    print("="*180)
    print(f"Total Test Cases (Baseline): {test_case_total}\n")
    
    # Group by model
    from collections import defaultdict
    by_model = defaultdict(list)
    for stat in all_stats:
        if stat:
            by_model[stat['model']].append(stat)
    
    for model, stats in sorted(by_model.items()):
        print(f"\n【Model: {model}】")
        
        # Pass@1 and Compilation Rate
        print("\n  Pass@1 and Compilation Rate:")
        widths = [18, 12, 14, 14, 16, 16, 20]
        print("  ", end="")
        print_table_header(['Version', 'Files', 'test_pass', 'test_total', 'Pass@1 overall', 'Compile Rate', 'Pass@1 (mean±std)'], widths)
        
        # Sort: No Summary first, then With Summary
        stats_sorted = sorted(stats, key=lambda x: x['version'])
        
        for stat in stats_sorted:
            total_pass = stat.get('total_pass', 0)
            overall_rate = compute_pass_rate(total_pass, test_case_total) if test_case_total else 0.0
            print("  ", end="")
            print_table_row([
                stat['version'],
                f"{stat['compiled_files']}/{stat['total_files']}",
                str(total_pass),
                str(stat.get('total_tests', 0)),
                format_percentage(overall_rate),
                format_percentage(stat['compilation_rate']),
                format_stats(stat['pass_rate_stats'])
            ], widths)
        
        # Gas Usage
        print("\n  Gas Usage:")
        widths = [20, 30]
        print("  ", end="")
        print_table_header(['Version', 'Gas @BestPass (mean±std)'], widths)
        
        for stat in stats_sorted:
            print("  ", end="")
            print_table_row([
                stat['version'],
                format_stats(stat['gas_stats'], precision=2)
            ], widths)
        
        # Vulnerabilities
        print("\n  Vulnerabilities:")
        widths = [20, 25, 25]
        print("  ", end="")
        print_table_header(['Version', 'Vuln @BestPass', 'Vuln @MinVuln'], widths)
        
        for stat in stats_sorted:
            print("  ", end="")
            print_table_row([
                stat['version'],
                format_stats(stat['vuln_best_pass_stats'], precision=2),
                format_stats(stat['vuln_min_vuln_stats'], precision=2)
            ], widths)
        
        # Metrics at min-vuln round
        if any(s['pass_at_min_vuln_stats']['count'] > 0 for s in stats_sorted):
            print("\n  Metrics at Min-Vuln Round:")
            widths = [20, 25, 25]
            print("  ", end="")
            print_table_header(['Version', 'Pass@1 @MinVuln', 'Gas @MinVuln'], widths)
            
            for stat in stats_sorted:
                print("  ", end="")
                print_table_row([
                    stat['version'],
                    format_stats(stat['pass_at_min_vuln_stats']),
                    format_stats(stat['gas_at_min_vuln_stats'], precision=2)
                ], widths)
        
        print("\n  " + "-"*80)
    
    print("\n" + "="*120)


def main():
    parser = argparse.ArgumentParser(description='Summary Version Comparison Statistics')
    parser.add_argument('--db', type=str, default='output/progress.db', help='Database path')
    parser.add_argument('--models', type=str, default=','.join(TARGET_MODELS), 
                       help='Comma-separated model names')
    
    args = parser.parse_args()
    models = [m.strip() for m in args.models.split(',')]
    
    all_stats = []
    
    for model in models:
        print(f"Collecting statistics for model {model}...")
        
        # No summary version
        no_summary = collect_tracking_stats(args.db, model, "process_tracking")
        if no_summary:
            all_stats.append(no_summary)
        
        # With summary version
        with_summary = collect_tracking_stats(args.db, model, "process_tracking_summary")
        if with_summary:
            all_stats.append(with_summary)
    
    # Get test case total from baseline
    from stats.common_utils import get_baseline_test_total
    test_case_total = get_baseline_test_total(args.db)
    
    # Print results
    print_summary_comparison(all_stats, test_case_total)
    
    print(f"\nStatistics completed! Processed {len(all_stats)} groups of data.")


if __name__ == '__main__':
    main()
