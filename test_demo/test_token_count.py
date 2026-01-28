import json
from pathlib import Path
from typing import Any, Dict, List, Tuple

ROOT = Path("output") / "memory-4"
FILES = ["code_agent.json", "messages.json"]

def find_usage_tokens(obj: Any) -> Tuple[int, int]:
    """
    Recursively find all occurrences of usage / prompt_tokens / completion_tokens and sum them.
    Returns (prompt_tokens, completion_tokens)
    """
    pt = ct = 0
    if isinstance(obj, dict):
        # direct usage object
        if "usage" in obj and isinstance(obj["usage"], dict):
            u = obj["usage"]
            pt += int(u.get("prompt_tokens", 0) or 0)
            ct += int(u.get("completion_tokens", 0) or 0)
        # direct fields
        if "prompt_tokens" in obj or "completion_tokens" in obj:
            pt += int(obj.get("prompt_tokens", 0) or 0)
            ct += int(obj.get("completion_tokens", 0) or 0)
        for v in obj.values():
            p, c = find_usage_tokens(v)
            pt += p; ct += c
    elif isinstance(obj, list):
        for item in obj:
            p, c = find_usage_tokens(item)
            pt += p; ct += c
    return pt, ct

def extract_messages(obj: Any) -> List[Dict]:
    """
    Try to extract a messages list. If the top-level object is a list whose elements contain role/content, return it.
    Otherwise look for keys like "messages" or "history" inside dicts.
    """
    if isinstance(obj, list):
        if all(isinstance(i, dict) and "content" in i and "role" in i for i in obj):
            return obj
    if isinstance(obj, dict):
        for k in ("messages", "msgs", "history"):
            if k in obj and isinstance(obj[k], list):
                if all(isinstance(i, dict) and "content" in i and "role" in i for i in obj[k]):
                    return obj[k]
        for v in obj.values():
            msgs = extract_messages(v)
            if msgs:
                return msgs
    return []

def process_file(path: Path) -> Dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    usage_pt, usage_ct = find_usage_tokens(data)

    # Tokens contained in assistant messages: for each message with role == "assistant",
    # sum the usage / prompt_tokens / completion_tokens present in that message
    assistant_pt = assistant_ct = 0
    msgs = extract_messages(data)
    if msgs:
        for m in msgs:
            if m.get("role") == "assistant":
                p, c = find_usage_tokens(m)
                assistant_pt += p
                assistant_ct += c

    return {
        "file": str(path),
        "usage_prompt_tokens": usage_pt,
        "usage_completion_tokens": usage_ct,
        "usage_total": usage_pt + usage_ct,
        "assistant_prompt_tokens": assistant_pt,
        "assistant_completion_tokens": assistant_ct,
        "assistant_total": assistant_pt + assistant_ct,
    }

def main():
    results = []
    for fname in FILES:
        p = ROOT / fname
        if not p.exists():
            print(f"Skipping, file not found: {p}")
            continue
        results.append(process_file(p))

    for r in results:
        print("File:", r["file"])
        print("  usage -> prompt:", r["usage_prompt_tokens"], "completion:", r["usage_completion_tokens"], "total:", r["usage_total"])
        print("  assistant -> prompt:", r["assistant_prompt_tokens"], "completion:", r["assistant_completion_tokens"], "total:", r["assistant_total"])
        print()

    if results:
        sum_usage_pt = sum(r["usage_prompt_tokens"] for r in results)
        sum_usage_ct = sum(r["usage_completion_tokens"] for r in results)
        sum_assist_pt = sum(r["assistant_prompt_tokens"] for r in results)
        sum_assist_ct = sum(r["assistant_completion_tokens"] for r in results)
        print("Totals:")
        print("  usage -> prompt:", sum_usage_pt, "completion:", sum_usage_ct, "total:", sum_usage_pt + sum_usage_ct)
        print("  assistant -> prompt:", sum_assist_pt, "completion:", sum_assist_ct, "total:", sum_assist_pt + sum_assist_ct)

if __name__ == "__main__":
    main()
