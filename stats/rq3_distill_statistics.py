#!/usr/bin/env python3
"""
RQ-3 Statistics: Compare distilled models with pre-distillation baselines
Compare model performance changes before and after distillation

Model groups:
- Pre-distillation (teacher): Qwen/Qwen3-8B, Qwen/Qwen3-32B
- Post-distillation (student): solagent-4k-mixed-v1, solagent-4k-tracker-v1, 
                                solagent-4k-tracker-v2, solagent-4k-mixed-v2

Training set exclusion: Uniformly exclude files in solagent-4k-tracker-v1.json

Usage:
    python stats/rq3_distill_statistics.py --db output/progress.db
"""
import argparse
import sys
import os
import json
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from collections import defaultdict
from stats.common_utils import (
    safe_json_loads, get_best_pass_round,
    get_min_vuln_round, get_gas_at_round, get_test_at_round,
    get_vuln_at_round, compute_pass_rate, aggregate_stats,
    print_table_header, print_table_row, format_stats, format_percentage,
    compute_pairwise_gas_comparison, extract_per_test_gas
)
from db.baseline_test import BaselineTest
from db.progress_tracker import ProgressTracker


# Model groups for distillation comparison
PRE_DISTILL_MODELS = ["Qwen/Qwen3-8B", "Qwen/Qwen3-32B"]
POST_DISTILL_MODELS = [
    "solagent-4k-tracker-v1",
    "solagent-4k-tracker-v2", 
    "solagent-4k-mixed-v1", 
    "solagent-4k-mixed-v2"
]

ALL_MODELS = PRE_DISTILL_MODELS + POST_DISTILL_MODELS

# Training set file path
TRAINING_SET_PATH = "z0train/train_files/solagent-4k-tracker-v1.json"


