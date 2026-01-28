import json
import os
import sqlite3
from pathlib import Path

from utils.code_utils import try_extract_code


def fetch_record(db_path: str, record_id: int):
    """Return a row from progress_tracker_agent by id."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        cur = conn.cursor()
        cur.execute("SELECT * FROM progress_tracker_agent WHERE id = ?", (record_id,))
        row = cur.fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def extract_and_write_code(record: dict, target_path: Path) -> bool:
    """Extract the last assistant Solidity block from coding_messages and write it."""
    coding_messages_str = record.get("coding_messages")
    if not coding_messages_str:
        print("[WARNING] Record has no coding_messages")
        return False

    try:
        coding_messages = json.loads(coding_messages_str)
    except json.JSONDecodeError as e:
        print(f"[ERROR] Failed to parse coding_messages JSON: {e}")
        return False

    if not isinstance(coding_messages, list):
        print("[ERROR] coding_messages is not a list")
        return False

    target_path = Path(target_path)
    target_path.parent.mkdir(parents=True, exist_ok=True)

    generated_file = None
    for msg in reversed(coding_messages):
        if not isinstance(msg, dict):
            continue
        if msg.get("role") == "assistant":
            content = msg.get("content", "")
            code_block = try_extract_code(content)
            if code_block and code_block.strip().startswith("// SPDX-License-Identifier: MIT"):
                generated_file = target_path
                print(f"[INFO] Found Solidity code from assistant message")
                print(f"[INFO] Code length: {len(code_block)} bytes")
            elif code_block and code_block.strip().startswith("```solidity"):
                generated_file = target_path
                print(f"[INFO] Found Solidity code from assistant message")
                print(f"[INFO] Code length: {len(code_block)} bytes")
        if generated_file:
            break

    if not generated_file:
        print("[WARNING] No assistant code block found in coding_messages")
        return False
    return True


def main():
    db_path = "output/progress.db"
    record_id = 3008
    base_dir = os.path.dirname(os.path.abspath(__file__))

    record = fetch_record(db_path, record_id)
    if not record:
        print(f"[ERROR] No record found with id={record_id}")
        return

    file_path = record.get("file_path")
    if file_path:
        target_path = Path(base_dir) / file_path
    else:
        target_path = Path(base_dir) / "extracted.sol"

    success = extract_and_write_code(record, target_path)
    if success:
        print(f"[DONE] Wrote extracted code to {target_path}")


if __name__ == "__main__":
    main()
