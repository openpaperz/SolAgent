#!/usr/bin/env python3
"""
RQ-2 Statistics: Ablation study comparing different ablation types
- ablation_type 2: no forge
- ablation_type 3: no slither
- ablation_type 4: no tools

Compares pass@1, gas usage, and vulnerabilities across ablation configurations.
Compares ablation results with Baseline (Repo) and ProgressTracker (full SolAgent).

Usage:
    python stats/rq2_ablation_statistics.py --db output/progress.db
"""
import argparse
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from collections import defaultdict
from stats.common_utils import (
    safe_json_loads, get_best_pass_round,
    get_min_vuln_round, get_gas_at_round, get_test_at_round,
    get_vuln_at_round, compute_pass_rate, aggregate_stats,
    print_table_header, print_table_row, format_stats, format_percentage, format_gas_stats,
    compute_pairwise_gas_comparison, extract_per_test_gas
)
from db.progress_tracker_ablation import ProgressTrackerAblation
from db.progress_tracker import ProgressTracker
from db.baseline_test import BaselineTest


TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
ABLATION_TYPES = {
    2: "no_forge",
    3: "no_slither",
    4: "no_tools"
}


def collect_baseline_stats(db_path: str):
    """Collect statistics from baseline_test table (original repo code)."""
    baseline = BaselineTest(db_path)
    rows = baseline.get_all_entries()
    
    if not rows:
        return None
    
    total_files = len(rows)
    compiled_files = sum(1 for r in rows if r['test_total'] > 0)
    total_pass = sum(r['test_pass'] for r in rows)
    total_tests = sum(r['test_total'] for r in rows)
    
    gas_mean_values = []
    gas_median_values = []
    vuln_values = []
    per_test_gas = {}  # Dict[test_name] -> (mean, median)
    
    for row in rows:
        if row['test_total'] > 0:  # Only compiled files
            gas_json = safe_json_loads(row['gas_fee_json'])
            if gas_json:
                # Extract per-test gas using common utility
                per_test_dict, total_mean, total_median = extract_per_test_gas(gas_json)
                # Add file path prefix to avoid key collisions
                file_path = row.get('file_path', 'unknown')
                for test_name, gas_values in per_test_dict.items():
                    unique_key = f"{file_path}::{test_name}"
                    per_test_gas[unique_key] = gas_values
                
                if total_mean > 0:
                    gas_mean_values.append(total_mean)
                if total_median > 0:
                    gas_median_values.append(total_median)
            
            test_pass = row['test_pass']
            vuln_count = row['vuln_count'] or 0
            vuln_values.append(vuln_count)
    
    return {
        'source': 'Baseline (Repo)',
        'model': 'N/A',
        'total_files': total_files,
        'compiled_files': compiled_files,
        'compilation_rate': compiled_files / total_files if total_files > 0 else 0,
        'total_pass': total_pass,
        'total_tests': total_tests,
        'test_pass_rate': compute_pass_rate(total_pass, total_tests),
        'pass_rate_stats': aggregate_stats([compute_pass_rate(r['test_pass'], r['test_total']) 
                                            for r in rows if r['test_total'] > 0]),
        'gas_mean_stats': aggregate_stats(gas_mean_values),
        'gas_median_stats': aggregate_stats(gas_median_values),
        'vuln_stats': aggregate_stats(vuln_values),
        'per_test_gas': per_test_gas,
        'vuln_by_file': {row.get('file_path', 'unknown'): row.get('vuln_count', 0) 
                         for row in rows if row['test_total'] > 0}
    }


