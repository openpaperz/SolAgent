# shared_context.py
import asyncio
import os
from typing import Any, Dict

class SharedContext:
    """A simple asyncio-safe shared memory for multiple LLM agents."""
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._lock = asyncio.Lock()
            cls._instance._data: Dict[str, Any] = {}
        return cls._instance

    async def set(self, key: str, value: Any):
        async with self._lock:
            self._data[key] = value

    async def get(self, key: str, default: Any = None) -> Any:
        async with self._lock:
            return self._data.get(key, default)

    async def remove(self, key: str):
        async with self._lock:
            if key in self._data:
                del self._data[key]

    async def clear(self):
        async with self._lock:
            self._data.clear()

    async def dump(self) -> Dict[str, Any]:
        async with self._lock:
            return dict(self._data)

    def _get_output_path(self):
        # agent-smart/utils/shared_context.py -> agent-smart/output/shared_context.txt
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        output_dir = os.path.join(base_dir, "output")
        if not os.path.exists(output_dir):
            os.makedirs(output_dir, exist_ok=True)
        return os.path.join(output_dir, "shared_context.txt")

    async def set_all(self, orig_sol_repo, orig_sol, cur_t_sol, cur_sol: str, file_path: str = None):
        async with self._lock:
            self._data["orig_sol_repo"] = orig_sol_repo
            self._data["orig_sol"] = orig_sol
            self._data["cur_t.sol"] = cur_t_sol
            self._data["cur_sol"] = cur_sol
            if file_path is not None:
                self._data["file_path"] = file_path

            content = (
                f"orig_sol_repo = {orig_sol_repo}\n"
                f"orig_sol = {orig_sol}\n"
                f"cur_t_sol = {cur_t_sol}\n"
                f"cur_sol = {cur_sol}\n"
            )
            if file_path is not None:
                content += f"file_path = {file_path}\n"

            with open(self._get_output_path(), "w") as f:
                f.write(content)

    async def set_checkpoint_meta(self, table_name: str, entry_id: int):
        """Store checkpoint metadata (table name and entry id) and persist to shared_context.txt.

        This enables cross-process recovery (e.g., EvalCallback) to locate checkpoint files.
        """
        async with self._lock:
            self._data["table_name"] = table_name
            self._data["entry_id"] = entry_id

            # Persist by updating/adding lines in shared_context.txt
            # Read existing lines if present
            lines = []
            output_file = self._get_output_path()
            if os.path.exists(output_file):
                try:
                    with open(output_file, "r") as f:
                        lines = f.readlines()
                except Exception:
                    lines = []

            # Convert to dict for simple overwrite semantics
            kv = {}
            for line in lines:
                line = line.strip()
                if not line or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                kv[k.strip()] = v.strip()

            kv["table_name"] = table_name
            kv["entry_id"] = str(entry_id)

            # Write back
            with open(output_file, "w") as f:
                for k in [
                    "orig_sol_repo", "orig_sol", "cur_t_sol", "cur_sol",
                    "file_path", "table_name", "entry_id"
                ]:
                    if k in kv:
                        f.write(f"{k} = {kv[k]}\n")

    def get_all(self) -> (str, str, str):
        """Get all stored .sol files: orig_sol, cur_t.sol, cur_sol."""
        return self._data["orig_sol"], self._data["cur_t.sol"], self._data["cur_sol"]

    def get_file_path(self):
        """Get stored relative file_path if available."""
        return self._data.get("file_path")

    def get_checkpoint_meta(self):
        """Return (table_name, entry_id) if available, else (None, None)."""
        table = self._data.get("table_name")
        entry_id = self._data.get("entry_id")
        return table, entry_id

    def get_cur_sol_name(self):
        return self._data["cur_sol"].split("/")[-1]

    def get_all_from_file(self) -> (str, str, str):
        """Read stored Solidity file paths from output/shared_context.txt and return (orig_sol, cur_t_sol, cur_sol)."""
        file_path = self._get_output_path()
        orig_sol = cur_t_sol = cur_sol = None

        if not os.path.exists(file_path):
            raise FileNotFoundError(f"{file_path} does not exist")

        with open(file_path, "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("orig_sol_repo"):
                    orig_sol_repo = line.split("=", 1)[1].strip()
                elif line.startswith("orig_sol"):
                    orig_sol = line.split("=", 1)[1].strip()
                elif line.startswith("cur_t_sol"):
                    cur_t_sol = line.split("=", 1)[1].strip()
                elif line.startswith("cur_sol"):
                    cur_sol = line.split("=", 1)[1].strip()

        if not all([orig_sol, cur_t_sol, cur_sol]):
            raise ValueError("Failed to parse all required fields from shared_context.txt")

        return orig_sol, cur_t_sol, cur_sol

# ✅ Singleton instance for import everywhere
shared_context = SharedContext()
