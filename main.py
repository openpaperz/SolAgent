import json
import pickle
import shutil
import copy
import sys
import subprocess
from datetime import datetime
from pathlib import Path

import tiktoken
from openai import OpenAI

from file_parser import extract_code_blocks
from gpt5 import gpt5_model, claude_model, qwen3_model, gptoss_model, gpt4o_model

from gpt5 import phi_model
from ms_agent import LLMAgent
from ms_agent.config import Config
from ms_agent.llm.utils import Message
import asyncio
import os
import re

from run_restore_genfile import restore_origsol
from db.summary_tracker import SummaryTracker
from utils.forge_utils import run_forge_test
from utils.path import remap_path
from utils.shared_context import shared_context
from utils.cost_calculator import CostCalculator, check_cost_pause, format_cost_report
from db.progress_tracker import ProgressTracker
from db.progress_tracker_patch import ProgressTrackerPatch
from gpt5 import choose_model, get_model_display_name


# Set environment variables

path = os.path.dirname(os.path.abspath(__file__))
dataset = os.path.join(path, 'data/dataset.json')
with open(dataset, "r", encoding="utf-8") as f:
    data = json.load(f)

code_agent_config = os.path.join(path, "coding.yaml")
# Default refine config, can be overridden by run_main function
refine_agent_config = os.path.join(path, "refine.yaml")

def backup_orig_sol(orig_repo, orig_sol):
    # Move orig_sol and corresponding test folder to backup/ under orig_repo (if exists)
    backup_dir = os.path.join(orig_repo, "backup")
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)
    try:
        shutil.move(orig_sol, backup_dir)
    except shutil.Error:
        # If target already exists, shutil.Error will be raised; do nothing here
        pass

def restore_orig_sol(orig_repo, orig_sol):
    backup_dir = os.path.join(orig_repo, "backup")
    file_name = os.path.basename(orig_sol)
    if os.path.exists(backup_dir):
        file_path = os.path.join(backup_dir, file_name)
        if os.path.exists(file_path):
            try:
                shutil.move(file_path, orig_sol)
            except shutil.Error:
                pass


