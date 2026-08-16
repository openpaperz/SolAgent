from __future__ import annotations

import fcntl
import hashlib
import os
import shutil
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Sequence

from testing.generate_eval_tests import _replace_path_with_backup, _restore_path


@dataclass(frozen=True)
class PathSnapshot:
    exists: bool
    kind: str
    digest: str | None


class OverlayRestoreError(RuntimeError):
    pass


def _digest_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _digest_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _digest_dir(path: Path) -> str:
    digest = hashlib.sha256()
    for child in sorted(path.rglob("*"), key=lambda item: item.relative_to(path).as_posix()):
        rel = child.relative_to(path).as_posix().encode("utf-8")
        stat = child.lstat()
        digest.update(rel)
        digest.update(str(stat.st_mode).encode("ascii"))
        if child.is_symlink():
            digest.update(b"symlink")
            digest.update(os.readlink(child).encode("utf-8", errors="surrogateescape"))
        elif child.is_file():
            digest.update(b"file")
            digest.update(_digest_file(child).encode("ascii"))
        elif child.is_dir():
            digest.update(b"dir")
    return digest.hexdigest()


def snapshot_path(path: Path) -> PathSnapshot:
    if not path.exists() and not path.is_symlink():
        return PathSnapshot(False, "missing", None)
    if path.is_symlink():
        return PathSnapshot(True, "symlink", _digest_bytes(os.readlink(path).encode("utf-8", errors="surrogateescape")))
    if path.is_dir():
        return PathSnapshot(True, "dir", _digest_dir(path))
    if path.is_file():
        return PathSnapshot(True, "file", _digest_file(path))
    return PathSnapshot(True, "other", _digest_bytes(str(path.lstat()).encode("utf-8")))


def _lock_path(root: Path, feedback_test_path: Path) -> Path:
    try:
        key = feedback_test_path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        key = feedback_test_path.resolve().as_posix()
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    stem = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in feedback_test_path.name)
    return root / "testing" / "eval" / ".locks" / f"{stem}.{digest}.lock"


def _verify_snapshots(before: dict[Path, PathSnapshot]) -> list[str]:
    errors: list[str] = []
    for path, expected in before.items():
        actual = snapshot_path(path)
        if actual != expected:
            errors.append(
                f"{path} restore mismatch: expected {expected.kind}/{expected.digest}, "
                f"got {actual.kind}/{actual.digest}"
            )
    return errors


@contextmanager
def locked_path_replacements(
    root: Path,
    feedback_test_path: Path,
    replacements: Sequence[tuple[Path, Path]],
    tmpdir: Path,
) -> Iterator[None]:
    """Serialize eval overlays for one feedback test and verify exact restoration."""

    lock_path = _lock_path(root, feedback_test_path)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_file = lock_path.open("a+", encoding="utf-8")
    backups: list[tuple[Path, bool, Path]] = []
    snapshots: dict[Path, PathSnapshot] = {}
    errors: list[str] = []
    try:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        snapshots = {path: snapshot_path(path) for path, _replacement in replacements}
        for path, replacement in replacements:
            backups.append((path, *_replace_path_with_backup(path, replacement, tmpdir)))
        yield
    finally:
        for path, existed, backup in reversed(backups):
            try:
                _restore_path(path, existed, backup)
            except Exception as exc:  # noqa: BLE001
                errors.append(f"{path} restore failed: {exc}")
                if existed and backup.exists():
                    try:
                        if path.exists() or path.is_symlink():
                            if path.is_dir() and not path.is_symlink():
                                shutil.rmtree(path)
                            else:
                                path.unlink()
                        if backup.is_dir():
                            shutil.copytree(backup, path)
                        else:
                            path.parent.mkdir(parents=True, exist_ok=True)
                            shutil.copy2(backup, path)
                    except Exception as retry_exc:  # noqa: BLE001
                        errors.append(f"{path} backup restore retry failed: {retry_exc}")
        errors.extend(_verify_snapshots(snapshots))
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        finally:
            lock_file.close()
        if errors:
            raise OverlayRestoreError("; ".join(errors))
