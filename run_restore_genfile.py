import shutil
from utils.shared_context import shared_context

# Before generating a new Solidity file that differs from the previous one,
# copy back the original Solidity file from the last round to overwrite the Solidity file in current repo.

def restore_origsol():
    orig_sol, cur_t_sol, cur_sol = shared_context.get_all_from_file()

    # copy orig_sol to cur_sol
    if orig_sol and cur_sol:
        shutil.copyfile(orig_sol, cur_sol)
        print(f"Copied {orig_sol} → {cur_sol}")
    else:
        print("Error: shared_context.get_all() did not return valid paths.")

if __name__ == "__main__":
    restore_origsol()
