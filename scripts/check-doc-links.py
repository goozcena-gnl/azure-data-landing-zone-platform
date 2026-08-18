#!/usr/bin/env python3
from __future__ import annotations
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from file_inventory import InventoryError, inventory_files  # noqa: E402


PATTERN = re.compile(r"\[[^\]]+\]\(([^)]+)\)")


def check_document_links(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    try:
        paths = [path for path in inventory_files(root) if path.suffix.lower() == ".md"]
    except InventoryError as error:
        return [str(error)]
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for target in PATTERN.findall(text):
            target = target.strip().split("#", 1)[0]
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            candidate = (path.parent / target).resolve()
            if not candidate.exists():
                errors.append(f"{path.relative_to(root)} -> {target}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    errors = check_document_links(parser.parse_args().root)
    if errors:
        print("Broken local Markdown links:")
        print("\n".join(f"- {item}" for item in errors))
        return 1
    print("Local Markdown links: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