async def process_file_generate_code(
    file_path: str,
    file_content: list,
    tracker,  # Can be ProgressTracker*
    actual_code_model: str,
    total_files: int,
    orig_repo: str,
    cur_repo: str,
    test_path_cargo: dict,
    code_agent: LLMAgent,
    refine_agent: LLMAgent,
    cost_calculator: CostCalculator,
    output_dir: str,
    ablation_type: int = 0,
    enable_summary: bool = False,
    summary_tracker: SummaryTracker = None
):
    """Process a single file: agent-based generation with precheck and cost tracking"""

    from db.progress_tracker_ablation import ProgressTrackerAblation

    # Check if already processed
    if isinstance(tracker, ProgressTrackerAblation):
        existing_entry = tracker.get_entry(file_path, actual_code_model, ablation_type)
    else:
        existing_entry = tracker.get_entry(file_path, actual_code_model)

    if existing_entry and existing_entry['status'] >= 1:
        print(f"[SKIP] File already processed: {file_path} (model: {actual_code_model})")
        return None

    # Initialize tracking entry
    start_time = datetime.now().isoformat()

    # Prepare special kwargs for ablation
    kwargs = {}
    if isinstance(tracker, ProgressTrackerAblation):
        kwargs['ablation_type'] = ablation_type

    # Create or update entry and capture ID for checkpointing
    created_id = tracker.create_or_update_entry(
        file_path=file_path,
        model_coding=actual_code_model,
        total_files=total_files,
        status=0,
        model_summary=None,
        start_time=start_time,
        **kwargs
    )

    # Determine checkpoint table name and entry id
    table_name = tracker.table_name
    entry_id = (existing_entry.get('id') if existing_entry else created_id)
    # Persist checkpoint meta to shared_context (for cross-process recovery)
    await shared_context.set_checkpoint_meta(table_name, entry_id)

    # if file_path == "repository/openzeppelin-contracts/contracts/utils/Packing.sol" or file_path == 'repository/openzeppelin-contracts/contracts/utils/cryptography/P256.sol':
    #     return None
    # if file_path != "repository/openzeppelin-contracts/contracts/utils/SlotDerivation.sol":
    #     return None
    # if file_path != "repository/ethernaut/lib/ethernaut.git/contracts/src/levels/PuzzleWallet.sol":
    #     return None
    # if file_path != "repository/ethernaut/lib/ethernaut.git/contracts/src/levels/Motorbike.sol":
    #     return None

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
    # Store shared paths and relative file_path for downstream callbacks (e.g., EvalCallback baseline lookup)
    await shared_context.set_all(orig_sol_repo, orig_sol, cur_t_sol, cur_sol, file_path=file_path)

    try:
        precheck_results = run_forge_test(cur_t_sol)
        if precheck_results.get("compile_error") or precheck_results.get("failed", 0) > 0:
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


    # Generate summary for large files
    result = ""
    summary_model_name = "gpt-5-mini"
    summary_row_id = None
    summary_prompt_tokens = 0
    summary_completion_tokens = 0
    summary_cost = 0.0

    if enable_summary:
        if not summary_tracker:
            raise ValueError(f"[ERROR] summary_tracker is None but enable_summary is True")

        # Query database for summary by file_path and model_name
        summary_json_str = summary_tracker.get_summary_by_file_and_model(file_path, summary_model_name)
        # If a summary exists, retrieve its primary key id for later recording.
        if summary_json_str:
            try:
                summary_id = summary_tracker.get_summary_id_by_file_and_model(file_path, summary_model_name)
                if summary_id is not None:
                    # remember the summary table primary key; we will write it to
                    # progress tracker at mark_completed time
                    summary_row_id = str(summary_id)
            except Exception as e:
                print(f"[WARNING] Failed to read summary id: {e}")

        if summary_json_str:
            try:
                # Parse JSON string to dictionary
                summary_dict = json.loads(summary_json_str)

                # Rebuild result from summary_dict matching file_content structure
                for cls in file_content:
                    identifier = cls['identifier']
                    cls_summary = summary_dict.get(identifier, "")
                    if cls_summary:
                        # Prepend file_class header before summary text
                        result += f"\n{cls['kind']} {cls['identifier']}\n"
                        result += cls_summary + "\n"

                print(f"[INFO] Using cached summary from database (summary model: {summary_model_name})")
            except Exception as e:
                print(f"[ERROR] Failed to parse summary JSON: {e}")
                print(f"[ERROR] Summary not found in database for file: {file_path}, model: {summary_model_name}")
                return None
        else:
            print(f"[ERROR] Summary not found in database for file: {file_path}, model: {summary_model_name}")
            return None

    if not result:
        result = query

    query = f"{query_head}\n{result}"

    # Load or generate code via agent
    memory_path = os.path.join(path, output_dir, "memory", "code_agent.json")
    generator = None

    # Attempt to restore generator from checkpoint file if present
    gen_ckpt_path = os.path.join(path, output_dir, f"{table_name}{entry_id}-generator.pkl")
    if isinstance(tracker, ProgressTrackerAblation):
        change_table_name = "process_tracking"
        # Try to find the corresponding entry in the canonical `process_tracking` table
        try:
            # Use a separate ProgressTracker instance pointed at the same DB to query the other table
            from db.progress_tracker import ProgressTracker as ChangeTracker
            change_tracker = ChangeTracker(db_path=tracker.db_path)
            change_entry = change_tracker.get_entry(file_path, actual_code_model)
            change_entry_id = change_entry['id'] if change_entry else None
        except Exception:
            change_entry_id = None

        gen_ckpt_path = os.path.join(path, output_dir, f"{change_table_name}{change_entry_id}-generator.pkl")

    if os.path.exists(gen_ckpt_path):
        try:
            with open(gen_ckpt_path, "rb") as gf:
                gen_dicts = pickle.load(gf)
            # Rebuild Message list from dicts
            if isinstance(gen_dicts, list):
                generator = [Message(**d) if isinstance(d, dict) else d for d in gen_dicts]
                # Optional: reconstruct cur_sol from last assistant message
                last_assist_msg = next((msg for msg in reversed(generator) if hasattr(msg, 'role') and msg.role == "assistant"), None)
                if last_assist_msg and hasattr(last_assist_msg, 'content'):
                    all_files, _ = extract_code_blocks(last_assist_msg.content)
                    for file in all_files:
                        code = file.get("code")
                        if code:
                            with open(cur_sol, "w") as f:
                                f.write(code)
                            break
            print(f"[RESTORE] Loaded generator checkpoint: {gen_ckpt_path}")
        except Exception as e:
            print(f"[WARNING] Failed to load generator checkpoint: {e}")
    elif os.path.exists(memory_path):
        with open(memory_path, "r", encoding="utf-8") as fm:
            memory = json.load(fm)
            generator: list[Message] = [Message(**item) for item in memory]

            last_assist_msg = next(
                (msg for msg in reversed(generator)
                 if msg.role == "assistant"),
                None
            )
            if last_assist_msg:
                last_assist_content = last_assist_msg.content
                all_files, _ = extract_code_blocks(last_assist_content)
                for file in all_files:
                    code = file["code"]
                    with open(cur_sol, "w") as f:
                        f.write(code)
                    break
    else:
        if remove_cur_sol.exists():
            remove_cur_sol.unlink()
        try:
            generator = await code_agent.run(messages=query)
        except Exception as e:
            print(f"[SKIP] code_agent.run failed for {file_path}: {e}\nSkipping this file and continuing.")
            return None

    # Persist generator checkpoint for recovery (only used in main.py)
    try:
        gen_ckpt_dicts = [m.to_dict() if hasattr(m, 'to_dict') else (m.__dict__ if hasattr(m, '__dict__') else m) for m in (generator or [])]
        with open(gen_ckpt_path, "wb") as gf:
            pickle.dump(gen_ckpt_dicts, gf)
    except Exception as e:
        print(f"[WARNING] Failed to write generator checkpoint: {e}")

    coding_messages = copy.deepcopy(generator)
    # Prepare messages for refine agent
    code_block = None
    generator[0].role = "system"
    messages: list[Message] = [generator[0], generator[1]]

    if remove_cur_sol.exists():
        with open(cur_sol, "r") as f:
            code_block = f.read()
        # print(code_block)
        file_name = cur_sol.split("/")[-1]
        if code_block:
            messages.append(Message(role="assistant", content=f"```solidity: {file_name}\n{code_block}```"))

    # Run refine agent; if LLM call hits WAF/connection errors, skip this file
    try:
        await refine_agent.run(messages)
    except Exception as e:
        print(f"[SKIP] refine_agent.run failed for {file_path}: {e}\nSkipping this file and continuing.")
        return None

    # Load test results and messages
    end_time = datetime.now().isoformat()
    test_json = None
    test_pass = 0
    test_fail = 0
    test_total = 0
    gas_fee_json = None
    round_gas_fee_json = None
    slither_raw = None
    round_slither_raw = None
    vuln_count = None
    round_vuln_count = None

    try:
        test_summary_path = os.path.join(path, output_dir, "memory", "test_summary.json")
        if os.path.exists(test_summary_path):
            with open(test_summary_path, "r", encoding="utf-8") as f:
                test_json = json.load(f)
            if isinstance(test_json, dict) and len(test_json) > 0:
                numeric_keys = [int(k) for k in test_json.keys() if str(k).isdigit()]
                if numeric_keys:
                    last_round_key = str(max(numeric_keys))
                    last = test_json.get(last_round_key, {})
                else:
                    last = list(test_json.values())[-1]
                if last:
                    test_pass = int(last.get("passed", 0) or 0)
                    test_fail = int(last.get("failed", 0) or 0)
                    test_total = int(last.get("total", 0) or 0)

                    # Extract gas fees, slither results, and vuln counts (store as dict/value, not JSON string)
                    if last.get("gas_fees"):
                        gas_fee_json = last["gas_fees"]  # Store as dict, not json.dumps()
                    if last.get("slither_raw"):
                        slither_raw = last["slither_raw"]  # Store as dict, not json.dumps()
                    if last.get("vuln_count") is not None:
                        vuln_count = int(last["vuln_count"])  # Store as int value

                    # Extract round-level gas_fees, slither_raw, vuln_count from all rounds
                    if isinstance(test_json, dict) and numeric_keys:
                        round_gas_fees = {}
                        round_slithers = {}
                        round_vulns = {}
                        for k in numeric_keys:
                            round_data = test_json.get(str(k), {})
                            if round_data.get("gas_fees"):
                                round_gas_fees[str(k)] = round_data["gas_fees"]
                            if round_data.get("slither_raw"):
                                round_slithers[str(k)] = round_data["slither_raw"]
                            if round_data.get("vuln_count") is not None:
                                round_vulns[str(k)] = int(round_data["vuln_count"])

                        if round_gas_fees:
                            round_gas_fee_json = round_gas_fees  # Store as dict, not json.dumps()
                        if round_slithers:
                            round_slither_raw = round_slithers  # Store as dict, not json.dumps()
                        if round_vulns:
                            round_vuln_count = round_vulns  # Store as dict mapping round -> vuln_count

                        # Remove extracted round-level details from test_json to avoid duplication
                        try:
                            for k in numeric_keys:
                                rk = str(k)
                                rd = test_json.get(rk, {})
                                if isinstance(rd, dict):
                                    rd.pop("gas_fees", None)
                                    rd.pop("slither_raw", None)
                                    rd.pop("vuln_count", None)
                                    test_json[rk] = rd
                        except Exception:
                            pass

            elif isinstance(test_json, list) and len(test_json) > 0:
                last = test_json[-1]
                test_pass = int(last.get("passed", 0) or 0)
                test_fail = int(last.get("failed", 0) or 0)
                test_total = int(last.get("total", 0) or 0)

                if last.get("gas_fees"):
                    gas_fee_json = last["gas_fees"]  # Store as dict
                if last.get("slither_raw"):
                    slither_raw = last["slither_raw"]  # Store as dict
                if last.get("vuln_count") is not None:
                    vuln_count = int(last["vuln_count"])
            else:
                vuln_count = -1
    except Exception as e:
        print(f"Warning: failed to load test_summary.json: {e}")

    messages_json = None
    round_messages_json = None
    try:
        messages_path = os.path.join(path, output_dir, "memory", "messages.json")
        if os.path.exists(messages_path):
            with open(messages_path, "r", encoding="utf-8") as f:
                messages_json = json.load(f)
    except Exception as e:
        print(f"Warning: failed to load messages.json: {e}")

    try:
        round_messages_path = os.path.join(path, output_dir, "memory", "round_messages.json")
        if os.path.exists(round_messages_path):
            with open(round_messages_path, "r", encoding="utf-8") as f:
                round_messages_json = json.load(f)
    except Exception as e:
        print(f"Warning: failed to load round_messages.json: {e}")

    # Calculate token usage and cost
    prompt_tokens = 0
    completion_tokens = 0
    total_cost = 0.0

    if generator:
        try:
            g_prompt, g_completion, g_cost = cost_calculator.extract_tokens_from_messages(generator, actual_code_model)
            prompt_tokens += g_prompt
            completion_tokens += g_completion
            total_cost += g_cost

            if messages_json:
                try:
                    assistant_msgs = []
                    if isinstance(messages_json, list):
                        assistant_msgs = [Message(**m) for m in messages_json if isinstance(m, dict) and m.get('role') == 'assistant']
                    elif isinstance(messages_json, dict):
                        if 'messages' in messages_json and isinstance(messages_json['messages'], list):
                            assistant_msgs = [Message(**m) for m in messages_json['messages'] if isinstance(m, dict) and m.get('role') == 'assistant']
                        else:
                            for v in messages_json.values():
                                if isinstance(v, list):
                                    assistant_msgs.extend([Message(**m) for m in v if isinstance(m, dict) and m.get('role') == 'assistant'])

                    if assistant_msgs:
                        m_prompt, m_completion, m_cost = cost_calculator.extract_tokens_from_messages(assistant_msgs, actual_code_model)
                        prompt_tokens += m_prompt
                        completion_tokens += m_completion
                        total_cost += m_cost
                except Exception as e:
                    print(f"Warning: failed to calculate tokens from messages.json: {e}")

            print(f"[COST] Agent usage: ${total_cost:.4f} "
                  f"({prompt_tokens}+{completion_tokens} tokens)")

            cost_report = format_cost_report(
                model_name=actual_code_model,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_cost=total_cost,
                summary_model=summary_model_name if summary_cost > 0 else None,
                summary_prompt_tokens=summary_prompt_tokens,
                summary_completion_tokens=summary_completion_tokens,
                summary_cost=summary_cost
            )
            print(cost_report)
        except Exception as e:
            print(f"Warning: Failed to calculate cost: {e}")

    if not messages_json or not round_messages_json:
        print(f"Warning: messages.json or round_messages.json missing; cannot record result.")
        return None

    # Mark as completed
    from db.progress_tracker_ablation import ProgressTrackerAblation

    # Prepare special kwargs for ablation
    kwargs = {}
    if isinstance(tracker, ProgressTrackerAblation):
        kwargs['ablation_type'] = ablation_type

    # Note: the final round stored in `round_messages` was recorded locally and
    # not sent to the LLM. Preserve it for reporting/analysis, but do not treat
    # it as additional LLM usage (to avoid double-counting tokens/costs).
    entry_id = tracker.mark_completed(
        file_path=file_path,
        methods=method_len,
        model_coding=actual_code_model,
        test_pass=test_pass,
        test_fail=test_fail,
        test_total=test_total,
        test_json=test_json,
        messages=messages_json,
        round_messages=round_messages_json,
        coding_messages=([m.to_dict() for m in coding_messages] if coding_messages else None),
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        total_cost=total_cost,
        # Prefer to write the summary row id (if available)
        summary_model=summary_row_id,
        summary_prompt_tokens=summary_prompt_tokens,
        summary_completion_tokens=summary_completion_tokens,
        summary_cost=summary_cost,
        gas_fee_json=gas_fee_json,
        round_gas_fee_json=round_gas_fee_json,
        slither_raw=slither_raw,
        round_slither_raw=round_slither_raw,
        vuln_count=vuln_count,
        round_vuln_count=round_vuln_count,
        end_time=end_time,
        **kwargs
    )

    # Rename memory folder
    try:
        memory_dir = os.path.join(path, output_dir, "memory")
        if entry_id and os.path.exists(memory_dir):
            new_dir = os.path.join(path, output_dir, f"memory-{table_name}-{entry_id}")
            if os.path.exists(new_dir):
                ts = datetime.now().strftime("%Y%m%d%H%M%S")
                new_dir = os.path.join(path, output_dir, f"memory-{table_name}-{entry_id}-{ts}")
            os.rename(memory_dir, new_dir)
            print(f"[INFO] Renamed memory folder -> {new_dir}")
    except Exception as e:
        print(f"Warning: failed to rename memory folder: {e}")

    print(f"[COMPLETED] File: {file_path}")

    # Check cost threshold
    if check_cost_pause(cost_calculator, tracker, table_name=tracker.table_name):
        return "PAUSED_DUE_TO_COST"

    return None


