#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
import importlib.util
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "tests"))

from file_inventory import InventoryError, inventory_files  # noqa: E402
from repository_policy import check_repository_policy  # noqa: E402
from tool_versions import required_paths  # noqa: E402

DOC_LINK_SPEC = importlib.util.spec_from_file_location(
    "check_doc_links", ROOT / "scripts" / "check-doc-links.py"
)
assert DOC_LINK_SPEC and DOC_LINK_SPEC.loader
DOC_LINK_MODULE = importlib.util.module_from_spec(DOC_LINK_SPEC)
DOC_LINK_SPEC.loader.exec_module(DOC_LINK_MODULE)
check_document_links = DOC_LINK_MODULE.check_document_links


def relative_names(root: Path) -> set[str]:
    return {path.relative_to(root).as_posix() for path in inventory_files(root)}


def copy_policy_fixture(destination: Path) -> None:
    for relative in required_paths():
        source = ROOT / relative
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


class FileInventoryTests(unittest.TestCase):
    def test_exact_repository_uses_index_and_excludes_ignored_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="inventory exact repo ") as temporary:
            root = Path(temporary)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / ".gitignore").write_text("ignored.txt\n", encoding="utf-8")
            (root / "tracked.txt").write_text("tracked\n", encoding="utf-8")
            (root / "untracked.txt").write_text("untracked\n", encoding="utf-8")
            (root / "ignored.txt").write_text("ignored\n", encoding="utf-8")
            subprocess.run(
                ["git", "-C", str(root), "add", ".gitignore", "tracked.txt"], check=True
            )
            names = relative_names(root)
            self.assertIn("tracked.txt", names)
            self.assertIn("untracked.txt", names)
            self.assertNotIn("ignored.txt", names)

    def test_clean_archive_outside_git_uses_filesystem(self) -> None:
        with tempfile.TemporaryDirectory(prefix="inventory archive ") as temporary:
            root = Path(temporary)
            (root / "ordinary.txt").write_text("content\n", encoding="utf-8")
            self.assertEqual(relative_names(root), {"ordinary.txt"})

    def test_unrelated_ignored_parent_cannot_hide_archive_violations(self) -> None:
        with tempfile.TemporaryDirectory(prefix="inventory parent ") as temporary:
            parent = Path(temporary)
            subprocess.run(["git", "init", "-q", str(parent)], check=True)
            (parent / ".gitignore").write_text("archive*/\n", encoding="utf-8")
            archive = parent / "archive ünicode path"
            archive.mkdir()
            copy_policy_fixture(archive)
            marker = b"-----BEGIN " + b"PRIVATE KEY-----"
            (archive / "injected.pem").write_bytes(marker + b"\nfixture\n")
            broken = archive / "docs" / "injected-broken.md"
            broken.write_text("[missing](does-not-exist.md)\n", encoding="utf-8")
            ignored_generated = archive / "ignored-generated.tmp"
            ignored_generated.write_text("must remain visible\n", encoding="utf-8")
            nested = archive / "nested" / ".git"
            nested.mkdir(parents=True)
            (nested / "config").write_text("metadata\n", encoding="utf-8")

            names = relative_names(archive)
            self.assertIn("injected.pem", names)
            self.assertIn("ignored-generated.tmp", names)
            self.assertNotIn("nested/.git/config", names)
            self.assertTrue(
                any("private key marker: injected.pem" in error for error in check_repository_policy(archive))
            )
            self.assertTrue(
                any("injected-broken.md -> does-not-exist.md" in error for error in check_document_links(archive))
            )
            self.assertTrue(
                any("nested Git metadata" in error for error in check_repository_policy(archive))
            )

    def test_missing_git_uses_filesystem(self) -> None:
        with tempfile.TemporaryDirectory(prefix="inventory no git ") as temporary:
            root = Path(temporary)
            (root / "visible.txt").write_text("visible\n", encoding="utf-8")
            with mock.patch("file_inventory.shutil.which", return_value=None):
                self.assertEqual(relative_names(root), {"visible.txt"})

    def test_not_a_repository_uses_filesystem(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[], returncode=128, stdout=b"", stderr=b"fatal: not a git repository\n"
        )
        with tempfile.TemporaryDirectory(prefix="inventory not repo ") as temporary:
            root = Path(temporary)
            (root / "visible.txt").write_text("visible\n", encoding="utf-8")
            with mock.patch("file_inventory.shutil.which", return_value="git"), mock.patch(
                "file_inventory.subprocess.run", return_value=completed
            ):
                self.assertEqual(relative_names(root), {"visible.txt"})

    def test_unexpected_identity_error_fails_closed(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[], returncode=2, stdout=b"", stderr=b"unexpected failure\n"
        )
        with tempfile.TemporaryDirectory(prefix="inventory git error ") as temporary:
            with mock.patch("file_inventory.shutil.which", return_value="git"), mock.patch(
                "file_inventory.subprocess.run", return_value=completed
            ):
                with self.assertRaisesRegex(InventoryError, "identity check failed"):
                    inventory_files(Path(temporary))

    def test_git_execution_error_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="inventory execution error ") as temporary:
            with mock.patch("file_inventory.shutil.which", return_value="git"), mock.patch(
                "file_inventory.subprocess.run", side_effect=OSError("execution denied")
            ):
                with self.assertRaisesRegex(InventoryError, "cannot execute Git"):
                    inventory_files(Path(temporary))

    def test_exact_repository_ls_files_error_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="inventory ls error ") as temporary:
            root = Path(temporary).resolve()
            identity = subprocess.CompletedProcess(
                args=[], returncode=0, stdout=f"{root}\n".encode(), stderr=b""
            )
            failure = subprocess.CompletedProcess(
                args=[], returncode=3, stdout=b"", stderr=b"index unavailable\n"
            )
            with mock.patch("file_inventory.shutil.which", return_value="git"), mock.patch(
                "file_inventory.subprocess.run", side_effect=[identity, failure]
            ):
                with self.assertRaisesRegex(InventoryError, "file inventory failed"):
                    inventory_files(root)


if __name__ == "__main__":
    unittest.main()
