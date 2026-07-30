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
            for relative in required_paths():
                source = ROOT / relative
                destination = fixture_root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
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


if __name__ == "__main__":
    unittest.main()