def collect_ablation_stats(db_path: str, model: str, ablation_type: int):
    """
    Collect statistics from process_tracking_ablation table.
    Uses the same structure as collect_solagent_stats from RQ1.
    
    Returns dict with:
    - pass@1 at best-pass round
    - gas at best-pass round (mean & median)
    - vuln at best-pass round
    - vuln at min-vuln round
    - pass@1 and gas at min-vuln round
    - per_test_gas for pairwise comparison
    - vuln_by_file for vulnerability comparison
    """
    tracker = ProgressTrackerAblation(db_path)
    all_rows = tracker.get_all_entries(status=1, ablation_type=ablation_type)
    rows = [r for r in all_rows if r['model_coding'] == model]
    
    if not rows:
        return None
    
    total_files = len(rows)
    compiled_files = 0
    pass_rates = []
    gas_mean_values = []
    gas_median_values = []
    vuln_best_pass = []
    vuln_min_vuln = []
    pass_at_min_vuln = []
    gas_at_min_vuln_mean = []
    gas_at_min_vuln_median = []
    total_pass = 0
    total_tests = 0
    per_test_gas = {}
    vuln_by_file = {}  # Track vuln count for each file at best pass round
    
    # Min-vuln round specific metrics
    min_vuln_compiled_files = 0
    min_vuln_total_pass = 0
    min_vuln_total_tests = 0
    min_vuln_pass_rates = []
    min_vuln_vuln_by_file = {}  # Track vuln count for each file at min vuln round
    
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
            
            # Gas at best pass round (mean & median)
            gas_mean, gas_median = get_gas_at_round(round_gas_json, best_round)
            if gas_mean and gas_mean > 0:
                gas_mean_values.append(gas_mean)
            if gas_median and gas_median > 0:
                gas_median_values.append(gas_median)
            
            # Extract per-test gas from best round
            if round_gas_json and str(best_round) in round_gas_json:
                gas_data = round_gas_json[str(best_round)]
                if isinstance(gas_data, dict):
                    file_path = row.get('file_path', 'unknown')
                    for test_name, test_gas in gas_data.items():
                        # Use file_path + test_name as key to avoid collisions across files
                        unique_test_key = f"{file_path}::{test_name}"
                        if isinstance(test_gas, dict) and '-' in test_gas and '~' in test_gas:
                            # Fuzz test format: {'-': mean, '~': median}
                            per_test_gas[unique_test_key] = (float(test_gas['-']), float(test_gas['~']))
                        elif isinstance(test_gas, dict) and 'gas' in test_gas:
                            # Non-fuzz format: {'gas': value}
                            gas_val = float(test_gas['gas'])
                            per_test_gas[unique_test_key] = (gas_val, gas_val)
                        elif isinstance(test_gas, (int, float)):
                            # Direct value
                            gas_val = float(test_gas)
                            per_test_gas[unique_test_key] = (gas_val, gas_val)
            
            # Vuln at best pass round
            vuln = get_vuln_at_round(round_vuln_json, best_round)
            vuln_best_pass.append(vuln)
            vuln_by_file[row.get('file_path', 'unknown')] = vuln
        
        # Get min vuln round
        min_vuln_round, min_vuln = get_min_vuln_round(round_vuln_json, round_test_json)
        if min_vuln_round > 0:
            vuln_min_vuln.append(min_vuln)
            
            # Pass rate at min vuln round
            pass_at_min, total_at_min = get_test_at_round(round_test_json, min_vuln_round)
            if total_at_min > 0:
                min_vuln_compiled_files += 1
                min_vuln_total_pass += pass_at_min
                min_vuln_total_tests += total_at_min
                pass_rate_at_min = compute_pass_rate(pass_at_min, total_at_min)
                pass_at_min_vuln.append(pass_rate_at_min)
                min_vuln_pass_rates.append(pass_rate_at_min)
                
                # Track vuln at min vuln round for this file
                min_vuln_vuln_by_file[row.get('file_path', 'unknown')] = min_vuln
            
            # Gas at min vuln round
            gas_at_min_mean, gas_at_min_median = get_gas_at_round(round_gas_json, min_vuln_round)
            if gas_at_min_mean and gas_at_min_mean > 0:
                gas_at_min_vuln_mean.append(gas_at_min_mean)
            if gas_at_min_median and gas_at_min_median > 0:
                gas_at_min_vuln_median.append(gas_at_min_median)
    
    return {
        'source': f'Ablation-{ABLATION_TYPES.get(ablation_type, f"type_{ablation_type}")}',
        'model': model,
        'ablation_type': ablation_type,
        'ablation_name': ABLATION_TYPES.get(ablation_type, f"type_{ablation_type}"),
        'total_files': total_files,
        'compiled_files': compiled_files,
        'compilation_rate': compiled_files / total_files if total_files > 0 else 0,
        'total_pass': total_pass,
        'total_tests': total_tests,
        'test_pass_rate': sum(pass_rates) / len(pass_rates) if pass_rates else 0,
        'pass_rate_stats': aggregate_stats(pass_rates),
        'gas_mean_stats': aggregate_stats(gas_mean_values),
        'gas_median_stats': aggregate_stats(gas_median_values),
        'vuln_best_pass_stats': aggregate_stats(vuln_best_pass),
        'vuln_min_vuln_stats': aggregate_stats(vuln_min_vuln),
        'pass_at_min_vuln_stats': aggregate_stats(pass_at_min_vuln),
        'gas_at_min_vuln_mean_stats': aggregate_stats(gas_at_min_vuln_mean),
        'gas_at_min_vuln_median_stats': aggregate_stats(gas_at_min_vuln_median),
        'per_test_gas': per_test_gas,
        'vuln_by_file': vuln_by_file,
        # Min-vuln round specific metrics
        'min_vuln_compiled_files': min_vuln_compiled_files,
        'min_vuln_total_pass': min_vuln_total_pass,
        'min_vuln_total_tests': min_vuln_total_tests,
        'min_vuln_pass_rate_stats': aggregate_stats(min_vuln_pass_rates),
        'min_vuln_vuln_by_file': min_vuln_vuln_by_file
    }


