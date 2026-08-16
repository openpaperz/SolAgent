#!/usr/bin/env python3
"""OpenCode + MiMo baseline generator.

This script mirrors the baseline-agent dataset/query construction, but writes
one JSON artifact per dataset file instead of writing to progress.db.
"""

import argparse
import json
import os
import pickle
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

from utils.code_utils import extract_solidity_code
from utils.path import remap_path


DEFAULT_OPENCODE_MODEL = os.environ.get("OPENCODE_MIMO_MODEL", "xiaomi-token-plan-cn/mimo-v2.5-pro")
DEFAULT_MODEL_CODING = "mimo-v2.5-pro"
PROJECT_BUILD_DIR_NAMES = {"out", "artifacts", "cache", "cache_forge"}
GENERATOR_DIR_NAMES = {"generate", "generators", "generated", "templates"}
OPENCODE_RESTRICTED_READ_DIR_NAMES = {"node_modules"}
OPENCODE_RESTRICTED_READ_PATTERNS = {
    "*node_modules*": "deny",
    "**/node_modules/**": "deny",
    "*.t.sol": "deny",
    "**/*.t.sol": "deny",
    "**/*.t.sol:*": "deny",
}
OPENCODE_RESTRICTED_READ_FILE_SUFFIXES = (".t.sol",)
OPENCODE_DENIED_BASH_PATTERNS = {
    "*curl*": "deny",
    "*wget*": "deny",
    "*raw.githubusercontent.com*": "deny",
    "*github.com*": "deny",
    "*git *": "deny",
    "*git clone*": "deny",
    "*git fetch*": "deny",
    "*git pull*": "deny",
    "*git push*": "deny",
    "*git submodule*": "deny",
    "*git ls-remote*": "deny",
    "*gh *": "deny",
    "*npx*": "deny",
    "*bunx*": "deny",
    "*npm install*": "deny",
    "*npm i *": "deny",
    "*npm add*": "deny",
    "*npm exec*": "deny",
    "*npm update*": "deny",
    "*npm upgrade*": "deny",
    "*pnpm install*": "deny",
    "*pnpm add*": "deny",
    "*pnpm dlx*": "deny",
    "*yarn install*": "deny",
    "*yarn add*": "deny",
    "*bun install*": "deny",
    "*bun add*": "deny",
    "*pip install*": "deny",
    "*python* -m pip*": "deny",
    "*uv pip*": "deny",
    "*uvx*": "deny",
    "*go get*": "deny",
    "*go install*": "deny",
    "*cargo install*": "deny",
    "*forge install*": "deny",
}
OPENCODE_NETWORK_DENY_CONFIG = {
    "permission": {
        "webfetch": "deny",
        "websearch": "deny",
        "codesearch": "deny",
        "repo_clone": "deny",
        "task": "deny",
        "read": OPENCODE_RESTRICTED_READ_PATTERNS,
        "glob": OPENCODE_RESTRICTED_READ_PATTERNS,
    "bash": OPENCODE_DENIED_BASH_PATTERNS,
    }
}
OPENCODE_NETWORK_GUARD_COMMANDS = (
    "curl",
    "wget",
    "gh",
    "npx",
    "npm",
    "pnpm",
    "yarn",
    "bun",
    "bunx",
    "git",
    "pip",
    "pip3",
    "python",
    "python3",
    "uv",
    "uvx",
    "go",
    "cargo",
    "forge",
    "find",
    "rg",
    "grep",
    "cat",
    "ls",
    "sed",
    "awk",
    "head",
    "tail",
    "less",
    "more",
)
ISOLATED_OPENCODE_ROOT_NAME = ".opencode-isolated"


def iso_now() -> str:
    return datetime.now().isoformat()


def load_coding_yaml(config_path: Path) -> str:
    try:
        import yaml

        with config_path.open("r", encoding="utf-8") as f:
            config = yaml.safe_load(f) or {}
        return config.get("prompt", {}).get("system", "")
    except ModuleNotFoundError:
        return load_prompt_system_without_yaml(config_path)


def load_prompt_system_without_yaml(config_path: Path) -> str:
    """Minimal fallback for coding.yaml's prompt.system literal block."""
    lines = config_path.read_text(encoding="utf-8").splitlines()
    in_prompt = False
    in_system = False
    system_indent: Optional[int] = None
    collected: List[str] = []

    for line in lines:
        stripped = line.strip()
        indent = len(line) - len(line.lstrip(" "))
        if stripped == "prompt:":
            in_prompt = True
            in_system = False
            continue
        if in_prompt and indent == 0 and stripped and stripped != "prompt:":
            break
        if in_prompt and stripped.startswith("system:"):
            in_system = True
            system_indent = None
            continue
        if not in_system:
            continue
        if system_indent is None:
            if not stripped:
                collected.append("")
                continue
            system_indent = indent
        if indent < (system_indent or 0) and stripped:
            break
        collected.append(line[system_indent or 0 :])

    return "\n".join(collected).rstrip() + "\n"


def load_env_file(env_path: Path) -> None:
    """Load .env values without overriding existing environment variables."""
    try:
        from dotenv import load_dotenv

        load_dotenv(env_path)
        return
    except ModuleNotFoundError:
        pass

    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("\"'")
        if key and key not in os.environ:
            os.environ[key] = value


def require_absolute_orig_repo() -> str:
    orig_repo = os.environ.get("ORIG_REPO")
    if not orig_repo:
        raise RuntimeError("ORIG_REPO is not set")
    if not os.path.isabs(orig_repo):
        raise RuntimeError(f"ORIG_REPO must be an absolute path, got: {orig_repo}")
    return orig_repo


def safe_artifact_name(file_path: str) -> str:
    safe = file_path.replace("\\", "__").replace("/", "__")
    safe = safe.replace(":", "_")
    return f"{safe}.json"


