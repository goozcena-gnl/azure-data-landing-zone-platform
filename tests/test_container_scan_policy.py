#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from container_scan_policy import evaluate  # noqa: E402


def scan(severity: str = "HIGH", secrets: bool = False) -> dict:
    return {
        "Results": [
            {
                "Target": "usr/local/bin/tool",
                "Vulnerabilities": [
                    {
                        "VulnerabilityID": "CVE-2099-0001",
                        "PkgName": "example/module",
                        "InstalledVersion": "1.0.0",
                        "FixedVersion": "1.0.1",
                        "Severity": severity,
                    }
                ],
                "Secrets": [{"RuleID": "fixture-secret"}] if secrets else [],
            }
        ]
    }


def exception() -> dict:
    return {
        "cve": "CVE-2099-0001",
        "target": "usr/local/bin/tool",
        "component": "example/module",
        "installed_version": "1.0.0",
        "upstream_status": "No supported fixed owning-tool release exists.",
        "rationale": "Temporary fixture exception for policy testing.",
        "owner": "repository maintainers",
        "expires": "2099-12-31",
    }


class ContainerScanPolicyTests(unittest.TestCase):
    def test_critical_cannot_be_excepted(self) -> None:
        errors = evaluate(scan("CRITICAL"), {"exceptions": [exception()]})
        self.assertTrue(any("CRITICAL vulnerability" in error for error in errors))

    def test_high_requires_exact_documented_exception(self) -> None:
        errors = evaluate(scan(), {"exceptions": []})
        self.assertTrue(any("HIGH vulnerability without approved exception" in error for error in errors))

    def test_exact_unexpired_high_exception_passes(self) -> None:
        self.assertEqual(evaluate(scan(), {"exceptions": [exception()]}), [])

    def test_stale_exception_fails(self) -> None:
        self.assertTrue(evaluate({"Results": []}, {"exceptions": [exception()]}))

    def test_secret_always_fails(self) -> None:
        errors = evaluate(scan(secrets=True), {"exceptions": [exception()]})
        self.assertTrue(any("secret finding" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
