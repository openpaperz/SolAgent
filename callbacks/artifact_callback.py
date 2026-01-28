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


class ArtifactCallback(Callback):
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
            # messages.pop(-1)
            return
        
        # Get the last assistant message content
        last_assistant_content = None
        for m in reversed(messages):
            if m.role == 'assistant' and m.content:
                last_assistant_content = m.content
                break
        
        if not last_assistant_content:
            return
        
        orig_sol, cur_t_sol, cur_sol = shared_context.get_all()
        target_filename = cur_sol.split("/")[-1]

        # content = '\n'.join([m.content for m in messages[2:]])
        content = last_assistant_content
        all_files, _ = extract_code_blocks(content, target_filename=target_filename)
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

        # move new_sol to cur_sol, for testing
        orig_sol, cur_t_sol, cur_sol = shared_context.get_all()
        new_sol = os.path.join(self.config["output_dir"], cur_sol.split("/")[-1])
        if os.path.exists(new_sol):
            try:
                shutil.move(new_sol, cur_sol)
            except shutil.Error:
                pass
