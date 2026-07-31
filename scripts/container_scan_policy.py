#!/usr/bin/env python3
"""Enforce the documented final-image vulnerability and secret policy."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any


REQUIRED_EXCEPTION_FIELDS = {
    "cve",
    "target",
    "component",
    "installed_version",
    "upstream_status",
    "rationale",
    "owner",
    "expires",
}


def finding_key(target: str, vulnerability: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(vulnerability.get("VulnerabilityID", "")),
        target,
        str(vulnerability.get("PkgName", "")),
        str(vulnerability.get("InstalledVersion", "")),
    )


def evaluate(scan: dict[str, Any], exceptions_document: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    today = dt.datetime.now(dt.timezone.utc).date()
    raw_exceptions = exceptions_document.get("exceptions")
    if not isinstance(raw_exceptions, list):
        return ["exception document must contain an exceptions array"]

    exceptions: dict[tuple[str, str, str, str], dict[str, Any]] = {}
    for index, exception in enumerate(raw_exceptions):
        if not isinstance(exception, dict):
            errors.append(f"exception {index} must be an object")
            continue
        missing = REQUIRED_EXCEPTION_FIELDS - exception.keys()
        if missing:
            errors.append(f"exception {index} is missing: {', '.join(sorted(missing))}")
            continue
        key = (
            str(exception["cve"]),
            str(exception["target"]),
            str(exception["component"]),
            str(exception["installed_version"]),
        )
        if key in exceptions:
            errors.append(f"duplicate exception: {' / '.join(key)}")
            continue
        try:
            expiry = dt.date.fromisoformat(str(exception["expires"]))
        except ValueError:
            errors.append(f"exception has invalid expiry: {' / '.join(key)}")
            continue
        if expiry < today:
            errors.append(f"exception expired on {expiry.isoformat()}: {' / '.join(key)}")
            continue
        for field in ("upstream_status", "rationale", "owner"):
            if not str(exception[field]).strip():
                errors.append(f"exception has empty {field}: {' / '.join(key)}")
        exceptions[key] = exception

    used: set[tuple[str, str, str, str]] = set()
    high_count = 0
    critical_count = 0
    secret_count = 0
    for result in scan.get("Results") or []:
        target = str(result.get("Target", "unknown target"))
        secrets = result.get("Secrets") or []
        secret_count += len(secrets)
        for secret in secrets:
            errors.append(
                f"secret finding {secret.get('RuleID', 'unknown')} in {target}"
            )
        for vulnerability in result.get("Vulnerabilities") or []:
            severity = str(vulnerability.get("Severity", "")).upper()
            key = finding_key(target, vulnerability)
            if severity == "CRITICAL":
                critical_count += 1
                errors.append(f"CRITICAL vulnerability: {' / '.join(key)}")
            elif severity == "HIGH":
                high_count += 1
                if key in exceptions:
                    used.add(key)
                else:
                    fixed = str(vulnerability.get("FixedVersion", "")) or "none reported"
                    errors.append(
                        f"HIGH vulnerability without approved exception: "
                        f"{' / '.join(key)} / fixed={fixed}"
                    )

    for key in sorted(exceptions.keys() - used):
        errors.append(f"stale exception does not match the image: {' / '.join(key)}")

    print(
        f"Container scan policy: {critical_count} CRITICAL, {high_count} HIGH, "
        f"{secret_count} secrets, {len(used)} active exceptions"
    )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scan", type=Path, required=True)
    parser.add_argument("--exceptions", type=Path, required=True)
    args = parser.parse_args()
    scan = json.loads(args.scan.read_text(encoding="utf-8"))
    exceptions = json.loads(args.exceptions.read_text(encoding="utf-8"))
    errors = evaluate(scan, exceptions)
    if errors:
        print("Container image policy: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Container image policy: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
