"""
Test script for cost calculation functionality.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.cost_calculator import CostCalculator, format_cost_report
from ms_agent.llm.utils import Message


def test_cost_calculator():
    """Test basic cost calculation."""
    print("=== Testing CostCalculator ===\n")
    
    # Initialize calculator
    calc = CostCalculator(price_file="data/price.json")
    
    # Test 1: Get pricing for a known model
    print("Test 1: Get pricing for gpt-5-mini")
    pricing = calc.get_model_price("gpt-5-mini")
    print(f"  Pricing: {pricing}\n")
    
    # Test 2: Calculate cost
    print("Test 2: Calculate cost for 10K prompt + 5K completion tokens")
    cost = calc.calculate_cost("gpt-5-mini", 10000, 5000)
    print(f"  Cost: ${cost:.4f}\n")
    
    # Test 3: Calculate cost for local model (should be $0)
    print("Test 3: Calculate cost for local model (qwen3)")
    cost_local = calc.calculate_cost("qwen2.5-coder:32b-instruct", 10000, 5000)
    print(f"  Cost: ${cost_local:.4f}\n")
    
    # Test 4: Extract tokens from messages
    print("Test 4: Extract tokens from messages")
    messages = [
        Message(role="user", content="Write a function that calculates fibonacci numbers"),
        Message(role="assistant", content="Here's a Python function:\n\ndef fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)")
    ]
    
    prompt_tokens, completion_tokens, cost = calc.extract_tokens_from_messages(
        messages, "gpt-5-mini"
    )
    print(f"  Estimated tokens: {prompt_tokens} prompt + {completion_tokens} completion")
    print(f"  Estimated cost: ${cost:.6f}\n")
    
    # Test 5: Calculate summary cost
    print("Test 5: Calculate summary cost")
    input_text = "This is a long document " * 100
    output_text = "This is a summary of the document."
    
    s_prompt, s_completion, s_cost = calc.calculate_summary_cost(
        "qwen3",
        input_text,
        output_text
    )
    print(f"  Summary tokens: {s_prompt} prompt + {s_completion} completion")
    print(f"  Summary cost: ${s_cost:.6f}\n")
    
    # Test 6: Format cost report
    print("Test 6: Format cost report")
    report = format_cost_report(
        model_name="gpt-5-mini",
        prompt_tokens=12345,
        completion_tokens=5678,
        total_cost=0.0145,
        summary_model="qwen3",
        summary_prompt_tokens=2000,
        summary_completion_tokens=500,
        summary_cost=0.0000
    )
    print(report)
    
    print("\n=== All tests completed ===")


if __name__ == "__main__":
    test_cost_calculator()
