"""Shared Solidity code extraction and source-code metric helpers."""

import os
import re
from typing import Any, Dict, List, Optional

from file_parser import extract_code_blocks
from utils.code_utils import try_extract_code


def calculate_complexity(code: str) -> int:
    """Estimate cyclomatic complexity from Solidity decision points."""
    pattern = r'("(?:\\[\s\S]|[^"\\])*"|\'(?:\\[\s\S]|[^\'\\])*\'|/\*[\s\S]*?\*/|//.*)'

    def replacer(match):
        value = match.group(0)
        return " " if value.startswith("/") else '""'

    cleaned_code = re.sub(pattern, replacer, code)
    complexity = 1
    keywords = [
        r"\bif\b",
        r"\bwhile\b",
        r"\bfor\b",
        r"\bcase\b",
        r"\bcatch\b",
        r"\&\&",
        r"\|\|",
        r"\?",
        r"\brequire\b",
        r"\bassert\b",
    ]
    for keyword_pattern in keywords:
        complexity += len(re.findall(keyword_pattern, cleaned_code))
    return complexity


def count_loc(code: str) -> int:
    """Count non-empty, non-comment source lines using the legacy RQ1 rule."""
    loc = 0
    in_multiline_comment = False

    for line in code.split("\n"):
        stripped = line.strip()
        if "/*" in stripped:
            in_multiline_comment = True
        if in_multiline_comment:
            if "*/" in stripped:
                in_multiline_comment = False
            continue
        if not stripped or stripped.startswith("//"):
            continue
        loc += 1
    return loc


def count_physical_loc(code: str) -> int:
    """Count all physical source lines, including comments and blanks."""
    return len(code.split("\n"))


def extract_code_from_messages(
    messages: Optional[List[Dict[str, Any]]],
    file_path: str,
    agent_type: str = "",
) -> Optional[str]:
    """Extract the last valid target Solidity file from assistant messages.

    The special cases intentionally match the extraction behavior previously
    embedded in ``ex_rq1_loc.py`` for MetaGPT and DeepCode outputs.
    """
    if not isinstance(messages, list):
        return None

    file_name = os.path.basename(file_path)
    file_class = file_name.removesuffix(".sol")

    for message in reversed(messages):
        if not isinstance(message, dict) or message.get("role") != "assistant":
            continue

        content = message.get("content", "")
        try:
            if agent_type == "metagpt":
                code_block = try_extract_code(content)
                if (
                    code_block
                    and code_block.strip().startswith("// SPDX-License-Identifier: MIT")
                    and file_class in code_block
                ):
                    return code_block.strip()
                if code_block and code_block.strip().startswith("```solidity"):
                    code = (
                        code_block.strip()
                        .replace("```solidity", "")
                        .replace("```", "")
                        .strip()
                    )
                    if file_class in code:
                        return code
                continue

            all_files, _ = extract_code_blocks(content, target_filename=file_name)
            if all_files:
                code = all_files[0]["code"].strip()
                if code and code != "NoContent":
                    return code

            if agent_type == "deepcode":
                for call in reversed(message.get("tool_calls", [])):
                    if call.get("name") != "write_file":
                        continue
                    input_data = call.get("input", {})
                    if input_data.get("file_path") != file_name:
                        continue
                    code = input_data.get("content", "").strip()
                    if code and code != "NoContent":
                        return code
        except Exception:
            continue

    return None
