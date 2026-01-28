"""Utilities for normalizing LLM responses across service providers."""
from __future__ import annotations

from typing import Any, Dict, Tuple, Sequence


def format_assistant_response(response: Any, service_type: str = "openai") -> Tuple[Dict[str, Any], str]:
    """Normalize an LLM response into a message dict and plain text content.

    Args:
        response: Raw response object or dict from the LLM client.
        service_type: Provider identifier (e.g., "openai", "ollama").

    Returns:
        A tuple (assistant_dict, response_text) where assistant_dict contains at
        least "role" and "content", plus token metadata when available, and
        response_text is the assistant's textual content (empty string if absent).
    """
    if service_type == "ollama":
        return _format_ollama_response(response)
    return _format_openai_response(response)


def _format_openai_response(response: Any) -> Tuple[Dict[str, Any], str]:
    assistant_msg = _extract_openai_message(response)
    assistant_dict = _message_to_dict(assistant_msg)

    if not assistant_dict:
        assistant_dict = {"role": "assistant", "content": str(response)}

    assistant_dict.setdefault("role", "assistant")
    assistant_dict.setdefault("content", "")

    usage = _extract_usage(response)
    prompt_tokens = _get_usage_value(usage, ["prompt_tokens", "promptToken"], 0)
    completion_tokens = _get_usage_value(usage, ["completion_tokens", "completionToken"], 0)

    # Fallback: check model_extra in usage object (e.g. for some providers)
    if prompt_tokens == 0 and completion_tokens == 0 and usage is not None:
        model_extra = getattr(usage, "model_extra", None)
        if isinstance(model_extra, dict):
            prompt_tokens = _safe_int(model_extra.get("input_tokens"), 0)
            completion_tokens = _safe_int(model_extra.get("output_tokens"), 0)

    total_tokens = _get_usage_value(
        usage,
        ["total_tokens", "totalToken"],
        prompt_tokens + completion_tokens,
    )

    if prompt_tokens:
        assistant_dict["prompt_tokens"] = int(prompt_tokens)
    if completion_tokens:
        assistant_dict["completion_tokens"] = int(completion_tokens)
    if total_tokens:
        assistant_dict["total_tokens"] = int(total_tokens)

    return assistant_dict, assistant_dict.get("content", "")


def _format_ollama_response(response: Any) -> Tuple[Dict[str, Any], str]:
    msg_obj = getattr(response, "message", None)
    if msg_obj is None and isinstance(response, dict):
        msg_obj = response.get("message")

    assistant_dict = _message_to_dict(msg_obj)
    assistant_dict.setdefault("role", "assistant")
    assistant_dict.setdefault("content", "")

    # Ollama exposes eval counts at the top level
    prompt_tokens = _safe_int(_maybe_get(response, ["prompt_eval_count", "prompt_tokens"]))
    completion_tokens = _safe_int(_maybe_get(response, ["eval_count", "completion_tokens"]))
    total_tokens = prompt_tokens + completion_tokens if (prompt_tokens or completion_tokens) else 0

    if prompt_tokens:
        assistant_dict["prompt_tokens"] = prompt_tokens
    if completion_tokens:
        assistant_dict["completion_tokens"] = completion_tokens
    if total_tokens:
        assistant_dict["total_tokens"] = total_tokens

    # Include response id when present
    resp_id = _maybe_get(response, ["id"])
    if resp_id:
        assistant_dict.setdefault("id", resp_id)

    return assistant_dict, assistant_dict.get("content", "")


def _extract_openai_message(response: Any) -> Any:
    choices = getattr(response, "choices", None)
    if choices:
        try:
            first = choices[0]
            if hasattr(first, "message"):
                return first.message
        except Exception:
            pass

    if isinstance(response, dict):
        choices = response.get("choices")
        if choices:
            return choices[0].get("message")

    return None


def _message_to_dict(message: Any) -> Dict[str, Any]:
    if isinstance(message, dict):
        return dict(message)
    if message is None:
        return {}

    result: Dict[str, Any] = {}
    for attr in (
        "role",
        "content",
        "reasoning_content",
        "tool_calls",
        "function_call",
        "name",
    ):
        value = getattr(message, attr, None)
        if value is not None:
            result[attr] = value
    return result


def _extract_usage(response: Any) -> Any:
    usage = getattr(response, "usage", None)
    if usage is not None:
        return usage
    if isinstance(response, dict):
        return response.get("usage")
    return None


def _get_usage_value(usage: Any, keys: Sequence[str], default: int = 0) -> int:
    if usage is None:
        return default
    for key in keys:
        if isinstance(usage, dict) and key in usage:
            return _safe_int(usage.get(key), default)
        value = getattr(usage, key, None)
        if value is not None:
            return _safe_int(value, default)
    return default


def _maybe_get(obj: Any, keys: Sequence[str]) -> Any:
    for key in keys:
        if isinstance(obj, dict) and key in obj:
            return obj.get(key)
        value = getattr(obj, key, None)
        if value is not None:
            return value
    return None


def _safe_int(value: Any, default: int | None = 0) -> int:
    if value in (None, ""):
        return default or 0
    try:
        return int(value)
    except (TypeError, ValueError):
        return default or 0