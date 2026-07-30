#!/usr/bin/env python3
"""Parse the tool manifest and detect version drift across active config."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


MANIFEST_RELATIVE_PATH = Path("tools/versions.env")
ASSIGNMENT = re.compile(r"^([A-Z][A-Z0-9_]*)=([A-Za-z0-9][A-Za-z0-9._:+-]*)$")


@dataclass(frozen=True)
class VersionRule:
    key: str
    path: str
    pattern: str
    prefix: str = ""


RULES = (
    VersionRule("TERRAFORM_VERSION", ".github/workflows/validate.yml", r"TERRAFORM_VERSION:\s*([0-9.]+)"),
    VersionRule("TERRAFORM_VERSION", ".github/workflows/deploy-lab.yml", r"TERRAFORM_VERSION:\s*([0-9.]+)"),
    VersionRule("TERRAFORM_VERSION", ".github/workflows/destroy-lab.yml", r"TERRAFORM_VERSION:\s*([0-9.]+)"),
    VersionRule("TERRAFORM_VERSION", ".azuredevops/azure-pipelines.yml", r"terraformVersion:\s*'([0-9.]+)'"),
    VersionRule("TERRAFORM_VERSION", "README.md", r"Terraform `([0-9.]+)`"),
    VersionRule("TFLINT_VERSION", ".github/workflows/validate.yml", r"tflint_version:\s*v([0-9.]+)"),
    VersionRule("TFLINT_VERSION", "README.md", r"TFLint `([0-9.]+)`"),
    VersionRule("TFLINT_AZURERM_PLUGIN_VERSION", ".tflint.hcl", r'version\s*=\s*"([0-9.]+)"'),
    VersionRule("CHECKOV_VERSION", "requirements-dev.txt", r"(?m)^checkov==([0-9.]+)$"),
    VersionRule("CHECKOV_VERSION", "requirements-dev.lock", r"(?m)^checkov==([0-9.]+) \\$"),
    VersionRule("CHECKOV_VERSION", ".github/workflows/validate.yml", r"checkov==([0-9.]+)"),
    VersionRule("CHECKOV_VERSION", ".azuredevops/azure-pipelines.yml", r"checkov==([0-9.]+)"),
    VersionRule("YAMLLINT_VERSION", "requirements-dev.txt", r"(?m)^yamllint==([0-9.]+)$"),
    VersionRule("YAMLLINT_VERSION", "requirements-dev.lock", r"(?m)^yamllint==([0-9.]+) \\$"),
    VersionRule("YAMLLINT_VERSION", ".github/workflows/validate.yml", r"yamllint==([0-9.]+)"),
    VersionRule("YAMLLINT_VERSION", ".pre-commit-config.yaml", r"repo: https://github.com/adrienverge/yamllint\s+rev: v([0-9.]+)"),
    VersionRule("SHELLCHECK_PY_PACKAGE_VERSION", "requirements-dev.txt", r"(?m)^shellcheck-py==([0-9.]+)$"),
    VersionRule("SHELLCHECK_PY_PACKAGE_VERSION", "requirements-dev.lock", r"(?m)^shellcheck-py==([0-9.]+) \\$"),
    VersionRule("SHELLCHECK_PY_PACKAGE_VERSION", ".github/workflows/validate.yml", r"shellcheck-py==([0-9.]+)"),
    VersionRule("MARKDOWNLINT_VERSION", ".github/workflows/validate.yml", r"markdownlint-cli@([0-9.]+)"),
    VersionRule("MARKDOWNLINT_VERSION", ".pre-commit-config.yaml", r"repo: https://github.com/igorshubovych/markdownlint-cli\s+rev: v([0-9.]+)"),
    VersionRule("PRE_COMMIT_VERSION", "requirements-dev.txt", r"(?m)^pre-commit==([0-9.]+)$"),
    VersionRule("PRE_COMMIT_VERSION", "requirements-dev.lock", r"(?m)^pre-commit==([0-9.]+) \\$"),
    VersionRule("AZURERM_PROVIDER_VERSION", "infra/bootstrap/.terraform.lock.hcl", r'provider "registry\.terraform\.io/hashicorp/azurerm" \{\s+version\s+=\s+"([0-9.]+)"'),
    VersionRule("AZURERM_PROVIDER_VERSION", "infra/landing-zone/.terraform.lock.hcl", r'provider "registry\.terraform\.io/hashicorp/azurerm" \{\s+version\s+=\s+"([0-9.]+)"'),
    VersionRule("RANDOM_PROVIDER_VERSION", "infra/bootstrap/.terraform.lock.hcl", r'provider "registry\.terraform\.io/hashicorp/random" \{\s+version\s+=\s+"([0-9.]+)"'),
    VersionRule("RANDOM_PROVIDER_VERSION", "infra/landing-zone/.terraform.lock.hcl", r'provider "registry\.terraform\.io/hashicorp/random" \{\s+version\s+=\s+"([0-9.]+)"'),
    VersionRule("TERRAFORM_VERSION", "docs/local-development.md", r"\| Terraform \| ([0-9.]+) \|"),
    VersionRule("TFLINT_VERSION", "docs/local-development.md", r"\| TFLint \| ([0-9.]+) \|"),
    VersionRule("TFLINT_AZURERM_PLUGIN_VERSION", "docs/local-development.md", r"\| TFLint AzureRM rules \| ([0-9.]+) \|"),
    VersionRule("PYTHON_VERSION", "docs/local-development.md", r"\| Python \| ([0-9.]+) \|"),
    VersionRule("NODE_VERSION", "docs/local-development.md", r"\| Node\.js \| ([0-9.]+) \|"),
    VersionRule("CHECKOV_VERSION", "docs/local-development.md", r"\| Checkov \| ([0-9.]+) \|"),
    VersionRule("YAMLLINT_VERSION", "docs/local-development.md", r"\| Yamllint \| ([0-9.]+) \|"),
    VersionRule("SHELLCHECK_VERSION", "docs/local-development.md", r"\| ShellCheck \| ([0-9.]+) \|"),
    VersionRule("MARKDOWNLINT_VERSION", "docs/local-development.md", r"\| Markdownlint CLI \| ([0-9.]+) \|"),
    VersionRule("PRE_COMMIT_VERSION", "docs/local-development.md", r"\| pre-commit \| ([0-9.]+) \|"),
    VersionRule("HELM_VERSION", "docs/local-development.md", r"\| Helm \| ([0-9.]+) \|"),
    VersionRule("KUBECTL_VERSION", "docs/local-development.md", r"\| kubectl \| ([0-9.]+) \|"),
    VersionRule("KUBECONFORM_VERSION", "docs/local-development.md", r"\| Kubeconform \| ([0-9.]+) \|"),
    VersionRule("JQ_VERSION", "docs/local-development.md", r"\| jq \| ([0-9.]+) \|"),
    VersionRule("BATS_VERSION", "docs/local-development.md", r"\| Bats Core \| ([0-9.]+) \|"),
    VersionRule("AZURERM_PROVIDER_VERSION", "docs/local-development.md", r"AzureRM ([0-9]+(?:\.[0-9]+)+)"),
    VersionRule("RANDOM_PROVIDER_VERSION", "docs/local-development.md", r"Random\s+([0-9]+(?:\.[0-9]+)+)"),
    VersionRule("DEVCONTAINER_UBUNTU_AMD64_DIGEST", ".devcontainer/Dockerfile", r"^FROM ubuntu:24\.04@(sha256:[0-9a-f]{64})$", prefix=""),
)


def parse_manifest(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = ASSIGNMENT.fullmatch(line)
        if not match:
            raise ValueError(f"{path}:{line_number}: invalid manifest assignment")
        key, value = match.groups()
        if key in values:
            raise ValueError(f"{path}:{line_number}: duplicate key {key}")
        values[key] = value
    if not values:
        raise ValueError(f"{path}: manifest is empty")
    return values


def required_paths() -> set[Path]:
    return {MANIFEST_RELATIVE_PATH, *(Path(rule.path) for rule in RULES)}


def check_repository(root: Path) -> list[str]:
    errors: list[str] = []
    try:
        versions = parse_manifest(root / MANIFEST_RELATIVE_PATH)
    except (OSError, ValueError) as error:
        return [str(error)]

    for rule in RULES:
        expected = versions.get(rule.key)
        if expected is None:
            errors.append(f"manifest is missing {rule.key}")
            continue
        path = root / rule.path
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as error:
            errors.append(f"cannot read {rule.path}: {error}")
            continue
        matches = re.findall(rule.pattern, text, flags=re.MULTILINE)
        if len(matches) != 1:
            errors.append(
                f"{rule.path}: expected exactly one {rule.key} version, found {len(matches)}"
            )
            continue
        observed = f"{rule.prefix}{matches[0]}"
        if observed != expected:
            errors.append(
                f"{rule.path}: {rule.key} drift: expected {expected}, found {observed}"
            )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = check_repository(args.root.resolve())
    if errors:
        print("Tool-version policy: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Tool-version policy: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
