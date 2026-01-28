#!/usr/bin/env python3
"""
Data Processing Module (DB Version)
Read data from SQLite progress table and generate SFT training dataset.
"""

import json
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional, Iterable
import logging
from copy import copy
import yaml


# Ensure can run from z0train directory: add repository root to sys.path
CURRENT_DIR = Path(__file__).resolve().parent
REPO_ROOT = CURRENT_DIR.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.llm.utils import Tool

from db.progress_tracker import ProgressTracker
from db.progress_tracker_summary import ProgressTrackerSummary

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


DEFAULT_MODEL_WHITELIST = ["gpt-5.1", "claude-sonnet-4-5", "gpt-5-mini"]
JUICE_PREFIX = "# Juice: 0 !important\n"




class DataProcessor:
    """Process agentic coder training data (read from progress DB)"""

    def __init__(
        self,
        db_path: str = "output/progress.db",
        use_summary: bool = False,
        status_filter: Optional[int] = 1,
        model_whitelist: Optional[List[str]] = None,
    ):
        self.db_path = db_path
        self.status_filter = status_filter
        self.model_whitelist = set(model_whitelist or DEFAULT_MODEL_WHITELIST)
        tracker_cls = ProgressTrackerSummary if use_summary else ProgressTracker
        self.tracker = tracker_cls(db_path=db_path)
        self.coding_system_prompt = self._load_coding_system_prompt()
        
        self._exclude_functions = ['create_directory', 'write_file']

    def _load_coding_system_prompt(self) -> str:
        """Read system prompt from coding.yaml; return empty string and log if missing."""
        yaml_path = REPO_ROOT / "coding.yaml"
        if not yaml_path.exists():
            logger.warning("coding.yaml not found, system prompt left empty")
            return ""
        try:
            with open(yaml_path, 'r', encoding='utf-8') as f:
                data = yaml.safe_load(f) or {}
            return data.get("prompt", {}).get("system", "") or ""
        except Exception as exc:
            logger.warning(f"Failed to read coding.yaml: {exc}; system prompt left empty")
            return ""
    
    def _get_tools(self):
        tools = {
            'myfile_system': [
                Tool(
                    tool_name='create_directory',
                    server_name='myfile_system',
                    description='Create a directory',
                    parameters={
                        'type': 'object',
                        'properties': {
                            'path': {
                                'type':
                                    'string',
                                'description':
                                    'The relative path of the directory to create',
                            }
                        },
                        'required': ['path'],
                        'additionalProperties': False
                    }),
                Tool(
                    tool_name='write_file',
                    server_name='myfile_system',
                    description='Write content into a file',
                    parameters={
                        'type': 'object',
                        'properties': {
                            'path': {
                                'type': 'string',
                                'description': 'The relative path of the file',
                            },
                            'content': {
                                'type': 'string',
                                'description': 'The content of the file',
                            },
                        },
                        'required': ['path', 'content'],
                        'additionalProperties': False
                    }),
                Tool(
                    tool_name='read_file',
                    server_name='myfile_system',
                    description='Read the content of a file',
                    parameters={
                        'type': 'object',
                        'properties': {
                            'path': {
                                'type': 'string',
                                'description': 'The relative path of the file',
                            }
                        },
                        'required': ['path'],
                        'additionalProperties': False
                    }),
                Tool(
                    tool_name='list_files',
                    server_name='myfile_system',
                    description='List all files in a directory',
                    parameters={
                        'type': 'object',
                        'properties': {
                            'path': {
                                'type':
                                    'string',
                                'description':
                                    "The path to list files, if path is None or '' or not given, "
                                    'the root dir will be used as path.',
                            }
                        },
                        'required': [],
                        'additionalProperties': False
                    }),
            ]
        }
        return {
            'myfile_system': [
                t for t in tools['myfile_system']
                if t['tool_name'] not in self._exclude_functions
            ]
        }

    @staticmethod
    def _reindex_tools(
        *tool_maps: Iterable[Dict[str, List[dict]]],
        max_tool_name_len: int = 64,
        tool_splitter: str = '---'
    ) -> List[dict]:
        tool_index: Dict[str, dict] = {}
        for tool_map in tool_maps:
            if not tool_map:
                continue
            for server_name, tool_list in tool_map.items():
                for tool in tool_list:
                    if 'tool_name' not in tool:
                        raise ValueError(f"tool entry missing 'tool_name': {tool!r}")
                    orig_tool_name = tool['tool_name']
                    # compute allowed server name length so that total key <= max_tool_name_len
                    max_server_len = max_tool_name_len - len(orig_tool_name) - len(tool_splitter)
                    if max_server_len < 0:
                        # if tool name alone exceeds limit, we still create a key using truncated server_name= ''
                        max_server_len = 0
                    if len(server_name) > max_server_len:
                        safe_server = server_name[:max(0, max_server_len)]
                    else:
                        safe_server = server_name
                    key = f"{safe_server}{tool_splitter}{orig_tool_name}"
                    if key in tool_index:
                        raise ValueError(f"Duplicate composed tool key detected: {key}")
                    new_tool = copy(tool)  # shallow copy to avoid mutating caller's object
                    new_tool['tool_name'] = key
                    tool_index[key] = new_tool
        # return list of tool dicts similar to [value[2] for value in self._tool_index.values()]
        return list(tool_index.values())

    
    def _format_tools(self,
                     tools: Optional[List[Tool]] = None
                     ) -> List[Dict[str, Any]]:
        if tools:
            tools = [{
                'type': 'function',
                'function': {
                    'name': tool['tool_name'],
                    'description': tool['description'],
                    'parameters': tool['parameters']
                }
            } for tool in tools]
        else:
            tools = None
        return tools
    
    def _wrap_sample_tools(self):
        tools = self._get_tools()
        tools = self._reindex_tools(tools)
        return self._format_tools(tools)

    # todo: Put tool_calls in qwen3 format into assistant's content
    def clean_message(self, message: Dict[str, Any]) -> Dict[str, Any]:
        """Clean a single message, extract role, content and tool call related fields"""
        role = message.get("role", "")
        content = message.get("content", "")
        
        # Skip messages without role
        if not role:
            return None
        
        # Build base message
        cleaned = {
            "role": role,
            "content": content if content else "",
            "tool_calls": [],
            "name": "",
            "tool_call_id": "",
        }
        
        # Keep assistant's tool_calls and rename internal tool_name field to name
        if role == "assistant" and message.get("tool_calls"):
            tool_calls = message.get("tool_calls")
            if isinstance(tool_calls, list) and len(tool_calls) > 0:
                normalized_calls = []
                for call in tool_calls:
                    if not isinstance(call, dict):
                        normalized_calls.append(call)
                        continue
                    call_copy = call.copy()
                    # Compatible with old format: replace tool_name with name
                    if "tool_name" in call_copy and "name" not in call_copy:
                        call_copy["name"] = call_copy.pop("tool_name")
                    normalized_calls.append(call_copy)

                cleaned["tool_calls"] = normalized_calls
                cleaned["content"] = ""  # When tool_calls exist, set content to empty
        
        # Keep tool message's name field
        if role == "tool" and message.get("name"):
            cleaned["name"] = message.get("name")
        if role == "tool" and message.get("tool_call_id"):
            cleaned["tool_call_id"] = message.get("tool_call_id")
        
        # If message has neither content nor tool_calls (and is not a tool message), skip
        if not content and role != "tool" and ("tool_calls" not in cleaned or not cleaned["tool_calls"]):
            return None
        
        return cleaned
    
    def filter_conversation(self, messages: List[Dict[str, Any]], apply_system_prompt: bool = True) -> List[Dict[str, str]]:
        """
        Filter conversation:
        - Keep user and assistant messages
        - Remove pure system prompts (but keep system messages with actual content)
        - Clean redundant fields
        """
        filtered = []
        juice_prefix = JUICE_PREFIX
        coding_system_prompt = self.coding_system_prompt or ""
        
        for msg in messages:
            role = msg.get("role", "")
            content = msg.get("content", "")

            # First normalize developer/system first prompt
            if role == "developer":
                role = "system"

            if role == "system":
                if apply_system_prompt and content and "You are a senior Solidity bug fixer" in content:
                    content = coding_system_prompt
                elif content and content.startswith(juice_prefix):
                    content = content[len(juice_prefix):]
            
            # Skip empty messages (except when assistant has tool_calls)
            if not content and not (role == "assistant" and msg.get("tool_calls")):
            # if not content:
                continue
            
            msg['role'] = role
            msg['content'] = content
            # For system messages, only keep the first one as context
            if role == "system":
                # If it's the first message and is system, keep it
                if len(filtered) == 0:
                    cleaned = self.clean_message(msg)
                    if cleaned:
                        filtered.append(cleaned)
                continue
            
            # Keep user, assistant and tool messages
            if role in ["user", "assistant", "tool"]:
            # if role in ["user", "assistant"]:
                cleaned = self.clean_message(msg)
                if cleaned:
                    filtered.append(cleaned)
        
        # Only keep up to the last assistant message, discard messages after (usually extra tool or system noise)
        last_assistant_idx = -1
        for idx, m in enumerate(filtered):
            if m.get("role") == "assistant":
                last_assistant_idx = idx

        if last_assistant_idx >= 0:
            filtered = filtered[: last_assistant_idx + 1]

        return filtered
    
    # === DB Reading and Sample Building ===

    @staticmethod
    def _loads_json_field(value: Any) -> Any:
        if value is None:
            return None
        if isinstance(value, (list, dict)):
            return value
        if isinstance(value, str):
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                logger.warning("Failed to parse JSON field; skipping")
                return None
        return None

    def _build_samples_from_entry(self, entry: Dict[str, Any]) -> List[Dict[str, Any]]:
        samples: List[Dict[str, Any]] = []
        file_path = entry.get("file_path", "")
        model_coding = entry.get("model_coding", "")

        # coding_messages → single sample
        coding_messages = self._loads_json_field(entry.get("coding_messages"))
        if isinstance(coding_messages, list) and coding_messages:
            # coding_messages: apply system-prompt normalization
            filtered = self.filter_conversation(coding_messages, apply_system_prompt=True)
            if filtered:
                has_assistant_tools = any(
                    m.get("role") == "assistant"
                    and isinstance(m.get("tool_calls"), list)
                    and len(m["tool_calls"]) > 0
                    for m in filtered
                )
                samples.append({
                    "messages": filtered,
                    "tools": self._wrap_sample_tools() if has_assistant_tools else [],
                    "source_file": file_path,
                    "model_coding": model_coding,
                })

        # round_messages → multiple rounds, one sample per round; remove last round
        round_messages = self._loads_json_field(entry.get("round_messages"))
        if isinstance(round_messages, dict) and round_messages:
            round_keys = sorted(round_messages.keys(), key=lambda k: int(k) if str(k).isdigit() else k)
            if round_keys:
                round_keys = round_keys[:-1]  # Discard last round (not generated by LLM)
            for rk in round_keys:
                msgs = round_messages.get(rk)
                if not msgs:
                    continue
                # round_messages (refine/etc.): do NOT apply the special system prompt replacement
                filtered = self.filter_conversation(msgs, apply_system_prompt=False)
                if filtered:
                    samples.append({
                        "messages": filtered,
                        "tools": self._wrap_sample_tools(),
                        "source_file": file_path,
                        "model_coding": model_coding,
                    })

        return samples

    def _iter_entries(self) -> List[Dict[str, Any]]:
        entries = self.tracker.get_all_entries(status=self.status_filter)
        filtered = []
        for e in entries:
            mc = e.get("model_coding")
            if self.model_whitelist and mc not in self.model_whitelist:
                continue
            filtered.append(e)
        logger.info(f"Fetched {len(entries)} rows from DB, kept {len(filtered)} after model/status filter")
        return filtered

    def process_all(self) -> List[Dict[str, Any]]:
        logger.info("=" * 60)
        logger.info("Starting data processing from DB")
        logger.info(f"DB path: {self.db_path}")
        logger.info(f"Status filter: {self.status_filter}, Model whitelist: {sorted(self.model_whitelist) if self.model_whitelist else 'ALL'}")
        logger.info("=" * 60)

        all_samples: List[Dict[str, Any]] = []
        for entry in self._iter_entries():
            entry_samples = self._build_samples_from_entry(entry)
            all_samples.extend(entry_samples)

        logger.info("\n" + "=" * 60)
        logger.info(f"Processing complete: {len(all_samples)} samples generated")
        logger.info("=" * 60)
        return all_samples
    
    def save_processed_data(self, samples: List[Dict[str, Any]], output_path: str):
        """Save processed data"""
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Save as JSON format (one sample per line in JSONL)
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(samples, f, ensure_ascii=False, indent=2)
        
        logger.info(f"\nProcessed data saved to: {output_file}")
        logger.info(f"Total samples: {len(samples)}")
        
        # Print statistics
        total_messages = sum(len(sample["messages"]) for sample in samples)
        avg_messages = total_messages / len(samples) if samples else 0
        
        # Statistics for tool call related information
        samples_with_tool_calls = 0
        assistant_tool_call_messages = 0
        tool_role_messages = 0
        
        for sample in samples:
            has_tool_call = False
            for msg in sample["messages"]:
                role = msg.get("role", "")
                # Count assistant messages with tool_calls
                if role == "assistant" and msg.get("tool_calls") and len(msg["tool_calls"]) > 0:
                    assistant_tool_call_messages += 1
                    has_tool_call = True
                # Count role=tool messages
                if role == "tool":
                    tool_role_messages += 1
                    has_tool_call = True
            
            if has_tool_call:
                samples_with_tool_calls += 1
        
        tool_call_ratio = (samples_with_tool_calls / len(samples) * 100) if samples else 0
        
        logger.info(f"Total messages: {total_messages}")
        logger.info(f"Average messages per sample: {avg_messages:.2f}")
        logger.info(f"Samples with tool calls: {samples_with_tool_calls} ({tool_call_ratio:.2f}%)")
        logger.info(f"Assistant messages with tool_calls: {assistant_tool_call_messages}")
        logger.info(f"Tool role messages: {tool_role_messages}")


