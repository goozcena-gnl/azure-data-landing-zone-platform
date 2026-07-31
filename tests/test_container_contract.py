#!/usr/bin/env python3
from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ContainerContractTests(unittest.TestCase):
    def test_devcontainer_uid_update_is_explicit(self) -> None:
        configuration = json.loads((ROOT / ".devcontainer/devcontainer.json").read_text())
        self.assertEqual(configuration["remoteUser"], "ubuntu")
        self.assertIs(configuration["updateRemoteUserUID"], True)

    def test_test_container_is_isolated_and_parallel_safe(self) -> None:
        script = (ROOT / "scripts/test-container.sh").read_text(encoding="utf-8")
        for forbidden in ("--volume", "/var/run/docker.sock", "--privileged", "--network=host", "--cap-add", "--user 1000"):
            self.assertNotIn(forbidden, script)
        self.assertIn("$$-${RANDOM}", script)
        self.assertIn("git -C \"$REPO_ROOT\" ls-files", script)
        self.assertIn("before_status=", script)
        self.assertIn("after_status=", script)
        self.assertIn("scan-container.sh", script)
        self.assertIn("trap cleanup EXIT INT TERM", script)

    def test_scan_gate_is_pinned_and_has_no_docker_socket_mount(self) -> None:
        script = (ROOT / "scripts/scan-container.sh").read_text(encoding="utf-8")
        self.assertIn("TRIVY_VERSION", script)
        self.assertIn("TRIVY_LINUX_AMD64_SHA256", script)
        self.assertIn("--scanners vuln,secret", script)
        self.assertNotIn("/var/run/docker.sock", script)


if __name__ == "__main__":
    unittest.main()
