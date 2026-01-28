import asyncio
import json
import os
import pickle
import subprocess
import textwrap
from datetime import datetime
from pathlib import Path
from typing import Optional

from openai import OpenAI
import yaml

from llm_utils import create_client
from utils.code_utils import try_extract_code
from utils.llm.anthropic_llm import Anthropic
from utils.path import remap_path
from utils.shared_context import shared_context
from utils.cost_calculator import CostCalculator, check_cost_pause
from utils.forge_utils import run_forge_test
from utils.slither_utils import run_slither, get_slither_feedback_and_count
from db.progress_tracker_agent import ProgressTrackerAgent
from run_restore_genfile import restore_origsol

from utils.feedback_utils import generate_feedback

def ensure_event_loop() -> None:
    """Ensure there is a current asyncio event loop in this thread.
    Some libraries call asyncio.get_event_loop() during construction
    and expect a loop to be set.
    """
    try:
        asyncio.get_running_loop()
        return
    except RuntimeError:
        pass
    try:
        asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)


class OpenAIInteractionLogger:
    """Collect all OpenAI API interactions as message list (QwenAgent format)"""
    
    def __init__(self):
        self.messages = []
        self.pending_request = None
    
    def log_request(self, messages: list[dict], kwargs: dict):
        """Record request messages - store them for pairing with response"""
        # Store the request messages to pair with response later
        self.pending_request = {
            "messages": messages.copy(),
            "kwargs": kwargs.copy()
        }
    
    def log_response(self, response_text: str, usage: dict = None):
        """Log response and build complete message list"""
        if not self.pending_request:
            return
        
        # Add all request messages to our list (system, user messages)
        for msg in self.pending_request["messages"]:
            # Only add if not already in list (avoid duplicates)
            if not self.messages or self.messages[-1] != msg:
                self.messages.append(msg.copy())
        
        # Build assistant response in QwenAgent format
        assistant_msg = {
            "role": "assistant",
            "content": response_text
        }
        
        # Add token usage if available
        if usage:
            prompt_tokens = usage.get("prompt_tokens", 0)
            completion_tokens = usage.get("completion_tokens", 0)
            total_tokens = usage.get("total_tokens", 0)
            # Fallback: check model_extra in usage object (e.g. for some providers)
            if (not prompt_tokens) and (not completion_tokens) and usage is not None:
                model_extra = getattr(usage, "model_extra", None)
                if isinstance(model_extra, dict):
                    prompt_tokens = model_extra.get("input_tokens", 0)
                    completion_tokens = model_extra.get("output_tokens", 0)
                    total_tokens = prompt_tokens + completion_tokens
                else:
                    prompt_tokens = usage.get("input_tokens", 0)
                    completion_tokens = usage.get("output_tokens", 0)
                    total_tokens = prompt_tokens + completion_tokens
                    
            assistant_msg["prompt_tokens"] = prompt_tokens
            assistant_msg["completion_tokens"] = completion_tokens
            assistant_msg["total_tokens"] = total_tokens
        
        self.messages.append(assistant_msg)
        
        # Clear pending request
        self.pending_request = None
    
    def get_messages(self) -> list[dict]:
        """Get collected messages in QwenAgent format"""
        return self.messages


# Global variable to hold the current logger
_interaction_logger = None
_original_achat_completion = None


