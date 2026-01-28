"""
Common utilities for statistics computation across RQ experiments.
Provides JSON parsing, round selection, and statistical aggregation helpers.
"""
import json
import numpy as np
from typing import Dict, List, Any, Optional, Tuple


def safe_json_loads(json_str: Optional[str]) -> Optional[Dict]:
    """Safely parse JSON string, returning None on failure."""
    if not json_str:
        return None
    try:
        return json.loads(json_str)
    except (json.JSONDecodeError, TypeError):
        return None


def get_best_pass_round(round_test_json: Optional[Dict]) -> Tuple[int, int, int]:
    """
    Find the round with maximum test passes.
    
    Args:
        round_test_json: Dict mapping round index to {"pass": X, "fail": Y, "total": Z}
        
    Returns:
        Tuple of (best_round_idx, pass_count, total_count)
        Returns (0, 0, 0) if no valid data
    """
    if not round_test_json:
        return (0, 0, 0)
    
    best_round = 0
    max_pass = -1
    best_total = 0
    
    for round_idx, test_info in round_test_json.items():
        if isinstance(test_info, dict):
            pass_count = test_info.get('pass', test_info.get('passed', 0))
            total_count = test_info.get('total', 0)
            if pass_count > max_pass:
                max_pass = pass_count
                best_round = int(round_idx)
                best_total = total_count
    
    return (best_round, max_pass, best_total)


def get_min_vuln_round(round_vuln_count: Optional[Dict], round_test_json: Optional[Dict] = None) -> Tuple[int, int]:
    """
    Find the round with minimum vulnerability count.
    If multiple rounds have the same min vuln count, choose the one with max passed tests.
    
    Args:
        round_vuln_count: Dict mapping round index to vulnerability count
        round_test_json: Optional dict mapping round index to test info for tiebreaking
        
    Returns:
        Tuple of (min_vuln_round_idx, vuln_count)
        Returns (0, 0) if no valid data
    """
    if not round_vuln_count:
        return (0, 0)
    
    min_round = 0
    min_vuln = float('inf')
    max_passed = -1
    
    for round_idx, vuln_count in round_vuln_count.items():
        if isinstance(vuln_count, (int, float)):
            vuln_int = int(vuln_count)
            
            # Check if this is a better min vuln
            if vuln_int < min_vuln:
                min_vuln = vuln_int
                min_round = int(round_idx)
                # Reset max_passed for new min vuln
                if round_test_json:
                    test_info = round_test_json.get(str(round_idx), {})
                    if isinstance(test_info, dict):
                        max_passed = test_info.get('pass', test_info.get('passed', 0))
                else:
                    max_passed = 0
            
            # If same vuln count, choose the one with more passed tests
            elif vuln_int == min_vuln and round_test_json:
                test_info = round_test_json.get(str(round_idx), {})
                if isinstance(test_info, dict):
                    passed = test_info.get('pass', test_info.get('passed', 0))
                    if passed > max_passed:
                        max_passed = passed
                        min_round = int(round_idx)
    
    return (min_round, int(min_vuln) if min_vuln != float('inf') else 0)


def get_gas_at_round(round_gas_json: Optional[Dict], round_idx: int) -> Tuple[Optional[float], Optional[float]]:
    """
    Get gas fee at a specific round.
    
    Args:
        round_gas_json: Dict mapping round index to gas value or gas dict
        round_idx: Round index to retrieve
        
    Returns:
        Tuple of (mean_gas, median_gas) or (None, None) if not found
    """
    if not round_gas_json:
        return (None, None)
    
    gas_data = round_gas_json.get(str(round_idx))
    if gas_data is None:
        return (None, None)
    
    def extract_gas_stats(data) -> Tuple[float, float]:
        """Extract mean and median gas values from nested structure.
        
        For fuzz tests: sum all test functions' '-' (mean) and '~' (median)
        For non-fuzz: use 'gas' key or direct numeric value for both
        """
        if isinstance(data, (int, float)):
            val = float(data)
            return (val, val)
        elif isinstance(data, dict):
            # Try standard keys first
            for key in ['total', 'gas', 'fee', 'value']:
                if key in data:
                    val = data[key]
                    if isinstance(val, (int, float)):
                        return (float(val), float(val))
            
            # For fuzz test structure: sum all test functions' mean and median
            # e.g., {'testFunc1': {'-': 4331, '~': 4331}, 'testFunc2': {...}}
            total_mean = 0.0
            total_median = 0.0
            for v in data.values():
                if isinstance(v, dict) and '-' in v and '~' in v:
                    # This is a fuzz test result
                    total_mean += float(v['-'])
                    total_median += float(v['~'])
                elif isinstance(v, (int, float)):
                    total_mean += float(v)
                    total_median += float(v)
            return (total_mean, total_median)
        return (0.0, 0.0)
    
    mean_gas, median_gas = extract_gas_stats(gas_data)
    return (mean_gas if mean_gas > 0 else None, median_gas if median_gas > 0 else None)


