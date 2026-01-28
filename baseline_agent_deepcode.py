import asyncio
import copy
import json
import os
import pickle
import re
import sys
import shutil
import subprocess
import textwrap
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse
from typing import Any, Dict, Optional

import yaml
from openai import OpenAI

from gpt5 import vllm_qwen3coder_model, choose_model, get_model_display_name
from llm_utils import create_client
from utils.config import Config
from utils.llm.anthropic_llm import Anthropic
from utils.path import remap_path
from utils.shared_context import shared_context
from utils.cost_calculator import CostCalculator, check_cost_pause, format_cost_report
from utils.forge_utils import run_forge_test
from utils.slither_utils import run_slither, get_slither_feedback_and_count
from db.progress_tracker_agent import ProgressTrackerAgent
from run_restore_genfile import restore_origsol

from utils.feedback_utils import generate_feedback
from utils.response_utils import format_assistant_response
            
async def deepcode_generate(
    repo_root: Path,
    full_query: str,
    api_key: str = None,
    base_url: str = None,
    model_name: str = None,
    cur_sol: str = None,
    generation_config: dict = None,
    service_type: str = None,
) -> Optional[Dict[str, Any]]:
    """Use DeepCode workflows to synthesize code based on README into repo_root.
    Strategy:
    - Create an implementation plan file from the README in repo_root.
    - Invoke DeepCode CodeImplementationWorkflow in pure code mode targeting repo_root.
    - Move generated files from generate_code/ up to repo_root.
    """
    # Ensure DeepCode is importable
    root_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = root_dir
    agent_deep_path = os.path.join(workspace_root, "lib", "DeepCode")
    if agent_deep_path not in sys.path and os.path.isdir(agent_deep_path):
        sys.path.insert(0, agent_deep_path)

    from workflows.code_implementation_workflow import CodeImplementationWorkflow

    repo_root.mkdir(parents=True, exist_ok=True)

    # Prepare plan file derived from README
    plan_path = repo_root / "initial_plan.txt"
    plan_content = textwrap.dedent(full_query).strip()
    plan_path.write_text(plan_content, encoding="utf-8")

    # Set API keys from arguments if provided
    if api_key:
        os.environ["OPENAI_API_KEY"] = api_key
    if base_url:
        os.environ["OPENAI_BASE_URL"] = base_url

    # Preflight: ensure config and API keys
    secrets_path = os.path.join(agent_deep_path, "mcp_agent.secrets.yaml")
    config_path = os.path.join(agent_deep_path, "mcp_agent.config.yaml")
    
    # Write API key and base URL to secrets file
    if api_key or base_url:
        try:
            secrets_data = {}
            if os.path.isfile(secrets_path):
                with open(secrets_path, 'r', encoding='utf-8') as f:
                    secrets_data = yaml.safe_load(f) or {}
            if service_type not in secrets_data:
                secrets_data[service_type] = {}
            if api_key:
                secrets_data[service_type]['api_key'] = api_key
            if base_url:
                secrets_data[service_type]['base_url'] = base_url
            with open(secrets_path, 'w', encoding='utf-8') as f:
                yaml.dump(secrets_data, f, default_flow_style=False)
            print(f"[deepcode] Updated secrets file: {secrets_path}")
        except Exception as e:
            print(f"[deepcode] WARNING: Failed to write secrets file: {e}")
    
    # Write model name to config file
    if model_name:
        try:
            config_data = {}
            if os.path.isfile(config_path):
                with open(config_path, 'r', encoding='utf-8') as f:
                    config_data = yaml.safe_load(f) or {}
            if service_type not in config_data:
                config_data[service_type] = {}
            elif service_type in config_data and not config_data[service_type]:
                config_data[service_type] = {}
            config_data[service_type]['default_model'] = model_name
            config_data['llm_provider'] = service_type
            with open(config_path, 'w', encoding='utf-8') as f:
                yaml.dump(config_data, f, default_flow_style=False)
            print(f"[deepcode] Updated config file with model: {model_name}")
        except Exception as e:
            print(f"[deepcode] WARNING: Failed to write config file: {e}")
    
    if not os.path.isfile(config_path):
        print("[deepcode] WARNING: mcp_agent.config.yaml not found; DeepCode may use defaults")
    if not os.path.isfile(secrets_path):
        print("[deepcode] WARNING: mcp_agent.secrets.yaml not found; ensure LLM keys via env")
    if not os.environ.get("OPENAI_API_KEY"):
        print("[deepcode] WARNING: OPENAI_API_KEY not set; DeepCode may fail to call LLM")

    # Ensure expected code workspace exists to satisfy DeepCode's existence checks
    gen_dir = repo_root / "generate_code"
    gen_dir.mkdir(parents=True, exist_ok=True)

    cwd = os.getcwd()
    responses = None
    try:
        # Run inside DeepCode directory so relative configs resolve
        os.chdir(agent_deep_path)
        
        # Initialize workflow inside the correct directory
        workflow = CodeImplementationWorkflow(config_path="mcp_agent.secrets.yaml")
        
        # Override default model if provided
        if model_name:
            workflow.default_models[service_type] = model_name
            print(f"[deepcode] Overriding {service_type} model to: {model_name}")
        
        # Prepare LLM kwargs from generation_config (similar to call_llm_api pattern)
        llm_kwargs = generation_config.copy() if generation_config else {}
        
        # Set default timeout if not provided
        if 'timeout' not in llm_kwargs:
            llm_kwargs['timeout'] = 2400
        
        print(f"[deepcode] LLM kwargs: {llm_kwargs}")
        
        # Run workflow with LLM kwargs passed through
        responses = await workflow.run_workflow(
            plan_file_path=str(plan_path),
            target_directory=str(repo_root),
            pure_code_mode=True,
            enable_read_tools=False,
            **llm_kwargs,
        )
        print(f"[deepcode] Workflow completed successfully: {responses.get('status', 'unknown')}")
            
    finally:
        os.chdir(cwd)

    return responses


    # Move generated code from generate_code into repo_root (flatten one level)
    # if gen_dir.exists() and gen_dir.is_dir():
    #     files_found = list(gen_dir.glob("**/*.sol"))
    #     print(f"[deepcode] Found {len(files_found)} files in {gen_dir}")
    #     for f in files_found:
    #         print(f"[deepcode] - {f}")
    #         shutil.move(str(f), cur_sol)

