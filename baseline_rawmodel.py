"""
Baseline RawModel script for RQ1.
Directly uses LLM API (no agent) to generate Solidity code based on coding.yaml system prompt.
Stores results in progress_tracker_rawmodel table with additional metrics.
"""
import asyncio
import json
import os
import pickle
import re
import sys
import subprocess
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

import yaml
from openai import OpenAI

from gpt5 import vllm_qwen3coder_model, choose_model, get_model_display_name
from llm_utils import create_client
from utils.config import Config
from utils.message_utils import convert_to_messages
from utils.path import remap_path
from utils.shared_context import shared_context
from utils.cost_calculator import CostCalculator, check_cost_pause
from utils.forge_utils import run_forge_test
from utils.slither_utils import run_slither, get_slither_feedback_and_count
from db.progress_tracker_rawmodel import ProgressTrackerRawModel
from run_restore_genfile import restore_origsol

from utils.feedback_utils import generate_feedback
from utils.response_utils import format_assistant_response
from utils.llm.openai_llm import call_openai_chat

from utils.code_utils import extract_solidity_code

def load_coding_yaml(config_path: str) -> str:
    """Load system prompt from coding.yaml"""
    with open(config_path, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    return config.get('prompt', {}).get('system', '')


def call_llm_api(client, model: str, messages: list, generation_config: dict = None, service_type: str = 'openai'):
    """Call LLM API directly with a pre-built `messages` list and return assistant content."""
    # Use generation_config if provided, otherwise use defaults
    if generation_config is None:
        generation_config = {}
    
    # generation_config['stream'] = True
    # Make a copy to avoid modifying the original
    kwargs = generation_config.copy()
    
    # Add stream_options if streaming is enabled (to get usage info)
    if kwargs.get('stream', False):
        kwargs['stream_options'] = {'include_usage': True}
    
    # Set default timeout if not provided (20 minutes)
    if 'timeout' not in kwargs:
        kwargs['timeout'] = 2400
    if service_type == "ollama":
        response = client.chat(model=model, messages=messages, **kwargs)
    elif service_type == "anthropic":
        messages = convert_to_messages(messages)
        full_content = ""
        prompt_tokens, completion_tokens = 0, 0
        generator = client.generate(messages=messages, **kwargs)
        for chunk in generator:
            if chunk.content:
                full_content = chunk.content
            prompt_tokens = chunk.prompt_tokens
            completion_tokens = chunk.completion_tokens
            # print(prompt_tokens, completion_tokens, flush=True)
        
        print(full_content, end="", flush=True)
        print()
        response = {
            "choices": [
                {"message": {"role": "assistant", "content": full_content}}
            ],
            "usage": {"prompt_tokens": prompt_tokens, "completion_tokens": completion_tokens}
        }
    else:
        # Use call_openai_chat which handles both stream and non-stream internally
        stream_enabled = kwargs.get('stream', True)
        response = call_openai_chat(
            client=client,
            model=model,
            messages=messages,
            generation_config=kwargs,
            stream=stream_enabled,
            return_usage=True
        )
    # Return the full response object so callers can access the full assistant message
    # (including any metadata). Callers should extract `.choices[0].message` and use
    # its `.content` for token counting and persistence.
    return response


async def process_file_generate_code(
    file_path: str,
    file_content: list,
    tracker: ProgressTrackerRawModel,
    actual_model: str,
    total_files: int,
    orig_repo: str,
    cur_repo: str,
    test_path_cargo: dict,
    system_prompt: str,
    client: OpenAI,
    model: str,
    generation_config: dict,
    service_type: str,
    cost_calculator: CostCalculator
):
    # Check if already processed
    existing_entry = tracker.get_entry(file_path, actual_model)
    if existing_entry and existing_entry['status'] >= 1:
        print(f"[SKIP] File already processed: {file_path} (model: {actual_model})")
        return None
    
    # Initialize tracking entry
    start_time = datetime.now().isoformat()
    tracker.create_or_update_entry(
        file_path=file_path,
        model_coding=actual_model,
        total_files=total_files,
        status=0,
        model_summary=None,
        start_time=start_time
    )

    # if file_path != "repository/openzeppelin-contracts/contracts/utils/Create2.sol":
    #     return None

    # if file_path != "repository/ethernaut/lib/ethernaut.git/contracts/src/levels/Motorbike.sol":
    #     return None
    # if file_path != "repository/openzeppelin-contracts/contracts/utils/SlotDerivation.sol":
    #     return None
    # if file_path != "repository/openzeppelin-contracts/contracts/utils/ShortStrings.sol":
    #     return None
    # if file_path == "repository/openzeppelin-contracts/contracts/utils/Packing.sol":
    #     return None

    # Restore original file before processing (to clean up previous generation)
    # This ensures we start fresh for each file
    try:
        restore_origsol()
    except Exception as e:
        print(f"[WARNING] Failed to restore original file: {e}")

    
    print(f"[PROCESSING] File: {file_path} (classes: {len(file_content)})")
    
    # Build file paths
    orig_sol_repo = os.path.join(orig_repo, "/".join(file_path.split("/")[0:2]))
    orig_sol = os.path.join(orig_repo, file_path)
    cur_sol = remap_path(orig_sol, orig_repo, cur_repo)
    cur_t_sol = remap_path(test_path_cargo[file_path], orig_repo, cur_repo)
    await shared_context.set_all(orig_sol_repo, orig_sol, cur_t_sol, cur_sol, file_path=file_path)
    
    # Pre-check: Run forge test to check if original file has compile errors
    try:
        precheck_results = run_forge_test(cur_t_sol)
        if precheck_results.get("compile_error"):
            print(f"[SKIP] Original file has compile errors, skipping: {file_path}")
            return None
    except subprocess.TimeoutExpired:
        print(f"[SKIP] Pre-check timeout, skipping file: {file_path}")
        return None
    except Exception as e:
        print(f"[WARNING] Pre-check failed: {e}")
        return None
    
    remove_cur_sol = Path(cur_sol)
    if remove_cur_sol.exists():
        remove_cur_sol.unlink()
    
    # Build query
    sol_version = file_content[0]['methods'][0]["sol_version"][0]
    # file_class = file_content[0]["class"]
    file_name = cur_sol.split("/")[-1]
    proj_repo = os.path.join(orig_repo, "/".join(file_path.split("/")[0:2]))
    # query_head = f"file name: {file_name}\n\n{sol_version}"
    query_head = f"given repo: {proj_repo}\nfile name: {file_name}\n\n{sol_version}"
    
    method_len = 0

    query = ""
    for cls in file_content:
        file_class = f"\n{cls['kind']} {cls['identifier']}\n"
        query += file_class
        
        for method in cls["methods"]:
            if method["kind"] not in ["struct", "function", "constructor"]:
                continue
            method_len += 1

            full_signature = method["full_signature"].strip()
            human_labeled_comment = method["human_labeled_comment"].strip()
            query = f"""{query}
{human_labeled_comment}
{full_signature}
"""
    
    # Calculate token count
    # encoding = tiktoken.encoding_for_model("gpt-3.5-turbo")
    # tokens = encoding.encode(query)
    # print(f'{len(query)/1024:.1f} KB; tokens: {len(tokens)}')
    
    # Combine query
    full_query = f"{query_head}\n{query}"
    # tokens = encoding.encode(full_query)
    # print(f'Full query: {len(full_query)/1024:.1f} KB; tokens: {len(tokens)}')

    # Call LLM API
    print(f"[INFO] Calling LLM API...")
    # initialize token/cost counters (must exist before any += operations)
    prompt_tokens = 0
    completion_tokens = 0
    total_cost = 0.0
    try:
        # build messages so we can persist them (user+assistant) as coding_messages
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": full_query}
        ]
        # Modify system message role to developer for gpt-5 reasoning model
        if model.startswith("gpt-5"):
            messages[0]["role"] = "developer"
            messages[0]["content"] = "# Juice: 0 !important\n" + messages[0]["content"]
        
        # 'claude-sonnet-4.5'
        response = call_llm_api(client, model, messages, generation_config, service_type)

        assistant_dict, response_text = format_assistant_response(response, service_type)

        print(f"[INFO] Received response ({len(response_text)} chars)")

        coding_messages = messages + [assistant_dict]

        # Extract code
        code_block, _ = extract_solidity_code(response_text)
        if not code_block:
            print(f"[WARNING] No code extracted from response")
            return None

        # Save code to file
        os.makedirs(os.path.dirname(cur_sol), exist_ok=True)
        with open(cur_sol, "w", encoding="utf-8") as f:
            f.write(code_block)
        print(f"[INFO] Saved code to {cur_sol}")

        # Run forge test to get test results and gas fees
        try:
            test_results = run_forge_test(cur_t_sol)
            # Extract gas fees from test results (already included)
            gas_fees = test_results.get("gas_fees", {})
        except subprocess.TimeoutExpired:
            print(f"[SKIP] Forge test timeout after generation, skipping file: {file_path}")
            return None
        except Exception as e:
            print(f"[WARNING] Forge test failed: {e}")
            test_results = {"passed": 0, "failed": 0, "total": 0}
            gas_fees = {}

        # Run slither for vulnerability detection (only if no compile error)
        if test_results.get("compile_error"):
            print(f"[SKIP] Skipping slither due to compile error")
            slither_raw = None
            slither_feedback = None
            vuln_count = -1
        else:
            try:
                slither_raw = run_slither(cur_sol)
                slither_feedback, vuln_count = get_slither_feedback_and_count(slither_raw)
            except Exception as e:
                print(f"[WARNING] Slither analysis failed: {e}")
                slither_raw = {"error": str(e)}
                slither_feedback = None
                vuln_count = -1

        # Generate feedback from test results and slither analysis
        feedback_content, _ = generate_feedback(test_results, slither_feedback)
        
        coding_messages += [{
            "role": "user",
            "content": feedback_content
        }]
        
        g_prompt, g_completion, g_cost = cost_calculator.extract_tokens_from_messages(coding_messages, actual_model)
        prompt_tokens += g_prompt
        completion_tokens += g_completion
        total_cost += g_cost

        # Mark as completed
        end_time = datetime.now().isoformat()
        tracker.mark_completed(
            file_path=file_path,
            methods=method_len,
            model_coding=actual_model,
            test_pass=test_results.get("passed", 0),
            test_fail=test_results.get("failed", 0),
            test_total=test_results.get("total", 0),
            gas_fee_json=gas_fees,
            slither_raw=slither_raw,
            coding_messages=coding_messages,
            vuln_count=vuln_count,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_cost=total_cost,
            end_time=end_time
        )
        print(f"[COMPLETED] File: {file_path}")
        
    except Exception as e:
        print(f"[ERROR] Failed to process {file_path}: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    # Check cost threshold after each file
    if check_cost_pause(cost_calculator, tracker, table_name="progress_tracker_rawmodel"):
        return "PAUSED_DUE_TO_COST"

async def main():
    """Main execution function"""
    path = os.path.dirname(os.path.abspath(__file__))
    dataset_path = os.path.join(path, 'data/dataset.json')
    
    # Load dataset
    with open(dataset_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # Configuration
    code_agent_config = os.path.join(path, "coding.yaml")
    output_dir = "output"
    
    # Load system prompt
    system_prompt = load_coding_yaml(code_agent_config)
    print(f"[INFO] Loaded system prompt from {code_agent_config}")
    
    # Model-independent initialization (do once)
    # Initialize cost calculator
    cost_calculator = CostCalculator(price_file="data/price.json")
    
    # Initialize progress tracker with rawmodel table
    tracker = ProgressTrackerRawModel(db_path=os.path.join(path, output_dir, "progress.db"))
    
    # Load test path mapping
    with open("data/test_map_cargo.pkl", "rb") as f:
        test_path_cargo = pickle.load(f)
    
    # Repository paths
    orig_repo = os.environ["ORIG_REPO"]
    cur_repo = os.getcwd()
    
    # Get total file count
    total_files = len(data)
    
    # Check cost threshold once at startup
    if check_cost_pause(cost_calculator, tracker, table_name="progress_tracker_rawmodel"):
        return "PAUSED_DUE_TO_COST"
    
    # Models to process
    models = ["gpt-5.1", "gpt-5-mini", "claude-sonnet-4-5"]# "gpt-5.1" "gpt-5-mini"
    
    # Process each model
    for model_name in models:
        print(f"\n{'='*80}")
        print(f"[INFO] Processing with model: {model_name}")
        print(f"{'='*80}\n")
        
        # Create OpenAI client for this model
        try:
            # client, model, generation_config, service_type = create_openai_client(model_name)
            if model_name == "claude-sonnet-4-5":
                platform = "anthropic"
            else:
                platform = "openai"
            client, model, generation_config, service_type = create_client(model_name, platform=platform, stream=True)
        except Exception as e:
            print(f"[ERROR] Failed to initialize model {model_name}: {e}")
            continue
        
        # Get actual model name for tracking
        actual_model = "qwen3-coder_30b" if model == "qwen3-coder:30b-a3b-fp16" else model
        print(f"[INFO] Tracking with model name: {actual_model}")
        
        # Process each file with this model
        for i, file_path in enumerate(data):
            file_content = data[file_path]
            result = await process_file_generate_code(
                file_path=file_path,
                file_content=file_content,
                tracker=tracker,
                actual_model=actual_model,
                total_files=total_files,
                orig_repo=orig_repo,
                cur_repo=cur_repo,
                test_path_cargo=test_path_cargo,
                system_prompt=system_prompt,
                client=client,
                model=model,
                generation_config=generation_config,
                service_type=service_type,
                cost_calculator=cost_calculator
            )
            if result == "PAUSED_DUE_TO_COST":
                print(f"[INFO] Paused during processing model {model_name}")
                return result
        
        print(f"\n[INFO] Completed processing all files with model: {model_name}\n")

    
    print("[INFO] Processing complete")


if __name__ == '__main__':
    asyncio.run(main())

