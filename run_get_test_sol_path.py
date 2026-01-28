
import pickle
import os
from dotenv import load_dotenv

from utils.path import remap_path

load_dotenv()

if __name__ == "__main__":
    path = os.path.dirname(os.path.abspath(__file__))

    with open(os.path.join(path, "data/test_map_cargo.pkl"), "rb") as f:
        test_path_cargo = pickle.load(f)
    
    file_path = 'repository/openzeppelin-foundry-upgrades/lib/openzeppelin-foundry-upgrades/src/internal/Core.sol'

    orig_repo = os.environ["ORIG_REPO"]
    if not os.path.isabs(orig_repo):
        orig_repo = os.path.join(path, orig_repo)
    cur_repo = path

    orig_sol_repo = os.path.join(orig_repo, "/".join(file_path.split("/")[0:2]))
    orig_sol = os.path.join(orig_repo, file_path)
    cur_sol = remap_path(orig_sol, orig_repo, cur_repo)
    cur_t_sol = remap_path(test_path_cargo[file_path], orig_repo, cur_repo)

    print(f"{file_path}")
    print(f"Test sol path: {test_path_cargo[file_path]}")
    print(f"Original sol path: {orig_sol}")
    print(f"Current sol path: {cur_sol}")
    print(f"Current test sol path: {cur_t_sol}")

    for k, v in test_path_cargo.items():
        if 'test-profiles' in v:
            print(f"{k}: {v}")