def load_coding_yaml(config_path: str) -> str:
    """Load system prompt from coding.yaml"""
    with open(config_path, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    return config.get('prompt', {}).get('system', '')

async def process_file_generate_code(
    file_path: str,
    file_content: list,
    tracker: ProgressTrackerAgent,
    actual_model: str,
    total_files: int,
    orig_repo: str,
    cur_repo: str,
    test_path_cargo: dict,
    system_prompt: str,
    client: OpenAI | Anthropic,
    model: str,
    generation_config: dict,
    service_type: str,
    cost_calculator: CostCalculator
):
    # Check if already processed
    existing_entry = tracker.get_entry(file_path, actual_model, "deepcode")
    if existing_entry and existing_entry['status'] >= 1:
        print(f"[SKIP] File already processed: {file_path} (model: {actual_model})")
        return None
    
    # Initialize tracking entry
    start_time = datetime.now().isoformat()
    tracker.create_or_update_entry(
        file_path=file_path,
        model_coding=actual_model,
        agent_type="deepcode",
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

    # Call DeepCode agent to generate code
    print(f"[INFO] Calling DeepCode agent...")
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
        
        # Use DeepCode agent instead of direct LLM API call
        # Create a temporary directory for DeepCode output in current workspace
        workspace_path = os.path.dirname(os.path.abspath(__file__))
        deepcode_output_dir = Path(workspace_path) / "deepcode_temp"
        full_query_with_context = f"{system_prompt}\n\n{full_query}"
        
        # Extract API key and base URL from client
        if service_type == 'anthropic':
            api_key = client.client.api_key
            base_url = str(client.client.base_url)
        else:
            api_key = client.api_key
            base_url = str(client.base_url)
        
        workflow_responses = await deepcode_generate(
            deepcode_output_dir,
            full_query_with_context,
            api_key=api_key,
            base_url=base_url,
            model_name=actual_model,
            cur_sol=cur_sol,
            generation_config=generation_config,
            service_type=service_type
        )
        
        # Read the generated code from DeepCode output
        generated_file = deepcode_output_dir / 'generate_code' / file_name
        if not generated_file.exists() or generated_file.stat().st_size == 0:
            # Try to find any non-empty .sol file in the output directory
            sol_files = [f for f in deepcode_output_dir.glob("**/*.sol") if f.stat().st_size > 0]
            if sol_files:
                generated_file = sol_files[0]
            else:
                print(f"[WARNING] No non-empty Solidity file generated by DeepCode")
                # Clean up temp directory
                if deepcode_output_dir.exists():
                    shutil.rmtree(deepcode_output_dir)
                return None
        
        with open(generated_file, "r", encoding="utf-8") as f:
            code_block = f.read()
        
        # Clean up temp directory
        if deepcode_output_dir.exists():
            shutil.rmtree(deepcode_output_dir)
        
        if not code_block:
            print(f"[WARNING] No code generated by DeepCode")
            return None
        
        print(f"[INFO] DeepCode generated code ({len(code_block)} chars)")
        
        workflow_coding_messages = []
        if workflow_responses:
            workflow_coding_messages = workflow_responses.get("coding_messages") or []

        if workflow_coding_messages:
            coding_messages = copy.deepcopy(workflow_coding_messages)
        else:
            coding_messages = copy.deepcopy(messages)
            # Build assistant response for tracking
            assistant_dict = {
                "role": "assistant",
                "content": f"```solidity\n{code_block}\n```"
            }
            coding_messages.append(assistant_dict)

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
            agent_type="deepcode",
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
    
    # Check cost threshold once at startup
    if check_cost_pause(cost_calculator, tracker, table_name="progress_tracker_agent"):
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
    cost_calculator = CostCalculator(price_file=os.path.join(path, "data/price.json"))
    
    # Initialize progress tracker with rawmodel table
    tracker = ProgressTrackerAgent(db_path=os.path.join(path, output_dir, "progress.db"))
    
    # Load test path mapping
    with open(os.path.join(path, "data/test_map_cargo.pkl"), "rb") as f:
        test_path_cargo = pickle.load(f)
    
    # Repository paths
    orig_repo = os.environ["ORIG_REPO"]
    if not os.path.isabs(orig_repo):
        orig_repo = os.path.join(path, orig_repo)
    cur_repo = path
    
    # Get total file count
    total_files = len(data)
    
    # Check cost threshold once at startup
    if check_cost_pause(cost_calculator, tracker, table_name="progress_tracker_agent"):
        return "PAUSED_DUE_TO_COST"
    
    
    # Models to process
    models = ["claude-sonnet-4-5", "gpt-5.1", "gpt-5-mini"]#, "claude-sonnet-4-5" "gpt-5.1" "gpt-5-mini"; "qwen3-coder_30b"
    
    # Process each model
    for model_name in models:
        print(f"\n{'='*80}")
        print(f"[INFO] Processing with model: {model_name}")
        print(f"{'='*80}\n")
        
        # Create OpenAI client for this model
        try:
            if model_name == "claude-sonnet-4-5":
                platform = "anthropic"
            else:
                platform = "openai"
            client, model, generation_config, service_type = create_client(model_name, stream=False, platform=platform)
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
            if result is not None and i > 0 and i % 5 == 0:
                await asyncio.sleep(20)
        
        print(f"\n[INFO] Completed processing all files with model: {model_name}\n")

    
    print("[INFO] Processing complete")


if __name__ == '__main__':
    asyncio.run(main())