def _patch_openai_with_logger(logger: OpenAIInteractionLogger):
    """Monkey patch OpenAILLM._achat_completion to log all interactions"""
    global _interaction_logger, _original_achat_completion
    
    # Import here to avoid circular dependency
    from metagpt.provider.openai_api import OpenAILLM
    
    _interaction_logger = logger
    
    # Save original method
    if _original_achat_completion is None:
        _original_achat_completion = OpenAILLM._achat_completion
    
    # Create logged version
    async def logged_achat_completion(self, messages: list[dict], timeout=None):
        from metagpt.const import USE_CONFIG_TIMEOUT
        if timeout is None:
            timeout = USE_CONFIG_TIMEOUT
        
        # Get kwargs that will be sent to API
        kwargs = self._cons_kwargs(messages, timeout=self.get_timeout(timeout))
        
        # Log request
        if _interaction_logger:
            _interaction_logger.log_request(messages, kwargs)
        
        # Call original method
        rsp = await _original_achat_completion(self, messages, timeout)
        
        # Normalize usage format for Anthropic models (convert to OpenAI format)
        # This ensures MetaGPT's _update_costs can extract tokens correctly
        if hasattr(rsp, 'usage') and rsp.usage:
            usage_dict = rsp.usage.model_dump() if hasattr(rsp.usage, 'model_dump') else dict(rsp.usage)
            
            # Check if this is Anthropic format (has input_tokens/output_tokens but not prompt_tokens)
            if 'input_tokens' in usage_dict and 'prompt_tokens' not in usage_dict:
                # Convert Anthropic format to OpenAI format
                usage_dict['prompt_tokens'] = usage_dict.get('input_tokens', 0)
                usage_dict['completion_tokens'] = usage_dict.get('output_tokens', 0)
                usage_dict['total_tokens'] = usage_dict['prompt_tokens'] + usage_dict['completion_tokens']
                
                # Update the rsp.usage object with normalized values
                # This is a bit hacky but necessary for MetaGPT to work
                for key, value in usage_dict.items():
                    if hasattr(rsp.usage, key):
                        setattr(rsp.usage, key, value)
        
        # Log response
        if _interaction_logger:
            response_text = self.get_choice_text(rsp)
            usage = rsp.usage.model_dump() if hasattr(rsp, 'usage') and rsp.usage else {}
            _interaction_logger.log_response(response_text, usage)
        
        return rsp
    
    # Apply patch
    OpenAILLM._achat_completion = logged_achat_completion


def _unpatch_openai():
    """Restore original OpenAILLM._achat_completion"""
    global _original_achat_completion
    
    if _original_achat_completion is not None:
        from metagpt.provider.openai_api import OpenAILLM
        OpenAILLM._achat_completion = _original_achat_completion


def _patch_editor_read_only_sol(target_file_path: Optional[str] = None, repo_root: Optional[str] = None):
    """Monkeypatch metagpt.tools.libs.editor.Editor.read to only allow reading .sol files.

    If the requested read path is not a .sol file or its basename matches target_file_path's
    basename, return an empty FileBlock. Any import/patch failure is caught and logged
    (does not raise).
    """
    try:
        import metagpt.tools.libs.editor as _m_editor

        _m_orig_read = getattr(_m_editor.Editor, "read", None)

        _target_basename = None
        if target_file_path:
            try:
                _target_basename = Path(str(target_file_path)).name.lower()
            except Exception:
                _target_basename = None

        _repo_root_path = None
        if repo_root:
            try:
                _repo_root_path = Path(str(repo_root)).resolve(strict=False)
            except Exception:
                _repo_root_path = None

        if _m_orig_read:
            async def _m_patched_read(self, path):
                try:
                    p_str = str(path)
                except Exception:
                    p_str = path

                try:
                    read_basename = Path(p_str).name.lower()
                except Exception:
                    read_basename = os.path.basename(p_str).lower() if isinstance(p_str, str) else ""

                # Allow reading if the path is a .sol file under repo_root (it's the generated file location)
                allowed_under_repo = False
                try:
                    if _repo_root_path is not None:
                        p_resolved = Path(p_str).resolve(strict=False)
                        try:
                            # Python >=3.9 has is_relative_to, emulate with relative_to
                            p_resolved.relative_to(_repo_root_path)
                            allowed_under_repo = True
                        except Exception:
                            allowed_under_repo = False
                except Exception:
                    allowed_under_repo = False

                # Block non-.sol files, or reads that target the same basename as the file we're generating
                # unless the read path is under repo_root (i.e., it's the generated file location)
                if (not isinstance(p_str, str) or not p_str.lower().endswith('.sol')) or (
                    _target_basename and read_basename == _target_basename and not allowed_under_repo
                ):
                    try:
                        return _m_editor.FileBlock(file_path=str(p_str), block_content="Not allowed to read this file.")
                    except Exception:
                        return ""

                return await _m_orig_read(self, path)

            _m_editor.Editor.read = _m_patched_read

    except Exception as _e:
        # Do not fail hard if patching is not possible in the environment
        print(f"[WARN] Could not patch MetaGPT Editor.read: {_e}")


