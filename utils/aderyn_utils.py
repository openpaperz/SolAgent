"""Aderyn static-analysis utilities."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, Optional


DEFAULT_ADERYN_BIN = "aderyn"
DEFAULT_ADERYN_TIMEOUT = 300


def resolve_aderyn_bin(aderyn_bin: Optional[str] = None) -> str:
    """Resolve the CLI override, ADERYN_BIN, or the binary on PATH."""
    configured = aderyn_bin or os.environ.get("ADERYN_BIN") or DEFAULT_ADERYN_BIN
    return os.path.expandvars(os.path.expanduser(configured))


def _profile_for_file(sol_path: Path) -> Optional[str]:
    path_text = str(sol_path)
    if "solady" in path_text and "/ext/ithaca/" in path_text:
        return "ithaca"
    if "solady" in path_text and "Transient" in sol_path.name:
        return "post_cancun"
    return None


def run_aderyn(
    sol_file: str,
    project_root: str,
    aderyn_bin: Optional[str] = None,
    timeout: int = DEFAULT_ADERYN_TIMEOUT,
    foundry_profile: Optional[str] = None,
    source_dir: Optional[str] = None,
) -> Dict[str, Any]:
    """Run Aderyn for one Solidity file within its project root."""
    aderyn_bin = resolve_aderyn_bin(aderyn_bin)
    sol_path = Path(sol_file).resolve()
    root_path = Path(project_root).resolve()
    try:
        include_path = sol_path.relative_to(root_path).as_posix()
    except ValueError:
        return {
            "error": f"Solidity file is outside Aderyn project root: {sol_path}",
            "project_root": str(root_path),
        }

    env = os.environ.copy()
    profile = foundry_profile or _profile_for_file(sol_path)
    if profile:
        env["FOUNDRY_PROFILE"] = profile

    with tempfile.TemporaryDirectory(prefix="aderyn_report_") as tmp_dir:
        report_path = Path(tmp_dir) / "report.json"
        cmd = [
            aderyn_bin,
            str(root_path),
            "-i",
            include_path,
            "-o",
            str(report_path),
            "--skip-update-check",
            "--no-snippets",
        ]
        if source_dir:
            cmd.extend(("--src", source_dir))
        try:
            process = subprocess.Popen(
                cmd,
                cwd=str(root_path),
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                start_new_session=True,
            )
            try:
                stdout, stderr = process.communicate(timeout=timeout)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                stdout, stderr = process.communicate()
                return {
                    "error": f"Aderyn execution timeout (>{timeout}s)",
                    "raw_stdout": stdout,
                    "raw_stderr": stderr,
                    "return_code": None,
                    "command": cmd,
                    "project_root": str(root_path),
                    "included_file": include_path,
                    "profile": profile,
                    "source_dir": source_dir,
                }
        except FileNotFoundError:
            return {"error": f"Aderyn binary not found: {aderyn_bin}", "command": cmd}
        except Exception as exc:
            return {"error": f"Aderyn execution failed: {exc}", "command": cmd}

        metadata = {
            "raw_stdout": stdout,
            "raw_stderr": stderr,
            "return_code": process.returncode,
            "command": cmd,
            "project_root": str(root_path),
            "included_file": include_path,
            "profile": profile,
            "source_dir": source_dir,
        }
        if process.returncode != 0:
            return {
                "error": f"Aderyn exited with return code {process.returncode}",
                **metadata,
            }
        if not report_path.exists():
            return {"error": "Aderyn did not produce a JSON report", **metadata}

        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            return {"error": f"Failed to parse Aderyn JSON report: {exc}", **metadata}

        return {"report": report, **metadata}


def get_vulnerability_summary(aderyn_raw: Dict[str, Any]) -> Dict[str, int]:
    if "error" in aderyn_raw:
        return {"error": 1}
    report = aderyn_raw.get("report", {})
    issue_count = report.get("issue_count", {})
    high = issue_count.get("high")
    low = issue_count.get("low")
    if not isinstance(high, int):
        high = len(report.get("high_issues", {}).get("issues", []))
    if not isinstance(low, int):
        low = len(report.get("low_issues", {}).get("issues", []))
    return {"High": high, "Low": low}


def count_vulnerabilities(aderyn_raw: Dict[str, Any]) -> int:
    if "error" in aderyn_raw:
        return 0
    summary = get_vulnerability_summary(aderyn_raw)
    return int(summary.get("High", 0)) + int(summary.get("Low", 0))


def get_sloc(aderyn_raw: Dict[str, Any]) -> Optional[int]:
    if "error" in aderyn_raw:
        return None
    value = aderyn_raw.get("report", {}).get("files_summary", {}).get("total_sloc")
    return value if isinstance(value, int) and value > 0 else None