def get_test_at_round(round_test_json: Optional[Dict], round_idx: int) -> Tuple[int, int]:
    """
    Get test pass/total at a specific round.
    
    Args:
        round_test_json: Dict mapping round index to test info
        round_idx: Round index to retrieve
        
    Returns:
        Tuple of (pass_count, total_count)
    """
    if not round_test_json:
        return (0, 0)
    
    test_info = round_test_json.get(str(round_idx))
    if not test_info or not isinstance(test_info, dict):
        return (0, 0)
    
    return (test_info.get('pass', test_info.get('passed', 0)), test_info.get('total', 0))


def get_vuln_at_round(round_vuln_json: Optional[Dict], round_idx: int) -> int:
    """
    Get vulnerability count at a specific round.
    
    Args:
        round_vuln_json: Dict mapping round index to vuln count
        round_idx: Round index to retrieve
        
    Returns:
        Vulnerability count
    """
    if not round_vuln_json:
        return 0
    
    vuln = round_vuln_json.get(str(round_idx), 0)
    return int(vuln) if isinstance(vuln, (int, float)) else 0


def compute_pass_rate(test_pass: int, test_total: int) -> float:
    """
    Compute pass rate (pass@1).
    
    Args:
        test_pass: Number of tests passed
        test_total: Total number of tests
        
    Returns:
        Pass rate as fraction (0.0 if test_total == 0)
    """
    if test_total == 0:
        return 0.0
    return test_pass / test_total


def aggregate_stats(values: List[float]) -> Dict[str, float]:
    """
    Compute mean and std from a list of values.
    
    Args:
        values: List of numeric values
        
    Returns:
        Dict with 'mean', 'std', 'count', 'median', 'p90' keys
    """
    if not values:
        return {'mean': 0.0, 'std': 0.0, 'count': 0}
    
    arr = np.array(values)
    return {
        'mean': float(np.mean(arr)),
        'std': float(np.std(arr)),
        'count': len(values),
    }


def print_table_header(columns: List[str], widths: Optional[List[int]] = None):
    """Print aligned table header."""
    if widths is None:
        widths = [20] * len(columns)
    
    header = "  ".join(col.ljust(w) for col, w in zip(columns, widths))
    print(header)
    print("=" * len(header))


def print_table_row(values: List[str], widths: Optional[List[int]] = None):
    """Print aligned table row."""
    if widths is None:
        widths = [20] * len(values)
    
    row = "  ".join(str(val).ljust(w) for val, w in zip(values, widths))
    print(row)


def format_stats(stats: Dict[str, float], precision: int = 4) -> str:
    """Format mean±std string."""
    if stats['count'] == 0:
        return "N/A"
    return f"{stats['mean']:.{precision}f} ± {stats['std']:.{precision}f}"


def format_gas_stats(mean_stats: Dict[str, float], median_stats: Dict[str, float], precision: int = 2) -> str:
    """Format gas stats as 'mean / median' string."""
    if mean_stats['count'] == 0:
        return "N/A"
    mean_str = f"{mean_stats['mean']:.{precision}f}"
    median_str = f"{median_stats['mean']:.{precision}f}" if median_stats['count'] > 0 else "N/A"
    return f"{mean_str} / {median_str}"


def format_percentage(value: float, precision: int = 2) -> str:
    """Format value as percentage."""
    return f"{value * 100:.{precision}f}%"


