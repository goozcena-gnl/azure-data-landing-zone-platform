#!/usr/bin/env python3
from __future__ import annotations
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pattern = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
errors: list[str] = []
listed = subprocess.run(
    [
        "git",
        "-C",
        str(root),
        "ls-files",
        "--cached",
        "--others",
        "--exclude-standard",
        "-z",
        "--",
        "*.md",
    ],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
)
if listed.returncode == 0:
    paths = (
        root / relative.decode("utf-8")
        for relative in listed.stdout.split(b"\0")
        if relative
    )
else:
    # Release archives intentionally contain no .git directory.
    paths = (
        path
        for path in sorted(root.rglob("*.md"))
        if ".git" not in path.relative_to(root).parts
    )
for path in paths:
    text = path.read_text(encoding="utf-8")
    for target in pattern.findall(text):
        target = target.strip().split("#", 1)[0]
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        candidate = (path.parent / target).resolve()
        if not candidate.exists():
            errors.append(f"{path.relative_to(root)} -> {target}")
if errors:
    print("Broken local Markdown links:")
    print("\n".join(f"- {item}" for item in errors))
    raise SystemExit(1)
print("Local Markdown links: PASS")
