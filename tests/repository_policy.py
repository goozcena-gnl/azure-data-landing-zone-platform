#!/usr/bin/env python3
from __future__ import annotations
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
errors: list[str] = []
private_marker = b"-----BEGIN " + b"PRIVATE KEY-----"
openssh_marker = b"-----BEGIN " + b"OPENSSH PRIVATE KEY-----"
for path in root.rglob("*"):
    rel = path.relative_to(root)
    rel_s = rel.as_posix()
    if path.is_dir() and path.name == ".git" and rel_s != ".git":
        errors.append(f"nested Git metadata: {rel_s}")
    if path.name.endswith("Zone.Identifier") or ":Zone.Identifier" in path.name:
        errors.append(f"Windows ADS metadata: {rel_s}")
    if path.is_file():
        if path.stat().st_size > 10 * 1024 * 1024:
            errors.append(f"file larger than 10 MiB: {rel_s}")
        if path.name in {"terraform.tfstate", "terraform.tfstate.backup", "terraform.tfvars", "backend.hcl", "azure.json"}:
            errors.append(f"forbidden local file: {rel_s}")
        if re.search(r"(^|/)(terraform|kubectl|helm|inframap)(\.exe)?$", rel_s):
            errors.append(f"committed tool binary: {rel_s}")
        try: data=path.read_bytes()[:4096]
        except OSError: continue
        if private_marker in data or openssh_marker in data:
            errors.append(f"private key marker: {rel_s}")

sha_action = re.compile(
    r"^\s*uses:\s+[^./][^@\s]*@[0-9a-f]{40}"
    r"\s+#\s+v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z._-]+)?\s*$"
)
action_files = sorted((root / ".github" / "workflows").glob("*.y*ml"))
actions_root = root / ".github" / "actions"
if actions_root.is_dir():
    action_files.extend(sorted(actions_root.rglob("*.y*ml")))

for action_file in action_files:
    for line_number, line in enumerate(action_file.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("uses:") and not stripped.startswith("uses: ./"):
            if not sha_action.match(line):
                errors.append(
                    "GitHub Action must use a full commit SHA and an adjacent "
                    f"semantic-version comment: {action_file.relative_to(root)}:{line_number}"
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

if errors:
    print("Repository policy: FAIL")
    print("\n".join(f"- {item}" for item in errors))
    raise SystemExit(1)
print("Repository policy: PASS")
