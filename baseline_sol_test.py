"""
Baseline Solidity Test script.
Tests original Solidity files using forge and slither.
Stores results in BaselineTest table (progress_tracker_rawmodel).
"""
import asyncio
import json
import os
import pickle
import subprocess
from datetime import datetime
from pathlib import Path

from utils.path import remap_path
from utils.forge_utils import run_forge_test
from utils.slither_utils import run_slither, get_slither_feedback_and_count
from db.baseline_test import BaselineTest
from run_restore_genfile import restore_origsol


async def process_file_test(
    file_path: str,
    tracker: BaselineTest,
    total_files: int,
    cur_repo: str,
    test_path_cargo: dict,
    file_content: list
):
    """
    Process a single file: run forge test and slither analysis.
    Save results to BaselineTest table.
    
    Args:
        file_path: Path to the Solidity file
        tracker: BaselineTest instance for database operations
        total_files: Total number of files in dataset
        cur_repo: Current repository path
        test_path_cargo: Mapping of file paths to test paths
        file_content: File content/metadata from dataset
    """
    # Check if already processed
    existing_entry = tracker.get_entry(file_path)
    if existing_entry and existing_entry['id'] < 30:
        print(f"[SKIP] File already tested: {file_path}")
        return None
    
    print(f"[PROCESSING] File: {file_path}")
    
    try:
        # Restore original file before processing
        # try:
        #     restore_origsol()
        # except Exception as e:
        #     print(f"[WARNING] Failed to restore original file: {e}")
        
        # Build file paths
        cur_sol = os.path.join(cur_repo, file_path)
        cur_t_sol = remap_path(test_path_cargo[file_path], file_path, cur_repo)
        
        # Calculate method count from file_content
        method_len = 0
        if isinstance(file_content, list):
            for cls in file_content:
                if isinstance(cls, dict) and "methods" in cls:
                    for method in cls["methods"]:
                        if method["kind"] not in ["struct", "function", "constructor"]:
                            continue
                        method_len += 1
        
        # Run forge test on original file
        print(f"[INFO] Running forge test...")
        try:
            test_results = run_forge_test(cur_t_sol)
            gas_fees = test_results.get("gas_fees", {})
            test_pass = test_results.get("passed", 0)
            test_fail = test_results.get("failed", 0)
            test_total = test_results.get("total", 0)
        except subprocess.TimeoutExpired:
            print(f"[SKIP] Forge test timeout, skipping file: {file_path}")
            return None
        except Exception as e:
            print(f"[WARNING] Forge test failed: {e}")
            test_results = {"passed": 0, "failed": 0, "total": 0}
            gas_fees = {}
            test_pass = 0
            test_fail = 0
            test_total = 0
        
        # Run slither for vulnerability detection (only if no compile error)
        print(f"[INFO] Running slither analysis...")
        slither_raw = None
        vuln_count = 0
        
        if test_results.get("compile_error"):
            print(f"[SKIP] Skipping slither due to compile error")
            vuln_count = -1
        else:
            try:
                slither_raw = run_slither(cur_sol)
                _, vuln_count = get_slither_feedback_and_count(slither_raw)
            except Exception as e:
                print(f"[WARNING] Slither analysis failed: {e}")
                slither_raw = {"error": str(e)}
                vuln_count = -1
        
        # Save results to database
        tracker.create_or_update_entry(
            file_path=file_path,
            methods=method_len,
            total_files=total_files,
            test_pass=test_pass,
            test_fail=test_fail,
            test_total=test_total,
            gas_fee_json=gas_fees,
            slither_raw=slither_raw,
            vuln_count=vuln_count
        )
        
        print(f"[COMPLETED] File: {file_path} (Pass: {test_pass}, Fail: {test_fail}, Vulns: {vuln_count})")
        return None
        
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
    
    print(f"[INFO] Loaded {len(data)} files from dataset")
    
    # Configuration
    output_dir = "output"
    
    # Initialize progress tracker with BaselineTest table
    tracker = BaselineTest(db_path=os.path.join(path, output_dir, "progress.db"))
    print(f"[INFO] Initialized BaselineTest tracker")
    
    # Load test path mapping
    with open("data/test_map_cargo.pkl", "rb") as f:
        test_path_cargo = pickle.load(f)
    
    # Current repository path
    cur_repo = os.getcwd()
    
    # Get total file count
    total_files = len(data)
    
    # Process each file
    for i, file_path in enumerate(data):
        print(f"\n[{i+1}/{total_files}] Processing: {file_path}")
        result = await process_file_test(
            file_path=file_path,
            tracker=tracker,
            total_files=total_files,
            cur_repo=cur_repo,
            test_path_cargo=test_path_cargo,
            file_content=data[file_path]
        )
        
        if result == "PAUSED":
            print(f"[INFO] Paused processing")
            return result
    
    # Print statistics
    stats = tracker.get_stats()
    print(f"\n[INFO] Testing complete")
    print(f"[STATS] Total files: {stats['total']}")


if __name__ == '__main__':
    asyncio.run(main())
