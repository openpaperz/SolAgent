import asyncio
import json
import os
import pickle
import subprocess
from datetime import datetime
from pathlib import Path

from utils.path import remap_path
from utils.shared_context import shared_context
from utils.forge_utils import run_forge_test
from utils.slither_utils import run_slither, get_slither_feedback_and_count
from db.progress_tracker_agent import ProgressTrackerAgent
from run_restore_genfile import restore_origsol

from utils.feedback_utils import generate_feedback


async def process_file_test_code(
    file_path: str,
    file_content: list,
    tracker: ProgressTrackerAgent,
    actual_model: str,
    total_files: int,
    orig_repo: str,
    cur_repo: str,
    test_path_cargo: dict,
    copilot_result_dir: str
):
    """Process a single file by testing pre-generated code from copilot"""
    # Check if already processed
    existing_entry = tracker.get_entry(file_path, actual_model, "copilot")
    if existing_entry and existing_entry['status'] >= 1:
        print(f"[SKIP] File already processed: {file_path} (model: {actual_model})")
        return None
    
    # Initialize tracking entry
    start_time = datetime.now().isoformat()
    tracker.create_or_update_entry(
        file_path=file_path,
        model_coding=actual_model,
        agent_type="copilot",
        total_files=total_files,
        status=0,
        model_summary=None,
        start_time=start_time
    )

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
    
    # Calculate method_len from file_content
    method_len = 0
    for cls in file_content:
        for method in cls["methods"]:
            if method["kind"] not in ["struct", "function", "constructor"]:
                continue
            method_len += 1
    
    # Load pre-generated code from copilot result directory
    file_name = cur_sol.split("/")[-1]
    copilot_code_path = os.path.join(copilot_result_dir, file_name)
    
    if not os.path.exists(copilot_code_path):
        print(f"[SKIP] Pre-generated code not found: {copilot_code_path}")
        return None
    
    # Read the pre-generated code
    try:
        with open(copilot_code_path, "r", encoding="utf-8") as f:
            code_block = f.read()
    except Exception as e:
        print(f"[ERROR] Failed to read pre-generated code: {e}")
        return None
    
    if not code_block:
        print(f"[WARNING] No code content in: {copilot_code_path}")
        return None
    
    print(f"[INFO] Loaded pre-generated code ({len(code_block)} chars)")
    
    # Initialize token/cost counters
    prompt_tokens = 0
    completion_tokens = 0
    total_cost = 0.0
    
    try:
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
            print(f"[SKIP] Forge test timeout after loading code, skipping file: {file_path}")
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
        
        # Build coding_messages for tracking (simplified for copilot)
        coding_messages = [
            {
                "role": "assistant",
                "content": f"```solidity\n{code_block}\n```"
            },
            {
                "role": "user",
                "content": feedback_content
            }
        ]
        
        # Mark as completed
        end_time = datetime.now().isoformat()
        tracker.mark_completed(
            file_path=file_path,
            methods=method_len,
            model_coding=actual_model,
            agent_type="copilot",
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


async def main():
    """Main execution function"""
    path = os.path.dirname(os.path.abspath(__file__))
    dataset_path = os.path.join(path, 'data/dataset.json')
    
    # Load dataset
    with open(dataset_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # Configuration
    output_dir = "output"
    
    # Initialize progress tracker with agent table
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
    
    # Copilot result base directory
    copilot_base_dir = os.path.join(path, "baseline_copilot", "result")
    
    # Models to process (directory names in baseline_copilot/result)
    models = ["claude-sonnet-4-5", "gpt-5.1", "gpt-5-mini"]
    
    # Process each model
    for model_name in models:
        print(f"\n{'='*80}")
        print(f"[INFO] Processing with model: {model_name}")
        print(f"{'='*80}\n")
        
        # Path to copilot generated code for this model
        copilot_result_dir = os.path.join(copilot_base_dir, model_name)
        
        if not os.path.exists(copilot_result_dir):
            print(f"[ERROR] Copilot result directory not found: {copilot_result_dir}")
            continue
        
        # Use model name as is for tracking
        actual_model = model_name
        print(f"[INFO] Tracking with model name: {actual_model}")
        
        # Process each file with this model
        for i, file_path in enumerate(data):
            file_content = data[file_path]
            result = await process_file_test_code(
                file_path=file_path,
                file_content=file_content,
                tracker=tracker,
                actual_model=actual_model,
                total_files=total_files,
                orig_repo=orig_repo,
                cur_repo=cur_repo,
                test_path_cargo=test_path_cargo,
                copilot_result_dir=copilot_result_dir
            )
        
        print(f"\n[INFO] Completed processing all files with model: {model_name}\n")

    
    print("[INFO] Processing complete")


if __name__ == '__main__':
    asyncio.run(main())
