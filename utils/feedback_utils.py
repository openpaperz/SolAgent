"""
Feedback generation utilities for test results and vulnerability analysis.
Extracted from eval_callback.py for reuse in baseline scripts.
"""
from enum import Enum
from typing import Dict, Any, Optional, Tuple


class FeedbackStatus(Enum):
    """Enumeration for feedback status categories."""
    NO_OUTPUT = "no_output"  # No valid output from testing or max rounds reached
    COMPILE_ERROR = "compile_error"  # Compilation failed
    NO_TESTS = "no_tests"  # No tests detected
    ALL_PASSED = "all_passed"  # All tests passed
    SOME_FAILED = "some_failed"  # Some tests failed


def generate_feedback(
    test_results: Dict[str, Any],
    slither_results: Optional[list] = None,
    include_forge: bool = True,
    include_slither: bool = True
) -> Tuple[str, FeedbackStatus]:
    """
    Generate human-readable feedback from forge test results and slither analysis.
    
    Args:
        test_results: Dictionary from run_forge_test containing:
            - compile_error: str (if compilation failed)
            - passed: int (number of passed tests)
            - failed: int (number of failed tests)
            - total: int (total number of tests)
            - fails: dict (mapping test names to failure messages)
            - gas_fees: dict (mapping test methods to gas fees)
        slither_results: List from simplify_slither_for_feedback containing vulnerability info
        include_forge: Whether to include forge test results in the feedback
        include_slither: Whether to include slither results in the feedback
        
    Returns:
        Tuple of (formatted feedback string for LLM, FeedbackStatus enum)
    """
    feedback_parts = []
    feedback_status = None
    
    # Check if test_results is empty or None
    if not test_results:
        feedback_status = FeedbackStatus.NO_OUTPUT
    
    # 1. Determine FeedbackStatus (Always calculate status for metrics/control flow)
    elif "compile_error" in test_results:
        feedback_status = FeedbackStatus.COMPILE_ERROR
    else:
        passed = test_results.get("passed", 0)
        failed = test_results.get("failed", 0)
        total = test_results.get("total", 0)
        
        if total == 0:
            feedback_status = FeedbackStatus.NO_TESTS
        elif failed == 0:
            feedback_status = FeedbackStatus.ALL_PASSED
        else:
            feedback_status = FeedbackStatus.SOME_FAILED
    
    # 2. Generate Feedback String (Conditionally based on flags)
    
    # --- Forge Feedback ---
    if include_forge:
        if feedback_status == FeedbackStatus.NO_OUTPUT:
            feedback_parts.append(
                'No valid output from testing or maximum compile rounds reached.'
            )
        elif feedback_status == FeedbackStatus.COMPILE_ERROR:
            feedback_parts.append(
                f'{test_results["compile_error"]}\n'
                f'Please fix the compile errors.'
            )
        elif feedback_status == FeedbackStatus.NO_TESTS:
            feedback_parts.append('No tests were detected. Assuming completion.')
        elif feedback_status == FeedbackStatus.ALL_PASSED:
            total = test_results.get("total", 0)
            feedback_parts.append(
                f'All {total} tests passed. No further refinement needed. Stopping refinement.'
            )
        elif feedback_status == FeedbackStatus.SOME_FAILED:
            passed = test_results.get("passed", 0)
            total = test_results.get("total", 0)
            fails = test_results.get("fails", {})
            fail_info = "\n".join(fails.values()) if fails else "(no details)"
            
            feedback_parts.append(
                f'Test Results: {passed}/{total} tests passed.\n'
                f'Failing tests:\n{fail_info}\n'
                f'Please fix the remaining failing tests.'
            )
    
    # --- Slither Feedback ---
    if include_slither and slither_results:
        vuln_count = len(slither_results)
        if vuln_count > 0:
            feedback_parts.append(f'\n--- Security Analysis ---')
            feedback_parts.append(f'Found {vuln_count} potential vulnerabilities:')
            
            for i, vuln in enumerate(slither_results, 1):
                impact = vuln.get("impact", "Unknown")
                check = vuln.get("check", "unknown")
                desc = vuln.get("description", "No description")
                confidence = vuln.get("confidence", "Unknown")
                
                feedback_parts.append(
                    f'{i}. [{impact}] {check} (confidence: {confidence})\n'
                    f'   {desc}'
                )
            
            feedback_parts.append('\nPlease address these security issues.')
    
    return "\n".join(feedback_parts), feedback_status


