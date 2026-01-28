#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Simplified Code Summary Generation Tool
Processes user-input code comments and function signatures, generates summary and reorganizes into new user prompt
"""

import json
import time
from typing import Dict, List, Tuple, Union
from urllib.parse import urlparse

from openai import OpenAI
from ollama import Client as Ollama, ChatResponse

from gpt5 import choose_model, gpt5_model, qwen3_model
from utils.config import Config
import asyncio
import os


class CodeSummaryGenerator:
    """Simplified code summary generation tool"""
    client: Union[Ollama, OpenAI]
    
    def __init__(self, openai_api_key: str = "ollama", openai_base_url: str = "http://localhost:11500/v1", model_name: str = "qwen3:30b-instruct"):
        code_agent_config = os.path.join(os.getcwd(), "coding.yaml")
        #
        code_config = Config.from_task(code_agent_config)

        code_config = choose_model(model_name, code_config)
    
        # Extract API key and base URL
        api_key = getattr(code_config.llm, 'openai_api_key', 'vllm')
        base_url = getattr(code_config.llm, 'openai_base_url', 'http://localhost:8000/v1')
        model = getattr(code_config.llm, 'model', model_name)
        
        self.service_type = getattr(code_config.llm, 'service', 'openai')
        # Extract generation config
        self.generation_config = code_config.get('generation_config', {})

        self.model = model
        self.api_key = api_key
        self.base_url = base_url

        # print(self.code_config["generation_config"])

        if self.api_key == "ollama":
            self.client = Ollama(
                host=f"{urlparse(self.base_url).scheme}://{urlparse(self.base_url).netloc}",
            )
        else:
            self.client = OpenAI(
                api_key=self.api_key,
                base_url=self.base_url,
            )

        self.system = """
You are a Solidity code summarization assistant."""
        self.system2 = """
Input:
- One or more blocks of function documentation in the following format:

/**
 * <Long comment including @notice, @param, @return, Steps, @dev, and implementation details>
 */
function <function_name>(<parameters>) <visibility> <state mutability> returns (<return values>)

Requirements for your summary:
1. Generate **one concise summary per function**, focusing on:
   - The main purpose of the function.
   - Essential implementation hints or key operations that are necessary to later reconstruct the function code (e.g., bitwise operations, packing steps).
   - **Security & Gas**: Identify and highlight adherence to strict security/gas patterns, specifically:
     - **Gas**: Storage/memory efficiency (avoiding redundant SLOADs/allocations), preference for `calldata`, and loop optimizations.
     - **Security**: Checks-effects-interactions, safe external calls, correct use of `unchecked` arithmetic and inline assembly, `abi.encodePacked` safety, and proper error handling (custom errors/revert reasons).
2. **Do not include the full comment or step-by-step details**; compress them into a short, readable summary (1–2 sentences).
3. **Preserve ALL input signatures** (functions, structs, constructors, etc.) exactly as written.
   - **EXCEPTION**: For `function` items ONLY, remove the leading 'function' keyword to save space.
   - Do NOT remove keywords for other types (e.g., keep 'struct', 'constructor').
4. Format the output as a **list**, one item per line:

<signature>: <summary content>
<signature>: <summary content>
...

5. **Strictly single-spaced**. Do not add empty lines between items.
6. If multiple functions are provided, maintain the input order.
7. Avoid unrelated details or excessive wording; focus on the function's purpose and core implementation logic.

Example:

Input:
/**
 * @notice Packs two `bytes1` values into a single `bytes2` value.
 * @param left The first `bytes1` value.
 * @param right The second `bytes1` value.
 * @return result The resulting `bytes2` value.
 * Steps:
 * 1. Clear higher bits of left and right to fit 8 bits.
 * 2. Combine left and right using bitwise operations.
 * @dev Uses inline assembly for efficiency.
 */
function pack_1_1(bytes1 left, bytes1 right) internal pure returns (bytes2 result)

/**
 * @notice Packs two `bytes2` values into a single `bytes4` value.
 * @param left The first `bytes2` value.
 * @param right The second `bytes2` value.
 * @return result The resulting `bytes4` value.
 * Steps:
 * 1. Clear upper 16 bits of left and right.
 * 2. Shift right by 16 bits and combine using OR.
 * @dev Uses inline assembly for efficiency.
 */
function pack_2_2(bytes2 left, bytes2 right) internal pure returns (bytes4 result)

