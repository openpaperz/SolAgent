"""
Custom MetaGPT tools for Solidity code generation.
Provides read_file and list_files tools with filtering logic.
"""
import os
from metagpt.tools.tool_registry import register_tool
from utils.shared_context import shared_context


@register_tool()
async def read_file(path: str) -> str:
    """Read the content of a Solidity file.

    Args:
        path: The relative file path to read, a prefix dir will be automatically concatenated.

    Returns:
        The file content or error message.
    """
    orig_sol_repo = await shared_context.get("orig_sol_repo")

    if not path:
        return f'Read file <{path or "empty path"}> failed, error: empty path.'
    
    # Convert to absolute path if relative
    if not os.path.isabs(path):
        path = os.path.join(orig_sol_repo, path)
    
    try:
        reading_file_name = path.split("/")[-1]
        
        # Get context to check restrictions
        orig_sol, cur_t_sol, cur_sol = shared_context.get_all()
        orig_sol_name = orig_sol.split('/')[-1]
        
        # Check if trying to read the original solution file
        if reading_file_name == orig_sol_name:
            return f'Read file <{path}> failed, error: Reading the original solution file is not allowed.'
        
        # Check if trying to read test files
        if reading_file_name.endswith(".t.sol"):
            return f'Read file <{path}> failed, error: Reading the test file is not allowed.'
        
        # Read the file
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        return f'Read file <{path}> failed, error: ' + str(e)


@register_tool()
async def list_files(path: str = None) -> str:
    """List all Solidity files in a directory.

    Args:
        path: The relative path to traverse, a prefix dir will be automatically concatenated.

    Returns:
        The file names concatenated as a string, one per line.
    """
    orig_sol_repo = await shared_context.get("orig_sol_repo")

    if not path:
        return f'List files of <{path or "root path"}> failed, error: empty path.'
    
    # Convert to absolute path if relative
    if not os.path.isabs(path):
        path = os.path.join(orig_sol_repo, path)
    
    file_paths = []
    try:
        # Get context to check restrictions
        orig_sol, cur_t_sol, cur_sol = shared_context.get_all()
        orig_sol_name = orig_sol.split('/')[-1]

        for root, dirs, files in os.walk(path):
            # Filter out hidden directories and specific directories
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['node_modules', 'dist', 'test', 'out']]

            for file in files:
                # Skip test files
                if file.endswith(".t.sol"):
                    continue
                
                # Skip the original solution file
                if file == orig_sol_name:
                    continue
                
                # Only include .sol files
                if not file.endswith('.sol'):
                    continue

                absolute_path = os.path.join(root, file)
                relative_path = os.path.relpath(absolute_path, path)
                file_paths.append(relative_path)
        
        return '\n'.join(file_paths)
    except Exception as e:
        return f'List files of <{path or "root path"}> failed, error: ' + str(e)
