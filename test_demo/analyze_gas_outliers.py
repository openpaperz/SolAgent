#!/usr/bin/env python3
"""
Re-run forge tests with --gas-report to update gas fee data in database.
Processes all entries with existing gas data across different tracker types.
"""

import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from utils.code_utils import try_extract_code

from db.progress_tracker import ProgressTracker
from db.baseline_test import BaselineTest
from db.progress_tracker_agent import ProgressTrackerAgent
from db.progress_tracker_rawmodel import ProgressTrackerRawModel
from stats.common_utils import safe_json_loads
import json
import pickle
from utils.forge_utils import run_gas_report, run_forge_test
from run_restore_genfile import restore_origsol
from utils.path import remap_path
from utils.shared_context import shared_context
import asyncio
import re
from collections import defaultdict
from file_parser import extract_code_blocks


def run_and_extract_gas_for_round(test_file_path: str) -> dict:
    """
    Run forge test with gas report for a specific test file and extract gas fees.
    
    Args:
        test_file_path: Absolute path to the test file
        
    Returns:
        Dictionary mapping test signatures to gas fees
        Format: {"test_sig": {"-": mean, "~": median}} or {"test_sig": {"gas": value}}
    """
    try:
        gas_fees = run_gas_report(test_file_path)
        return gas_fees
    except Exception as e:
        print(f"  [ERROR] Failed to run gas report: {e}")
        return {}


def update_baseline_test(db_path='output/progress.db', limit=None):
    """
    Re-run all baseline tests and update gas_fee_json.
    
    Args:
        db_path: Path to the database
        limit: Optional limit on number of entries to process
    """
    tracker = BaselineTest(db_path)
    all_entries = tracker.get_all_entries()
    
    print("="*120)
    print(f"Updating BaselineTest Gas Fees")
    print(f"Database: {db_path}")
    print(f"Total entries: {len(all_entries)}")
    print("="*120)
    
    # Get repo paths and test_path_cargo
    try:
        orig_repo = os.environ["ORIG_REPO"]
    except KeyError:
        print("[ERROR] ORIG_REPO environment variable not set")
        return
    
    cur_repo = os.getcwd()
    
    test_path_cargo = {}
    try:
        with open("data/test_map_cargo.pkl", "rb") as f:
            test_path_cargo = pickle.load(f)
        print(f"[INFO] Loaded test_path_cargo with {len(test_path_cargo)} entries")
    except Exception as e:
        print(f"[WARN] Failed to load test_path_cargo: {e}")
        return
    
    processed_count = 0
    
    for idx, entry in enumerate(all_entries):
        if limit and processed_count >= limit:
            break
        
        file_path = entry.get('file_path', '')
        # if file_path != 'repository/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol':
        #     continue
        gas_fee_json_str = entry.get('gas_fee_json', '{}')
        gas_fee_json = safe_json_loads(gas_fee_json_str)
        
        # Skip if no existing gas data
        if not gas_fee_json:
            continue
        
        print(f"\n[{idx + 1}/{len(all_entries)}] Processing: {file_path}")
        
        # Get test path
        if file_path not in test_path_cargo:
            print(f"  [SKIP] No test path found in test_path_cargo")
            continue
        
        test_path_orig = test_path_cargo[file_path]
        cur_t_sol = remap_path(test_path_orig, orig_repo, cur_repo)
        
        if not os.path.exists(cur_t_sol):
            print(f"  [SKIP] Test file not found: {cur_t_sol}")
            continue
        
        # Run gas report
        print(f"  Running gas report... {cur_t_sol}")
        new_gas_fees = run_and_extract_gas_for_round(cur_t_sol)
        
        if new_gas_fees:
            print(f"  ✓ Extracted {len(new_gas_fees)} gas measurements")
            
            # Update database
            try:
                tracker.update_row(entry['id'], {'gas_fee_json': new_gas_fees})
                print(f"  ✓ Updated database")
                processed_count += 1
            except Exception as e:
                print(f"  ✗ Failed to update database: {e}")
        else:
            print(f"  [WARN] No gas fees extracted")
    
    print(f"\n{'='*120}")
    print(f"BaselineTest Complete - Processed {processed_count} entries")
    print(f"{'='*120}")


