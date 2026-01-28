#!/usr/bin/env python3
"""
RQ-1 Statistics: Compare pass@1, gas usage, and vulnerabilities across
- Baseline (original repository code)
- Raw model (direct LLM generation)
- SolAgent (our framework with process_tracking)
- SOTA agents (MetaGPT, DeepCode, QwenAgent)

Usage:
    python stats/rq1_statistics.py --db output/progress.db
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
from db.baseline_test import BaselineTest
from db.progress_tracker_rawmodel import ProgressTrackerRawModel
from db.progress_tracker import ProgressTracker
from db.progress_tracker_agent import ProgressTrackerAgent
from db.progress_tracker_summary import ProgressTrackerSummary


TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]
AGENT_TYPES = ["metagpt", "deepcode", "qwenagent", "copilot"]


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


def collect_rawmodel_stats(db_path: str, model: str):
    """Collect statistics from progress_tracker_rawmodel table."""
    tracker = ProgressTrackerRawModel(db_path)
    all_rows = tracker.get_all_entries(status=1)
    rows = [r for r in all_rows if r['model_coding'] == model]
    
    if not rows:
        return None
    
    total_files = len(rows)
    compiled_files = sum(1 for r in rows if r['test_total'] > 0)
    total_pass = sum(r['test_pass'] for r in rows)
    total_tests = sum(r['test_total'] for r in rows)
    
    gas_mean_values = []
    gas_median_values = []
    vuln_values = []
    per_test_gas = {}
    
    for row in rows:
        if row['test_total'] > 0:
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
            
            vuln_values.append(row['vuln_count'] or 0)
    
    return {
        'source': 'Raw Model',
        'model': model,
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


def collect_solagent_stats(db_path: str, model: str, tracker_class=None, source_name=None):
    """Collect statistics from process_tracking table (SolAgent framework).
    
    Args:
        db_path: Database path
        model: Model name
        tracker_class: Optional tracker class to use (default: ProgressTracker)
        source_name: Optional source name override (default: 'SolAgent')
    """
    if tracker_class is None:
        tracker_class = ProgressTracker
    if source_name is None:
        source_name = 'SolAgent'
    
    tracker = tracker_class(db_path)
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
    vuln_by_file = {}  # Track vuln count for each file at best pass round
    
    # Min-vuln round specific metrics
    min_vuln_compiled_files = 0
    min_vuln_total_pass = 0
    min_vuln_total_tests = 0
    min_vuln_pass_rates = []
    min_vuln_vuln_by_file = {}  # Track vuln count for each file at min vuln round
    
    # Track files with mismatched data
    files_with_mismatched_counts = []
    files_with_test_no_gas_at_all = []  # Files that passed tests but have NO gas data
    
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
            
            # Check for mismatch between test_json passed count and gas_json test count
            gas_test_count = 0
            has_gas_data_at_round = False
            if round_gas_json and str(best_round) in round_gas_json:
                gas_data = round_gas_json[str(best_round)]
                if isinstance(gas_data, dict) and len(gas_data) > 0:
                    gas_test_count = len(gas_data)
                    has_gas_data_at_round = True
            
            # Track files with no gas data at all
            if not has_gas_data_at_round and best_pass > 0:
                files_with_test_no_gas_at_all.append({
                    'file_path': row.get('file_path', 'unknown'),
                    'id': row.get('id'),
                    'best_round': best_round,
                    'test_passed': best_pass,
                    'test_total': best_total
                })
            
            # Compare test passed count with gas test count (only when gas data exists)
            if has_gas_data_at_round and best_pass != gas_test_count:
                files_with_mismatched_counts.append({
                    'file_path': row.get('file_path', 'unknown'),
                    'id': row.get('id'),
                    'best_round': best_round,
                    'test_passed': best_pass,
                    'test_total': best_total,
                    'gas_count': gas_test_count
                })
            
            # Gas at best pass round
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
    
    # Print diagnostic information
    if files_with_test_no_gas_at_all:
        print(f"\n[Diagnostic Info] {model} - Files that passed tests but have no Gas data ({len(files_with_test_no_gas_at_all)} files):")
        print(f"{'ID':<6} {'Round':<7} {'Test Passed':<13} {'Test Total':<12} File Path")
        print("-" * 120)
        total_missing_tests = 0
        for info in files_with_test_no_gas_at_all[:20]:  # Print first 20
            print(f"{info['id']:<6} {info['best_round']:<7} {info['test_passed']:<13} {info['test_total']:<12} {info['file_path']}")
            total_missing_tests += info['test_passed']
        if len(files_with_test_no_gas_at_all) > 20:
            print(f"... and {len(files_with_test_no_gas_at_all) - 20} other files")
            for info in files_with_test_no_gas_at_all[20:]:
                total_missing_tests += info['test_passed']
        
        print(f"\nMissing Gas data for these files corresponds to {total_missing_tests} passed test cases")
        print(f"This explains why Pass@1 has more test count, but Gas comparison has fewer test count")
    
    if files_with_mismatched_counts:
        print(f"\n[Diagnostic Info] {model} - Files with Gas data but Test Passed count doesn't match Gas data count ({len(files_with_mismatched_counts)} files):")
        print(f"{'ID':<6} {'Round':<7} {'Test Passed':<13} {'Gas Count':<11} {'Diff':<6} File Path")
        print("-" * 120)
        for info in files_with_mismatched_counts[:20]:  # Print first 20
            diff = info['test_passed'] - info['gas_count']
            print(f"{info['id']:<6} {info['best_round']:<7} {info['test_passed']:<13} {info['gas_count']:<11} {diff:+<6} {info['file_path']}")
        if len(files_with_mismatched_counts) > 20:
            print(f"... and {len(files_with_mismatched_counts) - 20} other files")
        
        # Summary statistics
        total_test_passed = sum(f['test_passed'] for f in files_with_mismatched_counts)
        total_gas_count = sum(f['gas_count'] for f in files_with_mismatched_counts)
        print(f"\nSummary: Test Passed Total = {total_test_passed}, Gas Count Total = {total_gas_count}, Difference = {total_test_passed - total_gas_count}")
    
    return {
        'source': source_name,
        'model': model,
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


def collect_solagent_summary_stats(db_path: str, model: str):
    """Collect statistics from process_tracking_summary table (SolAgent-Summary framework).
    
    This is a thin wrapper that reuses collect_solagent_stats with a different tracker.
    """
    return collect_solagent_stats(db_path, model, 
                                   tracker_class=ProgressTrackerSummary, 
                                   source_name='SolAgent-Summary')


def collect_agent_stats(db_path: str, model: str, agent_type: str):
    """Collect statistics from progress_tracker_agent table."""
    tracker = ProgressTrackerAgent(db_path)
    rows = tracker.get_all_entries(model_coding=model, agent_type=agent_type)
    # Include all files regardless of status (status=1 or status=2)
    # rows = [r for r in rows if r.get('status') == 1]
    
    if not rows:
        return None
    
    total_files = len(rows)
    compiled_files = sum(1 for r in rows if r['test_total'] > 0)
    total_pass = sum(r['test_pass'] for r in rows)
    total_tests = sum(r['test_total'] for r in rows)
    
    gas_mean_values = []
    gas_median_values = []
    vuln_values = []
    per_test_gas = {}
    
    for row in rows:
        if row['test_total'] > 0:
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
            
            vuln_values.append(row['vuln_count'] or 0)
    
    return {
        'source': f'Agent-{agent_type}',
        'model': model,
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


def print_comparison_table(all_stats, test_case_total: int):
    """Print comprehensive comparison table."""
    print("\n" + "="*170)
    print("RQ-1 Experimental Results")
    print("="*170)
    
    # Pass@1 and Compilation Rate
    print("\n【Pass@1 and Compilation Rate】")
    print(f"Total Test Cases (Baseline): {test_case_total}\n")
    widths = [18, 12, 12, 14, 12, 18, 14, 20]
    print_table_header(['Source', 'Model', 'Files', 'Compile Rate', 'test_pass', 'test_total', 'Pass@1 overall', 'Pass@1 (mean±std)'], widths)
    
    for stat in all_stats:
        if stat:
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
    print("SolAgent vs. Baselines - Pairwise Intersection Analysis\n")
    
    # Group stats by model
    stats_by_model = {}
    for stat in all_stats:
        if stat and 'per_test_gas' in stat:
            model = stat.get('model', 'N/A')
            if model not in stats_by_model:
                stats_by_model[model] = {}
            stats_by_model[model][stat['source']] = stat
    
    widths = [30, 20, 12, 15, 15, 15, 15, 15, 15, 15, 15]
    headers = ['Comparison', 'Model', '#Common', 'Median R(-)', 'Median R(~)', 'Mean R(-)', 'Mean R(~)', 
               'Trim5% R(-)', 'Trim5% R(~)', 'P90 R(-)', 'P90 R(~)']
    # headers += ['%Better(-)', '%Better(~)', '%Worse(-)', '%Worse(~)']  # temporarily commented out
    print_table_header(headers, widths)
    
    comparison_count = 0
    # For each model, compare SolAgent with all other methods
    for model in sorted(stats_by_model.keys()):
        model_stats = stats_by_model[model]
        solagent_stat = model_stats.get('SolAgent')
        
        if solagent_stat:
            # Compare with all other sources for this model
            for source in sorted(model_stats.keys()):
                if source not in ['SolAgent', 'SolAgent-Summary']:
                    baseline_stat = model_stats[source]
                    
                    # Compute pairwise comparison
                    result = compute_pairwise_gas_comparison(
                        solagent_stat['per_test_gas'],
                        baseline_stat['per_test_gas']
                    )
                    
                    if result['common_count'] > 0:
                        comparison_name = f"SolAgent vs {source}"
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
                            # f"{result['better_percentage_mean']:.1f}%",
                            # f"{result['better_percentage_median']:.1f}%",
                            # f"{result['worse_percentage_mean']:.1f}%",
                            # f"{result['worse_percentage_median']:.1f}%"
                        ], widths)
                        comparison_count += 1
    
    # Also compare with Baseline (Repo) which has N/A model
    baseline_repo = None
    for stat in all_stats:
        if stat and stat['source'] == 'Baseline (Repo)' and 'per_test_gas' in stat:
            baseline_repo = stat
            break
    
    if baseline_repo:
        # Compare each SolAgent model with Baseline (Repo)
        for model in sorted(stats_by_model.keys()):
            if model != 'N/A':
                model_stats = stats_by_model[model]
                solagent_stat = model_stats.get('SolAgent')
                
                if solagent_stat:
                    result = compute_pairwise_gas_comparison(
                        solagent_stat['per_test_gas'],
                        baseline_repo['per_test_gas']
                    )
                    
                    if result['common_count'] > 0:
                        comparison_name = "SolAgent vs Baseline (Repo)"
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
                            # f"{result['better_percentage_mean']:.1f}%",
                            # f"{result['better_percentage_median']:.1f}%",
                            # f"{result['worse_percentage_mean']:.1f}%",
                            # f"{result['worse_percentage_median']:.1f}%"
                        ], widths)
                        comparison_count += 1
    
    if comparison_count == 0:
        print("  No pairwise comparisons available (no common test cases found)")
    else:
        print("\nNote:")
        print("- Median R(-): Median of mean gas ratios (SolAgent '-' / Baseline '-')")
        print("- Median R(~): Median of median gas ratios (SolAgent '~' / Baseline '~')")
        print("- Mean R(-): Mean of mean gas ratios")
        print("- Mean R(~): Mean of median gas ratios")
        print("- Trim5% R(-/~): 5% trimmed mean (remove lowest & highest 5% before averaging)")
        print("- P90 R(-/~): 90th percentile ratio (90% of test cases have ratio ≤ this value)")
        print("- %Better: Percentage of common test cases where SolAgent uses less gas")
        print("- %Worse: Percentage of common test cases where SolAgent uses more gas")
        print("- All ratios: lower is better (ratio < 1.0 means SolAgent saves gas)")
    
    # SolAgent-Summary Gas Usage - Pairwise Intersection Comparison
    print("\n【SolAgent-Summary: Gas Usage Comparison (Pairwise Intersection)】")
    print("SolAgent-Summary vs. Baselines - Pairwise Intersection Analysis\n")
    
    print_table_header(headers, widths)
    
    summary_comparison_count = 0
    # For each model, compare SolAgent-Summary with all other methods
    for model in sorted(stats_by_model.keys()):
        model_stats = stats_by_model[model]
        summary_stat = model_stats.get('SolAgent-Summary')
        
        if summary_stat:
            # Compare with all other sources for this model (excluding SolAgent and itself)
            for source in sorted(model_stats.keys()):
                if source not in ['SolAgent', 'SolAgent-Summary']:
                    baseline_stat = model_stats[source]
                    
                    # Compute pairwise comparison
                    result = compute_pairwise_gas_comparison(
                        summary_stat['per_test_gas'],
                        baseline_stat['per_test_gas']
                    )
                    
                    if result['common_count'] > 0:
                        comparison_name = f"SolAgent-Summary vs {source}"
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
                        summary_comparison_count += 1
    
    # Compare SolAgent-Summary with Baseline (Repo)
    if baseline_repo:
        for model in sorted(stats_by_model.keys()):
            if model != 'N/A':
                model_stats = stats_by_model[model]
                summary_stat = model_stats.get('SolAgent-Summary')
                
                if summary_stat:
                    result = compute_pairwise_gas_comparison(
                        summary_stat['per_test_gas'],
                        baseline_repo['per_test_gas']
                    )
                    
                    if result['common_count'] > 0:
                        comparison_name = "SolAgent-Summary vs Baseline (Repo)"
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
                        summary_comparison_count += 1
    
    if summary_comparison_count == 0:
        print("  No pairwise comparisons available for SolAgent-Summary (no common test cases found)")
    
    # File-level Gas comparison
    print("\n【File-Level Gas Comparison】")
    print("Compare total gas consumption per file (aggregate all common test cases)\n")
    
    file_widths = [30, 20, 15, 15, 15, 15, 15]
    file_headers = ['Comparison', 'Model', '#Common Files', 'Files Better', 'Files Worse', 'Files Equal', 'Better Files %']
    print_table_header(file_headers, file_widths)
    
    # Re-iterate to print file-level stats
    for model in sorted(stats_by_model.keys()):
        model_stats = stats_by_model[model]
        solagent_stat = model_stats.get('SolAgent')
        
        if solagent_stat:
            for source in sorted(model_stats.keys()):
                if source not in ['SolAgent', 'SolAgent-Summary']:
                    baseline_stat = model_stats[source]
                    result = compute_pairwise_gas_comparison(
                        solagent_stat['per_test_gas'],
                        baseline_stat['per_test_gas']
                    )
                    
                    if result['common_count'] > 0 and 'file_level_better' in result:
                        comparison_name = f"SolAgent vs {source}"
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
    
    # File-level comparison with Baseline (Repo)
    if baseline_repo:
        for model in sorted(stats_by_model.keys()):
            if model != 'N/A':
                model_stats = stats_by_model[model]
                solagent_stat = model_stats.get('SolAgent')
                
                if solagent_stat:
                    result = compute_pairwise_gas_comparison(
                        solagent_stat['per_test_gas'],
                        baseline_repo['per_test_gas']
                    )
                    
                    if result['common_count'] > 0 and 'file_level_better' in result:
                        comparison_name = "SolAgent vs Baseline (Repo)"
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
    print("Compare vulnerability count differences between each method and Baseline (Repo) (only for files that compiled successfully in both)\n")
    
    baseline_repo = None
    for stat in all_stats:
        if stat and stat['source'] == 'Baseline (Repo)':
            baseline_repo = stat
            break
    
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
        
        for stat in all_stats:
            if stat and stat['source'] != 'Baseline (Repo)':
                method_vuln_by_file = stat.get('vuln_by_file', {})
                
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
                    
                    # Format comparison name
                    comparison_name = f"{stat['source']} vs Baseline"
                    
                    delta_pct = None
                    if baseline_sum > 0:
                        delta_pct = (method_sum - baseline_sum) / baseline_sum * 100.0

                    delta_str = f"{delta_pct:+.2f}%" if delta_pct is not None else "N/A"

                    print_table_row([
                        comparison_name,
                        stat['model'],
                        str(len(common_files)),
                        str(less_vuln),
                        str(more_vuln),
                        str(equal_vuln),
                        str(baseline_sum),
                        str(method_sum),
                        delta_str,
                        f"{total_diff:+d}"
                    ], widths)
    
    # SolAgent additional metrics (pass/gas at min vuln round)
    solagent_stats = [s for s in all_stats if s and s['source'] in ['SolAgent', 'SolAgent-Summary']]
    if solagent_stats and baseline_repo:
        print("\n【SolAgent: Metrics at Min-Vuln Round】")
        print("SolAgent statistics at min-vuln round (including comparison with Baseline)\n")
        
        # Wider table to accommodate all columns
        widths = [18, 15, 12, 14, 12, 18, 14, 20, 15, 15, 15, 18, 18, 14, 20]
        print_table_header([
            'Source', 'Model', 'Files', 'Compile Rate', 'test_pass', 'test_total', 
            'Pass@1 overall', 'Pass@1 (mean±std)', 
            '#Less Vuln', '#More Vuln', '#Equal', 
            'Baseline Vuln Sum', 'Method Vuln Sum', 'Δ% vs Base', 'Vuln Diff'
        ], widths)
        
        baseline_vuln_by_file = baseline_repo.get('vuln_by_file', {})
        
        for stat in solagent_stats:
            # Use min-vuln specific metrics
            method_vuln_by_file = stat.get('min_vuln_vuln_by_file', {})
            
            # Find common files (both compiled)
            common_files = set(baseline_vuln_by_file.keys()) & set(method_vuln_by_file.keys())
            
            less_vuln = 0
            more_vuln = 0
            equal_vuln = 0
            total_diff = 0
            baseline_sum = 0
            method_sum = 0
            
            if common_files:
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
            
            delta_pct = None
            if baseline_sum > 0:
                delta_pct = (method_sum - baseline_sum) / baseline_sum * 100.0
            delta_str = f"{delta_pct:+.2f}%" if delta_pct is not None else "N/A"
            
            # Use min-vuln round metrics
            min_vuln_total_pass = stat.get('min_vuln_total_pass', 0)
            min_vuln_total_tests = stat.get('min_vuln_total_tests', 0)
            min_vuln_compiled = stat.get('min_vuln_compiled_files', 0)
            overall_rate = compute_pass_rate(min_vuln_total_pass, test_case_total) if test_case_total else 0.0
            
            print_table_row([
                stat['source'],
                stat['model'],
                f"{min_vuln_compiled}/{stat['total_files']}",
                format_percentage(min_vuln_compiled / stat['total_files'] if stat['total_files'] > 0 else 0),
                str(min_vuln_total_pass),
                str(min_vuln_total_tests),
                format_percentage(overall_rate),
                format_stats(stat.get('min_vuln_pass_rate_stats', {'mean': 0, 'std': 0, 'count': 0})),
                str(less_vuln),
                str(more_vuln),
                str(equal_vuln),
                str(baseline_sum),
                str(method_sum),
                delta_str,
                f"{total_diff:+d}"
            ], widths)
    
    print("\n" + "="*120)


def main():
    parser = argparse.ArgumentParser(description='RQ-1 Statistics Analysis')
    parser.add_argument('--db', type=str, default='output/progress.db', help='Database path')
    parser.add_argument('--models', type=str, default=','.join(TARGET_MODELS), 
                       help='Comma-separated model names')
    parser.add_argument('--agents', type=str, default=','.join(AGENT_TYPES),
                       help='Comma-separated agent types')
    
    args = parser.parse_args()
    models = [m.strip() for m in args.models.split(',')]
    agents = [a.strip() for a in args.agents.split(',')]
    
    all_stats = []
    
    # Baseline
    print("Collecting Baseline statistics...")
    baseline = collect_baseline_stats(args.db)
    if baseline:
        all_stats.append(baseline)
    
    # Raw Model + SolAgent + SolAgent-Summary for each model
    for model in models:
        print(f"Collecting statistics for model {model}...")
        
        rawmodel = collect_rawmodel_stats(args.db, model)
        if rawmodel:
            all_stats.append(rawmodel)
        
        solagent = collect_solagent_stats(args.db, model)
        if solagent:
            all_stats.append(solagent)
        
        solagent_summary = collect_solagent_summary_stats(args.db, model)
        if solagent_summary:
            all_stats.append(solagent_summary)
    
    # SOTA Agents
    for agent_type in agents:
        for model in models:
            print(f"Collecting statistics for {agent_type} agent (model={model})...")
            agent_stat = collect_agent_stats(args.db, model, agent_type)
            if agent_stat:
                all_stats.append(agent_stat)
    
    # Get test case total from baseline
    from stats.common_utils import get_baseline_test_total
    test_case_total = get_baseline_test_total(args.db)
    
    # Print results
    print_comparison_table(all_stats, test_case_total)
    
    print(f"\nStatistics completed! Processed {len(all_stats)} groups of data.")


if __name__ == '__main__':
    main()