def compute_pairwise_gas_comparison(
    target_data: Dict[str, Tuple[float, float]], 
    baseline_data: Dict[str, Tuple[float, float]]
) -> Dict[str, Any]:
    """
    Compute pairwise gas comparison between target and baseline on common test cases.
    Both test-case level and file-level statistics.
    
    Args:
        target_data: Dict mapping "file_path::test_name" -> (mean_gas, median_gas) for target
        baseline_data: Dict mapping "file_path::test_name" -> (mean_gas, median_gas) for baseline
        
    Returns:
        Dict with comparison metrics:
        - common_count: number of common test cases
        - File-level stats: target and baseline gas aggregated by file
        - Test-case level stats: ratios and percentages
    """
    common_tests = set(target_data.keys()) & set(baseline_data.keys())
    
    if not common_tests:
        return {
            'common_count': 0,
            'median_ratio_mean': 0.0,
            'median_ratio_median': 0.0,
            'mean_ratio_mean': 0.0,
            'mean_ratio_median': 0.0,
            'better_percentage_mean': 0.0,
            'better_percentage_median': 0.0,
            'worse_percentage_mean': 0.0,
            'worse_percentage_median': 0.0,
            'file_level_better': 0,
            'file_level_worse': 0,
            'file_level_equal': 0
        }
    
    # Test-case level analysis
    ratios_mean = []
    ratios_median = []
    better_count_mean = 0
    better_count_median = 0
    worse_count_mean = 0
    worse_count_median = 0
    
    for test_name in common_tests:
        target_mean, target_median = target_data[test_name]
        baseline_mean, baseline_median = baseline_data[test_name]
        
        # Compute mean gas ratio
        if baseline_mean > 0:
            ratio_mean = target_mean / baseline_mean
            ratios_mean.append(ratio_mean)
            if target_mean < baseline_mean:
                better_count_mean += 1
            elif target_mean > baseline_mean:
                worse_count_mean += 1
        
        # Compute median gas ratio
        if baseline_median > 0:
            ratio_median = target_median / baseline_median
            ratios_median.append(ratio_median)
            if target_median < baseline_median:
                better_count_median += 1
            elif target_median > baseline_median:
                worse_count_median += 1
    
    # File-level analysis: aggregate by file
    file_level_comparison = {}  # {file_path: {'target_mean': ..., 'baseline_mean': ..., ...}}
    
    for test_name in common_tests:
        # Extract file path from "file_path::test_name" format
        parts = test_name.split("::")
        if len(parts) >= 2:
            file_path = parts[0]
            test_only = "::".join(parts[1:])
        else:
            file_path = "unknown"
            test_only = test_name
        
        if file_path not in file_level_comparison:
            file_level_comparison[file_path] = {
                'target_mean': 0.0,
                'target_median': 0.0,
                'baseline_mean': 0.0,
                'baseline_median': 0.0,
                'test_count': 0
            }
        
        target_mean, target_median = target_data[test_name]
        baseline_mean, baseline_median = baseline_data[test_name]
        
        file_level_comparison[file_path]['target_mean'] += target_mean
        file_level_comparison[file_path]['target_median'] += target_median
        file_level_comparison[file_path]['baseline_mean'] += baseline_mean
        file_level_comparison[file_path]['baseline_median'] += baseline_median
        file_level_comparison[file_path]['test_count'] += 1
    
    # Count file-level wins/losses
    file_level_better = 0
    file_level_worse = 0
    file_level_equal = 0
    
    for file_path, stats in file_level_comparison.items():
        if stats['baseline_mean'] > 0:
            if stats['target_mean'] < stats['baseline_mean']:
                file_level_better += 1
            elif stats['target_mean'] > stats['baseline_mean']:
                file_level_worse += 1
            else:
                file_level_equal += 1
    
    # Compute trimmed mean (5%) and P90 for mean ratios
    trimmed_mean_mean = 0.0
    p90_mean = 0.0
    if ratios_mean:
        sorted_ratios_mean = sorted(ratios_mean)
        n = len(sorted_ratios_mean)
        trim_count = int(n * 0.05)
        if trim_count > 0 and n > 2 * trim_count:
            trimmed_ratios = sorted_ratios_mean[trim_count:-trim_count]
            trimmed_mean_mean = float(np.mean(trimmed_ratios))
        else:
            trimmed_mean_mean = float(np.mean(sorted_ratios_mean))
        p90_mean = float(np.percentile(sorted_ratios_mean, 90)) # 90th percentile
    
    # Compute trimmed mean (5%) and P90 for median ratios
    trimmed_mean_median = 0.0
    p90_median = 0.0
    if ratios_median:
        sorted_ratios_median = sorted(ratios_median)
        n = len(sorted_ratios_median)
        trim_count = int(n * 0.05)
        if trim_count > 0 and n > 2 * trim_count:
            trimmed_ratios = sorted_ratios_median[trim_count:-trim_count]
            trimmed_mean_median = float(np.mean(trimmed_ratios))
        else:
            trimmed_mean_median = float(np.mean(sorted_ratios_median))
        p90_median = float(np.percentile(sorted_ratios_median, 90))
    
    return {
        'common_count': len(common_tests),
        'common_files': len(file_level_comparison),
        'median_ratio_mean': float(np.median(ratios_mean)) if ratios_mean else 0.0,  # median of mean ratios (-)
        'median_ratio_median': float(np.median(ratios_median)) if ratios_median else 0.0,  # median of median ratios (~)
        'mean_ratio_mean': float(np.mean(ratios_mean)) if ratios_mean else 0.0,  # mean of mean ratios (-)
        'mean_ratio_median': float(np.mean(ratios_median)) if ratios_median else 0.0,  # mean of median ratios (~)
        'trimmed_mean_mean': trimmed_mean_mean,  # 5% trimmed mean of mean ratios (-)
        'trimmed_mean_median': trimmed_mean_median,  # 5% trimmed mean of median ratios (~)
        'p90_mean': p90_mean,  # 90th percentile of mean ratios (-)
        'p90_median': p90_median,  # 90th percentile of median ratios (~)
        'better_percentage_mean': (better_count_mean / len(ratios_mean) * 100) if ratios_mean else 0.0,
        'better_percentage_median': (better_count_median / len(ratios_median) * 100) if ratios_median else 0.0,
        'worse_percentage_mean': (worse_count_mean / len(ratios_mean) * 100) if ratios_mean else 0.0,
        'worse_percentage_median': (worse_count_median / len(ratios_median) * 100) if ratios_median else 0.0,
        'file_level_better': file_level_better,
        'file_level_worse': file_level_worse,
        'file_level_equal': file_level_equal,
        'file_level_details': file_level_comparison
    }