def update_progress_tracker_generic(tracker, tracker_name, db_path='output/progress.db', limit=None):
    """
    Generic function to re-run all progress tracker tests and update round_gas_fee_json.
    Works with any tracker that has the same structure as ProgressTracker.
    
    Args:
        tracker: Progress tracker instance (ProgressTracker, ProgressTrackerSummary, or ProgressTrackerAblation)
        tracker_name: Name of the tracker (for display purposes)
        db_path: Path to the database
        limit: Optional limit on number of entries to process
    """
    all_entries = tracker.get_all_entries()
    
    print("="*120)
    print(f"Updating {tracker_name} Gas Fees")
    print(f"Database: {db_path}")
    print(f"Total entries: {len(all_entries)}")
    print("="*120)
    
    # Get repo paths and test_path_cargo
    try:
        orig_repo = os.environ["ORIG_REPO"]
    except KeyError:
        print("[ERROR] ORIG_REPO environment variable not set")
        return
    
    cur_repo = os.getcwd()
    
    test_path_cargo = {}
    try:
        with open("data/test_map_cargo.pkl", "rb") as f:
            test_path_cargo = pickle.load(f)
        print(f"[INFO] Loaded test_path_cargo with {len(test_path_cargo)} entries")
    except Exception as e:
        print(f"[WARN] Failed to load test_path_cargo: {e}")
        return
    
    processed_count = 0
    mismatches = []  # Track len(gas_fees) != passed_count mismatches
    
    # included_ids = set([91, 80])  # Add any IDs to include from processing
    for idx, entry in enumerate(all_entries):
        # if entry['id'] not in included_ids:
        #     print(f"\n[{idx + 1}/{len(all_entries)}] Skipping excluded ID: {entry['id']}")
        #     continue
        if limit and processed_count >= limit:
            break
        
        file_path = entry.get('file_path', '')
        test_json_str = entry.get('test_json', '{}')
        test_json = safe_json_loads(test_json_str)
        
        # Skip if no existing test data
        if not test_json:
            continue
        
        print(f"\n[{idx + 1}/{len(all_entries)}] Processing: {file_path}, model: {entry.get('model_coding', 'N/A')}, id: {entry.get('id', 'N/A')}")
        print(f"  Rounds to process: {list(test_json.keys())}")
        
        # Get test path
        if file_path not in test_path_cargo:
            print(f"  [SKIP] No test path found in test_path_cargo")
            continue
        
        test_path_orig = test_path_cargo[file_path]
        cur_t_sol = remap_path(test_path_orig, orig_repo, cur_repo)
        
        if not os.path.exists(cur_t_sol):
            print(f"  [SKIP] Test file not found: {cur_t_sol}")
            continue
        
        print(f"  [INFO] Test file found: {cur_t_sol}")
        # Setup paths for restore
        orig_sol = os.path.join(orig_repo, file_path)
        cur_sol = remap_path(orig_sol, orig_repo, cur_repo)
        orig_sol_repo = os.path.join(orig_repo, "/".join(file_path.split("/")[0:2]))
        
        # Restore original file first (once per file)
        try:
            restore_origsol()
            print(f"  ✓ Original file restored")
        except Exception as e:
            print(f"  ✗ Failed to restore: {e}")
            continue
        
        # Set shared context (once per file)
        try:
            try:
                loop = asyncio.get_running_loop()
                task = loop.create_task(shared_context.set_all(orig_sol_repo, orig_sol, cur_t_sol, cur_sol, file_path=file_path))
            except RuntimeError:
                asyncio.run(shared_context.set_all(orig_sol_repo, orig_sol, cur_t_sol, cur_sol, file_path=file_path))
        except Exception as e:
            shared_context._data["orig_sol_repo"] = orig_sol_repo
            shared_context._data["orig_sol"] = orig_sol
            shared_context._data["cur_t.sol"] = cur_t_sol
            shared_context._data["cur_sol"] = cur_sol
            shared_context._data["file_path"] = file_path
        
        # Process each round
        new_round_gas_json = {}
        
        for round_idx in test_json.keys():
            print(f"\n  Processing Round {round_idx}...")
            
            # Check if this round has any passed tests
            round_idx_str = str(round_idx)
            if round_idx_str in test_json:
                round_test_data = test_json[round_idx_str]
                if isinstance(round_test_data, dict):
                    passed_count = round_test_data.get('passed', 0)
                    if passed_count == 0:
                        print(f"    [SKIP] No passed tests in this round")
                        continue
            
            print(f"    {passed_count} passed tests found")

            # Remove the current sol file to ensure clean state
            if os.path.exists(cur_sol):
                try:
                    os.remove(cur_sol)
                    print(f"    ✓ Removed existing file: {cur_sol}")
                except Exception as e:
                    print(f"    ✗ Failed to remove file: {e}")
                    continue
            
            # Get round messages and extract code
            round_messages = safe_json_loads(entry.get('round_messages', '{}'))
            
            if round_idx_str not in round_messages:
                print(f"    [SKIP] No messages found")
                continue
            
            messages_list = round_messages[round_idx_str]
            
            # Find last assistant message with valid code (not NoContent)
            valid_code = None
            file_name = file_path.split('/')[-1]
            
            for i in range(len(messages_list) - 1, -1, -1):
                msg = messages_list[i]
                if isinstance(msg, dict) and msg.get('role') == 'assistant':
                    content = msg.get('content', '')
                    
                    # Try to extract code from this message
                    try:
                        all_files, _ = extract_code_blocks(content, target_filename=file_name)
                        
                        if all_files:
                            code = all_files[0]['code'].strip()
                            # Check if code is not NoContent
                            if code and code != "NoContent":
                                valid_code = code
                                break
                    except Exception:
                        continue
            
            if not valid_code:
                print(f"    [SKIP] No assistant message with valid code found")
                continue
            
            # Write code directly
            try:
                with open(cur_sol, 'w') as f:
                    f.write(valid_code)
                print(f"    ✓ Code written ({len(valid_code)} chars)")
                
                # Run gas report
                print(f"    Running gas report...")
                gas_fees = run_and_extract_gas_for_round(cur_t_sol)
                
                if gas_fees:
                    # Check if len(gas_fees) matches passed_count
                    if len(gas_fees) != passed_count:
                        mismatches.append({
                            'file_path': file_path,
                            'model': entry.get('model_coding', 'N/A'),
                            'id': entry.get('id', 'N/A'),
                            'round': round_idx,
                            'passed_count': passed_count,
                            'gas_fees_count': len(gas_fees),
                            'cur_t_sol': cur_t_sol
                        })
                        print(f"    ⚠️  MISMATCH: passed_count={passed_count}, len(gas_fees)={len(gas_fees)}")
                    
                    new_round_gas_json[round_idx] = gas_fees
                    print(f"    ✓ Extracted {len(gas_fees)} gas measurements")
                else:
                    print(f"    [WARN] No gas fees extracted")
                    
            except Exception as e:
                print(f"    [ERROR] Failed to process round: {e}")
                continue
        
        # Update database if we got new data
        if new_round_gas_json:
            try:
                # Pass dict directly; BaseProgressTracker will JSON-encode
                tracker.update_row(entry['id'], {'round_gas_fee_json': new_round_gas_json})
                print(f"\n  ✓ Updated database with {len(new_round_gas_json)} rounds")
                processed_count += 1
            except Exception as e:
                print(f"\n  ✗ Failed to update database: {e}")
        else:
            # Set to NULL if no valid gas data was collected
            try:
                tracker.update_row(entry['id'], {'round_gas_fee_json': None})
                print(f"\n  ✓ Updated database with NULL (no valid gas data)")
                processed_count += 1
            except Exception as e:
                print(f"\n  ✗ Failed to update database to NULL: {e}")
    
    print(f"\n{'='*120}")
    print(f"{tracker_name} Complete - Processed {processed_count} entries")
    print(f"{'='*120}")
    
    # Print mismatch summary
    if mismatches:
        print(f"\n{'='*120}")
        print(f"Mismatches Found: {len(mismatches)}")
        print(f"{'='*120}")
        for mismatch in mismatches:
            print(f"File: {mismatch['file_path']}, Model: {mismatch['model']}, ID: {mismatch['id']}, Round: {mismatch['round']}, passed_count: {mismatch['passed_count']}, len(gas_fees): {mismatch['gas_fees_count']}, Test: {mismatch['cur_t_sol']}")
        print(f"{'='*120}")
    else:
        print(f"\n✓ No mismatches found between passed_count and len(gas_fees)")