async def metagpt_generate(
    repo_root: Path,
    full_query: str,
    api_key: str = None,
    base_url: str = None,
    model_name: str = None,
    generation_config: dict = None,
    target_file_path: Optional[str] = None,
) -> list[dict]:
    # Ensure local MetaGPT source is importable when not installed via pip
    import sys
    root_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = root_dir
    agent_meta_path = os.path.join(workspace_root, "agent", "MetaGPT")
    if agent_meta_path not in sys.path and os.path.isdir(agent_meta_path):
        sys.path.insert(0, agent_meta_path)
    
    from metagpt.config2 import config
    from metagpt.context import Context
    from metagpt.roles import (
        Architect,
        DataAnalyst,
        Engineer2,
        ProductManager,
        TeamLeader,
    )
    from metagpt.team import Team

    # Apply a safe monkeypatch so MetaGPT Editor.read cannot read arbitrary files
    # outside of .sol generation. Pass the target file path (repo-relative) so
    # reads that attempt to open the file being generated are also blocked.
    try:
        _patch_editor_read_only_sol(target_file_path, repo_root=str(repo_root) if repo_root is not None else None)
    except Exception:
        # Keep running even if patch fails
        pass

    # Configure MetaGPT's config.llm BEFORE Context/Team creation
    # This is the correct way to pass generation parameters to MetaGPT
    if api_key:
        config.llm.api_key = str(api_key)
    if base_url:
        config.llm.base_url = str(base_url)
    if model_name:
        config.llm.model = str(model_name)
    
    # Inject generation_config parameters into config.llm
    # Note: generation_config might be DictConfig from OmegaConf, not regular dict
    if generation_config and hasattr(generation_config, '__getitem__'):
        # Map common parameters to MetaGPT's LLMConfig fields
        if "temperature" in generation_config:
            config.llm.temperature = generation_config["temperature"]
        if "top_p" in generation_config:
            config.llm.top_p = generation_config["top_p"]
        if "max_completion_tokens" in generation_config:
            config.llm.max_token = generation_config["max_completion_tokens"]
        if "max_tokens" in generation_config:
            config.llm.max_token = generation_config["max_tokens"]
        if "timeout" in generation_config:
            config.llm.timeout = generation_config["timeout"]
        # Add more mappings as needed: frequency_penalty, presence_penalty, etc.
    config.llm.stream = False

    # Update config with project settings
    config.update_via_cli(
        project_path=str(repo_root),
        project_name=repo_root.name,
        inc=False,
        reqa_file="",
        max_auto_summarize_code=0
    )
    
    # CRITICAL: Set workspace.path to control where MetaGPT writes files
    # Without this, MetaGPT will use paths from the 'idea' content
    config.workspace.path = repo_root
    
    # Create interaction logger (in-memory, no file saving)
    interaction_logger = OpenAIInteractionLogger()
    
    # Patch OpenAI API to log all interactions
    _patch_openai_with_logger(interaction_logger)
    
    try:
        # Create context and team
        ctx = Context(config=config)
        company = Team(context=ctx)
        company.hire([
            TeamLeader(),
            ProductManager(),
            Architect(),
            Engineer2(),
            DataAnalyst(),
        ])
        
        # Set investment
        company.invest(3.0)
        
        # Use official API to generate directly into repo_root
        idea = textwrap.dedent(
            f"""
            Implement the software per the following README, generating files directly under: {repo_root}
            Do NOT access or rely on any tests directory.
            README:
            {full_query}
            """
        ).strip()
        
        # Run MetaGPT (history is not used, we return messages from logger)
        await company.run(n_round=5, idea=idea)
        
        # Return collected messages in QwenAgent format
        coding_messages = interaction_logger.get_messages()
        return coding_messages
        
    finally:
        # Always restore original method
        _unpatch_openai()

