#!/usr/bin/env python3
from __future__ import annotations
import argparse
import json
import math
import re
from pathlib import Path

PATTERNS = {
    "private-key": re.compile(r"-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----"),
    "github-token": re.compile(r"\b(?:ghp|github_pat)_[A-Za-z0-9_]{20,}\b"),
    "azure-storage-key": re.compile(r"AccountKey=[A-Za-z0-9+/=]{40,}"),
    "azure-client-secret": re.compile(r'''(?i)(?:client[_-]?secret|AZURE_CLIENT_SECRET)\s*[:=]\s*["']?(?!<|\$\{)[A-Za-z0-9._~+/=-]{16,}'''),
    "generic-password": re.compile(r'''(?i)(?:password|passwd)\s*[:=]\s*["']?(?!<|example|dummy|\$\{)[^\s"']{12,}'''),
    "sas-token": re.compile(r"(?i)[?&]sig=[A-Za-z0-9%+/=]{20,}"),
}
SKIP_NAMES={".terraform.lock.hcl", "secret-scan.py"}
SKIP_DIRS={".git", ".terraform", ".venv", "artifacts", "__pycache__"}
TEXT_EXTENSIONS={".tf", ".md", ".yml", ".yaml", ".json", ".txt", ".sh", ".py", ".hcl", ".example", ".gitignore", ".gitattributes", ".editorconfig"}

def shannon_entropy(value: str) -> float:
    if not value: return 0.0
    return -sum((value.count(c)/len(value))*math.log2(value.count(c)/len(value)) for c in set(value))

def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--output")
    args=parser.parse_args()
    root=Path(args.root).resolve()
    findings=[]
    for path in root.rglob("*"):
        if not path.is_file() or any(part in SKIP_DIRS for part in path.parts) or path.name in SKIP_NAMES:
            continue
        if path.suffix.lower() not in TEXT_EXTENSIONS and not path.name.startswith(".") and path.name != "Makefile":
            continue
        try: text=path.read_text(encoding="utf-8")
        except (UnicodeDecodeError,OSError): continue
        for lineno,line in enumerate(text.splitlines(),1):
            if "allowlist-secret" in line: continue
            for kind,pattern in PATTERNS.items():
                if pattern.search(line): findings.append({"path":str(path.relative_to(root)),"line":lineno,"type":kind})
            for token in re.findall(r"[A-Za-z0-9+/=_-]{40,}", line):
                if token.startswith(("https", "terraform", "Microsoft")): continue
                if shannon_entropy(token) >= 4.6:
                    findings.append({"path":str(path.relative_to(root)),"line":lineno,"type":"high-entropy-token"})
    findings=sorted({(x['path'],x['line'],x['type']) for x in findings})
    result={"findings":[{"path":p,"line":l,"type":t} for p,l,t in findings]}
    if args.output: Path(args.output).write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    if findings:
        print("Secret scan: FAIL")
        for p,l,t in findings: print(f"- {p}:{l}: {t}")
        return 1
    print("Secret scan: PASS")
    return 0
if __name__ == "__main__": raise SystemExit(main())