async def run_main(
    refine_config_path: str = None,
    tracker=None,
    ablation_type: int = 0
):
    """
    Main execution function with multi-model support.

    Args:
        refine_config_path: Path to refine config YAML (default: refine.yaml)
        tracker: ProgressTracker or ProgressTrackerPatch instance (will create default if None)
        ablation_type: Integer type for ablation study (default 0)
    """
    global refine_agent_config

    # Override refine config if provided
    if refine_config_path:
        refine_agent_config = os.path.join(path, refine_config_path)

    # Model-independent initialization (do once)
    cost_calculator = CostCalculator(price_file="data/price.json")

    # Tracker must be provided
    if tracker is None:
        raise ValueError("tracker must be provided (ProgressTracker* instance)")

    # Determine output directory from tracker's db_path
    # Extract output_dir from tracker's db_path (e.g., "output/progress.db" -> "output")
    db_path = tracker.db_path
    output_dir = os.path.dirname(db_path)
    if not output_dir:
        output_dir = "output"

    # Initialize SummaryTracker using same db_path as tracker
    summary_tracker = SummaryTracker(db_path=tracker.db_path)

    # Load test path mapping
    with open("data/test_map_cargo.pkl", "rb") as f:
        test_path_cargo = pickle.load(f)

    # Repository paths
    orig_repo = os.environ["ORIG_REPO"]
    cur_repo = os.getcwd()

    # Get total file count
    total_files = len(data)

    # Check cost threshold once at startup
    if check_cost_pause(cost_calculator, tracker, table_name=tracker.table_name):
        return "PAUSED_DUE_TO_COST"

    # Models to process
    opensource_models = ["mimo-v2.5-pro"] # 'Qwen/Qwen3-8B' Qwen/Qwen3-32B 'solagent-4k-tracker-v1' 'solagent-4k-mixed-v1' 'solagent-4k-tracker-v2' solagent-20k-tracker-4b-instruct-v2 Qwen/Qwen3-4B-Instruct-2507-v solagent-256k-tracker-4b-instruct solagent-4k-mixed-v2
    models = opensource_models + ["gpt-5-mini", "gpt-5.1", "claude-sonnet-4-5"]

    # Process each model
    for model_name in models:
        print(f"\n{'='*80}")
        print(f"[INFO] Processing with model: {model_name}")
        print(f"{'='*80}\n")

        # Load and configure model
        code_config = Config.from_task(code_agent_config)
        refine_config = Config.from_task(refine_agent_config)

        if model_name == "claude-sonnet-4-5":
            platform = "anthropic"
        else:
            platform = "openai"
        code_config = choose_model(model_name, code_config, platform=platform)
        refine_config = choose_model(model_name, refine_config, platform=platform)

        # Check if summary is enabled in config (default False)
        enable_summary = getattr(refine_config, 'summary', False)

        actual_code_model = get_model_display_name(code_config)
        print(f"[INFO] Using code model: {actual_code_model}")

        # Load already trained files from z0train/train_files/{model_name}.json
        trained_files = set()
        # Convert model_name format: Qwen/Qwen3-8B -> Qwen_Qwen3-8B
        model_name_normalized = model_name.replace("/", "_")
        train_json_path = os.path.join(path, "z0train", "train_files", f"{model_name_normalized}.json")
        if os.path.exists(train_json_path):
            try:
                with open(train_json_path, "r", encoding="utf-8") as f:
                    train_data = json.load(f)
                if isinstance(train_data, list):
                    trained_files = set(train_data)
                elif isinstance(train_data, dict) and 'files' in train_data:
                    trained_files = set(train_data['files'])
                print(f"[INFO] Loaded {len(trained_files)} already trained files from {train_json_path}")
            except Exception as e:
                print(f"[WARN] Failed to load train files from {train_json_path}: {e}")

        # Process each file with this model
        for i, file_path in enumerate(data):
            # Skip if this file was already trained
            if file_path in trained_files:
                print(f"[SKIP] File already trained: {file_path}")
                continue
            memory_dir = os.path.join(path, output_dir, "memory")
            if os.path.exists(memory_dir):
                shutil.rmtree(memory_dir)
            os.makedirs(memory_dir, exist_ok=True)

            # Initialize agents for this model
            code_agent = LLMAgent(config=code_config, trust_remote_code=True, tag='code_agent')
            refine_agent = LLMAgent(config=refine_config, trust_remote_code=True, tag='refine_agent')

            print(f"[INFO] Processing: {i+1}/{total_files}, with model: {actual_code_model} =====>")
            file_content = data[file_path]
            result = await process_file_generate_code(
                file_path=file_path,
                file_content=file_content,
                tracker=tracker,
                actual_code_model=actual_code_model,
                total_files=total_files,
                orig_repo=orig_repo,
                cur_repo=cur_repo,
                test_path_cargo=test_path_cargo,
                code_agent=code_agent,
                refine_agent=refine_agent,
                cost_calculator=cost_calculator,
                output_dir=output_dir,
                ablation_type=ablation_type,
                enable_summary=enable_summary,
                summary_tracker=summary_tracker
            )

            if result == "PAUSED_DUE_TO_COST":
                print(f"[INFO] Paused during processing model {model_name}")
                return result
            if result is not None and i > 0 and i % 3 == 0 and model_name not in opensource_models:
                await asyncio.sleep(20)

        print(f"\n[INFO] Completed processing all files with model: {model_name}\n")

    print("[INFO] Processing complete")
    return ""


async def main():
    """Default main function for backward compatibility."""
    code_config = Config.from_task(code_agent_config)
    output_dir = getattr(code_config, "output_dir", "output")
    tracker = ProgressTracker(db_path=os.path.join(path, output_dir, "progress.db"))
    return await run_main(refine_config_path="refine.yaml", tracker=tracker)


if __name__ == '__main__':
    # Launch the async main function
    asyncio.run(main())