def collect_solagent_stats(db_path: str, model: str):
    """Collect statistics from process_tracking table (full SolAgent without ablation)."""
    tracker = ProgressTracker(db_path)
    all_rows = tracker.get_all_entries(status=1)
    rows = [r for r in all_rows if r['model_coding'] == model]
    
    if not rows:
        return None
    
    total_files = len(rows)
    compiled_files = 0
    pass_rates = []
    gas_mean_values = []
    gas_median_values = []
    vuln_best_pass = []
    vuln_min_vuln = []
    pass_at_min_vuln = []
    gas_at_min_vuln_mean = []
    gas_at_min_vuln_median = []
    total_pass = 0
    total_tests = 0
    per_test_gas = {}
    vuln_by_file = {}
    
    # Min-vuln round specific metrics
    min_vuln_compiled_files = 0
    min_vuln_total_pass = 0
    min_vuln_total_tests = 0
    min_vuln_pass_rates = []
    min_vuln_vuln_by_file = {}
    
    for row in rows:
        round_test_json = safe_json_loads(row['test_json'])
        round_gas_json = safe_json_loads(row['round_gas_fee_json'])
        round_vuln_json = safe_json_loads(row['round_vuln_count'])
        
        best_round, best_pass, best_total = get_best_pass_round(round_test_json)
        
        if best_total > 0:
            compiled_files += 1
            pass_rate = compute_pass_rate(best_pass, best_total)
            pass_rates.append(pass_rate)
            total_pass += best_pass
            total_tests += best_total
            
            gas_mean, gas_median = get_gas_at_round(round_gas_json, best_round)
            if gas_mean and gas_mean > 0:
                gas_mean_values.append(gas_mean)
            if gas_median and gas_median > 0:
                gas_median_values.append(gas_median)
            
            # Extract per-test gas from best round
            if round_gas_json and str(best_round) in round_gas_json:
                gas_data = round_gas_json[str(best_round)]
                if isinstance(gas_data, dict):
                    file_path = row.get('file_path', 'unknown')
                    for test_name, test_gas in gas_data.items():
                        unique_test_key = f"{file_path}::{test_name}"
                        if isinstance(test_gas, dict) and '-' in test_gas and '~' in test_gas:
                            per_test_gas[unique_test_key] = (float(test_gas['-']), float(test_gas['~']))
                        elif isinstance(test_gas, dict) and 'gas' in test_gas:
                            gas_val = float(test_gas['gas'])
                            per_test_gas[unique_test_key] = (gas_val, gas_val)
                        elif isinstance(test_gas, (int, float)):
                            gas_val = float(test_gas)
                            per_test_gas[unique_test_key] = (gas_val, gas_val)
            
            vuln = get_vuln_at_round(round_vuln_json, best_round)
            vuln_best_pass.append(vuln)
            vuln_by_file[row.get('file_path', 'unknown')] = vuln
        
        # Get min vuln round
        min_vuln_round, min_vuln = get_min_vuln_round(round_vuln_json, round_test_json)
        if min_vuln_round > 0:
            vuln_min_vuln.append(min_vuln)
            
            pass_at_min, total_at_min = get_test_at_round(round_test_json, min_vuln_round)
            if total_at_min > 0:
                min_vuln_compiled_files += 1
                min_vuln_total_pass += pass_at_min
                min_vuln_total_tests += total_at_min
                pass_rate_at_min = compute_pass_rate(pass_at_min, total_at_min)
                pass_at_min_vuln.append(pass_rate_at_min)
                min_vuln_pass_rates.append(pass_rate_at_min)
                
                min_vuln_vuln_by_file[row.get('file_path', 'unknown')] = min_vuln
            
            gas_at_min_mean, gas_at_min_median = get_gas_at_round(round_gas_json, min_vuln_round)
            if gas_at_min_mean and gas_at_min_mean > 0:
                gas_at_min_vuln_mean.append(gas_at_min_mean)
            if gas_at_min_median and gas_at_min_median > 0:
                gas_at_min_vuln_median.append(gas_at_min_median)
    
    return {
        'source': 'SolAgent (Full)',
        'model': model,
        'ablation_type': 0,
        'ablation_name': 'Full (no ablation)',
        'total_files': total_files,
        'compiled_files': compiled_files,
        'compilation_rate': compiled_files / total_files if total_files > 0 else 0,
        'total_pass': total_pass,
        'total_tests': total_tests,
        'test_pass_rate': sum(pass_rates) / len(pass_rates) if pass_rates else 0,
        'pass_rate_stats': aggregate_stats(pass_rates),
        'gas_mean_stats': aggregate_stats(gas_mean_values),
        'gas_median_stats': aggregate_stats(gas_median_values),
        'vuln_best_pass_stats': aggregate_stats(vuln_best_pass),
        'vuln_min_vuln_stats': aggregate_stats(vuln_min_vuln),
        'pass_at_min_vuln_stats': aggregate_stats(pass_at_min_vuln),
        'gas_at_min_vuln_mean_stats': aggregate_stats(gas_at_min_vuln_mean),
        'gas_at_min_vuln_median_stats': aggregate_stats(gas_at_min_vuln_median),
        'per_test_gas': per_test_gas,
        'vuln_by_file': vuln_by_file,
        # Min-vuln round specific metrics
        'min_vuln_compiled_files': min_vuln_compiled_files,
        'min_vuln_total_pass': min_vuln_total_pass,
        'min_vuln_total_tests': min_vuln_total_tests,
        'min_vuln_pass_rate_stats': aggregate_stats(min_vuln_pass_rates),
        'min_vuln_vuln_by_file': min_vuln_vuln_by_file
    }


