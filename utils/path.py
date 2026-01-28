from pathlib import Path
import os

# Replace the original repository address orig_repo in file_path with replace_repo
def remap_path(file_path: str, orig_repo: str, replace_repo: str) -> str:
    """
    Replace the prefix `orig_repo` in `file_path` with `replace_repo`,
    preserving the relative subpath.

    Args:
        file_path (str): The original absolute or relative file path.
        orig_repo (str): The original repository root directory.
        replace_repo (str): The new repository root directory.

    Returns:
        str: The remapped file path as a string.
    """
    orig_repo = Path(orig_repo).resolve()
    replace_repo = Path(replace_repo).resolve()

    if str(file_path).startswith(str(orig_repo)):
        file_path = Path(file_path).resolve()
        new_file_path = replace_repo / file_path.relative_to(orig_repo)
    else:
        new_file_path = os.path.join(replace_repo, file_path)

    return str(new_file_path)
