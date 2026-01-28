import json
import os
import sys
import asyncio
from datetime import datetime
import shutil

import yaml
import pyperclip

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


def load_coding_yaml(config_path: str) -> str:
    """Load system prompt from coding.yaml"""
    with open(config_path, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    return config.get('prompt', {}).get('system', '')

async def process_file_generate_code(
    file_path: str,
    file_content: list,
    orig_repo: str,
    system_prompt: str,
    model: str
):
    print(f"[PROCESSING] File: {file_path} (classes: {len(file_content)})")
    
    # Build query
    sol_version = file_content[0]['methods'][0]["sol_version"][0]
    file_name = file_path.split("/")[-1]
    proj_repo = os.path.join(orig_repo, "/".join(file_path.split("/")[0:2]))
    query_head = f"given repo: {proj_repo}\nfile name: {file_name}\n\n{sol_version}"

    query = ""
    for cls in file_content:
        file_class = f"\n{cls['kind']} {cls['identifier']}\n"
        query += file_class
        
        for method in cls["methods"]:
            if method["kind"] not in ["struct", "function", "constructor"]:
                continue

            full_signature = method["full_signature"].strip()
            human_labeled_comment = method["human_labeled_comment"].strip()
            query = f"""{query}
{human_labeled_comment}
{full_signature}
"""

    # Combine query
    full_query = f"{query_head}\n{query}"
    
    full_system_query = f"{system_prompt}\n\n{full_query}"

    try:
        # write the combined system+query into workspace/plan.txt so we can inspect it
        workspace_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'workspace')
        os.makedirs(workspace_dir, exist_ok=True)
        plan_path = os.path.join(workspace_dir, 'plan.txt')
        with open(plan_path, 'w', encoding='utf-8') as wf:
            wf.write(full_system_query)

        # Clean up any existing .sol files in workspace before creating the new target
        try:
            for existing in os.listdir(workspace_dir):
                if existing.endswith('.sol'):
                    fp = os.path.join(workspace_dir, existing)
                    try:
                        os.remove(fp)
                    except Exception as e:
                        print(f"[WARN] Failed to remove {fp}: {e}")
        except Exception as e:
            print(f"[WARN] Could not clean workspace .sol files: {e}")

        # Ensure the target file exists in workspace (create empty file if missing)
        target_path = os.path.join(workspace_dir, file_name)
        try:
            # 'a' will create the file if it doesn't exist, then close immediately
            open(target_path, 'a').close()
        except Exception as e:
            print(f"[WARN] Failed to create workspace file {target_path}: {e}")

        query_clipboard = f"@workspace Create a file named {file_name} and Implement the plan in plan.txt and write the content to {file_name}."
        pyperclip.copy(query_clipboard)

        print(query_clipboard)
        print(f"[COMPLETED] File: {file_path}")

        # If a file named `file_name` exists in workspace, move it to result/{model}/
        move_success = False
        try:
            source_file = os.path.join(workspace_dir, file_name)
            if os.path.exists(source_file):
                dest_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'result', model)
                os.makedirs(dest_dir, exist_ok=True)
                dest_path = os.path.join(dest_dir, file_name)
                try:
                    shutil.move(source_file, dest_path)
                    print(f"[MOVED] {source_file} -> {dest_path}")
                    move_success = True
                except Exception as e:
                    print(f"[WARN] Failed to move {source_file} to {dest_path}: {e}")
            else:
                # No source file to move; treat as not moved
                move_success = False
        except Exception as e:
            print(f"[WARN] Error while attempting to move workspace file: {e}")

        return move_success
    except Exception as e:
        print(f"[ERROR] Failed to process {file_path}: {e}")
        import traceback
        traceback.print_exc()
        return False
    

async def main():
    """Main execution function"""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(current_dir)
    
    # Try to find dataset.json in current dir first, then parent dir
    dataset_path = os.path.join(current_dir, 'data/dataset.json')
    if not os.path.exists(dataset_path):
        dataset_path = os.path.join(parent_dir, 'data/dataset.json')
    
    print(f"[DEBUG] Looking for dataset at: {dataset_path}")
    
    # Load dataset
    with open(dataset_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # Configuration - also try parent dir
    code_agent_config = os.path.join(current_dir, "coding.yaml")
    if not os.path.exists(code_agent_config):
        code_agent_config = os.path.join(parent_dir, "coding.yaml")
    
    # Load system prompt
    system_prompt = load_coding_yaml(code_agent_config)
    print(f"[INFO] Loaded system prompt from {code_agent_config}")
    
    # Get original repo path from environment
    orig_repo = os.environ.get("ORIG_REPO", "")
    
    # Process each file
    models = ["gpt-5.1"] #"claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"
    for model in models:
        for file_path in data:
            # If the file already exists in result/{model}/, skip processing and don't record it
            file_name = file_path.split("/")[-1]
            result_file_path = os.path.join(current_dir, 'result', model, file_name)
            if os.path.exists(result_file_path):
                print(f"[SKIP] Already exists in result for model {model}: {result_file_path}")
                continue
            # (no completed.txt check) build entry string for logging
            entry = f"{model}: {file_path}"
            
            file_content = data[file_path]
            moved = await process_file_generate_code(
                file_path=file_path,
                file_content=file_content,
                orig_repo=orig_repo,
                system_prompt=system_prompt,
                model=model
            )

            # If moved successfully, we're done; if not, leave artifacts for inspection
            if moved:
                print(f"[OK] Processed and moved: {entry}")
            else:
                print(f"[INFO] Move not successful for {entry}; leaving workspace file (if any) for inspection")
    
    print("[INFO] Processing complete")


if __name__ == '__main__':
    asyncio.run(main())