def print_ablation_comparison(all_stats, test_case_total: int):
    """Print ablation study comparison table following RQ1 structure."""
    print("\n" + "="*170)
    print("RQ-2 Ablation Study Results")
    print("="*170)
    
    # Group by model
    by_model = defaultdict(list)
    baseline_repo = None
    
    for stat in all_stats:
        if stat:
            if stat['source'] == 'Baseline (Repo)':
                baseline_repo = stat
            else:
                by_model[stat['model']].append(stat)
    
    for model in sorted(by_model.keys()):
        stats = by_model[model]
        
        print(f"\n{'='*170}")
        print(f"Model: {model}")
        print(f"{'='*170}")
        
        # Pass@1 and Compilation Rate
        print("\n【Pass@1 and Compilation Rate】")
        print(f"Total Test Cases (Baseline): {test_case_total}\n")
        widths = [18, 12, 12, 14, 12, 18, 14, 20]
        print_table_header(['Source', 'Model', 'Files', 'Compile Rate', 'test_pass', 'test_total', 'Pass@1 overall', 'Pass@1 (mean±std)'], widths)
        
        # Sort: Full first, then by ablation type
        stats_sorted = sorted(stats, key=lambda x: (x['ablation_type'] != 0, x['ablation_type']))
        
        for stat in stats_sorted:
            total_pass = stat.get('total_pass', 0)
            overall_rate = compute_pass_rate(total_pass, test_case_total) if test_case_total else 0.0
            print_table_row([
                stat['source'],
                stat['model'],
                f"{stat['compiled_files']}/{stat['total_files']}",
                format_percentage(stat['compilation_rate']),
                str(total_pass),
                str(stat.get('total_tests', 0)),
                format_percentage(overall_rate),
                format_stats(stat['pass_rate_stats'])
            ], widths)
        
        # Gas Usage - Pairwise Intersection Comparison
        print("\n【Gas Usage Comparison (Pairwise Intersection)】")
        print("Ablation experiments vs. Baselines - Pairwise Intersection Analysis\n")
        
        widths = [30, 20, 12, 15, 15, 15, 15, 15, 15, 15, 15]
        headers = ['Comparison', 'Model', '#Common', 'Median R(-)', 'Median R(~)', 'Mean R(-)', 'Mean R(~)', 
                   'Trim5% R(-)', 'Trim5% R(~)', 'P90 R(-)', 'P90 R(~)']
        print_table_header(headers, widths)
        
        # Get SolAgent (Full) stat for this model
        solagent_full = None
        ablation_stats = []
        for stat in stats_sorted:
            if stat['ablation_type'] == 0:
                solagent_full = stat
            else:
                ablation_stats.append(stat)
        
        # Compare each ablation with SolAgent (Full)
        if solagent_full:
            for ablation_stat in ablation_stats:
                result = compute_pairwise_gas_comparison(
                    ablation_stat['per_test_gas'],
                    solagent_full['per_test_gas']
                )
                
                if result['common_count'] > 0:
                    comparison_name = f"{ablation_stat['source']} vs Full"
                    print_table_row([
                        comparison_name,
                        model,
                        str(result['common_count']),
                        f"{result['median_ratio_mean']:.4f}",
                        f"{result['median_ratio_median']:.4f}",
                        f"{result['mean_ratio_mean']:.4f}",
                        f"{result['mean_ratio_median']:.4f}",
                        f"{result['trimmed_mean_mean']:.4f}",
                        f"{result['trimmed_mean_median']:.4f}",
                        f"{result['p90_mean']:.4f}",
                        f"{result['p90_median']:.4f}"
                    ], widths)
        
        # Compare each ablation with Baseline (Repo)
        if baseline_repo:
            for ablation_stat in ablation_stats:
                result = compute_pairwise_gas_comparison(
                    ablation_stat['per_test_gas'],
                    baseline_repo['per_test_gas']
                )
                
                if result['common_count'] > 0:
                    comparison_name = f"{ablation_stat['source']} vs Baseline"
                    print_table_row([
                        comparison_name,
                        model,
                        str(result['common_count']),
                        f"{result['median_ratio_mean']:.4f}",
                        f"{result['median_ratio_median']:.4f}",
                        f"{result['mean_ratio_mean']:.4f}",
                        f"{result['mean_ratio_median']:.4f}",
                        f"{result['trimmed_mean_mean']:.4f}",
                        f"{result['trimmed_mean_median']:.4f}",
                        f"{result['p90_mean']:.4f}",
                        f"{result['p90_median']:.4f}"
                    ], widths)
            
            # Also compare SolAgent (Full) with Baseline (Repo)
            if solagent_full:
                result = compute_pairwise_gas_comparison(
                    solagent_full['per_test_gas'],
                    baseline_repo['per_test_gas']
                )
                
                if result['common_count'] > 0:
                    comparison_name = "SolAgent (Full) vs Baseline"
                    print_table_row([
                        comparison_name,
                        model,
                        str(result['common_count']),
                        f"{result['median_ratio_mean']:.4f}",
                        f"{result['median_ratio_median']:.4f}",
                        f"{result['mean_ratio_mean']:.4f}",
                        f"{result['mean_ratio_median']:.4f}",
                        f"{result['trimmed_mean_mean']:.4f}",
                        f"{result['trimmed_mean_median']:.4f}",
                        f"{result['p90_mean']:.4f}",
                        f"{result['p90_median']:.4f}"
                    ], widths)
        
        print("\nNote:")
        print("- Median R(-): Median of mean gas ratios (Ablation '-' / Baseline '-')")
        print("- Median R(~): Median of median gas ratios (Ablation '~' / Baseline '~')")
        print("- Mean R(-): Mean of mean gas ratios")
        print("- Mean R(~): Mean of median gas ratios")
        print("- Trim5% R(-/~): 5% trimmed mean (remove lowest & highest 5% before averaging)")
        print("- P90 R(-/~): 90th percentile ratio (90% of test cases have ratio ≤ this value)")
        print("- All ratios: lower is better (ratio < 1.0 means ablation saves gas)")
        
        # File-level Gas comparison
        print("\n【File-Level Gas Comparison】")
        print("Compare total gas consumption per file (aggregate all common test cases)\n")
        
        file_widths = [30, 20, 15, 15, 15, 15, 15]
        file_headers = ['Comparison', 'Model', '#Common Files', 'Files Better', 'Files Worse', 'Files Equal', 'Better Files %']
        print_table_header(file_headers, file_widths)
        
        # Compare ablations with SolAgent (Full)
        if solagent_full:
            for ablation_stat in ablation_stats:
                result = compute_pairwise_gas_comparison(
                    ablation_stat['per_test_gas'],
                    solagent_full['per_test_gas']
                )
                
                if result['common_count'] > 0 and 'file_level_better' in result:
                    comparison_name = f"{ablation_stat['source']} vs Full"
                    total_files = result['file_level_better'] + result['file_level_worse'] + result['file_level_equal']
                    better_pct = (result['file_level_better'] / total_files * 100) if total_files > 0 else 0.0
                    print_table_row([
                        comparison_name,
                        model,
                        str(result['common_files']),
                        str(result['file_level_better']),
                        str(result['file_level_worse']),
                        str(result['file_level_equal']),
                        f"{better_pct:.2f}%"
                    ], file_widths)
        
        # Compare ablations with Baseline (Repo)
        if baseline_repo:
            for ablation_stat in ablation_stats:
                result = compute_pairwise_gas_comparison(
                    ablation_stat['per_test_gas'],
                    baseline_repo['per_test_gas']
                )
                
                if result['common_count'] > 0 and 'file_level_better' in result:
                    comparison_name = f"{ablation_stat['source']} vs Baseline"
                    total_files = result['file_level_better'] + result['file_level_worse'] + result['file_level_equal']
                    better_pct = (result['file_level_better'] / total_files * 100) if total_files > 0 else 0.0
                    print_table_row([
                        comparison_name,
                        model,
                        str(result['common_files']),
                        str(result['file_level_better']),
                        str(result['file_level_worse']),
                        str(result['file_level_equal']),
                        f"{better_pct:.2f}%"
                    ], file_widths)
            
            # SolAgent (Full) vs Baseline
            if solagent_full:
                result = compute_pairwise_gas_comparison(
                    solagent_full['per_test_gas'],
                    baseline_repo['per_test_gas']
                )
                
                if result['common_count'] > 0 and 'file_level_better' in result:
                    comparison_name = "SolAgent (Full) vs Baseline"
                    total_files = result['file_level_better'] + result['file_level_worse'] + result['file_level_equal']
                    better_pct = (result['file_level_better'] / total_files * 100) if total_files > 0 else 0.0
                    print_table_row([
                        comparison_name,
                        model,
                        str(result['common_files']),
                        str(result['file_level_better']),
                        str(result['file_level_worse']),
                        str(result['file_level_equal']),
                        f"{better_pct:.2f}%"
                    ], file_widths)
        
        # Vulnerabilities - Comparison with Baseline
        print("\n【Vulnerability Comparison】")
        print("Compare vulnerability count differences between each ablation method and Baseline (Repo) and SolAgent (Full) (only for files that compiled successfully in both)\n")
        
        if not baseline_repo:
            print("  Missing Baseline (Repo) data, cannot perform comparison")
        else:
            baseline_vuln_by_file = baseline_repo.get('vuln_by_file', {})
            
            # Header
            widths = [30, 20, 15, 15, 15, 15, 18, 18, 14, 20]
            print_table_header([
                'Comparison', 'Model', '#Common Files', '#Less Vuln', '#More Vuln', '#Equal',
                'Baseline Vuln Sum', 'Method Vuln Sum', 'Δ% vs Base', 'Vuln Diff'
            ], widths)
            
            # Compare ablations with Baseline (Repo)
            for ablation_stat in ablation_stats:
                method_vuln_by_file = ablation_stat.get('vuln_by_file', {})
                
                # Find common files (both compiled)
                common_files = set(baseline_vuln_by_file.keys()) & set(method_vuln_by_file.keys())
                
                if common_files:
                    less_vuln = 0
                    more_vuln = 0
                    equal_vuln = 0
                    total_diff = 0
                    baseline_sum = 0
                    method_sum = 0
                    
                    for file_path in common_files:
                        baseline_count = baseline_vuln_by_file[file_path]
                        method_count = method_vuln_by_file[file_path]
                        diff = method_count - baseline_count
                        total_diff += diff
                        baseline_sum += baseline_count
                        method_sum += method_count
                        
                        if method_count < baseline_count:
                            less_vuln += 1
                        elif method_count > baseline_count:
                            more_vuln += 1
                        else:
                            equal_vuln += 1
                    
                    comparison_name = f"{ablation_stat['source']} vs Baseline"
                    
                    delta_pct = None
                    if baseline_sum > 0:
                        delta_pct = (method_sum - baseline_sum) / baseline_sum * 100.0
                    delta_str = f"{delta_pct:+.2f}%" if delta_pct is not None else "N/A"
                    
                    print_table_row([
                        comparison_name,
                        model,
                        str(len(common_files)),
                        str(less_vuln),
                        str(more_vuln),
                        str(equal_vuln),
                        str(baseline_sum),
                        str(method_sum),
                        delta_str,
                        f"{total_diff:+d}"
                    ], widths)
            
            # Compare ablations with SolAgent (Full)
            if solagent_full:
                full_vuln_by_file = solagent_full.get('vuln_by_file', {})
                
                for ablation_stat in ablation_stats:
                    method_vuln_by_file = ablation_stat.get('vuln_by_file', {})
                    
                    common_files = set(full_vuln_by_file.keys()) & set(method_vuln_by_file.keys())
                    
                    if common_files:
                        less_vuln = 0
                        more_vuln = 0
                        equal_vuln = 0
                        total_diff = 0
                        full_sum = 0
                        method_sum = 0
                        
                        for file_path in common_files:
                            full_count = full_vuln_by_file[file_path]
                            method_count = method_vuln_by_file[file_path]
                            diff = method_count - full_count
                            total_diff += diff
                            full_sum += full_count
                            method_sum += method_count
                            
                            if method_count < full_count:
                                less_vuln += 1
                            elif method_count > full_count:
                                more_vuln += 1
                            else:
                                equal_vuln += 1
                        
                        comparison_name = f"{ablation_stat['source']} vs Full"
                        
                        delta_pct = None
                        if full_sum > 0:
                            delta_pct = (method_sum - full_sum) / full_sum * 100.0
                        delta_str = f"{delta_pct:+.2f}%" if delta_pct is not None else "N/A"
                        
                        print_table_row([
                            comparison_name,
                            model,
                            str(len(common_files)),
                            str(less_vuln),
                            str(more_vuln),
                            str(equal_vuln),
                            str(full_sum),
                            str(method_sum),
                            delta_str,
                            f"{total_diff:+d}"
                        ], widths)
                
                # Compare SolAgent (Full) with Baseline (Repo)
                common_files = set(baseline_vuln_by_file.keys()) & set(full_vuln_by_file.keys())
                
                if common_files:
                    less_vuln = 0
                    more_vuln = 0
                    equal_vuln = 0
                    total_diff = 0
                    baseline_sum = 0
                    full_sum = 0
                    
                    for file_path in common_files:
                        baseline_count = baseline_vuln_by_file[file_path]
                        full_count = full_vuln_by_file[file_path]
                        diff = full_count - baseline_count
                        total_diff += diff
                        baseline_sum += baseline_count
                        full_sum += full_count
                        
                        if full_count < baseline_count:
                            less_vuln += 1
                        elif full_count > baseline_count:
                            more_vuln += 1
                        else:
                            equal_vuln += 1
                    
                    comparison_name = "SolAgent (Full) vs Baseline"
                    
                    delta_pct = None
                    if baseline_sum > 0:
                        delta_pct = (full_sum - baseline_sum) / baseline_sum * 100.0
                    delta_str = f"{delta_pct:+.2f}%" if delta_pct is not None else "N/A"
                    
                    print_table_row([
                        comparison_name,
                        model,
                        str(len(common_files)),
                        str(less_vuln),
                        str(more_vuln),
                        str(equal_vuln),
                        str(baseline_sum),
                        str(full_sum),
                        delta_str,
                        f"{total_diff:+d}"
                    ], widths)
        
        # Min-vuln round metrics for ablations
        print("\n【Ablation: Metrics at Min-Vuln Round】")
        print("Ablation experiment statistics at min-vuln round (compared with SolAgent (Full))\n")
        
        if solagent_full:
            widths = [18, 15, 12, 14, 12, 18, 14, 20, 15, 15, 15, 18, 18, 14, 20]
            print_table_header([
                'Source', 'Model', 'Files', 'Compile Rate', 'test_pass', 'test_total', 
                'Pass@1 overall', 'Pass@1 (mean±std)', 
                '#Less Vuln', '#More Vuln', '#Equal', 
                'Full Vuln Sum', 'Method Vuln Sum', 'Δ% vs Full', 'Vuln Diff'
            ], widths)
            
            full_vuln_by_file = solagent_full.get('min_vuln_vuln_by_file', {})
            
            for ablation_stat in ablation_stats:
                # Use min-vuln specific metrics
                method_vuln_by_file = ablation_stat.get('min_vuln_vuln_by_file', {})
                
                # Find common files (both compiled)
                common_files = set(full_vuln_by_file.keys()) & set(method_vuln_by_file.keys())
                
                less_vuln = 0
                more_vuln = 0
                equal_vuln = 0
                total_diff = 0
                full_sum = 0
                method_sum = 0
                
                if common_files:
                    for file_path in common_files:
                        full_count = full_vuln_by_file[file_path]
                        method_count = method_vuln_by_file[file_path]
                        diff = method_count - full_count
                        total_diff += diff
                        full_sum += full_count
                        method_sum += method_count
                        
                        if method_count < full_count:
                            less_vuln += 1
                        elif method_count > full_count:
                            more_vuln += 1
                        else:
                            equal_vuln += 1
                
                delta_pct = None
                if full_sum > 0:
                    delta_pct = (method_sum - full_sum) / full_sum * 100.0
                delta_str = f"{delta_pct:+.2f}%" if delta_pct is not None else "N/A"
                
                # Use min-vuln round metrics
                min_vuln_total_pass = ablation_stat.get('min_vuln_total_pass', 0)
                min_vuln_total_tests = ablation_stat.get('min_vuln_total_tests', 0)
                min_vuln_compiled = ablation_stat.get('min_vuln_compiled_files', 0)
                overall_rate = compute_pass_rate(min_vuln_total_pass, test_case_total) if test_case_total else 0.0
                
                print_table_row([
                    ablation_stat['source'],
                    model,
                    f"{min_vuln_compiled}/{ablation_stat['total_files']}",
                    format_percentage(min_vuln_compiled / ablation_stat['total_files'] if ablation_stat['total_files'] > 0 else 0),
                    str(min_vuln_total_pass),
                    str(min_vuln_total_tests),
                    format_percentage(overall_rate),
                    format_stats(ablation_stat.get('min_vuln_pass_rate_stats', {'mean': 0, 'std': 0, 'count': 0})),
                    str(less_vuln),
                    str(more_vuln),
                    str(equal_vuln),
                    str(full_sum),
                    str(method_sum),
                    delta_str,
                    f"{total_diff:+d}"
                ], widths)
            
            # Also show SolAgent (Full) at min-vuln round as reference
            print_table_row([
                solagent_full['source'],
                model,
                f"{solagent_full.get('min_vuln_compiled_files', 0)}/{solagent_full['total_files']}",
                format_percentage(solagent_full.get('min_vuln_compiled_files', 0) / solagent_full['total_files'] if solagent_full['total_files'] > 0 else 0),
                str(solagent_full.get('min_vuln_total_pass', 0)),
                str(solagent_full.get('min_vuln_total_tests', 0)),
                format_percentage(compute_pass_rate(solagent_full.get('min_vuln_total_pass', 0), test_case_total) if test_case_total else 0.0),
                format_stats(solagent_full.get('min_vuln_pass_rate_stats', {'mean': 0, 'std': 0, 'count': 0})),
                "-",
                "-",
                "-",
                "-",
                "-",
                "-",
                "-"
            ], widths)
    
    print("\n" + "="*170)