def compute_pairwise_gas_comparison_merged(
    target_data: dict, 
    baseline_data: dict
) -> dict:
    """
    Compute pairwise gas comparison between target and baseline on common test cases.
    Uses merged gas values (mean + median + gas combined into single value).
    
    Args:
        target_data: Dict mapping "file_path::test_name" -> gas_value for target
        baseline_data: Dict mapping "file_path::test_name" -> gas_value for baseline
        
    Returns:
        Dict with comparison metrics
    """
    common_tests = set(target_data.keys()) & set(baseline_data.keys())
    
    if not common_tests:
        return {
            'common_count': 0,
            'median_ratio': 0.0,
            'mean_ratio': 0.0,
            'trimmed_mean': 0.0,
            'p90': 0.0,
            'file_level_better': 0,
            'file_level_worse': 0,
            'file_level_equal': 0,
            'common_files': 0
        }
    
    # Test-case level analysis
    ratios = []
    
    for test_name in common_tests:
        target_gas = target_data[test_name]
        baseline_gas = baseline_data[test_name]
        
        if baseline_gas > 0:
            ratio = target_gas / baseline_gas
            ratios.append(ratio)
    
    # File-level analysis: aggregate by file
    file_level_comparison = {}  # {file_path: {'target': ..., 'baseline': ...}}
    
    for test_name in common_tests:
        # Extract file path from "file_path::test_name" format
        parts = test_name.split("::")
        if len(parts) >= 2:
            file_path = parts[0]
        else:
            file_path = "unknown"
        
        if file_path not in file_level_comparison:
            file_level_comparison[file_path] = {
                'target': 0.0,
                'baseline': 0.0
            }
        
        file_level_comparison[file_path]['target'] += target_data[test_name]
        file_level_comparison[file_path]['baseline'] += baseline_data[test_name]
    
    # Count file-level wins/losses
    file_level_better = 0
    file_level_worse = 0
    file_level_equal = 0
    
    for file_path, stats in file_level_comparison.items():
        if stats['baseline'] > 0:
            if stats['target'] < stats['baseline']:
                file_level_better += 1
            elif stats['target'] > stats['baseline']:
                file_level_worse += 1
            else:
                file_level_equal += 1
    
    # Compute statistics
    trimmed_mean = 0.0
    p90 = 0.0
    if ratios:
        sorted_ratios = sorted(ratios)
        n = len(sorted_ratios)
        trim_count = int(n * 0.05)
        if trim_count > 0 and n > 2 * trim_count:
            trimmed_ratios = sorted_ratios[trim_count:-trim_count]
            trimmed_mean = float(np.mean(trimmed_ratios))
        else:
            trimmed_mean = float(np.mean(sorted_ratios))
        p90 = float(np.percentile(sorted_ratios, 90))
    
    return {
        'common_count': len(common_tests),
        'common_files': len(file_level_comparison),
        'median_ratio': float(np.median(ratios)) if ratios else 0.0,
        'mean_ratio': float(np.mean(ratios)) if ratios else 0.0,
        'trimmed_mean': trimmed_mean,
        'p90': p90,
        'file_level_better': file_level_better,
        'file_level_worse': file_level_worse,
        'file_level_equal': file_level_equal
    }


