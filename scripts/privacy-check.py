#!/usr/bin/env python3
"""Check the intended public Git tree before publishing. Does not print secrets."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
files = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
patterns = {
    "personal filesystem path": re.compile(rb"/Users/[A-Za-z0-9_.-]+/"),
    "GitHub token": re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})"),
    "API key": re.compile(rb"sk-(?:proj-)?[A-Za-z0-9_-]{24,}"),
    "private key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "private IPv4 address": re.compile(rb"\b(?:192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b"),
}
problems = []
for name in filter(None, files):
    path = root / name
    if name.startswith((".build/", "build/", "dist/", "local/")) or path.suffix in (".log", ".app", ".dmg", ".zip"):
        problems.append((name, "generated or local file tracked"))
    data = path.read_bytes()
    for label, pattern in patterns.items():
        if pattern.search(data):
            problems.append((name, label))
for name, label in problems:
    print(f"FAIL {name}: {label}")
print(f"Scanned {len(list(filter(None, files)))} public files; {len(problems)} findings.")
sys.exit(bool(problems))