def main():
    parser = argparse.ArgumentParser(description='RQ-2 Ablation Study Statistics')
    parser.add_argument('--db', type=str, default='output/progress.db', help='Database path')
    parser.add_argument('--models', type=str, default=','.join(TARGET_MODELS), 
                       help='Comma-separated model names')
    parser.add_argument('--ablation-types', type=str, default=','.join(map(str, ABLATION_TYPES.keys())),
                       help='Comma-separated ablation type IDs')
    
    args = parser.parse_args()
    models = [m.strip() for m in args.models.split(',')]
    ablation_types = [int(a.strip()) for a in args.ablation_types.split(',')]
    
    all_stats = []
    
    # Collect Baseline (Repo) stats - only once since it's model-independent
    print("Collecting Baseline (Repo) statistics...")
    baseline = collect_baseline_stats(args.db)
    if baseline:
        all_stats.append(baseline)
    
    # For each model, collect SolAgent (Full) and ablation stats
    for model in models:
        print(f"\nCollecting statistics for model {model}...")
        
        # SolAgent (Full) from process_tracking
        print(f"  - Collecting SolAgent (Full) data...")
        solagent_full = collect_solagent_stats(args.db, model)
        if solagent_full:
            all_stats.append(solagent_full)
        
        # Ablation experiments from process_tracking_ablation
        for ablation_type in ablation_types:
            ablation_name = ABLATION_TYPES.get(ablation_type, f"type_{ablation_type}")
            print(f"  - Collecting ablation experiment {ablation_name} data...")
            ablation_stat = collect_ablation_stats(args.db, model, ablation_type)
            if ablation_stat:
                all_stats.append(ablation_stat)
    
    # Get test case total from baseline
    from stats.common_utils import get_baseline_test_total
    test_case_total = get_baseline_test_total(args.db)
    
    # Print results
    print_ablation_comparison(all_stats, test_case_total)
    
    print(f"\nStatistics completed! Processed {len(all_stats)} groups of data.")


if __name__ == '__main__':
    main()
