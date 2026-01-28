# Copyright (c) Alibaba, Inc. and its affiliates.
import os
import shutil
from typing import List

from omegaconf import DictConfig

from file_parser import extract_code_blocks
from ms_agent.agent.runtime import Runtime
from ms_agent.callbacks import Callback
from ms_agent.llm.utils import Message
from ms_agent.tools.myfilesystem_tool import MyFileSystemTool
from ms_agent.utils import get_logger
from utils.shared_context import shared_context

logger = get_logger()


class ArtifactPatchCallback(Callback):
    """Save the output code to local disk.
    """

    def __init__(self, config: DictConfig):
        super().__init__(config)
        self.file_system = MyFileSystemTool(config)

    async def on_task_begin(self, runtime: Runtime, messages: List[Message]):
        await self.file_system.connect()

    async def on_generate_response(self, runtime: Runtime, messages: List[Message]):
        for message in messages:
            if message.role == 'assistant' and message.tool_calls and not message.content:
                # Claude seems does not allow empty content
                message.content = 'I should do a tool calling to continue:\n'

    async def on_tool_call(self, runtime: Runtime, messages: List[Message]):
        if messages[-1].tool_calls or messages[-1].role == 'tool':
            return
        await self.file_system.create_directory() #
        if messages[-1].role == 'assistant' and not messages[-1].content: #
            messages.pop(-1)
            return
        
        # Get the last assistant message content
        last_assistant_content = None
        for m in reversed(messages):
            if m.role == 'assistant' and m.content:
                last_assistant_content = m.content
                break
        
        if not last_assistant_content:
            return
        
        # Check if content is a patch format (starts with --- or @@)
        is_patch = last_assistant_content.strip().startswith(('---', '@@', 'diff'))
        
        if is_patch:
            # Apply patch directly to cur_sol
            orig_sol, cur_t_sol, cur_sol = shared_context.get_all()
            
            if not os.path.exists(cur_sol):
                logger.warning(f"Target file does not exist: {cur_sol}")
                return
            
            # Apply patch using context-based matching (more robust than line numbers)
            try:
                import re
                
                # Backup cur_sol to output/temp.sol before patching (ensure absolute path)
                output_dir = self.config["output_dir"]
                if not os.path.isabs(output_dir):
                    output_dir = os.path.join(os.getcwd(), output_dir)
                temp_backup = os.path.join(output_dir, "temp.sol")
                shutil.copy2(cur_sol, temp_backup)
                logger.info(f"Backed up {cur_sol} to {temp_backup}")
                
                # Read current file content
                with open(cur_sol, 'r') as f:
                    original_lines = f.readlines()
                
                patch_content = last_assistant_content
                
                # Parse patch content manually for context-based matching
                # Split into hunks
                hunks = []
                current_hunk = {'context_before': [], 'remove_lines': [], 'add_lines': [], 'context_after': []}
                in_hunk = False
                
                for line in patch_content.split('\n'):
                    line = line.rstrip()
                    
                    # Skip file headers
                    if line.startswith('---') or line.startswith('+++'):
                        continue
                    
                    # Start of new hunk
                    if line.startswith('@@'):
                        if in_hunk and (current_hunk['remove_lines'] or current_hunk['add_lines']):
                            hunks.append(current_hunk)
                        current_hunk = {'context_before': [], 'remove_lines': [], 'add_lines': [], 'context_after': []}
                        in_hunk = True
                        continue
                    
                    if not in_hunk:
                        continue
                    
                    # Parse hunk lines
                    if line.startswith('-'):
                        current_hunk['remove_lines'].append(line[1:])
                    elif line.startswith('+'):
                        current_hunk['add_lines'].append(line[1:])
                    elif line.startswith(' ') or (not line.startswith(('+', '-')) and line):
                        # Context line
                        context_line = line[1:] if line.startswith(' ') else line
                        if not current_hunk['remove_lines'] and not current_hunk['add_lines']:
                            current_hunk['context_before'].append(context_line)
                        else:
                            current_hunk['context_after'].append(context_line)
                
                # Add last hunk
                if in_hunk and (current_hunk['remove_lines'] or current_hunk['add_lines']):
                    hunks.append(current_hunk)
                
                # Apply hunks by context matching
                modified_lines = original_lines.copy()
                applied_count = 0
                
                for hunk in hunks:
                    # Find matching position by context
                    found = False
                    for i in range(len(modified_lines)):
                        # Try to match context_before
                        match = True
                        for j, ctx in enumerate(hunk['context_before']):
                            if i + j >= len(modified_lines) or ctx.strip() != modified_lines[i + j].strip():
                                match = False
                                break
                        
                        if not match:
                            continue
                        
                        # Verify remove_lines match
                        start_idx = i + len(hunk['context_before'])
                        for j, rem in enumerate(hunk['remove_lines']):
                            if start_idx + j >= len(modified_lines) or rem.strip() != modified_lines[start_idx + j].strip():
                                match = False
                                break
                        
                        if match:
                            # Apply patch: remove old lines and insert new ones
                            end_idx = start_idx + len(hunk['remove_lines'])
                            new_lines = [line + '\n' for line in hunk['add_lines']]
                            modified_lines[start_idx:end_idx] = new_lines
                            applied_count += 1
                            found = True
                            break
                    
                    if not found:
                        logger.warning(f"Could not find match for hunk in {cur_sol}")
                
                # Write modified content back
                if applied_count > 0:
                    with open(cur_sol, 'w') as f:
                        f.writelines(modified_lines)
                    feedback = f"Patch applied successfully to {os.path.basename(cur_sol)} ({applied_count} hunks)"
                    logger.info(feedback)
                    messages.append(Message(role='user', content=feedback))
                else:
                    error_msg = f"Patch failed: no hunks could be applied to {os.path.basename(cur_sol)}"
                    logger.error(error_msg)
                    messages.append(Message(role='user', content=error_msg))
                    
            except Exception as e:
                logger.error(f"Error applying patch: {e}")
                messages.append(Message(role='user', content=f"Error applying patch: {e}"))
        else:
            # Original behavior: extract code blocks and write files
            all_files, _ = extract_code_blocks(last_assistant_content)
            if not all_files:
                return
            
            # Deduplicate files by filename (keep last occurrence)
            tmp = {}
            for f in all_files:
                tmp[f['filename']] = f['code']
            all_files = []
            for filename, code in tmp.items():
                all_files.append({'filename': filename, 'code': code.strip()})

            results = []
            for f in all_files:
                result = await self.file_system.write_file(f['filename'], f['code'])
                results.append(result)

            r = '\n'.join(results)
            if len(r) > 0:
                messages.append(Message(role='user', content=r))

            # Move new_sol to cur_sol for testing
            orig_sol, cur_t_sol, cur_sol = shared_context.get_all()
            new_sol = os.path.join(self.config["output_dir"], cur_sol.split("/")[-1])
            if os.path.exists(new_sol):
                try:
                    shutil.move(new_sol, cur_sol)
                except shutil.Error:
                    pass
