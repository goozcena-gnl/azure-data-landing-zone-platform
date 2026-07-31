#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class LocalPolicyClaimTests(unittest.TestCase):
    def test_support_and_reproducibility_disclosures(self) -> None:
        guide = (ROOT / "docs/local-development.md").read_text(encoding="utf-8")
        normalized = " ".join(guide.split())
        for required in (
            "x86-64 Ubuntu 24.04 LTS",
            "partially reproducible overall",
            "not byte-for-byte reproducible",
            "apt repository metadata",
            "npm transitive dependency resolution",
            "pre-commit environment creation",
            "TFLint plugin initialization",
            "Trivy database",
            "byte-for-byte reproducibility is independently tested",
        ):
            self.assertIn(required, normalized)
        self.assertNotIn("Ubuntu/Debian", guide)
        self.assertNotIn("Debian-compatible", guide)

    def test_manifest_records_python_policy(self) -> None:
        manifest = (ROOT / "tools/versions.env").read_text(encoding="utf-8")
        self.assertIn("PYTHON_SERIES=3.12", manifest)
        self.assertIn("PYTHON_TESTED_VERSION=3.12.3", manifest)


if __name__ == "__main__":
    unittest.main()
