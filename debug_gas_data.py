#!/usr/bin/env python3
"""Debug script to check gas data collection and pairwise gas comparison"""

import sys
sys.path.insert(0, '.')

from stats.rq1_statistics import collect_baseline_stats, collect_solagent_stats
from stats.common_utils import compute_pairwise_gas_comparison
import json
import numpy as np

print("="*100)
print("Detailed Gas Comparison Analysis")
print("="*100)

# Collect baseline
print("\n1. Collecting Baseline stats...")
baseline = collect_baseline_stats('output/progress.db')

# Collect SolAgent for specific models
models = ['gpt-5-mini', 'gpt-5.1']

for model in models:
    print(f"\n{'='*100}")
    print(f"Analysis for Model: {model}")
    print(f"{'='*100}")
    
    solagent = collect_solagent_stats('output/progress.db', model)
    
    if baseline and solagent and 'per_test_gas' in baseline and 'per_test_gas' in solagent:
        baseline_tests = baseline['per_test_gas']
        solagent_tests = solagent['per_test_gas']
        
        # Find common tests
        common_test_names = set(baseline_tests.keys()) & set(solagent_tests.keys())
        
        print(f"\nBaseline test count: {len(baseline_tests)}")
        print(f"SolAgent ({model}) test count: {len(solagent_tests)}")
        print(f"Common tests: {len(common_test_names)}")
        
        if len(common_test_names) > 0:
            # Compute pairwise comparison
            result = compute_pairwise_gas_comparison(solagent_tests, baseline_tests)
            
            print(f"\nPairwise Comparison Results:")
            print(f"  Common count: {result['common_count']}")
            print(f"  Median ratio (median): {result['median_ratio_median']:.6f}")
            print(f"  Median ratio (mean): {result['median_ratio_mean']:.6f}")
            print(f"  Mean ratio (mean): {result['mean_ratio_mean']:.6f}")
            print(f"  Mean ratio (median): {result['mean_ratio_median']:.6f}")
            print(f"  Better % (median): {result['better_percentage_median']:.2f}%")
            print(f"  Better % (mean): {result['better_percentage_mean']:.2f}%")
            
            # Detailed analysis
            print(f"\nDetailed Ratio Analysis:")
            
            ratios_mean = []
            ratios_median = []
            outlier_tests = []
            
            for test_name in common_test_names:
                sol_mean, sol_median = solagent_tests[test_name]
                base_mean, base_median = baseline_tests[test_name]
                
                if base_mean > 0:
                    ratio_mean = sol_mean / base_mean
                    ratios_mean.append(ratio_mean)
                
                if base_median > 0:
                    ratio_median = sol_median / base_median
                    ratios_median.append(ratio_median)
                    
                    # Track outliers (ratio > 10 or < 0.1)
                    if ratio_mean > 10 or ratio_mean < 0.1:
                        outlier_tests.append((test_name, sol_mean, base_mean, ratio_mean))
            
            print(f"  Mean gas ratios (SolAgent / Baseline):")
            print(f"    Min: {min(ratios_mean):.6f}")
            print(f"    Max: {max(ratios_mean):.6f}")
            print(f"    Median: {np.median(ratios_mean):.6f}")
            print(f"    Mean: {np.mean(ratios_mean):.6f}")
            print(f"    Std: {np.std(ratios_mean):.6f}")
            
            print(f"\n  Median gas ratios (SolAgent / Baseline):")
            print(f"    Min: {min(ratios_median):.6f}")
            print(f"    Max: {max(ratios_median):.6f}")
            print(f"    Median: {np.median(ratios_median):.6f}")
            print(f"    Mean: {np.mean(ratios_median):.6f}")
            print(f"    Std: {np.std(ratios_median):.6f}")
            
            # Show outliers
            if len(outlier_tests) > 0:
                print(f"\n  ⚠️  Outliers (ratio > 10 or < 0.1): {len(outlier_tests)} tests")
                print(f"  Top 10 extreme ratios:")
                sorted_outliers = sorted(outlier_tests, key=lambda x: x[3], reverse=True)
                for i, (test_name, sol, base, ratio) in enumerate(sorted_outliers[:10]):
                    print(f"    {i+1}. {test_name}")
                    print(f"       SolAgent: {sol:.2f}, Baseline: {base:.2f}, Ratio: {ratio:.4f}")
            
            # Show first 5 common tests for verification
            print(f"\n  First 5 common tests:")
            for test_name in list(common_test_names)[:5]:
                sol_mean, sol_median = solagent_tests[test_name]
                base_mean, base_median = baseline_tests[test_name]
                ratio = sol_mean / base_mean if base_mean > 0 else 0
                print(f"    {test_name}")
                print(f"      SolAgent: ({sol_mean:.2f}, {sol_median:.2f})")
                print(f"      Baseline: ({base_mean:.2f}, {base_median:.2f})")
                print(f"      Ratio: {ratio:.4f}")

print("\n" + "="*100)
print("Debug Complete")
print("="*100)

