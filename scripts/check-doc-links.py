#!/usr/bin/env python3
from __future__ import annotations
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pattern = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
errors: list[str] = []
for path in root.rglob("*.md"):
    if ".git" in path.parts:
        continue
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