def update_progress_tracker(db_path='output/progress.db', limit=None):
    """
    Re-run all progress tracker tests and update round_gas_fee_json.
    
    Args:
        db_path: Path to the database
        limit: Optional limit on number of entries to process
    """
    tracker = ProgressTracker(db_path)
    update_progress_tracker_generic(tracker, "ProgressTracker", db_path, limit)


def update_progress_tracker_summary(db_path='output/progress.db', limit=None):
    """
    Re-run all progress tracker summary tests and update round_gas_fee_json.
    
    Args:
        db_path: Path to the database
        limit: Optional limit on number of entries to process
    """
    from db.progress_tracker_summary import ProgressTrackerSummary
    tracker = ProgressTrackerSummary(db_path)
    update_progress_tracker_generic(tracker, "ProgressTrackerSummary", db_path, limit)


def update_progress_tracker_ablation(db_path='output/progress.db', limit=None):
    """
    Re-run all progress tracker ablation tests and update round_gas_fee_json.
    
    Args:
        db_path: Path to the database
        limit: Optional limit on number of entries to process
    """
    from db.progress_tracker_ablation import ProgressTrackerAblation
    tracker = ProgressTrackerAblation(db_path)
    update_progress_tracker_generic(tracker, "ProgressTrackerAblation", db_path, limit)


