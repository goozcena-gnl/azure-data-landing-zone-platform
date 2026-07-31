#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from tool_versions import check_repository, parse_manifest, required_paths  # noqa: E402


class ToolVersionTests(unittest.TestCase):
    def make_fixture(self, destination: Path) -> None:
        for relative in required_paths():
            source = ROOT / relative
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

    def test_manifest_parsing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "versions.env"
            path.write_text(
                "# comment\nTERRAFORM_VERSION=1.15.8\n"
                "DEVCONTAINER_DIGEST=sha256:" + "a" * 64 + "\n",
                encoding="utf-8",
            )
            self.assertEqual(parse_manifest(path)["TERRAFORM_VERSION"], "1.15.8")

    def test_manifest_rejects_shell_syntax(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "versions.env"
            path.write_text("BAD=$(command)\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                parse_manifest(path)

    def test_repository_versions_are_aligned(self) -> None:
        self.assertEqual(check_repository(ROOT), [])

    def test_version_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture_root = Path(temporary)
            self.make_fixture(fixture_root)
            pre_commit = fixture_root / ".pre-commit-config.yaml"
            pre_commit.write_text(
                pre_commit.read_text(encoding="utf-8").replace(
                    "adrienverge/yamllint\n    rev: v1.38.0",
                    "adrienverge/yamllint\n    rev: v1.37.1",
                ),
                encoding="utf-8",
            )
            errors = check_repository(fixture_root)
            self.assertTrue(any("YAMLLINT_VERSION drift" in error for error in errors))

    def mutate_validate_checksum(self, replacement: str) -> list[str]:
        with tempfile.TemporaryDirectory() as temporary:
            fixture_root = Path(temporary)
            self.make_fixture(fixture_root)
            path = fixture_root / ".github/workflows/validate.yml"
            text = path.read_text(encoding="utf-8")
            text = text.replace(
                "  TERRAFORM_SHA256: " + "d25ce7b6902013ad905db3d2eab0be4cd905887fe88b81a6171b8d5503c31f3d",
                replacement,
            )
            path.write_text(text, encoding="utf-8")
            return check_repository(fixture_root)

    def test_stale_terraform_checksum_is_detected(self) -> None:
        errors = self.mutate_validate_checksum("  TERRAFORM_SHA256: " + "a" * 64)
        self.assertTrue(any("TERRAFORM_LINUX_AMD64_SHA256 drift" in item for item in errors))

    def test_missing_terraform_checksum_is_detected(self) -> None:
        errors = self.mutate_validate_checksum("  REMOVED_TERRAFORM_SHA256: " + "a" * 64)
        self.assertTrue(any("found 0" in item for item in errors))

    def test_duplicate_terraform_checksum_is_detected(self) -> None:
        checksum = "  TERRAFORM_SHA256: d25ce7b6902013ad905db3d2eab0be4cd905887fe88b81a6171b8d5503c31f3d"
        errors = self.mutate_validate_checksum(checksum + "\n" + checksum)
        self.assertTrue(any("found 2" in item for item in errors))

    def test_comment_lookalike_does_not_count_as_checksum(self) -> None:
        errors = self.mutate_validate_checksum(
            "  # TERRAFORM_SHA256: d25ce7b6902013ad905db3d2eab0be4cd905887fe88b81a6171b8d5503c31f3d"
        )
        self.assertTrue(any("found 0" in item for item in errors))

    def test_unrelated_action_sha_does_not_count_as_terraform_checksum(self) -> None:
        errors = self.mutate_validate_checksum(
            "  REMOVED_TERRAFORM_SHA256: 3d3c42e5aac5ba805825da76410c181273ba90b1"
        )
        self.assertTrue(any("found 0" in item for item in errors))


if __name__ == "__main__":
    unittest.main()