def load_coding_yaml(config_path: str) -> str:
    """Load system prompt from coding.yaml"""
    with open(config_path, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    return config.get('prompt', {}).get('system', '')


# def create_model_config(model_name: str):
#     """Create model configuration for MetaGPT"""
#     # Create config to extract API settings
#     code_config = Config.from_task("coding.yaml")
#     code_config = choose_model(model_name, code_config)
    
#     # Extract model name
#     model = getattr(code_config.llm, 'model', model_name)
    
#     # Extract generation config (no filtering needed for MetaGPT)
#     generation_config = code_config.get('generation_config', {})

#     # Add stream_options if streaming is enabled (to get usage info)
#     if generation_config.get('stream', False):
#         generation_config['stream_options'] = {'include_usage': True}
    
#     # Set default timeout if not provided (20 minutes)
#     if 'timeout' not in generation_config:
#         generation_config['timeout'] = 3600 # 2400
    
#     return model, generation_config, code_config


async def process_file_generate_code(
    file_path: str,
    file_content: list,
    tracker: ProgressTrackerAgent,
    actual_model: str,
    total_files: int,
    orig_repo: str,
    cur_repo: str,
    test_path_cargo: dict,
    system_prompt: str,
    model: str,
    generation_config: dict,
    cost_calculator: CostCalculator,
    client: OpenAI | Anthropic,
    service_type: str,
    agent_type: str = "metagpt"
):
    # Check if already processed
    existing_entry = tracker.get_entry(file_path, actual_model, agent_type)
    if existing_entry and existing_entry['status'] >= 1:
        print(f"[SKIP] File already processed: {file_path} (model: {actual_model})")
        return None
    
    # Initialize tracking entry
    start_time = datetime.now().isoformat()
    tracker.create_or_update_entry(
        file_path=file_path,
        model_coding=actual_model,
        agent_type=agent_type,
        total_files=total_files,
        status=0,
        model_summary=None,
        start_time=start_time
    )

    # if file_path != "repository/openzeppelin-contracts/contracts/utils/ShortStrings.sol":
    #     return None
    # if file_path != "repository/openzeppelin-contracts/contracts/utils/SlotDerivation.sol":
    #     return None
    # if file_path == "repository/openzeppelin-contracts/contracts/utils/Packing.sol":
    #     return None

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
    
    # Build query
    sol_version = file_content[0]['methods'][0]["sol_version"][0]
    # file_class = file_content[0]["class"]
    file_name = cur_sol.split("/")[-1]
    # proj_repo = os.path.join(orig_repo, "/".join(file_path.split("/")[0:2]))
    proj_repo = os.path.join(cur_repo, "/".join(file_path.split("/")[0:2]))
    query_head = f"given repo: {proj_repo}\nfile name: {file_name}\n\n{sol_version}"
    
    method_len = 0

    query = ""
    for cls in file_content:
        file_class = f"\n{cls['kind']} {cls['identifier']}\n"
        query += file_class
        
        for method in cls["methods"]:
            if method["kind"] not in ["struct", "function", "constructor"]:
                continue
            method_len += 1

            full_signature = method["full_signature"].strip()
            human_labeled_comment = method["human_labeled_comment"].strip()
            query = f"""{query}
{human_labeled_comment}
{full_signature}
"""
    
    # Calculate token count
    # encoding = tiktoken.encoding_for_model("gpt-3.5-turbo")
    # tokens = encoding.encode(query)
    # print(f'{len(query)/1024:.1f} KB; tokens: {len(tokens)}')
    
    # Combine query
    full_query = f"{query_head}\n{query}"
    # tokens = encoding.encode(full_query)
    # print(f'Full query: {len(full_query)/1024:.1f} KB; tokens: {len(tokens)}')

    # Call MetaGPT to generate code files
    print(f"[INFO] Calling MetaGPT generator...")
    # initialize token/cost counters (must exist before any += operations)
    prompt_tokens = 0
    completion_tokens = 0
    total_cost = 0.0
    try:
        # Use a temporary output directory similar to DeepCode flow
        workspace_path = os.path.dirname(os.path.abspath(__file__))
        metagpt_output_dir = Path(workspace_path) / "metagpt_temp"
        metagpt_output_dir.mkdir(parents=True, exist_ok=True)

        # Build query with context (system prompt + file query)
        full_query_with_context = f"{system_prompt}\n\n{full_query}"

        # Extract API key and base URL from client
        if service_type == 'anthropic':
            api_key = client.client.api_key
            base_url = str(client.client.base_url)
        else:
            api_key = client.api_key
            base_url = str(client.base_url)

        # Run MetaGPT repo generation (async function)
        # It will generate files under metagpt_output_dir
        # Returns coding_messages in QwenAgent format
        coding_messages = await metagpt_generate(
            metagpt_output_dir,
            full_query_with_context,
            api_key=api_key,
            base_url=base_url,
            model_name=model,
            generation_config=generation_config,
            target_file_path=file_path,
        )

        # After generation, try to locate the target Solidity file
        # MetaGPT might generate files in different locations:
        # 1. In metagpt_output_dir (expected)
        # 2. Directly at cur_sol path (if it parsed the path from full_query)
        # 3. Somewhere else in metagpt_output_dir (search for .sol files)
        
        generated_file = None
        
        # First, check the expected location
        expected_file = metagpt_output_dir / file_name
        if expected_file.exists():
            generated_file = expected_file
            print(f"[INFO] Found generated file at expected location: {expected_file}")
        
        # Fallback 1: Check if MetaGPT generated directly to cur_sol
        if not generated_file and Path(cur_sol).exists():
            generated_file = Path(cur_sol)
            print(f"[INFO] Found generated file at cur_sol: {cur_sol}")
        
        # Fallback 2: Search for any .sol file in output directory
        if not generated_file:
            sol_files = [f for f in metagpt_output_dir.glob("**/*.sol") if f.stat().st_size > 0]
            if sol_files:
                generated_file = sol_files[0]
                print(f"[INFO] Found .sol file in output dir: {generated_file}")
        
        if not generated_file: # extract from coding_messages assistant message with reversed order
            for msg in reversed(coding_messages):
                if not isinstance(msg, dict):
                    continue
                if msg["role"] == "assistant":
                    content = msg["content"]
                    # extract using code_utils.extract_code_blocks
                    code_block = try_extract_code(content)
                    if code_block and code_block.strip().startswith("// SPDX-License-Identifier: MIT"):
                        generated_file = expected_file
                        with open(generated_file, "w", encoding="utf-8") as f:
                            f.write(code_block)
                        print(f"[INFO] Extracted Solidity code from assistant message")
                    elif code_block and code_block.strip().startswith("```solidity"):
                        generated_file = expected_file
                        with open(generated_file, "w", encoding="utf-8") as f:
                            f.write(code_block)
                        print(f"[INFO] Extracted Solidity code from assistant message")
                if generated_file:
                    break
        
        # If still not found, give up
        if not generated_file:
            print(f"[WARNING] No Solidity file generated by MetaGPT")
            print(f"[WARNING] Checked locations:")
            print(f"  - Expected: {metagpt_output_dir / file_name}")
            print(f"  - cur_sol: {cur_sol}")
            print(f"  - All .sol in {metagpt_output_dir}: {list(metagpt_output_dir.glob('**/*.sol'))}")
            # Clean up temp directory
            if metagpt_output_dir.exists():
                try:
                    import shutil
                    shutil.rmtree(metagpt_output_dir)
                except Exception:
                    pass
            return None

        with open(generated_file, "r", encoding="utf-8") as f:
            code_block = f.read()

        # Clean up temp directory
        if metagpt_output_dir.exists():
            try:
                import shutil
                shutil.rmtree(metagpt_output_dir)
            except Exception:
                pass

        if not code_block:
            print(f"[WARNING] No code generated by MetaGPT")
            return None
        
        # Remove file path from first line if present
        # MetaGPT might add the file path as the first line
        lines = code_block.split('\n')
        if lines and (str(generated_file) in lines[0] or '.sol' in lines[0] and '/' in lines[0]):
            # First line looks like a file path, remove it
            code_block = '\n'.join(lines[1:]).strip()
            print(f"[INFO] Removed file path from first line of generated code")

        print(f"[INFO] MetaGPT generated code ({len(code_block)} chars)")

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
        
        coding_messages += [{
            "role": "user",
            "content": feedback_content
        }]
        
        g_prompt, g_completion, g_cost = cost_calculator.extract_tokens_from_messages(coding_messages, actual_model)
        prompt_tokens += g_prompt
        completion_tokens += g_completion
        total_cost += g_cost

        # Mark as completed
        end_time = datetime.now().isoformat()
        tracker.mark_completed(
            file_path=file_path,
            methods=method_len,
            model_coding=actual_model,
            agent_type=agent_type,
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
    
    # Check cost threshold once at startup
    if check_cost_pause(cost_calculator, tracker, table_name="progress_tracker_agent"):
        return "PAUSED_DUE_TO_COST"
    

async def main():
    """Main execution function"""
    path = os.path.dirname(os.path.abspath(__file__))
    dataset_path = os.path.join(path, 'data/dataset.json')
    
    # Load dataset
    with open(dataset_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # Configuration
    code_agent_config = os.path.join(path, "coding.yaml")
    output_dir = "output"
    
    # Load system prompt
    system_prompt = load_coding_yaml(code_agent_config)
    print(f"[INFO] Loaded system prompt from {code_agent_config}")
    
    # Model-independent initialization (do once)
    # Initialize cost calculator
    cost_calculator = CostCalculator(price_file="data/price.json")
    
    # Initialize progress tracker with agent table
    tracker = ProgressTrackerAgent(db_path=os.path.join(path, output_dir, "progress.db"))
    
    # Load test path mapping
    with open("data/test_map_cargo.pkl", "rb") as f:
        test_path_cargo = pickle.load(f)
    
    # Repository paths
    orig_repo = os.environ["ORIG_REPO"]
    cur_repo = os.getcwd()
    
    # Get total file count
    total_files = len(data)
    
    # Check cost threshold once at startup
    if check_cost_pause(cost_calculator, tracker, table_name="progress_tracker_agent"):
        return "PAUSED_DUE_TO_COST"
    
    
    # Models to process
    # models = ["gpt-5-mini"]#"qwen3-coder_30b", "gpt-5-mini", "claude-sonnet-4-5", "deepseek-v3-1-vol"]
    models = ["claude-sonnet-4-5", "gpt-5.1", "gpt-5-mini"] # "gpt-5.1"
    
    # Process each model
    for model_name in models:
        print(f"\n{'='*80}")
        print(f"[INFO] Processing with model: {model_name}")
        print(f"{'='*80}\n")
        
        # Create OpenAI client for this model
        try:
            # model, generation_config, code_config = create_model_config(model_name)

            platform = "openai"
            client, model, generation_config, service_type = create_client(model_name, stream=False, platform=platform)
        except Exception as e:
            print(f"[ERROR] Failed to initialize model {model_name}: {e}")
            continue
        
        # Get actual model name for tracking
        actual_model = model
        print(f"[INFO] Tracking with model name: {actual_model}")
        
        # Process each file with this model
        for i, file_path in enumerate(data):
            file_content = data[file_path]
            result = await process_file_generate_code(
                file_path=file_path,
                file_content=file_content,
                tracker=tracker,
                actual_model=actual_model,
                total_files=total_files,
                orig_repo=orig_repo,
                cur_repo=cur_repo,
                test_path_cargo=test_path_cargo,
                system_prompt=system_prompt,
                model=model,
                generation_config=generation_config,
                cost_calculator=cost_calculator,
                client=client,
                service_type=service_type,
            )
            if result == "PAUSED_DUE_TO_COST":
                print(f"[INFO] Paused during processing model {model_name}")
                return result
            if result is not None and i > 0 and i % 5 == 0:
                await asyncio.sleep(20)
        
        print(f"\n[INFO] Completed processing all files with model: {model_name}\n")

    
    print("[INFO] Processing complete")


if __name__ == '__main__':
    asyncio.run(main())