def update_other_trackers_generic(tracker, tracker_name, db_path='output/progress.db', limit=None):
    """
    Generic function to re-run tests for other trackers (Agent, RawModel) and update gas_fee_json.
    Works with any tracker that stores gas_fee_json (not round-based).
    
    Args:
        tracker: Progress tracker instance (ProgressTrackerAgent or ProgressTrackerRawModel)
        tracker_name: Name of the tracker (for display purposes)
        db_path: Path to the database
        limit: Optional limit on number of entries to process
    """
    all_entries = tracker.get_all_entries()
    
    print("="*120)
    print(f"Updating {tracker_name} Gas Fees")
    print(f"Database: {db_path}")
    print(f"Total entries: {len(all_entries)}")
    print("="*120)
    
    # Get repo paths and test_path_cargo
    try:
        orig_repo = os.environ["ORIG_REPO"]
    except KeyError:
        print("[ERROR] ORIG_REPO environment variable not set")
        return
    
    cur_repo = os.getcwd()
    
    test_path_cargo = {}
    try:
        with open("data/test_map_cargo.pkl", "rb") as f:
            test_path_cargo = pickle.load(f)
        print(f"[INFO] Loaded test_path_cargo with {len(test_path_cargo)} entries")
    except Exception as e:
        print(f"[WARN] Failed to load test_path_cargo: {e}")
        return
    
    processed_count = 0
    mismatches = []  # Track len(gas_fees) != test_total mismatches
    
    excluded_ids = set([])  # Add any IDs to exclude from processing
    for idx, entry in enumerate(all_entries):
        if entry['id'] in excluded_ids:
            continue
        if entry['update_time'] > '2026-01-10T00:00:00':  # Process only entries before this date
            continue
        if limit and processed_count >= limit:
            break
        
        file_path = entry.get('file_path', '')
        
        # Get pass/total counts
        test_pass = entry.get('test_pass', 0)
        test_total = entry.get('test_total', 0)
        
        # Skip if no tests recorded
        if not test_pass > 0:
            continue
        agent_type = entry.get('agent_type', 'N/A')
        if agent_type != 'metagpt':
            continue
        
        print(f"\n[{idx + 1}/{len(all_entries)}] Processing: {file_path}, model: {entry.get('model_coding', 'N/A')}, id: {entry.get('id', 'N/A')}")
        print(f"  Expected passed tests: {test_pass} (test_total={test_total})")
        
        # Get test path
        if file_path not in test_path_cargo:
            print(f"  [SKIP] No test path found in test_path_cargo")
            continue
        
        test_path_orig = test_path_cargo[file_path]
        cur_t_sol = remap_path(test_path_orig, orig_repo, cur_repo)
        
        if not os.path.exists(cur_t_sol):
            print(f"  [SKIP] Test file not found: {cur_t_sol}")
            continue
        
        print(f"  [INFO] Test file found: {cur_t_sol}")
        # Setup paths for restore
        orig_sol = os.path.join(orig_repo, file_path)
        cur_sol = remap_path(orig_sol, orig_repo, cur_repo)
        orig_sol_repo = os.path.join(orig_repo, "/".join(file_path.split("/")[0:2]))
        
        # Restore original file first
        try:
            restore_origsol()
            print(f"  ✓ Original file restored")
        except Exception as e:
            print(f"  ✗ Failed to restore: {e}")
            continue
        
        # Set shared context
        try:
            try:
                loop = asyncio.get_running_loop()
                task = loop.create_task(shared_context.set_all(orig_sol_repo, orig_sol, cur_t_sol, cur_sol, file_path=file_path))
            except RuntimeError:
                asyncio.run(shared_context.set_all(orig_sol_repo, orig_sol, cur_t_sol, cur_sol, file_path=file_path))
        except Exception as e:
            shared_context._data["orig_sol_repo"] = orig_sol_repo
            shared_context._data["orig_sol"] = orig_sol
            shared_context._data["cur_t.sol"] = cur_t_sol
            shared_context._data["cur_sol"] = cur_sol
            shared_context._data["file_path"] = file_path
        
        # Extract assistant code (from coding_messages) and write to cur_sol
        coding_messages = safe_json_loads(entry.get('coding_messages', '[]'))
        if not coding_messages:
            print(f"  [SKIP] No coding_messages found")
            continue

        # Remove existing sol file to ensure clean state
        if os.path.exists(cur_sol):
            try:
                os.remove(cur_sol)
                print(f"  ✓ Removed existing file: {cur_sol}")
            except Exception as e:
                print(f"  ✗ Failed to remove file: {e}")
                continue

        valid_code = None
        file_name = file_path.split('/')[-1]
        file_class = file_name.replace('.sol', '')
        for i in range(len(coding_messages) - 1, -1, -1):
            msg = coding_messages[i]
            if isinstance(msg, dict) and msg.get('role') == 'assistant':
                content = msg.get('content', '')
                try:
                    if agent_type == 'metagpt':
                        code_block = try_extract_code(content)
                        if code_block and code_block.strip().startswith("// SPDX-License-Identifier: MIT"):
                            code = code_block.strip()
                            if file_class not in code:
                                continue
                            valid_code = code
                            break
                        elif code_block and code_block.strip().startswith("```solidity"):
                            code = code_block.strip().replace("```solidity", "").replace("```", "").strip()
                            if file_class not in code:
                                continue
                            valid_code = code
                            break
                    else:    
                        all_files, _ = extract_code_blocks(content, target_filename=file_name)
                        if all_files:
                            code = all_files[0]['code'].strip()
                            if code and code != "NoContent":
                                valid_code = code
                                break
                            else:
                                if agent_type == 'deepcode':
                                    tool_calls = msg.get('tool_calls', [])
                                    for call in reversed(tool_calls):
                                        if call.get('name') == 'write_file':
                                            input = call.get('input', {})
                                            if input.get('file_path') == file_name:
                                                code = input.get('content', '').strip()
                                                if code and code != "NoContent":
                                                    valid_code = code
                                                    break
                                if valid_code:
                                    break
                except Exception:
                    continue

        if not valid_code:
            print(f"  [SKIP] No assistant message with valid code found")
            continue

        try:
            with open(cur_sol, 'w') as f:
                f.write(valid_code)
            print(f"  ✓ Code written ({len(valid_code)} chars)")
        except Exception as e:
            print(f"  ✗ Failed to write code: {e}")
            continue

        # Run gas report
        print(f"  Running gas report...")
        gas_fees = run_and_extract_gas_for_round(cur_t_sol)
        
        if gas_fees:
            # Check if len(gas_fees) matches test_pass
            if len(gas_fees) != test_pass:
                mismatches.append({
                    'file_path': file_path,
                    'model': entry.get('model_coding', 'N/A'),
                    'id': entry.get('id', 'N/A'),
                    'test_pass': test_pass,
                    'test_total': test_total,
                    'gas_fees_count': len(gas_fees),
                    'cur_t_sol': cur_t_sol
                })
                print(f"  ⚠️  MISMATCH: test_pass={test_pass}, len(gas_fees)={len(gas_fees)} (test_total={test_total})")
            
            # Update database
            try:
                tracker.update_row(entry['id'], {'gas_fee_json': gas_fees})
                print(f"  ✓ Extracted {len(gas_fees)} gas measurements and updated database")
                processed_count += 1
            except Exception as e:
                print(f"  ✗ Failed to update database: {e}")
        else:
            print(f"  [WARN] No gas fees extracted")
    
    print(f"\n{'='*120}")
    print(f"{tracker_name} Complete - Processed {processed_count} entries")
    print(f"{'='*120}")
    
    # Print mismatch summary
    if mismatches:
        print(f"\n{'='*120}")
        print(f"Mismatches Found: {len(mismatches)}")
        print(f"{'='*120}")
        for mismatch in mismatches:
            print(f"File: {mismatch['file_path']}, Model: {mismatch['model']}, ID: {mismatch['id']}, test_pass: {mismatch['test_pass']}, test_total: {mismatch['test_total']}, len(gas_fees): {mismatch['gas_fees_count']}, Test: {mismatch['cur_t_sol']}")
        print(f"{'='*120}")
    else:
        print(f"\n✓ No mismatches found between test_pass and len(gas_fees)")


def update_progress_tracker_agent(db_path='output/progress.db', limit=None):
    """
    Re-run all progress tracker agent tests and update gas_fee_json.
    
    Args:
        db_path: Path to the database
        limit: Optional limit on number of entries to process
    """
    tracker = ProgressTrackerAgent(db_path)
    update_other_trackers_generic(tracker, "ProgressTrackerAgent", db_path, limit)