def count_methods(file_content: list) -> int:
    method_len = 0
    for cls in file_content:
        for method in cls.get("methods", []):
            if method.get("kind") in ["struct", "function", "constructor"]:
                method_len += 1
    return method_len


def build_file_query(file_path: str, file_content: list, project_root: Path, file_name: str) -> Tuple[str, int]:
    sol_version = file_content[0]["methods"][0]["sol_version"][0]
    query_head = f"given repo: {project_root}\nfile name: {file_name}\n\n{sol_version}"

    method_len = 0
    query = ""
    for cls in file_content:
        file_class = f"\n{cls['kind']} {cls['identifier']}\n"
        query += file_class

        for method in cls["methods"]:
            if method["kind"] not in ["struct", "function", "constructor"]:
                continue
            method_len += 1

            full_signature = method["full_signature"].strip()
            human_labeled_comment = method["human_labeled_comment"].strip()
            query = f"""{query}
{human_labeled_comment}
{full_signature}
"""

    return f"{query_head}\n{query}", method_len


def project_relative_path(project_root: Path, path: Path) -> Path:
    try:
        return path.resolve(strict=False).relative_to(project_root.resolve(strict=False))
    except ValueError:
        return Path(path.name)


def find_same_name_sol_files(project_root: Path, target_name: str) -> List[Path]:
    if not project_root.exists():
        return []
    return sorted(
        path
        for path in project_root.rglob(target_name)
        if path.is_file() and path.name == target_name and path.suffix == ".sol"
    )


def delete_bak_files(project_root: Path) -> List[str]:
    if not project_root.exists():
        return []

    deleted: List[str] = []
    for path in sorted(project_root.rglob("*.bak")):
        if not path.is_file():
            continue
        try:
            path.unlink()
            deleted.append(str(path))
        except FileNotFoundError:
            pass
    return deleted


def find_project_config_dirs(project_root: Path) -> List[Path]:
    if not project_root.exists():
        return []

    config_dirs = set()
    for path in project_root.rglob("*"):
        if not path.is_file():
            continue
        if "node_modules" in path.parts:
            continue
        if path.name == "foundry.toml" or path.name.startswith("hardhat.config."):
            config_dirs.add(path.parent)
    return sorted(config_dirs, key=lambda p: (len(p.parts), str(p)), reverse=True)


def delete_project_build_dirs(project_root: Path) -> List[str]:
    deleted: List[str] = []
    for config_dir in find_project_config_dirs(project_root):
        for dir_name in PROJECT_BUILD_DIR_NAMES:
            path = config_dir / dir_name
            if not path.is_dir():
                continue
            if "node_modules" in path.parts:
                continue
            shutil.rmtree(path)
            deleted.append(str(path))
    return deleted


BackupEntry = Tuple[Path, bytes, int]


def find_target_generator_files(project_root: Path, target_name: str) -> List[Path]:
    if not project_root.exists():
        return []

    stem = Path(target_name).stem
    candidates: List[Path] = []
    for path in project_root.rglob("*"):
        if not path.is_file():
            continue
        if "node_modules" in path.parts:
            continue
        if not any(part in GENERATOR_DIR_NAMES for part in path.parts):
            continue

        path_stem = path.stem
        parent_name = path.parent.name
        if (
            path_stem == stem
            or path_stem == f"{stem}.opts"
            or path.name.startswith(f"{stem}.")
            or parent_name == stem
        ):
            candidates.append(path)

    return sorted(set(candidates))


def backup_and_delete(paths: Iterable[Path]) -> List[BackupEntry]:
    backups: List[BackupEntry] = []
    for path in paths:
        st = path.stat()
        backups.append((path, path.read_bytes(), stat.S_IMODE(st.st_mode)))
    for path, _content, _mode in backups:
        path.unlink()
    return backups


def restore_backups(project_root: Path, target_name: str, backups: List[BackupEntry]) -> Dict[str, Any]:
    backup_paths = {path.resolve() for path, _content, _mode in backups}
    removed_extra: List[str] = []

    # Remove same-name files created at new locations before restoring originals.
    for path in find_same_name_sol_files(project_root, target_name):
        resolved = path.resolve()
        if resolved not in backup_paths:
            try:
                path.unlink()
                removed_extra.append(str(path))
            except FileNotFoundError:
                pass

    restored: List[str] = []
    for path, content, mode in backups:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        os.chmod(path, mode)
        restored.append(str(path))

    return {"restored_paths": restored, "removed_extra_paths": removed_extra}


def restore_exact_backups(backups: List[BackupEntry]) -> List[str]:
    restored: List[str] = []
    for path, content, mode in backups:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        os.chmod(path, mode)
        restored.append(str(path))
    return restored


@contextmanager
def copy_project_for_opencode(project_root: Path, target_name: str):
    isolation_parent = project_root.parents[1] / ISOLATED_OPENCODE_ROOT_NAME
    isolation_parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="run-", dir=str(isolation_parent)) as tmp_dir:
        isolated_root = Path(tmp_dir) / project_root.name
        shutil.copytree(
            project_root,
            isolated_root,
            ignore=shutil.ignore_patterns(".git", "out", "artifacts", "cache", "cache_forge"),
        )
        for path in find_same_name_sol_files(isolated_root, target_name):
            path.unlink()
        yield isolated_root


def sync_generated_file_to_project(
    *,
    isolated_root: Path,
    project_root: Path,
    cur_sol: Path,
    generated_file: Optional[Path],
    generated_content: str,
    selected_source: Optional[str],
) -> Tuple[Optional[Path], Optional[str]]:
    if generated_file and generated_file.exists():
        relative = project_relative_path(isolated_root, generated_file)
        target = project_root / relative
        if target.resolve(strict=False) != cur_sol.resolve(strict=False):
            target = cur_sol
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(generated_file, target)
        return target, f"isolated:{generated_file}"

    if generated_content.strip():
        cur_sol.parent.mkdir(parents=True, exist_ok=True)
        cur_sol.write_text(generated_content, encoding="utf-8")
        return cur_sol, selected_source

    return None, selected_source


