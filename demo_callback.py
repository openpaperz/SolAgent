# Copyright (c) Alibaba, Inc. and its affiliates.
from typing import List

from ms_agent.agent.runtime import Runtime
from ms_agent.callbacks import Callback
from ms_agent.llm.utils import Message
from ms_agent.tools import FileSystemTool
from ms_agent.utils import get_logger
from omegaconf import DictConfig

logger = get_logger()


class DemoCallback(Callback):
    """."""

    def __init__(self, config: DictConfig):
        super().__init__(config)
        self.file_system = FileSystemTool(config)
        self.callback_dataf = config.get("callback_dataf")
        self.counter = 0

    async def on_task_begin(self, runtime: Runtime, messages: List[Message]):
        await self.file_system.connect()

    async def on_tool_call(self, runtime: Runtime, messages: List[Message]):
        """Called before calling tools"""
        print("|on_tool_call|")

    async def after_tool_call(self, runtime: Runtime, messages: List[Message]):
        if messages[-1].tool_calls or messages[-1].role in ('tool', 'user'):
            return

        print("||call demo callback.||")
        # print(messages)

    async def on_generate_response(self, runtime: Runtime, messages: List[Message]):
        # print(messages)
        pass

    async def after_generate_response(self, runtime: Runtime,
                                      messages: List[Message]):
        self.counter += 1
        print(f"{self.counter}|should_stop={runtime.should_stop}")
        # print(messages)
