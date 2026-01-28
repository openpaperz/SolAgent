"""
Slither vulnerability detection utilities.
"""
import json
import os
import subprocess
from typing import Dict, Any, List, Optional


def run_slither_old(sol_file: str, slither_bin: str = "slither") -> Dict[str, Any]:
    """
    Run slither on a Solidity file and return results as JSON.
    
    Args:
        sol_file: Absolute path to the Solidity file to analyze
        slither_bin: Path to slither binary (default: "slither")
        
    Returns:
        Dictionary with slither results in JSON format
        If slither fails, returns {"error": error_message}
    """
    try:
        slither_bin = os.environ['SLITHER_PATH']
    except KeyError:
        raise RuntimeError(
            "Environment variable SLITHER_PATH is not set. "
            "Please set it (e.g. in .env) before running."
        )

    try:
        # Run slither with JSON output
        result = subprocess.run(
            [slither_bin, sol_file, "--json", "-"],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        # Parse JSON output from stdout
        if result.stdout:
            try:
                slither_json = json.loads(result.stdout)
                return slither_json
            except json.JSONDecodeError as e:
                return {
                    "error": f"Failed to parse slither JSON output: {e}",
                    "raw_stdout": result.stdout,
                    "raw_stderr": result.stderr
                }
        else:
            # No stdout, return error info
            return {
                "error": "Slither produced no output",
                "raw_stderr": result.stderr,
                "return_code": result.returncode
            }
            
    except subprocess.TimeoutExpired:
        return {"error": "Slither execution timeout (>120s)"}
    except FileNotFoundError:
        return {"error": f"Slither binary not found: {slither_bin}"}
    except Exception as e:
        return {"error": f"Slither execution failed: {str(e)}"}

def run_slither(sol_file: str, slither_bin: str = "slither") -> Dict[str, Any]:
    """
    Run slither on a Solidity file and return results as JSON.
    
    Args:
        sol_file: Absolute path to the Solidity file to analyze
        slither_bin: Path to slither binary (default: "slither")
        
    Returns:
        Dictionary with slither results in JSON format
        If slither fails, returns {"error": error_message}
    """
    try:
        slither_bin = os.environ['SLITHER_PATH']
    except KeyError:
        raise RuntimeError(
            "Environment variable SLITHER_PATH is not set. "
            "Please set it (e.g. in .env) before running."
        )

    match_path = sol_file.split('/')[-1]

    env = os.environ.copy()
    # if test_profile:
    #     env['FOUNDRY_PROFILE'] = test_profile # = 'openzeppelin-contracts-v4'
    # Special case: solady ext/ithaca tests need ithaca profile (for Ithaca precompiles)
    if 'solady' in sol_file and '/ext/ithaca/' in sol_file:
        env['FOUNDRY_PROFILE'] = 'ithaca'
    # Special case: files with "Transient" in name need post_cancun profile (for EIP-1153 transient storage)
    # This is specifically for solady project which skips Transient tests in default profile
    elif 'solady' in sol_file and 'Transient' in match_path:
        env['FOUNDRY_PROFILE'] = 'post_cancun'

    try:
        # Run slither with JSON output
        result = subprocess.run(
            [slither_bin, sol_file, "--json", "-"],
            capture_output=True,
            text=True,
            timeout=120,
            env=env
        )
        
        # Parse JSON output from stdout
        if result.stdout:
            try:
                slither_json = json.loads(result.stdout)
                return slither_json
            except json.JSONDecodeError as e:
                return {
                    "error": f"Failed to parse slither JSON output: {e}",
                    "raw_stdout": result.stdout,
                    "raw_stderr": result.stderr
                }
        else:
            # No stdout, return error info
            return {
                "error": "Slither produced no output",
                "raw_stderr": result.stderr,
                "return_code": result.returncode
            }
            
    except subprocess.TimeoutExpired:
        return {"error": "Slither execution timeout (>120s)"}
    except FileNotFoundError:
        return {"error": f"Slither binary not found: {slither_bin}"}
    except Exception as e:
        return {"error": f"Slither execution failed: {str(e)}"}

def count_vulnerabilities(slither_raw: Dict[str, Any], 
                         impact_levels: Optional[List[str]] = None) -> int:
    """
    Count vulnerabilities from slither output based on Impact level.
    
    Args:
        slither_raw: Slither analysis result (JSON dict)
        impact_levels: List of impact levels to count (e.g., ["High", "Medium"])
                      If None, counts all impacts except "Informational" and "Optimization"
        
    Returns:
        Number of vulnerabilities matching the criteria
    """
    if "error" in slither_raw:
        # Slither failed, can't count vulnerabilities
        return 0
    
    # Define default impact levels to count if not specified
    if impact_levels is None:
        impact_levels = ["High", "Medium", "Low"]
    
    count = 0
    
    # Slither JSON structure typically has "results" -> "detectors"
    # Each detector has "impact" field
    results = slither_raw.get("results", {})
    detectors = results.get("detectors", [])
    
    for detector in detectors:
        impact = detector.get("impact", "")
        if impact in impact_levels:
            count += 1
    
    return count

def simplify_slither_for_feedback(slither_raw: dict) -> list:
    """Extract minimal slither feedback for LLM, only including real vulnerabilities (High, Medium, Low)"""
    if not slither_raw or "results" not in slither_raw:
        return []
    
    detectors = slither_raw.get("results", {}).get("detectors", [])
    simplified = []
    impact_levels = ["High", "Medium", "Low"]
    
    for detector in detectors:
        impact = detector.get("impact")
        # Only keep real vulnerabilities (High, Medium, Low)
        if impact not in impact_levels:
            continue
        
        simplified.append({
            "impact": impact,
            "confidence": detector.get("confidence"),
            "check": detector.get("check"),
            "description": detector.get("description")
        })
    
    return simplified

def get_slither_feedback_and_count(slither_raw: Dict[str, Any]) -> tuple:
    """
    Extract slither feedback and get vulnerability count in one call.
    
    Args:
        slither_raw: Slither analysis result (JSON dict) from run_slither()
        
    Returns:
        Tuple of (slither_feedback, vuln_count) where:
        - slither_feedback: List of simplified vulnerability objects (High, Medium, Low only)
        - vuln_count: Count of vulnerabilities (int), equal to len(slither_feedback)
    """
    slither_feedback = simplify_slither_for_feedback(slither_raw)
    vuln_count = len(slither_feedback)
    return slither_feedback, vuln_count

def get_vulnerability_summary(slither_raw: Dict[str, Any]) -> Dict[str, int]:
    """
    Get a summary of vulnerabilities by impact level.
    
    Args:
        slither_raw: Slither analysis result (JSON dict)
        
    Returns:
        Dictionary mapping impact levels to counts
        Example: {"High": 2, "Medium": 5, "Low": 3, "Informational": 10}
    """
    if "error" in slither_raw:
        return {"error": 1}
    
    summary = {
        "High": 0,
        "Medium": 0,
        "Low": 0,
        "Informational": 0,
        "Optimization": 0
    }
    
    results = slither_raw.get("results", {})
    detectors = results.get("detectors", [])
    
    for detector in detectors:
        impact = detector.get("impact", "Unknown")
        if impact in summary:
            summary[impact] += 1
        else:
            summary[impact] = summary.get(impact, 0) + 1
    
    return summary


# For testing
if __name__ == '__main__':
    # Example test
    import sys
    
    if len(sys.argv) > 1:
        sol_file = sys.argv[1]
        print(f"Running slither on {sol_file}...")
        result = run_slither(sol_file)
        
        if "error" in result:
            print(f"Error: {result['error']}")
        else:
            print(f"Slither completed successfully")
            vuln_count = count_vulnerabilities(result)
            print(f"Vulnerability count (High/Medium/Low): {vuln_count}")
            
            summary = get_vulnerability_summary(result)
            print(f"Vulnerability summary: {summary}")
    else:
        print("Usage: python slither_utils.py <solidity_file>")
