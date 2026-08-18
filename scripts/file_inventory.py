#!/usr/bin/env python3
"""Deterministic Git-checkout and release-archive file inventory."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


class InventoryError(RuntimeError):
    """Raised when Git identifies the root but cannot enumerate it safely."""


def _inside(root: Path, candidate: Path) -> bool:
    try:
        candidate.relative_to(root)
    except ValueError:
        return False
    return True


def _filesystem_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if ".git" in relative.parts:
            continue
        resolved = path.resolve()
        if not _inside(root, resolved):
            raise InventoryError(f"inventory path escapes root: {relative.as_posix()}")
        if resolved.is_file():
            files.append(path)
    return sorted(files, key=lambda item: item.relative_to(root).as_posix())


def inventory_files(candidate_root: Path) -> list[Path]:
    """Return repository-index files only for the exact root, else archive files."""

    root = candidate_root.resolve()
    git = shutil.which("git")
    if git is None:
        return _filesystem_files(root)

    try:
        top_level = subprocess.run(
            [git, "-C", str(root), "rev-parse", "--show-toplevel"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as error:
        raise InventoryError(f"cannot execute Git repository identity check: {error}") from error

    if top_level.returncode != 0:
        message = top_level.stderr.decode("utf-8", errors="replace").strip()
        if "not a git repository" in message.lower():
            return _filesystem_files(root)
        raise InventoryError(
            f"Git repository identity check failed with exit {top_level.returncode}: "
            f"{message or 'no diagnostic'}"
        )

    reported_text = top_level.stdout.decode("utf-8", errors="surrogateescape").strip()
    if not reported_text:
        raise InventoryError("Git repository identity check returned an empty top level")
    reported = Path(reported_text).resolve()
    if reported != root:
        return _filesystem_files(root)

    listed = subprocess.run(
        [
            git,
            "-C",
            str(root),
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard",
            "-z",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if listed.returncode != 0:
        message = listed.stderr.decode("utf-8", errors="replace").strip()
        raise InventoryError(
            f"Git file inventory failed with exit {listed.returncode}: "
            f"{message or 'no diagnostic'}"
        )

    files: list[Path] = []
    for encoded in listed.stdout.split(b"\0"):
        if not encoded:
            continue
        relative = Path(encoded.decode("utf-8", errors="surrogateescape"))
        path = root / relative
        resolved = path.resolve()
        if not _inside(root, resolved):
            raise InventoryError(f"Git inventory path escapes root: {relative.as_posix()}")
        if resolved.is_file():
            files.append(path)
    return files
