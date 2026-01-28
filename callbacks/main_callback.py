# Copyright (c) Alibaba, Inc. and its affiliates.
import json
from typing import List

from ms_agent.agent.runtime import Runtime
from ms_agent.callbacks import Callback
from ms_agent.llm.utils import Message
from ms_agent.tools import MyFileSystemTool
from ms_agent.utils import get_logger
from omegaconf import DictConfig

from utils.shared_context import shared_context

logger = get_logger()


class MainCallback(Callback):
    """."""

    def __init__(self, config: DictConfig):
        super().__init__(config)
        self.file_system = MyFileSystemTool(config)

    async def on_task_begin(self, runtime: Runtime, messages: List[Message]):
        await self.file_system.connect()
        #-- modify system message role to developer for gpt5 reasoning model
        if self.config.llm.model.startswith("gpt-5") and messages[0].role == 'system':
            system_message = messages[0]
            system_message.role = "developer"
            system_message.content = "# Juice: 0 !important\n" + system_message.content
        #----

    async def on_tool_call(self, runtime: Runtime, messages: List[Message]):
        """Called before calling tools"""
        if not messages[-1].tool_calls:
            return
        print("|on_tool_call|")
        # if messages[-1].tool_calls and 'read_file' in messages[-1].tool_calls[0]['tool_name']:
        #     arguments = json.loads(messages[-1].tool_calls[0]['arguments'])
        #     cur_sol = shared_context.get_cur_sol_name()
        #     if arguments['path'].split("/")[-1] == cur_sol:
        #         del messages[-1].tool_calls[0]

        # remove dummy list_file
        if messages[-1].tool_calls and 'list_file' in messages[-1].tool_calls[0]['tool_name']:
            tool_calls = []
            for tool_call in messages[-1].tool_calls:
                if not tool_call['id']:
                    continue
                if 'list_file' in tool_call['tool_name'] and not tool_call['arguments']:
                    continue
                tool_calls.append(tool_call)
            messages[-1].tool_calls = tool_calls

    async def after_tool_call(self, runtime: Runtime, messages: List[Message]):
        print("||call demo callback.||")
        if messages[-1].role == 'tool' and 'list_file' in messages[-1].name:
            # remove files contain cur_sol
            cur_sol = shared_context.get_cur_sol_name()
            files = messages[-1].content.split("\n")
            files = [f for f in files if cur_sol not in f]
            messages[-1].content = "\n".join(files)