def format_test_and_vuln_summary(
    test_results: Dict[str, Any],
    slither_results: Optional[list] = None
) -> Dict[str, Any]:
    """
    Create a structured summary of test results and vulnerabilities.
    Useful for adding to coding_messages as structured data.
    
    Args:
        test_results: Dictionary from run_forge_test
        slither_results: List from simplify_slither_for_feedback
        
    Returns:
        Dictionary with structured summary
    """
    summary = {
        "test_results": {
            "passed": test_results.get("passed", 0),
            "failed": test_results.get("failed", 0),
            "total": test_results.get("total", 0),
        }
    }
    
    if "compile_error" in test_results:
        summary["compile_error"] = True
    
    if test_results.get("fails"):
        summary["test_results"]["failing_tests"] = list(test_results["fails"].keys())
    
    if slither_results:
        summary["vulnerabilities"] = {
            "count": len(slither_results),
            "issues": slither_results
        }
    
    return summary


if __name__ == '__main__':
    print("=" * 80)
    print("Testing generate_feedback function")
    print("=" * 80)
    
    # Test 1: Empty test results
    print("\n--- Test 1: Empty test results ---")
    feedback, status = generate_feedback(None)
    print(f"Status: {status.value}")
    print(feedback)
    
    # Test 2: Compilation error
    print("\n--- Test 2: Compilation error ---")
    test_results_compile_error = {
        "compile_error": "Error: Undeclared identifier.\n  --> contracts/Test.sol:10:5:\n   |\n10 |     unknownVar = 5;\n   |     ^^^^^^^^^^\n"
    }
    feedback, status = generate_feedback(test_results_compile_error)
    print(f"Status: {status.value}")
    print(feedback)
    
    # Test 3: All tests passed
    print("\n--- Test 3: All tests passed ---")
    test_results_passed = {
        "passed": 5,
        "failed": 0,
        "total": 5,
        "fails": {},
        "gas_fees": {}
    }
    feedback, status = generate_feedback(test_results_passed)
    print(f"Status: {status.value}")
    print(feedback)
    
    # Test 4: Some tests failed
    print("\n--- Test 4: Some tests failed ---")
    test_results_failed = {
        "passed": 3,
        "failed": 2,
        "total": 5,
        "fails": {
            "testTransfer()": "[FAIL: assertion failed] testTransfer()",
            "testApprove()": "[FAIL: revert] testApprove()"
        },
        "gas_fees": {}
    }
    feedback, status = generate_feedback(test_results_failed)
    print(f"Status: {status.value}")
    print(feedback)
    
    # Test 5: Tests passed with vulnerabilities
    print("\n--- Test 5: Tests passed with vulnerabilities ---")
    slither_vulns = [
        {
            "impact": "High",
            "confidence": "High",
            "check": "reentrancy-eth",
            "description": "Reentrancy in Contract.withdraw() (contracts/Test.sol#15-20)"
        },
        {
            "impact": "Medium",
            "confidence": "Medium",
            "check": "unchecked-transfer",
            "description": "Contract.transfer() does not check return value (contracts/Test.sol#25)"
        }
    ]
    feedback, status = generate_feedback(test_results_passed, slither_vulns)
    print(f"Status: {status.value}")
    print(feedback)
    
    # Test 6: No tests detected
    print("\n--- Test 6: No tests detected ---")
    test_results_no_tests = {
        "passed": 0,
        "failed": 0,
        "total": 0,
        "fails": {},
        "gas_fees": {}
    }
    feedback, status = generate_feedback(test_results_no_tests)
    print(f"Status: {status.value}")
    print(feedback)
    
    # Test 7: Some tests failed AND vulnerabilities detected
    print("\n--- Test 7: Some tests failed AND vulnerabilities ---")
    feedback, status = generate_feedback(test_results_failed, slither_vulns)
    print(f"Status: {status.value}")
    print(feedback)
    
    print("\n" + "=" * 80)
    print("All tests completed!")
    print("=" * 80)