Expected Output:
pack_1_1(bytes1 left, bytes1 right) internal pure returns (bytes2 result): Packs two bytes1 values into a bytes2 using bitwise operations and inline assembly.
pack_2_2(bytes2 left, bytes2 right) internal pure returns (bytes4 result): Packs two bytes2 values into a bytes4 using bitwise operations and inline assembly.
"""
    
    def generate_summary_and_prompt(self, user_input: str, return_usage: bool = False) -> Union[str, Tuple[str, Dict[str, int]], None]:
        """Generate summary and reorganize into new user prompt"""

        try:
            # Build prompt
            prompt = self._build_summary_prompt(user_input)
            
            # Call OpenAI API
            if self.service_type == "ollama":
                result = self._call_ollama_api(prompt, return_usage=return_usage)
            else:
                result = self._call_openai_api(prompt, return_usage=return_usage)
            
            return result
            
        except Exception as e:
            print(f"OpenAI API call failed: {e}")
            return None
    
    def _build_summary_prompt(self, user_input: str) -> str:
        """Build prompt for code generation"""
        
        return user_input

    def _call_ollama_api(self, prompt: str, max_retries: int = 3, return_usage: bool = False) -> Union[str, Tuple[str, Dict[str, int]], None]:
        if self.model.startswith("qwen3"):
            system = self.system
            prompt = f"{self.system2}\n{prompt}"

        for attempt in range(max_retries):
            try:
                response = self.client.chat(
                    model=self.model,
                    messages=[
                        {"role": "system", "content": system},
                        {"role": "user", "content": prompt},
                    ],

                    **self.code_config.generation_config,
                )
                content = response.message.content
                if return_usage:
                    usage = {
                        "prompt_tokens": response.prompt_eval_count or 0,
                        "completion_tokens": response.eval_count or 0
                    }
                    return content, usage
                return content

            except Exception as e:
                print(f"Ollama API call failed (attempt {attempt + 1}/{max_retries}): {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                else:
                    raise e
        return None

    def _call_openai_api(self, prompt: str, max_retries: int = 3, return_usage: bool = False) -> Union[str, Tuple[str, Dict[str, int]], None]:
        from utils.llm.openai_llm import call_openai_chat
        
        system = f"{self.system}\n{self.system2}"
        messages = [
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ]
        
        return call_openai_chat(
            client=self.client,
            model=self.model,
            messages=messages,
            generation_config=self.generation_config,
            max_retries=max_retries,
            return_usage=return_usage
        )

    
    def format_output(self, result: Dict) -> str:
        """Format output"""
        output = []
        output.append("=== Code Generation Summary Results ===\n")
        output.append(f"Overall Summary: {result['summary']}\n")
        
        for i, func in enumerate(result["functions"], 1):
            output.append(f"\n--- Function {i}: {func['name']} ---")
            output.append(f"Description: {func['description']}")
            param_str = ', '.join([f"{p['name']}: {p['type']}" for p in func['parameters']])
            output.append(f"Parameters: {param_str}")
            output.append(f"Return Type: {func['return_type']}")
            output.append(f"Complexity: {func['complexity']}")
            output.append("Implementation Steps:")
            for step in func['implementation_steps']:
                output.append(f"  {step}")
            output.append(f"Implementation Suggestion: {func['implementation_suggestion']}")
        
        output.append(f"\n=== Reorganized User Prompt ===")
        output.append(result['new_user_prompt'])
        
        return "\n".join(output)


def main():
    """Main function"""
    # Example input
    user_input = """
/**
 * @notice Packs two `bytes1` values into a single `bytes2` value.
 *
 * @param left The first `bytes1` value to be packed.
 * @param right The second `bytes1` value to be packed.
 * @return result The resulting `bytes2` value after packing.
 *
 * Steps:
 * 1. Clear the higher bits of the `left` value to ensure it fits within the lower 8 bits.
 * 2. Clear the higher bits of the `right` value to ensure it fits within the lower 8 bits.
 * 3. Combine the `left` and `right` values into a single `bytes2` value by shifting and OR-ing them.
 *
 * @dev This function uses inline assembly to perform bitwise operations for efficiency.
 */
function pack_1_1(bytes1 left, bytes1 right) internal pure returns (bytes2 result)

/**
 * @notice Packs two `bytes2` values into a single `bytes4` value.
 *
 * @param left The first `bytes2` value to be packed.
 * @param right The second `bytes2` value to be packed.
 * @return result The resulting `bytes4` value after packing the two `bytes2` values.
 *
 * Steps:
 * 1. Use inline assembly to perform bitwise operations:
 *    - Clear the upper 16 bits of `left` and `right` to ensure they are properly aligned.
 *    - Shift `right` by 16 bits to the right and combine it with `left` using the `or` operation.
 * 2. Return the resulting `bytes4` value.
 */
function pack_2_2(bytes2 left, bytes2 right) internal pure returns (bytes4 result)
"""
    
    # Create generator instance
    generator = CodeSummaryGenerator()
    
    # Generate summary and prompt
    result = generator.generate_summary_and_prompt(user_input)
    
    # Format output
    formatted_output = generator.format_output(result)
    print(formatted_output)
    
    # Output JSON format
    print("\n=== JSON Format Output ===")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()