def update_progress_tracker_rawmodel(db_path='output/progress.db', limit=None):
    """
    Re-run all progress tracker rawmodel tests and update gas_fee_json.
    
    Args:
        db_path: Path to the database
        limit: Optional limit on number of entries to process
    """
    tracker = ProgressTrackerRawModel(db_path)
    update_other_trackers_generic(tracker, "ProgressTrackerRawModel", db_path, limit)


# ---------------------------------------------------------------------------
# Preserved legacy analysis methods (not invoked via __main__)
# ---------------------------------------------------------------------------

def analyze_gas_outliers_with_baseline(
    db_path='output/progress.db', 
    target_models=None,
    limit=1
):
    """
    Analyze gas outliers in the database and compare with baseline.
    Outliers are identified as tests that have failures in test_json.
    For each row, remove failed tests from round_gas_fee_json and update the database.
    
    Args:
        db_path: Path to the database
        target_models: List of models to analyze (default: ['claude-sonnet-4-5', 'gpt-5-mini', 'gpt-5.1'])
        limit: Number of rows to process (default: 1)
    """
    if target_models is None:
        target_models = ['claude-sonnet-4-5', 'gpt-5-mini', 'gpt-5.1']
    
    tracker = ProgressTracker(db_path)
    baseline_tracker = BaselineTest(db_path)
    
    all_rows = tracker.get_all_entries(status=1)
    
    print("="*120)
    print(f"Gas Outlier Analysis with Baseline Comparison")
    print(f"Database: {db_path}")
    print(f"Outlier detection: Tests with failures in test_json")
    print(f"Target models: {target_models}")
    print("="*120)
    
    # Group rows by row.id that have outliers
    rows_with_outliers = {}  # {row_id: row}
    outliers_by_row = {}  # {row_id: {round_idx: {test_name: outlier_data}}}
    
    print(f"\nScanning {len(all_rows)} entries for outliers...")
    
    # Analyze each entry
    for idx, row in enumerate(all_rows):
        model = row.get('model_coding', '')
        
        # Only process target models
        if model not in target_models:
            continue
        
        row_id = row.get('id')
        file_path = row.get('file_path', 'unknown')
        round_gas_json = safe_json_loads(row.get('round_gas_fee_json', '{}'))
        test_json = safe_json_loads(row.get('test_json', '{}'))
        
        if not round_gas_json or not test_json:
            continue
        
        # Get baseline for comparison
        baseline_entry = baseline_tracker.get_entry(file_path)
        baseline_gas_json = {}
        if baseline_entry:
            baseline_gas_json = safe_json_loads(baseline_entry.get('gas_fee_json', '{}'))
        
        # Extract all gas values from all rounds
        row_has_outliers = False
        outliers_in_row = {}
        
        for round_idx, gas_data in round_gas_json.items():
            if not isinstance(gas_data, dict):
                continue
            
            # Get failed tests for this round from test_json
            failed_test_signatures = set()
            if round_idx in test_json:
                round_test_data = test_json[round_idx]
                if isinstance(round_test_data, dict):
                    fails = round_test_data.get('fails', {})
                    if isinstance(fails, dict):
                        for fail_key in fails.keys():
                            # Remove (gas: xxxx) suffix if present
                            clean_sig = re.sub(r'\s*\(gas:\s*\d+\)\s*$', '', fail_key)
                            failed_test_signatures.add(clean_sig)
            
            # Only process tests that have failures
            if not failed_test_signatures:
                continue
            
            # Process each failed test if it has gas data
            round_has_outliers = False
            outliers_in_round = {}
            
            for test_name in failed_test_signatures:
                if test_name not in gas_data:
                    continue
                
                test_gas = gas_data[test_name]
                
                # Handle different formats
                gas_values = []
                if isinstance(test_gas, dict):
                    if '-' in test_gas:  # Fuzz mean
                        gas_values.append(('mean', float(test_gas['-'])))
                    if '~' in test_gas:  # Fuzz median
                        gas_values.append(('median', float(test_gas['~'])))
                    if 'gas' in test_gas:  # Non-fuzz
                        gas_values.append(('gas', float(test_gas['gas'])))
                elif isinstance(test_gas, (int, float)):
                    gas_values.append(('direct', float(test_gas)))
                
                for gas_type, gas_val in gas_values:
                    # Get baseline gas for this test
                    baseline_gas_val = None
                    if test_name in baseline_gas_json:
                        baseline_gas = baseline_gas_json[test_name]
                        if isinstance(baseline_gas, dict):
                            # Match gas type: fuzz mean with '-', fuzz median with '~', non-fuzz with 'gas'
                            if gas_type == 'mean' and '-' in baseline_gas:
                                baseline_gas_val = float(baseline_gas['-'])
                            elif gas_type == 'median' and '~' in baseline_gas:
                                baseline_gas_val = float(baseline_gas['~'])
                            elif gas_type == 'gas' and 'gas' in baseline_gas:
                                baseline_gas_val = float(baseline_gas['gas'])
                            elif 'gas' in baseline_gas:  # Fallback to 'gas' field
                                baseline_gas_val = float(baseline_gas['gas'])
                        elif isinstance(baseline_gas, (int, float)):
                            baseline_gas_val = float(baseline_gas)
                    
                    outliers_in_round[test_name] = {
                        'gas_type': gas_type,
                        'gas_value': gas_val,
                        'baseline_gas': baseline_gas_val,
                    }
                    round_has_outliers = True
            
            if round_has_outliers:
                outliers_in_row[round_idx] = outliers_in_round
                row_has_outliers = True
        
        # Store row if it has outliers
        if row_has_outliers:
            rows_with_outliers[row_id] = row
            outliers_by_row[row_id] = outliers_in_row
    
    # Print outliers summary by model
    print(f"\n{'='*120}")
    print("Outlier Rows Found by Model")
    print(f"{'='*120}")
    
    model_row_count = defaultdict(int)
    for row_id in rows_with_outliers:
        row = rows_with_outliers[row_id]
        model = row.get('model_coding', '')
        if model in target_models:
            model_row_count[model] += 1
    
    for model in target_models:
        if model_row_count[model] > 0:
            print(f"\n{model}: {model_row_count[model]} rows with outliers")
    
    # Process rows: display details and update database
    print(f"\n{'='*120}")
    print(f"Processing First {limit} Rows with Outliers")
    print(f"{'='*120}")
    
    processed_count = 0
    
    for row_id in list(rows_with_outliers.keys()):
        # if processed_count >= limit:
        #     break
        
        row = rows_with_outliers[row_id]
        model = row.get('model_coding', '')
        file_path = row.get('file_path', 'unknown')
        outliers_in_row = outliers_by_row.get(row_id, {})
        
        print(f"\n{'='*120}")
        print(f"Processing Row {processed_count + 1} (ID: {row_id})")
        print(f"Model: {model}, File: {file_path}")
        print(f"{'='*120}")
        
        # Load original round_gas_fee_json
        original_round_gas_json = safe_json_loads(row.get('round_gas_fee_json', '{}'))
        
        # Build new round_gas_fee_json by removing failed tests
        new_round_gas_json = {}
        
        for round_idx, gas_data in original_round_gas_json.items():
            if not isinstance(gas_data, dict):
                new_round_gas_json[round_idx] = gas_data
                continue
            
            # Get failed test signatures for this round from outliers_in_row
            failed_test_signatures = set()
            if round_idx in outliers_in_row:
                failed_test_signatures = set(outliers_in_row[round_idx].keys())
            
            # Copy gas_data but remove failed tests
            new_gas_data = {}
            for test_name, test_gas in gas_data.items():
                if test_name not in failed_test_signatures:
                    new_gas_data[test_name] = test_gas
            
            new_round_gas_json[round_idx] = new_gas_data
            
            # Display summary for this round
            removed_count = len(failed_test_signatures)
            kept_count = len(new_gas_data)
            print(f"  Round {round_idx}: Removed {removed_count} failed tests, Kept {kept_count} passing tests")
            
            if removed_count > 0:
                for fail_sig in list(failed_test_signatures)[:3]:
                    print(f"    - Removed: {fail_sig}")
                if removed_count > 3:
                    print(f"    - ... and {removed_count - 3} more")
        
        # Convert new_round_gas_json back to JSON string
        new_round_gas_json_str = json.dumps(new_round_gas_json, ensure_ascii=False)
        
        # Update the database
        print(f"\n  Updating database for row {row_id}...")
        try:
            tracker.update_row(row_id, {'round_gas_fee_json': new_round_gas_json_str})
            print(f"  ✓ Successfully updated round_gas_fee_json")
        except Exception as e:
            print(f"  ✗ Failed to update database: {e}")
        
        processed_count += 1
    
    print(f"\n{'='*120}")
    print(f"Analysis Complete - Processed {processed_count}/{limit} rows")
    print(f"{'='*120}")
    
    return rows_with_outliers


