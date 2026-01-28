from asyncio import subprocess
import json
import os
import pickle

import dotenv
from utils.feedback_utils import generate_feedback
from utils.forge_utils import run_forge_test
from utils.slither_utils import get_slither_feedback_and_count, run_slither

from dotenv import load_dotenv

load_dotenv()

def run_feedback(cur_sol, cur_t_sol, file_path: str):
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
    
    print("Gas Fees:")
    print(json.dumps(gas_fees))
    print("Slither Raw Output:")
    print(json.dumps(slither_raw))
    print(f"Vulnerability Count: {vuln_count}")
    print("Feedback Content:")
    print(json.dumps(feedback_content))


def run_slither_feedback(file_path: str):
    try:
        slither_raw = run_slither(file_path)
        slither_feedback, vuln_count = get_slither_feedback_and_count(slither_raw)
    except Exception as e:
        print(f"[WARNING] Slither analysis failed: {e}")
        slither_raw = {"error": str(e)}
        slither_feedback = None
        vuln_count = -1

    # Generate feedback from test results and slither analysis
    feedback_content, _ = generate_feedback({}, slither_feedback)

    print("Slither Raw Output:")
    print(json.dumps(slither_raw))
    print(f"Vulnerability Count: {vuln_count}")
    print("Feedback Content:")
    print(feedback_content)

if __name__ == '__main__':
    path = os.path.dirname(os.path.abspath(__file__))
    file_path = 'repository/openzeppelin-contracts/contracts/utils/math/Math.sol'

    # Load test path mapping
    with open("data/test_map_cargo.pkl", "rb") as f:
        test_path_cargo = pickle.load(f)

    cur_sol = os.path.join(path, file_path)
    cur_t_sol = os.path.join(path, test_path_cargo.get(file_path, ""))

    # run_slither_feedback(cur_sol)

    run_feedback(cur_sol, cur_t_sol, file_path)

    