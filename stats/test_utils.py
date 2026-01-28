#!/usr/bin/env python3
"""
Test basic functionality of statistics scripts
"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from stats.common_utils import (
    safe_json_loads, get_best_pass_round, get_min_vuln_round,
    get_gas_at_round, get_test_at_round, get_vuln_at_round,
    compute_pass_rate, aggregate_stats, format_stats, format_percentage
)


def test_json_parsing():
    """Test JSON parsing"""
    print("Testing JSON parsing...")
    
    # Valid JSON
    result = safe_json_loads('{"test": 1, "pass": 10}')
    assert result == {"test": 1, "pass": 10}, "JSON parsing failed"
    
    # Invalid JSON
    result = safe_json_loads('invalid json')
    assert result is None, "Invalid JSON should return None"
    
    # None input
    result = safe_json_loads(None)
    assert result is None, "None input should return None"
    
    print("✅ JSON parsing test passed")


def test_best_pass_round():
    """Test best pass round selection"""
    print("\nTesting best pass round selection...")
    
    test_data = {
        "0": {"pass": 5, "fail": 2, "total": 7},
        "1": {"pass": 8, "fail": 1, "total": 9},
        "2": {"pass": 6, "fail": 3, "total": 9}
    }
    
    best_round, best_pass, best_total = get_best_pass_round(test_data)
    assert best_round == 1, f"Expected round 1, got {best_round}"
    assert best_pass == 8, f"Expected pass count 8, got {best_pass}"
    assert best_total == 9, f"Expected total 9, got {best_total}"
    
    # Empty data
    best_round, best_pass, best_total = get_best_pass_round(None)
    assert best_round == 0, "Empty data should return 0"
    
    print("✅ Best pass round test passed")


def test_min_vuln_round():
    """Test min vuln round selection"""
    print("\nTesting min vuln round selection...")
    
    vuln_data = {
        "0": 5,
        "1": 2,
        "2": 3
    }
    
    min_round, min_vuln = get_min_vuln_round(vuln_data)
    assert min_round == 1, f"Expected round 1, got {min_round}"
    assert min_vuln == 2, f"Expected vuln count 2, got {min_vuln}"
    
    print("✅ Min vuln round test passed")


def test_gas_extraction():
    """Test gas value extraction"""
    print("\nTesting gas value extraction...")
    
    # Direct numeric value
    gas_data = {"0": 1000, "1": 1500, "2": 1200}
    gas_mean, gas_median = get_gas_at_round(gas_data, 1)
    assert gas_mean == 1500, f"Expected gas_mean 1500, got {gas_mean}"
    assert gas_median == 1500, f"Expected gas_median 1500, got {gas_median}"
    
    # Nested dict with total
    gas_data_nested = {"0": {"total": 1000, "method1": 500, "method2": 500}}
    gas_mean, gas_median = get_gas_at_round(gas_data_nested, 0)
    assert gas_mean == 1000, f"Expected gas_mean 1000, got {gas_mean}"
    assert gas_median == 1000, f"Expected gas_median 1000, got {gas_median}"
    
    print("✅ Gas value extraction test passed")


def test_pass_rate():
    """Test pass rate calculation"""
    print("\nTesting pass rate calculation...")
    
    rate = compute_pass_rate(8, 10)
    assert abs(rate - 0.8) < 0.001, f"Expected 0.8, got {rate}"
    
    # Compilation failure
    rate = compute_pass_rate(0, 0)
    assert rate == 0.0, "test_total=0 should return 0.0"
    
    print("✅ Pass rate calculation test passed")


def test_aggregation():
    """Test statistics aggregation"""
    print("\nTesting statistics aggregation...")
    
    values = [0.8, 0.85, 0.9, 0.75, 0.95]
    stats = aggregate_stats(values)
    
    assert 'mean' in stats, "Should contain mean"
    assert 'std' in stats, "Should contain std"
    assert 'count' in stats, "Should contain count"
    assert stats['count'] == 5, f"Expected count 5, got {stats['count']}"
    assert 0.8 < stats['mean'] < 0.9, f"mean should be between 0.8-0.9, got {stats['mean']}"
    
    # Empty list
    stats = aggregate_stats([])
    assert stats['count'] == 0, "Empty list should return count=0"
    
    print("✅ Statistics aggregation test passed")


def test_formatting():
    """Test formatting output"""
    print("\nTesting formatting output...")
    
    stats = {'mean': 0.8567, 'std': 0.1234, 'count': 10}
    formatted = format_stats(stats, precision=2)
    assert "0.86" in formatted, f"Formatted result should contain 0.86, got {formatted}"
    assert "0.12" in formatted, f"Formatted result should contain 0.12, got {formatted}"
    
    # Percentage
    pct = format_percentage(0.8567, precision=2)
    assert "85.67%" in pct, f"Expected 85.67%, got {pct}"
    
    print("✅ Formatting output test passed")


def main():
    print("="*60)
    print("Statistics Utilities Unit Tests")
    print("="*60)
    
    try:
        test_json_parsing()
        test_best_pass_round()
        test_min_vuln_round()
        test_gas_extraction()
        test_pass_rate()
        test_aggregation()
        test_formatting()
        
        print("\n" + "="*60)
        print("✅ All tests passed!")
        print("="*60)
        return 0
    
    except AssertionError as e:
        print(f"\n❌ Test failed: {e}")
        return 1
    except Exception as e:
        print(f"\n❌ Test error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