def main():
    """Main function: generate three datasets (tracker, summary, mixed)."""

    script_dir = Path(__file__).resolve().parent
    repo_output_dir = script_dir.parent / "output"

    db_path = repo_output_dir / "progress.db"
    model_whitelist = DEFAULT_MODEL_WHITELIST
    status_filter = 1

    # Output to z0train/output/, can be correctly located regardless of where it's executed from
    output_root = script_dir / "output"
    output_root.mkdir(parents=True, exist_ok=True)
    tracker_out = output_root / "processed_tracker.json"
    summary_out = output_root / "processed_summary.json"
    mixed_out = output_root / "processed_mixed.json"

    # 1) Non-summary table
    tracker_processor = DataProcessor(db_path=db_path, use_summary=False, status_filter=status_filter, model_whitelist=model_whitelist)
    # tools = tracker_processor._get_tools()
    # tools = tracker_processor.reindex_tools(tools)
    # print(tracker_processor._format_tools(tools))

    # return
    tracker_samples = tracker_processor.process_all()
    tracker_processor.save_processed_data(tracker_samples, tracker_out)

    # 2) Summary table
    summary_processor = DataProcessor(db_path=db_path, use_summary=True, status_filter=status_filter, model_whitelist=model_whitelist)
    summary_samples = summary_processor.process_all()
    summary_processor.save_processed_data(summary_samples, summary_out)

    # 3) Mixed
    mixed_samples = tracker_samples + summary_samples
    tracker_processor.save_processed_data(mixed_samples, mixed_out)

    logger.info("\n✅ Data processing completed for tracker/summary/mixed datasets!")


if __name__ == "__main__":
    main()