def get_baseline_test_total(db_path: str) -> int:
    """
    Get total number of test cases from baseline (original repository code).
    This should be consistent across all experiments.
    """
    from db.baseline_test import BaselineTest
    baseline = BaselineTest(db_path)
    rows = baseline.get_all_entries()
    
    if not rows:
        return 0
    
    # Sum all test_total from baseline
    return sum(r['test_total'] for r in rows)


def extract_per_test_gas(gas_json: Optional[Dict]) -> Tuple[Dict[str, Tuple[float, float]], float, float]:
    """
    Extract per-test gas data from gas_fee_json, handling both fuzz and non-fuzz formats.
    
    Supports three formats:
    1. Fuzz format: {'testName': {'-': mean_gas, '~': median_gas}, ...}
    2. Non-fuzz format: {'testName': {'gas': gas_value}, ...}
    3. Direct value: {'testName': numeric_value, ...}
    
    Args:
        gas_json: Gas data dictionary
        
    Returns:
        Tuple of (per_test_gas_dict, total_mean, total_median) where:
        - per_test_gas_dict: Dict[test_name] -> (mean_gas, median_gas)
        - total_mean: Sum of all mean gas values
        - total_median: Sum of all median gas values
    """
    per_test_gas = {}
    total_mean = 0.0
    total_median = 0.0
    
    if not gas_json or not isinstance(gas_json, dict):
        return per_test_gas, total_mean, total_median
    
    for test_name, test_gas in gas_json.items():
        if isinstance(test_gas, dict) and '-' in test_gas and '~' in test_gas:
            # Fuzz format: {'-': mean, '~': median}
            mean_val = float(test_gas['-'])
            median_val = float(test_gas['~'])
            per_test_gas[test_name] = (mean_val, median_val)
            total_mean += mean_val
            total_median += median_val
        elif isinstance(test_gas, dict) and 'gas' in test_gas:
            # Non-fuzz format: {'gas': value}
            gas_val = float(test_gas['gas'])
            per_test_gas[test_name] = (gas_val, gas_val)
            total_mean += gas_val
            total_median += gas_val
        elif isinstance(test_gas, (int, float)) and test_gas > 0:
            # Direct numeric value
            gas_val = float(test_gas)
            per_test_gas[test_name] = (gas_val, gas_val)
            total_mean += gas_val
            total_median += gas_val
    
    return per_test_gas, total_mean, total_median

