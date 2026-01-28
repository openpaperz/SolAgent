import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.feedback_utils import generate_feedback
from utils.forge_utils import run_forge_test


if __name__ == "__main__":
    test_file = '/Users/chenwei/GolandProjects/solagent/agent-smart/repository/openzeppelin-contracts/test/utils/cryptography/P256.t.sol'

    result = run_forge_test(test_file)
    feedback_content, _ = generate_feedback(result, None)
    print(feedback_content)