def load_training_set_files():
    """Load training set file paths to exclude from statistics."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    train_file_path = os.path.join(os.path.dirname(script_dir), TRAINING_SET_PATH)
    
    if not os.path.exists(train_file_path):
        print(f"Warning: Training set file does not exist: {train_file_path}")
        return set()
    
    with open(train_file_path, 'r', encoding='utf-8') as f:
        training_files = json.load(f)
    
    print(f"Loaded training set file: {len(training_files)} files will be excluded")
    return set(training_files)


def collect_model_stats(db_path: str, model: str, exclude_files: set):
    """Collect statistics for a specific model from process_tracking table."""
    tracker = ProgressTracker(db_path)
    all_rows = tracker.get_all_entries()  # Get all entries regardless of status
    # Filter by model and exclude training set files
    rows = [r for r in all_rows if r['model_coding'] == model and r.get('file_path', '') not in exclude_files]
    
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
    total_pass = 0
    total_tests = 0
    per_test_gas = {}
    vuln_by_file = {}
    
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
                pass_rate_at_min = compute_pass_rate(pass_at_min, total_at_min)
                pass_at_min_vuln.append(pass_rate_at_min)
    
    return {
        'model': model,
        'model_type': 'Pre-Distill' if model in PRE_DISTILL_MODELS else 'Post-Distill',
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
        'per_test_gas': per_test_gas,
        'vuln_by_file': vuln_by_file
    }


def get_baseline_test_total(db_path: str, exclude_files: set) -> int:
    """Get total test count from baseline_test table, excluding training set files."""
    baseline = BaselineTest(db_path)
    rows = baseline.get_all_entries()
    
    if not rows:
        return 0
    
    # Exclude training set files
    total_tests = sum(r['test_total'] for r in rows if r.get('file_path', '') not in exclude_files)
    return total_tests


def print_overall_comparison(all_stats, test_case_total: int):
    """Print overall comparison table."""
    print("\n" + "="*150)
    print("RQ-3: Pre-Distillation vs. Post-Distillation Comparison")
    print("="*150)
    
    # Find teacher model for delta calculation
    teacher_stat = None
    for stat in all_stats:
        if stat and stat['model'] == 'Qwen/Qwen3-8B':
            teacher_stat = stat
            break
    
    teacher_compile = teacher_stat['compilation_rate'] if teacher_stat else 0
    teacher_pass_overall = 0
    if teacher_stat and test_case_total > 0:
        teacher_pass_overall = compute_pass_rate(teacher_stat.get('total_pass', 0), test_case_total)
    
    # Pass@1 and Compilation Rate
    print("\n【Pass@1 and Compilation Rate】")
    print(f"Total Test Cases (Baseline): {test_case_total}")
    print(f"Delta Baseline: Qwen/Qwen3-8B (Teacher Model)\n")
    widths = [25, 20, 12, 14, 14, 12, 18, 14, 20, 20]
    print_table_header(['Model', 'Type', 'Files', 'Compile Rate', 'ΔCompile %', 'test_pass', 'test_total', 
                       'Pass@1 overall', 'ΔPass@1 %', 'Pass@1 (mean±std)'], widths)
    
    for stat in all_stats:
        if stat:
            total_pass = stat.get('total_pass', 0)
            overall_rate = compute_pass_rate(total_pass, test_case_total) if test_case_total else 0.0
            
            # Calculate deltas
            delta_compile = (stat['compilation_rate'] - teacher_compile) * 100
            delta_pass = (overall_rate - teacher_pass_overall) * 100
            
            print_table_row([
                stat['model'],
                stat['model_type'],
                f"{stat['compiled_files']}/{stat['total_files']}",
                format_percentage(stat['compilation_rate']),
                f"{delta_compile:+.2f}%",
                str(total_pass),
                str(stat.get('total_tests', 0)),
                format_percentage(overall_rate),
                f"{delta_pass:+.2f}%",
                format_stats(stat['pass_rate_stats'])
            ], widths)
    
    # Gas Usage Comparison
    print("\n【Gas Usage Comparison (Pairwise Intersection)】")
    print("Post-Distill vs. Pre-Distill Models - Pairwise Intersection Analysis\n")
    
    widths = [40, 12, 15, 15, 15, 15, 15, 15, 15, 15]
    headers = ['Comparison', '#Common', 'Median R(-)', 'Median R(~)', 'Mean R(-)', 'Mean R(~)', 
               'Trim5% R(-)', 'Trim5% R(~)', 'P90 R(-)', 'P90 R(~)']
    print_table_header(headers, widths)
    
    # Group stats by type
    pre_distill_stats = [s for s in all_stats if s and s['model_type'] == 'Pre-Distill']
    post_distill_stats = [s for s in all_stats if s and s['model_type'] == 'Post-Distill']
    
    # Compare each post-distill with each pre-distill
    for post_stat in post_distill_stats:
        for pre_stat in pre_distill_stats:
            result = compute_pairwise_gas_comparison(
                post_stat['per_test_gas'],
                pre_stat['per_test_gas']
            )
            
            if result['common_count'] > 0:
                comparison_name = f"{post_stat['model']} vs {pre_stat['model']}"
                print_table_row([
                    comparison_name,
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
    print("- Ratio < 1.0: Post-Distill model uses less gas (better)")
    print("- Ratio > 1.0: Post-Distill model uses more gas (worse)")
    print("- Median R(-): Median of mean gas ratios")
    print("- Median R(~): Median of median gas ratios")
    print("- Trim5% R: 5% trimmed mean (remove extreme 5% from both ends)")
    print("- P90 R: 90th percentile ratio")
    
    # Vulnerabilities Comparison (Post-Distill vs Pre-Distill)
    print("\n【Vulnerability Comparison】")
    print("Compare vulnerability count differences between post-distillation and pre-distillation models (only for files that compiled successfully in both)")
    print("Note: All solagent-* models are distilled from Qwen/Qwen3-8B, Qwen/Qwen3-32B is used as an additional reference for comparison\n")
    
    pre_distill_stats = [s for s in all_stats if s and s['model_type'] == 'Pre-Distill']
    post_distill_stats = [s for s in all_stats if s and s['model_type'] == 'Post-Distill']
    
    if not pre_distill_stats:
        print("  Missing pre-distillation model data, cannot perform comparison")
    else:
        widths = [50, 15, 15, 15, 15, 18, 18, 14, 20]
        print_table_header([
            'Comparison', '#Common Files', '#Less Vuln', '#More Vuln', '#Equal',
            'Base Model Vuln', 'Student Vuln', 'Δ% vs Base', 'Vuln Diff'
        ], widths)
        
        for post_stat in post_distill_stats:
            post_vuln_by_file = post_stat.get('vuln_by_file', {})
            
            for pre_stat in pre_distill_stats:
                pre_vuln_by_file = pre_stat.get('vuln_by_file', {})
                
                # Find common files (both compiled)
                common_files = set(pre_vuln_by_file.keys()) & set(post_vuln_by_file.keys())
                
                if common_files:
                    less_vuln = 0
                    more_vuln = 0
                    equal_vuln = 0
                    total_diff = 0
                    pre_sum = 0
                    post_sum = 0
                    
                    for file_path in common_files:
                        pre_count = pre_vuln_by_file[file_path]
                        post_count = post_vuln_by_file[file_path]
                        diff = post_count - pre_count
                        total_diff += diff
                        pre_sum += pre_count
                        post_sum += post_count
                        
                        if post_count < pre_count:
                            less_vuln += 1
                        elif post_count > pre_count:
                            more_vuln += 1
                        else:
                            equal_vuln += 1
                    
                    delta_pct = None
                    if pre_sum > 0:
                        delta_pct = (post_sum - pre_sum) / pre_sum * 100.0
                    delta_str = f"{delta_pct:+.2f}%" if delta_pct is not None else "N/A"
                    
                    comparison_name = f"{post_stat['model']} vs {pre_stat['model']}"
                    print_table_row([
                        comparison_name,
                        str(len(common_files)),
                        str(less_vuln),
                        str(more_vuln),
                        str(equal_vuln),
                        str(pre_sum),
                        str(post_sum),
                        delta_str,
                        f"{total_diff:+d}"
                    ], widths)
    
    print("\nNote:")
    print("- Base Model: Comparison baseline model (Qwen/Qwen3-8B is the teacher model, Qwen/Qwen3-32B is the reference model)")
    print("- Student: Post-distillation model (solagent-4k-* series)")
    print("- #Less Vuln: Number of files where student model has fewer vulnerabilities")
    print("- #More Vuln: Number of files where student model has more vulnerabilities")
    print("- Δ% vs Base: Percentage change in vulnerability count relative to baseline model (negative value indicates improvement)")
    
    print("\n" + "="*150)


def print_distillation_delta(all_stats, test_case_total: int):
    """Print delta comparison between pre and post distillation."""
    print("\n" + "="*150)
    print("【Distillation Effect Comparison】")
    print("Post-Distill vs. Pre-Distill - Performance Delta Analysis")
    print("="*150)
    
    pre_distill_stats = [s for s in all_stats if s and s['model_type'] == 'Pre-Distill']
    post_distill_stats = [s for s in all_stats if s and s['model_type'] == 'Post-Distill']
    
    if not pre_distill_stats or not post_distill_stats:
        print("  Missing pre-distillation or post-distillation data, cannot perform comparison")
        return
    
    # Find the teacher model (Qwen/Qwen3-8B)
    teacher_stat = None
    reference_stats = []
    for s in pre_distill_stats:
        if s['model'] == 'Qwen/Qwen3-8B':
            teacher_stat = s
        else:
            reference_stats.append(s)
    
    if not teacher_stat:
        print("  Missing teacher model Qwen/Qwen3-8B data, cannot perform comparison")
        return
    
    # Use teacher model as baseline
    print("\n【Teacher Model Performance】")
    print(f"Teacher Model: {teacher_stat['model']} (distillation source)\n")
    
    teacher_compile = teacher_stat['compilation_rate']
    teacher_pass_overall = compute_pass_rate(teacher_stat['total_pass'], test_case_total) if test_case_total > 0 else 0
    teacher_gas_mean = teacher_stat['gas_mean_stats']['mean'] if teacher_stat['gas_mean_stats']['count'] > 0 else 0
    teacher_gas_median = teacher_stat['gas_median_stats']['mean'] if teacher_stat['gas_median_stats']['count'] > 0 else 0
    teacher_vuln = teacher_stat['vuln_best_pass_stats']['mean'] if teacher_stat['vuln_best_pass_stats']['count'] > 0 else 0
    
    print(f"  Compilation Rate: {teacher_compile:.2%}")
    print(f"  Pass@1 (Overall): {teacher_pass_overall:.2%}")
    print(f"  Gas (Mean): {teacher_gas_mean:.2f}")
    print(f"  Gas (Median): {teacher_gas_median:.2f}")
    print(f"  Vulnerabilities: {teacher_vuln:.2f}")
    
    # Show reference models if available
    if reference_stats:
        print(f"\nReference Models (for comparison reference only):")
        for ref_stat in reference_stats:
            ref_pass_overall = compute_pass_rate(ref_stat['total_pass'], test_case_total) if test_case_total > 0 else 0
            print(f"  {ref_stat['model']}:")
            print(f"    - Compilation Rate: {ref_stat['compilation_rate']:.2%}")
            print(f"    - Pass@1 (Overall): {ref_pass_overall:.2%}")
    
    # Compare each post-distill with teacher model
    print("\n【Post-Distill Performance and Improvements】")
    print(f"Comparison baseline: {teacher_stat['model']} (Teacher Model)\n")
    widths = [25, 14, 14, 18, 18, 20, 20]
    print_table_header([
        'Model', 'Compile Rate', 'ΔCompile %', 'Pass@1', 'ΔPass@1 %',
        'Gas Mean', 'ΔGas %'
    ], widths)
    
    # First print teacher model as baseline (with zero deltas)
    print_table_row([
        teacher_stat['model'],
        format_percentage(teacher_compile),
        f"{0.00:+.2f}%",
        format_percentage(teacher_pass_overall),
        f"{0.00:+.2f}%",
        f"{teacher_gas_mean:.2f}",
        f"{0.00:+.2f}%"
    ], widths)
    
    # Then print post-distill models with their deltas
    for stat in post_distill_stats:
        post_pass_overall = compute_pass_rate(stat['total_pass'], test_case_total) if test_case_total > 0 else 0
        
        delta_compile = (stat['compilation_rate'] - teacher_compile) * 100
        delta_pass = (post_pass_overall - teacher_pass_overall) * 100
        
        post_gas = stat['gas_mean_stats']['mean'] if stat['gas_mean_stats']['count'] > 0 else 0
        delta_gas = ((post_gas - teacher_gas_mean) / teacher_gas_mean * 100) if teacher_gas_mean > 0 else 0
        
        print_table_row([
            stat['model'],
            format_percentage(stat['compilation_rate']),
            f"{delta_compile:+.2f}%",
            format_percentage(post_pass_overall),
            f"{delta_pass:+.2f}%",
            f"{post_gas:.2f}",
            f"{delta_gas:+.2f}%"
        ], widths)
    
    print("\nNote:")
    print("- Baseline: Qwen/Qwen3-8B (Teacher Model)")
    print("- Δ represents delta from teacher model")
    print("- ΔCompile%, ΔPass@1%: Positive is better (higher compilation rate, higher pass rate)")
    print("- ΔGas%: Negative is better (lower gas consumption)")
    
    print("\n" + "="*150)


def main():
    parser = argparse.ArgumentParser(description='RQ-3 Distillation Statistics')
    parser.add_argument('--db', type=str, default='output/progress.db', help='Database path')
    
    args = parser.parse_args()
    
    print("Collecting statistics...")
    print(f"Pre-Distill Models: {', '.join(PRE_DISTILL_MODELS)}")
    print(f"Post-Distill Models: {', '.join(POST_DISTILL_MODELS)}")
    
    # Load training set to exclude
    exclude_files = load_training_set_files()
    
    all_stats = []
    
    # Collect all models (excluding training set files)
    for model in ALL_MODELS:
        print(f"Collecting statistics for model {model}...")
        stat = collect_model_stats(args.db, model, exclude_files)
        if stat:
            all_stats.append(stat)
        else:
            print(f"  Warning: Model {model} has no data")
    
    # Get test case total from baseline (excluding training set)
    test_case_total = get_baseline_test_total(args.db, exclude_files)
    
    # Print results
    print_overall_comparison(all_stats, test_case_total)
    print_distillation_delta(all_stats, test_case_total)
    
    print(f"\nStatistics completed! Processed {len(all_stats)} groups of data.")


if __name__ == '__main__':
    main()