def deep_merge_dict(base: Dict[str, Any], overlay: Dict[str, Any]) -> Dict[str, Any]:
    merged = dict(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge_dict(merged[key], value)
        else:
            merged[key] = value
    return merged


def build_opencode_config_content() -> Dict[str, Any]:
    existing_raw = os.environ.get("OPENCODE_CONFIG_CONTENT")
    existing_config: Dict[str, Any] = {}
    if existing_raw:
        try:
            parsed = json.loads(existing_raw)
            if isinstance(parsed, dict):
                existing_config = parsed
        except json.JSONDecodeError:
            pass
    return deep_merge_dict(existing_config, OPENCODE_NETWORK_DENY_CONFIG)


def network_guard_wrapper(command: str, original: Optional[str]) -> str:
    return f"""#!{sys.executable}
import os
import sys

COMMAND = {command!r}
ORIGINAL = {original!r}
ALLOWED_ROOT = os.environ.get("OPENCODE_ALLOWED_ROOT", "")
FORBIDDEN_ROOTS = [
    path
    for path in os.environ.get("OPENCODE_FORBIDDEN_ROOTS", "").split(os.pathsep)
    if path
]
RESTRICTED_READ_DIRS = [
    name
    for name in os.environ.get("OPENCODE_RESTRICTED_READ_DIRS", "").split(os.pathsep)
    if name
]
RESTRICTED_READ_FILE_SUFFIXES = tuple(
    suffix
    for suffix in os.environ.get("OPENCODE_RESTRICTED_READ_FILE_SUFFIXES", "").split(os.pathsep)
    if suffix
)
READLIKE_COMMANDS = {{"find", "rg", "grep", "cat", "ls", "sed", "awk", "head", "tail", "less", "more"}}
CONTENT_READING_COMMANDS = {{"rg", "grep", "cat", "sed", "awk", "head", "tail", "less", "more"}}


def deny() -> None:
    print(
        "opencode network guard denied: " + COMMAND + " " + " ".join(sys.argv[1:]),
        file=sys.stderr,
    )
    sys.exit(126)


args = " " + " ".join(sys.argv[1:]) + " "
tokens = sys.argv[1:]

if ALLOWED_ROOT:
    normalized_args = args.replace("/private/var/", "/var/")
    normalized_allowed = ALLOWED_ROOT.replace("/private/var/", "/var/")
    for root in FORBIDDEN_ROOTS:
        normalized_root = root.replace("/private/var/", "/var/")
        if normalized_root and normalized_root in normalized_args and normalized_allowed not in normalized_args:
            deny()
    if COMMAND in READLIKE_COMMANDS:
        for dirname in RESTRICTED_READ_DIRS:
            if (
                f"/{{dirname}}/" in normalized_args
                or f"/{{dirname}} " in normalized_args
                or f" {{dirname}}/" in normalized_args
                or f" {{dirname}} " in normalized_args
                or f"*{{dirname}}*" in normalized_args
            ):
                deny()
        if RESTRICTED_READ_FILE_SUFFIXES:
            for suffix in RESTRICTED_READ_FILE_SUFFIXES:
                if suffix in normalized_args and COMMAND in CONTENT_READING_COMMANDS and COMMAND not in {{"find", "ls"}}:
                    deny()
                if COMMAND in CONTENT_READING_COMMANDS and any(token.endswith(suffix) for token in tokens):
                    deny()
                if COMMAND == "find" and any(token in tokens for token in ["-exec", "-execdir"]):
                    deny()

if COMMAND == "grep" and RESTRICTED_READ_FILE_SUFFIXES:
    extra_args = []
    for suffix in RESTRICTED_READ_FILE_SUFFIXES:
        if suffix == ".t.sol":
            extra_args.append("--exclude=*.t.sol")
    if extra_args:
        sys.argv = [sys.argv[0], *extra_args, *sys.argv[1:]]
elif COMMAND == "rg" and RESTRICTED_READ_FILE_SUFFIXES:
    extra_args = []
    for suffix in RESTRICTED_READ_FILE_SUFFIXES:
        if suffix == ".t.sol":
            extra_args.extend(["--glob", "!*.t.sol"])
    if extra_args:
        sys.argv = [sys.argv[0], *extra_args, *sys.argv[1:]]

if COMMAND in {{"curl", "wget", "gh", "npx", "bunx", "pip", "pip3", "uvx"}}:
    deny()
elif COMMAND == "git":
    deny()
elif COMMAND in {{"npm", "pnpm", "yarn", "bun"}} and any(
    token in tokens for token in ["install", "i", "add", "exec", "dlx", "create", "update", "upgrade", "publish"]
):
    deny()
elif COMMAND in {{"python", "python3"}} and any(
    marker in args
    for marker in [
        "http://",
        "https://",
        "urllib",
        "requests",
        "httpx",
        "aiohttp",
        "socket",
        " -m pip",
    ]
):
    deny()
elif COMMAND == "uv" and any(token in tokens for token in ["pip", "tool", "add", "sync"]):
    deny()
elif COMMAND == "go" and (
    any(token in tokens for token in ["get", "install"]) or " mod download " in args
):
    deny()
elif COMMAND == "cargo" and any(token in tokens for token in ["install", "update", "add"]):
    deny()
elif COMMAND == "forge" and "install" in tokens:
    deny()

if ORIGINAL:
    os.execv(ORIGINAL, [ORIGINAL, *sys.argv[1:]])

print("opencode network guard: original command not found for " + COMMAND, file=sys.stderr)
sys.exit(127)
"""


def install_network_guard_wrappers(wrapper_dir: Path, base_path: str) -> Dict[str, Optional[str]]:
    originals: Dict[str, Optional[str]] = {}
    for command in OPENCODE_NETWORK_GUARD_COMMANDS:
        original = shutil.which(command, path=base_path)
        originals[command] = original
        wrapper_path = wrapper_dir / command
        wrapper_path.write_text(network_guard_wrapper(command, original), encoding="utf-8")
        wrapper_path.chmod(0o755)
    return originals


def build_opencode_env(wrapper_dir: Path, *, allowed_root: Path, forbidden_roots: List[Path]) -> Tuple[Dict[str, str], Dict[str, Any]]:
    base_env = os.environ.copy()
    base_path = base_env.get("PATH", "")
    originals = install_network_guard_wrappers(wrapper_dir, base_path)
    config_content = build_opencode_config_content()
    base_env.update(
        {
            "PATH": f"{wrapper_dir}{os.pathsep}{base_path}" if base_path else str(wrapper_dir),
            "OPENCODE_CONFIG_CONTENT": json.dumps(config_content),
            "OPENCODE_DISABLE_MODELS_FETCH": "1",
            "OPENCODE_DISABLE_LSP_DOWNLOAD": "1",
            "OPENCODE_ALLOWED_ROOT": str(allowed_root),
            "OPENCODE_FORBIDDEN_ROOTS": os.pathsep.join(str(path) for path in forbidden_roots),
            "OPENCODE_RESTRICTED_READ_DIRS": os.pathsep.join(sorted(OPENCODE_RESTRICTED_READ_DIR_NAMES)),
            "OPENCODE_RESTRICTED_READ_FILE_SUFFIXES": os.pathsep.join(OPENCODE_RESTRICTED_READ_FILE_SUFFIXES),
        }
    )
    guard_info = {
        "opencode_config_content": config_content,
        "path_wrappers": originals,
        "env": {
            "OPENCODE_DISABLE_MODELS_FETCH": "1",
            "OPENCODE_DISABLE_LSP_DOWNLOAD": "1",
            "OPENCODE_ALLOWED_ROOT": str(allowed_root),
            "OPENCODE_FORBIDDEN_ROOTS": [str(path) for path in forbidden_roots],
            "OPENCODE_RESTRICTED_READ_DIRS": sorted(OPENCODE_RESTRICTED_READ_DIR_NAMES),
            "OPENCODE_RESTRICTED_READ_FILE_SUFFIXES": list(OPENCODE_RESTRICTED_READ_FILE_SUFFIXES),
        },
    }
    return base_env, guard_info


def run_opencode(
    *,
    project_root: Path,
    prompt: str,
    opencode_model: str,
    timeout: int,
    title: str,
    forbidden_roots: Optional[List[Path]] = None,
) -> Dict[str, Any]:
    cmd = [
        "opencode",
        "run",
        "--model",
        opencode_model,
        "--format",
        "json",
        "--dir",
        str(project_root),
        "--title",
        title,
        prompt,
    ]
    started = iso_now()
    network_guard: Dict[str, Any] = {}
    try:
        with tempfile.TemporaryDirectory(prefix="opencode-network-guard-") as wrapper_dir:
            env, network_guard = build_opencode_env(
                Path(wrapper_dir),
                allowed_root=project_root,
                forbidden_roots=forbidden_roots or [],
            )
            completed = subprocess.run(
                cmd,
                cwd=str(project_root),
                capture_output=True,
                text=True,
                timeout=timeout,
                env=env,
            )
        stdout = completed.stdout
        stderr = completed.stderr
        return_code: Optional[int] = completed.returncode
        timed_out = False
        error = None
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout.decode() if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr = exc.stderr.decode() if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        return_code = None
        timed_out = True
        error = f"opencode timeout after {timeout}s"

    events = parse_json_lines(stdout)
    session_id = extract_session_id(events)
    return {
        "command": cmd[:-1] + ["<prompt>"],
        "started": started,
        "ended": iso_now(),
        "returncode": return_code,
        "timed_out": timed_out,
        "error": error,
        "stdout": stdout,
        "stderr": stderr,
        "events": events,
        "session_id": session_id,
        "network_guard": network_guard,
    }


def parse_json_lines(output: str) -> List[Any]:
    events: List[Any] = []
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            events.append({"raw": line})
    return events


def iter_values(obj: Any) -> Iterable[Any]:
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from iter_values(value)
    elif isinstance(obj, list):
        for item in obj:
            yield from iter_values(item)


def extract_session_id(events: Any) -> Optional[str]:
    session_keys = {
        "sessionID",
        "sessionId",
        "session_id",
        "session",
    }
    for obj in iter_values(events):
        if not isinstance(obj, dict):
            continue
        for key in session_keys:
            value = obj.get(key)
            if isinstance(value, str) and value:
                return value
        nested = obj.get("session")
        if isinstance(nested, dict):
            for key in ("id", "sessionID", "sessionId"):
                value = nested.get(key)
                if isinstance(value, str) and value:
                    return value
    return None


def export_opencode_session(session_id: Optional[str], timeout: int = 120) -> Optional[Dict[str, Any]]:
    if not session_id:
        return None
    stdout_path: Optional[Path] = None
    try:
        with tempfile.NamedTemporaryFile(prefix="opencode-export-", suffix=".json", delete=False) as stdout_file:
            stdout_path = Path(stdout_file.name)
            result = subprocess.run(
                ["opencode", "export", session_id],
                stdout=stdout_file,
                stderr=subprocess.PIPE,
                text=True,
                timeout=timeout,
            )
    except subprocess.TimeoutExpired as exc:
        stdout = ""
        if stdout_path and stdout_path.exists():
            stdout = stdout_path.read_text(encoding="utf-8", errors="ignore")
        stderr = exc.stderr.decode() if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        if stdout_path:
            stdout_path.unlink(missing_ok=True)
        return {
            "session_id": session_id,
            "error": f"opencode export timeout after {timeout}s",
            "stdout": stdout,
            "stderr": stderr,
        }

    stdout = ""
    if stdout_path and stdout_path.exists():
        stdout = stdout_path.read_text(encoding="utf-8", errors="ignore")
        stdout_path.unlink(missing_ok=True)
    export: Dict[str, Any] = {
        "session_id": session_id,
        "returncode": result.returncode,
        "stdout": stdout,
        "stderr": result.stderr,
    }
    if stdout:
        try:
            export["json"] = json.loads(stdout)
        except json.JSONDecodeError:
            export["json_error"] = "Failed to parse opencode export stdout as JSON"
    return export


def as_int(value: Any) -> int:
    if value in (None, ""):
        return 0
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def as_float(value: Any) -> float:
    if value in (None, ""):
        return 0.0
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def empty_usage(usage_source: Optional[str] = None) -> Dict[str, Any]:
    return {
        "prompt_tokens": 0,
        "completion_tokens": 0,
        "total_cost": 0.0,
        "usage_source": usage_source,
        "opencode_input_tokens": 0,
        "opencode_output_tokens": 0,
        "opencode_reasoning_tokens": 0,
        "opencode_cache_read_tokens": 0,
        "opencode_cache_write_tokens": 0,
        "opencode_total_tokens": 0,
    }


def usage_from_tokens(tokens: Any, usage_source: str, cost: float = 0.0) -> Dict[str, Any]:
    if not isinstance(tokens, dict):
        return empty_usage()

    input_tokens = as_int(tokens.get("input") or tokens.get("input_tokens") or tokens.get("prompt_tokens"))
    output_tokens = as_int(tokens.get("output") or tokens.get("output_tokens") or tokens.get("completion_tokens"))
    reasoning_tokens = as_int(tokens.get("reasoning") or tokens.get("reasoning_tokens"))
    cache = tokens.get("cache") if isinstance(tokens.get("cache"), dict) else {}
    cache_read_tokens = as_int(cache.get("read") or tokens.get("cache_read") or tokens.get("cached_tokens"))
    cache_write_tokens = as_int(cache.get("write") or tokens.get("cache_write"))
    total_tokens = as_int(tokens.get("total"))
    if not total_tokens:
        total_tokens = input_tokens + output_tokens + reasoning_tokens + cache_read_tokens + cache_write_tokens

    return {
        # Match the legacy SolAgent DB usage shape, where provider prompt_tokens
        # already includes cached prompt tokens and completion_tokens includes reasoning.
        "prompt_tokens": input_tokens + cache_read_tokens + cache_write_tokens,
        "completion_tokens": output_tokens + reasoning_tokens,
        "total_cost": cost,
        "usage_source": usage_source,
        "opencode_input_tokens": input_tokens,
        "opencode_output_tokens": output_tokens,
        "opencode_reasoning_tokens": reasoning_tokens,
        "opencode_cache_read_tokens": cache_read_tokens,
        "opencode_cache_write_tokens": cache_write_tokens,
        "opencode_total_tokens": total_tokens,
    }


def add_usage(left: Dict[str, Any], right: Dict[str, Any], usage_source: str) -> Dict[str, Any]:
    result = empty_usage(usage_source)
    for key in (
        "prompt_tokens",
        "completion_tokens",
        "total_cost",
        "opencode_input_tokens",
        "opencode_output_tokens",
        "opencode_reasoning_tokens",
        "opencode_cache_read_tokens",
        "opencode_cache_write_tokens",
        "opencode_total_tokens",
    ):
        result[key] = left.get(key, 0) + right.get(key, 0)
    return result


def extract_usage(opencode_result: Dict[str, Any], opencode_export: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    export_json = (opencode_export or {}).get("json")
    if isinstance(export_json, dict):
        info = export_json.get("info") or {}
        usage = usage_from_tokens(info.get("tokens"), "opencode_export_info", as_float(info.get("cost")))
        if usage["opencode_total_tokens"]:
            return usage

    usage = empty_usage("opencode_events")
    for event in opencode_result.get("events", []):
        if not isinstance(event, dict):
            continue
        part = event.get("part")
        if not isinstance(part, dict) or part.get("type") != "step-finish":
            continue
        step_usage = usage_from_tokens(part.get("tokens"), "opencode_events")
        if step_usage["opencode_total_tokens"]:
            usage = add_usage(usage, step_usage, "opencode_events")

    if usage["opencode_total_tokens"]:
        return usage
    return empty_usage()


def read_generated_content(path: Optional[Path]) -> str:
    if path and path.exists() and path.is_file():
        return path.read_text(encoding="utf-8", errors="ignore")
    return ""


def choose_generated_file(cur_sol: Path, candidates: List[Path]) -> Optional[Path]:
    resolved_cur = cur_sol.resolve(strict=False)
    for candidate in candidates:
        if candidate.resolve(strict=False) == resolved_cur:
            return candidate
    if len(candidates) == 1:
        return candidates[0]
    if candidates:
        # Prefer the shortest path: usually the intended source tree over nested deps.
        return sorted(candidates, key=lambda p: (len(p.parts), str(p)))[0]
    return None


def _extract_text_from_events(events: Any) -> str:
    """Return assistant text emitted by opencode JSONL events."""
    if not isinstance(events, list):
        return ""

    text_parts: List[str] = []
    for event in events:
        if not isinstance(event, dict):
            continue
        part = event.get("part")
        if not isinstance(part, dict):
            continue
        if part.get("type") == "text" and isinstance(part.get("text"), str):
            text_parts.append(part["text"])

    return "\n\n".join(part for part in text_parts if part.strip())


def _extract_text_from_export(opencode_export: Any) -> str:
    """Return assistant text from `opencode export` JSON, if available."""
    if not isinstance(opencode_export, dict):
        return ""
    export_json = opencode_export.get("json")
    if not isinstance(export_json, dict):
        return ""

    text_parts: List[str] = []
    for message in export_json.get("messages", []):
        if not isinstance(message, dict):
            continue
        info = message.get("info") or {}
        if isinstance(info, dict) and info.get("role") == "user":
            continue
        for part in message.get("parts", []):
            if isinstance(part, dict) and part.get("type") == "text" and isinstance(part.get("text"), str):
                text_parts.append(part["text"])

    return "\n\n".join(part for part in text_parts if part.strip())


def _has_structured_events(events: Any) -> bool:
    return isinstance(events, list) and any(isinstance(event, dict) and event.get("type") for event in events)


def ensure_cur_sol_for_metrics(
    *,
    cur_sol: Path,
    generated_file: Optional[Path],
    opencode_stdout: str,
    opencode_events: Optional[List[Any]] = None,
    opencode_export: Optional[Dict[str, Any]] = None,
) -> Tuple[Optional[Path], str, Optional[str]]:
    if generated_file and generated_file.exists():
        if generated_file.resolve(strict=False) != cur_sol.resolve(strict=False):
            cur_sol.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(generated_file, cur_sol)
            return cur_sol, read_generated_content(cur_sol), str(generated_file)
        return generated_file, read_generated_content(generated_file), str(generated_file)

    response_candidates: List[Tuple[str, str]] = []
    event_text = _extract_text_from_events(opencode_events)
    if event_text:
        response_candidates.append(("opencode_text_events", event_text))
    export_text = _extract_text_from_export(opencode_export)
    if export_text and export_text != event_text:
        response_candidates.append(("opencode_export_text", export_text))
    if not _has_structured_events(opencode_events):
        response_candidates.append(("opencode_stdout_code_block", opencode_stdout))

    for source, response in response_candidates:
        code, ok = extract_solidity_code(response)
        if ok and code.strip():
            cur_sol.parent.mkdir(parents=True, exist_ok=True)
            cur_sol.write_text(code, encoding="utf-8")
            return cur_sol, code, source

    return None, "", None


def run_metrics(cur_t_sol: Path, cur_sol: Path) -> Dict[str, Any]:
    from utils.forge_utils import run_forge_test
    from utils.slither_utils import get_slither_feedback_and_count, run_slither

    test_results: Dict[str, Any]
    gas_fees: Dict[str, Any] = {}
    slither_raw: Optional[Dict[str, Any]] = None
    vuln_count = -1

    try:
        test_results = run_forge_test(str(cur_t_sol))
        gas_fees = test_results.get("gas_fees", {})
    except subprocess.TimeoutExpired:
        test_results = {"compile_error": "Forge test timeout after generation", "gas_fees": {}}
    except Exception as exc:
        test_results = {"compile_error": f"Forge test failed: {exc}", "gas_fees": {}}

    if test_results.get("compile_error"):
        return {
            "test_results": test_results,
            "gas_fees": gas_fees,
            "slither_raw": None,
            "vuln_count": -1,
        }

    try:
        slither_raw = run_slither(str(cur_sol))
        _slither_feedback, vuln_count = get_slither_feedback_and_count(slither_raw)
    except Exception as exc:
        slither_raw = {"error": str(exc)}
        vuln_count = -1

    return {
        "test_results": test_results,
        "gas_fees": gas_fees,
        "slither_raw": slither_raw,
        "vuln_count": vuln_count,
    }


def build_empty_artifact(
    *,
    file_path: str,
    method_len: int,
    total_files: int,
    model_coding: str,
    start_time: str,
) -> Dict[str, Any]:
    now = iso_now()
    return {
        "file_path": file_path,
        "methods": method_len,
        "total_files": total_files,
        "status": 0,
        "model_coding": model_coding,
        "model_summary": None,
        "agent_type": "opencode",
        "coding_messages": [],
        "test_pass": 0,
        "test_fail": 0,
        "test_total": 0,
        "gas_fee_json": {},
        "slither_raw": None,
        "vuln_count": -1,
        "prompt_tokens": 0,
        "completion_tokens": 0,
        "opencode_input_tokens": 0,
        "opencode_output_tokens": 0,
        "opencode_reasoning_tokens": 0,
        "opencode_cache_read_tokens": 0,
        "opencode_cache_write_tokens": 0,
        "opencode_total_tokens": 0,
        "summary_prompt_tokens": 0,
        "summary_completion_tokens": 0,
        "total_cost": 0.0,
        "start_time": start_time,
        "end_time": None,
        "duration": 0.0,
        "create_time": now,
        "update_time": now,
    }


def write_json(path: Path, obj: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp_path.replace(path)


def process_file(
    *,
    file_path: str,
    file_content: list,
    total_files: int,
    index: int,
    path: Path,
    orig_repo: str,
    cur_repo: str,
    test_path_cargo: Dict[str, str],
    system_prompt: str,
    result_dir: Path,
    opencode_model: str,
    model_coding: str,
    opencode_timeout: int,
    overwrite: bool,
) -> Optional[Dict[str, Any]]:
    artifact_path = result_dir / safe_artifact_name(file_path)
    if artifact_path.exists() and not overwrite:
        print(f"[SKIP] Artifact already exists: {artifact_path}")
        return None

    start_time = iso_now()
    orig_sol = Path(os.path.join(orig_repo, file_path))
    cur_sol = Path(remap_path(str(orig_sol), orig_repo, cur_repo))
    cur_t_sol = Path(remap_path(test_path_cargo[file_path], orig_repo, cur_repo))
    project_root = Path(os.path.join(cur_repo, *file_path.split("/")[:2]))
    target_name = cur_sol.name
    file_name = target_name

    method_len = count_methods(file_content)
    artifact = build_empty_artifact(
        file_path=file_path,
        method_len=method_len,
        total_files=total_files,
        model_coding=model_coding,
        start_time=start_time,
    )
    artifact.update(
        {
            "artifact_schema": "opencode_baseline_artifact_v1",
            "index": index,
            "orig_sol": str(orig_sol),
            "cur_sol": str(cur_sol),
            "cur_t_sol": str(cur_t_sol),
            "project_root": str(project_root),
            "opencode_project_root": None,
            "opencode_project_isolated": True,
            "opencode_copied_node_modules": True,
            "opencode_restricted_read_dirs": sorted(OPENCODE_RESTRICTED_READ_DIR_NAMES),
            "opencode_restricted_read_file_suffixes": list(OPENCODE_RESTRICTED_READ_FILE_SUFFIXES),
            "target_name": target_name,
            "opencode_model": opencode_model,
            "opencode_network_guard": {},
            "artifact_path": str(artifact_path),
            "generation_error": None,
            "opencode_session_id": None,
            "opencode_export": None,
            "generated_candidates": [],
            "selected_generated_file": None,
            "selected_generated_source": None,
            "deleted_bak_paths": [],
            "deleted_build_dirs": [],
            "deleted_generator_paths": [],
            "deleted_same_name_paths": [],
            "restore_result": None,
            "usage_source": None,
        }
    )

    backups: List[BackupEntry] = []
    generator_backups: List[BackupEntry] = []
    full_query_with_context = ""
    try:
        deleted_bak_paths = delete_bak_files(project_root)
        deleted_build_dirs = delete_project_build_dirs(project_root)
        artifact["deleted_bak_paths"] = deleted_bak_paths
        artifact["deleted_build_dirs"] = deleted_build_dirs

        generator_paths = find_target_generator_files(project_root, target_name)
        artifact["deleted_generator_paths"] = [str(p) for p in generator_paths]
        generator_backups = backup_and_delete(generator_paths)

        same_name_paths = find_same_name_sol_files(project_root, target_name)
        artifact["deleted_same_name_paths"] = [str(p) for p in same_name_paths]
        backups = backup_and_delete(same_name_paths)
        print(f"[PROCESSING] {index + 1}/{total_files}: {file_path}")
        print(f"[INFO] Deleted {len(deleted_bak_paths)} .bak files under {project_root}")
        print(f"[INFO] Deleted {len(deleted_build_dirs)} build dirs under project config dirs")
        print(f"[INFO] Deleted {len(generator_backups)} target generator files under {project_root}")
        print(f"[INFO] Deleted {len(backups)} same-name files under {project_root}")

        with copy_project_for_opencode(project_root, target_name) as isolated_project_root:
            artifact["opencode_project_root"] = str(isolated_project_root)
            full_query, method_len = build_file_query(file_path, file_content, isolated_project_root, file_name)
            artifact["methods"] = method_len
            full_query_with_context = f"{system_prompt}\n\n{full_query}"

            opencode_result = run_opencode(
                project_root=isolated_project_root,
                prompt=full_query_with_context,
                opencode_model=opencode_model,
                timeout=opencode_timeout,
                title=f"opencode-baseline-{target_name}",
                forbidden_roots=[project_root.parents[0]],
            )
            artifact["opencode_session_id"] = opencode_result.get("session_id")
            artifact["opencode_network_guard"] = opencode_result.get("network_guard", {})

            opencode_export = export_opencode_session(opencode_result.get("session_id"))
            artifact["opencode_export"] = opencode_export

            generated_candidates = find_same_name_sol_files(isolated_project_root, target_name)
            artifact["generated_candidates"] = [str(p) for p in generated_candidates]
            generated_file = choose_generated_file(
                isolated_project_root / project_relative_path(project_root, cur_sol),
                generated_candidates,
            )
            metric_file, generated_content, selected_source = ensure_cur_sol_for_metrics(
                cur_sol=isolated_project_root / project_relative_path(project_root, cur_sol),
                generated_file=generated_file,
                opencode_stdout=opencode_result.get("stdout", ""),
                opencode_events=opencode_result.get("events", []),
                opencode_export=opencode_export,
            )
            metric_file, selected_source = sync_generated_file_to_project(
                isolated_root=isolated_project_root,
                project_root=project_root,
                cur_sol=cur_sol,
                generated_file=metric_file,
                generated_content=generated_content,
                selected_source=selected_source,
            )
        artifact["opencode_session_id"] = opencode_result.get("session_id")
        artifact["opencode_network_guard"] = opencode_result.get("network_guard", {})
        artifact["selected_generated_file"] = str(metric_file) if metric_file else None
        artifact["selected_generated_source"] = selected_source

        usage = extract_usage(opencode_result, opencode_export)
        artifact["prompt_tokens"] = usage["prompt_tokens"]
        artifact["completion_tokens"] = usage["completion_tokens"]
        artifact["total_cost"] = usage["total_cost"]
        artifact["usage_source"] = usage["usage_source"]
        artifact["opencode_input_tokens"] = usage["opencode_input_tokens"]
        artifact["opencode_output_tokens"] = usage["opencode_output_tokens"]
        artifact["opencode_reasoning_tokens"] = usage["opencode_reasoning_tokens"]
        artifact["opencode_cache_read_tokens"] = usage["opencode_cache_read_tokens"]
        artifact["opencode_cache_write_tokens"] = usage["opencode_cache_write_tokens"]
        artifact["opencode_total_tokens"] = usage["opencode_total_tokens"]

        artifact["coding_messages"] = [
            {"role": "user", "content": full_query_with_context},
            {
                "role": "assistant",
                "content": opencode_result.get("stdout", ""),
                "stderr": opencode_result.get("stderr", ""),
                "events": opencode_result.get("events", []),
                "returncode": opencode_result.get("returncode"),
                "timed_out": opencode_result.get("timed_out"),
                "session_id": opencode_result.get("session_id"),
            },
            {
                "role": "tool",
                "name": "opencode_export",
                "content": opencode_export,
            },
            {
                "role": "assistant",
                "content": f"```solidity\n{generated_content}\n```" if generated_content else "",
                "generated_file": str(metric_file) if metric_file else None,
                "generated_source": selected_source,
            },
        ]

        if not metric_file or not metric_file.exists():
            artifact["generation_error"] = "No generated Solidity file was found"
            metrics = {
                "test_results": {"compile_error": artifact["generation_error"], "gas_fees": {}},
                "gas_fees": {},
                "slither_raw": None,
                "vuln_count": -1,
            }
        else:
            metrics = run_metrics(cur_t_sol, metric_file)

        test_results = metrics["test_results"]
        artifact["test_pass"] = test_results.get("passed", 0)
        artifact["test_fail"] = test_results.get("failed", 0)
        artifact["test_total"] = test_results.get("total", 0) or 0
        artifact["gas_fee_json"] = metrics["gas_fees"]
        artifact["slither_raw"] = metrics["slither_raw"]
        artifact["vuln_count"] = metrics["vuln_count"]
        artifact["forge_result"] = test_results
        artifact["status"] = 1
    except Exception as exc:
        artifact["generation_error"] = str(exc)
        artifact["status"] = 1
    finally:
        restore_result: Dict[str, Any] = {}
        try:
            restore_result = restore_backups(project_root, target_name, backups)
        except Exception as restore_exc:
            artifact["restore_error"] = str(restore_exc)
        try:
            restored_generator_paths = restore_exact_backups(generator_backups)
            if restore_result:
                restore_result["restored_generator_paths"] = restored_generator_paths
            else:
                restore_result = {
                    "restored_paths": [],
                    "removed_extra_paths": [],
                    "restored_generator_paths": restored_generator_paths,
                }
        except Exception as restore_exc:
            artifact["generator_restore_error"] = str(restore_exc)
        artifact["restore_result"] = restore_result
        end_time = iso_now()
        artifact["end_time"] = end_time
        artifact["update_time"] = end_time
        try:
            artifact["duration"] = (
                datetime.fromisoformat(end_time) - datetime.fromisoformat(start_time)
            ).total_seconds()
        except Exception:
            artifact["duration"] = 0.0
        write_json(artifact_path, artifact)
        print(f"[ARTIFACT] {artifact_path}")

    return artifact


def iter_selected_items(data: Dict[str, Any], files: Optional[List[str]], start_index: int, limit: Optional[int]):
    items = list(data.items())
    if files:
        wanted = set(files)
        items = [(path, content) for path, content in items if path in wanted]
    if start_index:
        items = items[start_index:]
    if limit is not None:
        items = items[:limit]
    return items


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run OpenCode + MiMo baseline and write per-file JSON artifacts.")
    parser.add_argument("--opencode-model", default=DEFAULT_OPENCODE_MODEL, help="OpenCode model id in provider/model format.")
    parser.add_argument("--model-coding", default=DEFAULT_MODEL_CODING, help="Model name stored in artifacts.")
    parser.add_argument("--result-dir", default=None, help="Override artifact output directory.")
    parser.add_argument("--limit", type=int, default=None, help="Process at most N selected files.")
    parser.add_argument("--start-index", type=int, default=0, help="Start from this dataset index after optional file filtering.")
    parser.add_argument("--file", action="append", dest="files", help="Dataset file_path to process. Can be repeated.")
    parser.add_argument("--overwrite", action="store_true", help="Regenerate artifacts that already exist.")
    parser.add_argument("--opencode-timeout", type=int, default=3600, help="Timeout in seconds for each opencode run.")
    parser.add_argument("--sleep-every", type=int, default=5, help="Sleep after every N processed files; 0 disables.")
    parser.add_argument("--sleep-seconds", type=int, default=20, help="Sleep duration used with --sleep-every.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    path = Path(os.path.dirname(os.path.abspath(__file__)))
    load_env_file(path / ".env")

    orig_repo = require_absolute_orig_repo()
    cur_repo = str(path)
    dataset_path = path / "data" / "dataset.json"
    test_map_path = path / "data" / "test_map_cargo.pkl"
    coding_yaml_path = path / "coding.yaml"

    with dataset_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    with test_map_path.open("rb") as f:
        test_path_cargo = pickle.load(f)
    system_prompt = load_coding_yaml(coding_yaml_path)

    result_dir = (
        Path(args.result_dir)
        if args.result_dir
        else path / "baseline_opencode" / "result" / args.model_coding
    )
    if not result_dir.is_absolute():
        result_dir = path / result_dir

    items = iter_selected_items(data, args.files, args.start_index, args.limit)
    total_files = len(data)
    processed = 0
    print(f"[INFO] Workspace root: {path}")
    print(f"[INFO] ORIG_REPO: {orig_repo}")
    print(f"[INFO] OpenCode model: {args.opencode_model}")
    print(f"[INFO] Artifact dir: {result_dir}")
    print(f"[INFO] Selected files: {len(items)} / {total_files}")

    for local_index, (file_path, file_content) in enumerate(items):
        dataset_index = args.start_index + local_index
        artifact = process_file(
            file_path=file_path,
            file_content=file_content,
            total_files=total_files,
            index=dataset_index,
            path=path,
            orig_repo=orig_repo,
            cur_repo=cur_repo,
            test_path_cargo=test_path_cargo,
            system_prompt=system_prompt,
            result_dir=result_dir,
            opencode_model=args.opencode_model,
            model_coding=args.model_coding,
            opencode_timeout=args.opencode_timeout,
            overwrite=args.overwrite,
        )
        if artifact is not None:
            processed += 1
        if args.sleep_every and processed > 0 and processed % args.sleep_every == 0:
            time.sleep(args.sleep_seconds)

    print("[INFO] OpenCode baseline artifact generation complete")


if __name__ == "__main__":
    main()
