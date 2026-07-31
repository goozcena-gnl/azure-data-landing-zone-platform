#!/usr/bin/env python3
from __future__ import annotations
import argparse
import re
import sys
from pathlib import Path

DEFAULT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(DEFAULT_ROOT / "scripts"))
from file_inventory import InventoryError, inventory_files  # noqa: E402
from tool_versions import check_repository  # noqa: E402

private_marker = b"-----BEGIN " + b"PRIVATE KEY-----"
openssh_marker = b"-----BEGIN " + b"OPENSSH PRIVATE KEY-----"


def check_repository_policy(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    try:
        paths = inventory_files(root)
    except InventoryError as error:
        return [str(error)]
    for path in paths:
        rel = path.relative_to(root)
        rel_s = rel.as_posix()
        if path.name.endswith("Zone.Identifier") or ":Zone.Identifier" in path.name:
            errors.append(f"Windows ADS metadata: {rel_s}")
        if path.stat().st_size > 10 * 1024 * 1024:
            errors.append(f"file larger than 10 MiB: {rel_s}")
        if path.name in {"terraform.tfstate", "terraform.tfstate.backup", "terraform.tfvars", "backend.hcl", "azure.json"}:
            errors.append(f"forbidden local file: {rel_s}")
        if re.search(r"(^|/)(terraform|kubectl|helm|inframap)(\.exe)?$", rel_s):
            errors.append(f"committed tool binary: {rel_s}")
        try:
            data = path.read_bytes()[:4096]
        except OSError:
            continue
        if private_marker in data or openssh_marker in data:
            errors.append(f"private key marker: {rel_s}")

    for path in root.rglob(".git"):
        if path != root / ".git":
            errors.append(f"nested Git metadata: {path.relative_to(root).as_posix()}")

    sha_action = re.compile(r"^\s*uses:\s+[^./][^@\s]*@([0-9a-f]{40})(?:\s+#.*)?$")
    for workflow in (root / ".github" / "workflows").glob("*.yml"):
        for line_number, line in enumerate(workflow.read_text(encoding="utf-8").splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("uses:") and not stripped.startswith("uses: ./"):
                if not sha_action.match(line):
                    errors.append(
                        f"GitHub Action is not pinned to a full commit SHA: "
                        f"{workflow.relative_to(root)}:{line_number}"
                    )

    yamllint_pin = re.compile(r"^\s*yamllint==(\d+\.\d+\.\d+)(?:\s*\\)?\s*$", re.MULTILINE)
    yamllint_versions: dict[str, str] = {}
    for relative_path in ("requirements-dev.txt", ".github/workflows/validate.yml"):
        matches = yamllint_pin.findall((root / relative_path).read_text(encoding="utf-8"))
        if len(matches) != 1:
            errors.append(
                f"expected exactly one Yamllint version pin in {relative_path}, "
                f"found {len(matches)}"
            )
        else:
            yamllint_versions[relative_path] = matches[0]

    if len(yamllint_versions) == 2 and len(set(yamllint_versions.values())) != 1:
        errors.append(
            "Yamllint version mismatch: "
            + ", ".join(f"{path}={version}" for path, version in yamllint_versions.items())
        )

    errors.extend(check_repository(root))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    errors = check_repository_policy(parser.parse_args().root)
    if errors:
        print("Repository policy: FAIL")
        print("\n".join(f"- {item}" for item in errors))
        return 1
    print("Repository policy: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