def process_outliers_by_ratio(
    db_path='output/progress.db',
    target_models=None,
    limit=1
):
    """
    Process outliers sorted by ratio (gas/baseline).
    For each outlier, extract assistant message from round_messages, write to file, and run forge test.
    Does NOT update database.
    
    Args:
        db_path: Path to the database
        target_models: List of models to analyze
        limit: Number of outliers to process
    """
    if target_models is None:
        target_models = ['claude-sonnet-4-5', 'gpt-5-mini', 'gpt-5.1']
    
    tracker = ProgressTracker(db_path)
    baseline_tracker = BaselineTest(db_path)
    
    all_rows = tracker.get_all_entries(status=1)
    
    print("="*120)
    print(f"Processing Outliers by Ratio (Gas/Baseline)")
    print(f"Database: {db_path}")
    print(f"Target models: {target_models}")
    print("="*120)
    
    # Collect all outliers with their ratios
    all_outliers = []  # [(ratio, row_id, round_idx, test_name, row), ...]
    
    print(f"\nScanning {len(all_rows)} entries for outliers...")
    
    for idx, row in enumerate(all_rows):
        model = row.get('model_coding', '')
        
        if model not in target_models:
            continue
        
        row_id = row.get('id')
        file_path = row.get('file_path', 'unknown')
        round_gas_json = safe_json_loads(row.get('round_gas_fee_json', '{}'))
        test_json = safe_json_loads(row.get('test_json', '{}'))
        
        if not round_gas_json or not test_json:
            continue
        
        # Get baseline for comparison
        baseline_entry = baseline_tracker.get_entry(file_path)
        baseline_gas_json = {}
        if baseline_entry:
            baseline_gas_json = safe_json_loads(baseline_entry.get('gas_fee_json', '{}'))
        
        # Extract outliers from all rounds
        for round_idx, gas_data in round_gas_json.items():
            if not isinstance(gas_data, dict):
                continue
            
            # Process each test in gas_data
            for test_name, test_gas in gas_data.items():
                # Extract gas value
                gas_val = None
                if isinstance(test_gas, dict):
                    if '-' in test_gas:
                        gas_val = float(test_gas['-'])
                    elif '~' in test_gas:
                        gas_val = float(test_gas['~'])
                    elif 'gas' in test_gas:
                        gas_val = float(test_gas['gas'])
                elif isinstance(test_gas, (int, float)):
                    gas_val = float(test_gas)
                
                if gas_val is None:
                    continue
                
                # Get baseline gas
                baseline_gas_val = None
                if test_name in baseline_gas_json:
                    baseline_gas = baseline_gas_json[test_name]
                    if isinstance(baseline_gas, dict):
                        if 'gas' in baseline_gas:
                            baseline_gas_val = float(baseline_gas['gas'])
                        elif '-' in baseline_gas:
                            baseline_gas_val = float(baseline_gas['-'])
                        elif '~' in baseline_gas:
                            baseline_gas_val = float(baseline_gas['~'])
                    elif isinstance(baseline_gas, (int, float)):
                        baseline_gas_val = float(baseline_gas)
                
                # Calculate ratio
                if baseline_gas_val and baseline_gas_val > 0:
                    ratio = gas_val / baseline_gas_val
                    
                    # Skip if ratio is less than 1 (only process cases where SolAgent > baseline)
                    if ratio < 1:
                        continue
                    
                    all_outliers.append({
                        'ratio': ratio,
                        'row_id': row_id,
                        'round_idx': round_idx,
                        'test_name': test_name,
                        'gas_val': gas_val,
                        'baseline_gas': baseline_gas_val,
                        'row': row,
                        'model': model,
                        'file_path': file_path
                    })
    
    # Sort by ratio (largest first), then by row_id
    all_outliers.sort(key=lambda x: (-x['ratio'], x['row_id']))
    
    print(f"\nFound {len(all_outliers)} outlier measurements")
    if all_outliers:
        print(f"Ratio range: {all_outliers[0]['ratio']:.4f} - {all_outliers[-1]['ratio']:.4f}")
    
    # Group outliers by row_id (preserving ratio-sorted order within each row_id)
    from collections import OrderedDict
    outliers_by_row_id = OrderedDict()
    round_idx_by_row_id = OrderedDict()  # Track unique rounds per row_id
    
    for outlier in all_outliers:
        row_id = outlier['row_id']
        round_idx = outlier['round_idx']
        
        if row_id not in outliers_by_row_id:
            outliers_by_row_id[row_id] = []
            round_idx_by_row_id[row_id] = []
        
        outliers_by_row_id[row_id].append(outlier)
        
        # Track unique round_idx for this row_id (preserve order)
        if round_idx not in round_idx_by_row_id[row_id]:
            round_idx_by_row_id[row_id].append(round_idx)
    
    print(f"Grouped into {len(outliers_by_row_id)} row(s)")
    for row_id, outliers_in_row in outliers_by_row_id.items():
        rounds = round_idx_by_row_id[row_id]
        print(f"  Row {row_id}: {len(outliers_in_row)} outliers across {len(rounds)} round(s): {rounds}")
    
    # Flatten back to single list for processing, now grouped by row_id
    all_outliers_grouped = []
    for row_id, outliers_in_row in outliers_by_row_id.items():
        all_outliers_grouped.extend(outliers_in_row)
    
    # Get repo paths and test_path_cargo
    try:
        orig_repo = os.environ["ORIG_REPO"]
    except KeyError:
        print("[ERROR] ORIG_REPO environment variable not set")
        return
    
    cur_repo = os.getcwd()
    
    test_path_cargo = {}
    try:
        with open("data/test_map_cargo.pkl", "rb") as f:
            test_path_cargo = pickle.load(f)
        print(f"[INFO] Loaded test_path_cargo with {len(test_path_cargo)} entries")
    except Exception as e:
        print(f"[WARN] Failed to load test_path_cargo: {e}")
    
    # Process outliers
    print(f"\n{'='*120}")
    print(f"Processing First {limit} Outliers (Grouped by Row ID)")
    print(f"{'='*120}")
    
    processed_count = 0
    processed_rounds_by_row = {}  # Track which rounds have been processed for each row_id
    
    for outlier in all_outliers_grouped:
        if processed_count >= limit:
            break
        
        row_id = outlier['row_id']
        row = outlier['row']
        round_idx = outlier['round_idx']
        test_name = outlier['test_name']
        gas_val = outlier['gas_val']
        baseline_gas = outlier['baseline_gas']
        ratio = outlier['ratio']
        model = outlier['model']
        file_path = outlier['file_path']
        
        # Initialize processed_rounds for this row_id if not exists
        if row_id not in processed_rounds_by_row:
            processed_rounds_by_row[row_id] = set()
        
        # Skip if this round for this row has already been processed
        if round_idx in processed_rounds_by_row[row_id]:
            print(f"\n[SKIP] Row {row_id}, Round {round_idx} already processed")
            continue
        
        print(f"\n{'='*120}")
        print(f"Processing Row {row_id}, Round {round_idx} (Outlier {processed_count + 1}, Ratio: {ratio:.4f})")
        print(f"{'='*120}")
        print(f"Model: {model}")
        print(f"File: {file_path}")
        print(f"Test: {test_name}")
        print(f"Gas: {gas_val:,.0f} (Baseline: {baseline_gas:,.0f})")
        print(f"Ratio: {ratio:.4f}x")
        
        # Extract round_messages for this round
        round_messages = safe_json_loads(row.get('round_messages', '{}'))
        round_idx_str = str(round_idx)
        
        if round_idx_str not in round_messages:
            print(f"[SKIP] No messages found for round {round_idx}")
            continue
        
        messages_list = round_messages[round_idx_str]
        
        # Find last assistant message (iterate from back)
        last_assistant_msg = None
        for idx in range(len(messages_list) - 1, -1, -1):
            msg = messages_list[idx]
            if isinstance(msg, dict) and msg.get('role') == 'assistant':
                last_assistant_msg = msg
                break
        
        if not last_assistant_msg:
            print(f"[SKIP] No assistant message found in round {round_idx}")
            continue
        
        content = last_assistant_msg.get('content', '')
        print(f"\nAssistant message length: {len(content)} chars")
        
        # Extract code blocks
        file_name = file_path.split('/')[-1]
        try:
            all_files, remaining = extract_code_blocks(content, target_filename=file_name)
            
            if not all_files:
                print(f"[SKIP] No code blocks extracted from assistant message")
                continue
            
            print(f"Extracted {len(all_files)} code block(s)")
            
            # Setup paths
            orig_sol_repo = os.path.join(orig_repo, "/".join(file_path.split("/")[0:2]))
            orig_sol = os.path.join(orig_repo, file_path)
            cur_sol = remap_path(orig_sol, orig_repo, cur_repo)
            
            if file_path not in test_path_cargo:
                print(f"[WARN] No test path found in test_path_cargo for {file_path}")
                continue
            
            test_path_orig = test_path_cargo[file_path]
            cur_t_sol = remap_path(test_path_orig, orig_repo, cur_repo)
            
            # Restore original file first
            print(f"\nRestoring original file...")
            try:
                restore_origsol()
                print(f"✓ Original file restored: {cur_sol}")
            except Exception as e:
                print(f"✗ Failed to restore original file: {e}")
                continue
            
            # Set shared_context and restore original file
            print(f"Setting shared context...")
            try:
                import asyncio
                try:
                    loop = asyncio.get_running_loop()
                    task = loop.create_task(shared_context.set_all(orig_sol_repo, orig_sol, cur_t_sol, cur_sol, file_path=file_path))
                except RuntimeError:
                    asyncio.run(shared_context.set_all(orig_sol_repo, orig_sol, cur_t_sol, cur_sol, file_path=file_path))
            except Exception as e:
                try:
                    shared_context._data["orig_sol_repo"] = orig_sol_repo
                    shared_context._data["orig_sol"] = orig_sol
                    shared_context._data["cur_t.sol"] = cur_t_sol
                    shared_context._data["cur_sol"] = cur_sol
                    shared_context._data["file_path"] = file_path
                except Exception as e2:
                    print(f"[WARN] Failed to set shared_context: {e2}")
            
            # Write extracted code
            if os.path.exists(cur_sol):
                for file_info in all_files:
                    code = file_info['code'].strip()
                    print(f"\nWriting extracted code to {cur_sol} ({len(code)} chars)")
                    
                    try:
                        with open(cur_sol, 'w') as f:
                            f.write(code)
                        print(f"✓ Code written")
                    except Exception as e:
                        print(f"✗ Failed to write code: {e}")
                        continue
                    
                    # Run forge test
                    if os.path.exists(cur_t_sol):
                        print(f"\nRunning forge test: {cur_t_sol}")
                        try:
                            result = run_forge_test(cur_t_sol)
                            
                            # Display results
                            if 'compile_error' in result:
                                print(f"✗ Compile error:")
                                print(f"  {result['compile_error'][:300]}")
                            else:
                                passed = result.get('passed', 0)
                                failed = result.get('failed', 0)
                                total = result.get('total', 0)
                                print(f"✓ Test result: {passed}/{total} passed, {failed} failed")
                                
                                # Check gas for this test
                                gas_fees = result.get('gas_fees', {})
                                if test_name in gas_fees:
                                    new_gas_info = gas_fees[test_name]
                                    print(f"\n  Gas for {test_name}: {new_gas_info}")
                                    print(f"  Original gas: {gas_val:,.0f}")
                                
                                # Print failures
                                if failed > 0:
                                    fails = result.get('fails', {})
                                    print(f"\n  Failed tests ({len(fails)}):")
                                    for fail_test, fail_msg in list(fails.items())[:5]:
                                        print(f"    - {fail_test}")
                                        print(f"      {fail_msg[:100]}")
                        except Exception as e:
                            print(f"✗ Forge test failed: {e}")
                    else:
                        print(f"[SKIP] Test file not found: {cur_t_sol}")
            else:
                print(f"[SKIP] Cur sol file not found: {cur_sol}")
        
        except Exception as e:
            print(f"[ERROR] Failed to process outlier: {e}")
            continue
        
        # Mark this round as processed for this row_id
        processed_rounds_by_row[row_id].add(round_idx)
        processed_count += 1
    
    print(f"\n{'='*120}")
    print(f"Processing Complete - Processed {processed_count}/{limit} outliers")
    print(f"{'='*120}")


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Re-run forge tests with gas report to update gas data')
    parser.add_argument('--db', type=str, default='output/progress.db', 
                       help='Path to database file')
    parser.add_argument('--limit', type=int, default=None,
                       help='Limit number of entries to process per table')
    parser.add_argument('--table', type=str, choices=['baseline', 'progress', 'summary', 'ablation', 'agent', 'rawmodel', 'others', 'all'], default='all',
                       help='Which table(s) to update (default: all)')
    
    args = parser.parse_args()
    
    # if args.table in ['baseline', 'all']:
    #     update_baseline_test(db_path=args.db, limit=args.limit)
    
    # if args.table in ['progress', 'all']:
    #     update_progress_tracker(db_path=args.db, limit=args.limit)
    
    # if args.table in ['summary', 'all']:
    #     update_progress_tracker_summary(db_path=args.db, limit=args.limit)
    
    # if args.table in ['ablation', 'all']:
    #     update_progress_tracker_ablation(db_path=args.db, limit=args.limit)
    
    # if args.table in ['rawmodel', 'all']:
    #     update_progress_tracker_rawmodel(db_path=args.db, limit=args.limit)
    
    if args.table in ['agent', 'all']:
        update_progress_tracker_agent(db_path=args.db, limit=args.limit)
    
    # if args.table in ['others', 'all']:
    #     update_other_trackers(db_path=args.db, limit=args.limit)
