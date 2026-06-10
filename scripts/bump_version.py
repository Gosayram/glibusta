#!/usr/bin/env python3
"""Bump version in pubspec.yaml following Semantic Versioning 2.0.0.

Usage:
    bump_version.py              # bump PATCH:  0.1.5+3 → 0.1.6+0
    bump_version.py --minor      # bump MINOR:  0.1.5+3 → 0.2.0+0
    bump_version.py --major      # bump MAJOR:  0.1.5+3 → 1.0.0+0
    bump_version.py --build      # bump BUILD:  0.1.5+3 → 0.1.5+4
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

VERSION_RE = re.compile(
    r"^(version:\s*)"
    r"(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)"
    r"(?:\+(?P<build>\d+))?",
    re.MULTILINE,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Bump semver in pubspec.yaml")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--major", action="store_true", help="Bump major version")
    group.add_argument("--minor", action="store_true", help="Bump minor version")
    group.add_argument("--build", action="store_true", help="Bump build number only")
    args = parser.parse_args()

    pubspec = Path("pubspec.yaml")
    if not pubspec.exists():
        print("pubspec.yaml not found", file=sys.stderr)
        return 1

    text = pubspec.read_text(encoding="utf-8")
    match = VERSION_RE.search(text)
    if not match:
        print("version not found in pubspec.yaml", file=sys.stderr)
        return 1

    major = int(match.group("major"))
    minor = int(match.group("minor"))
    patch = int(match.group("patch"))
    build = int(match.group("build")) if match.group("build") else 0

    if args.major:
        major += 1
        minor = 0
        patch = 0
        build = 0
    elif args.minor:
        minor += 1
        patch = 0
        build = 0
    elif args.build:
        build += 1
    else:
        patch += 1
        build = 0

    prefix = match.group(1)
    new_version = f"{prefix}{major}.{minor}.{patch}+{build}"
    new_text = text[: match.start()] + new_version + text[match.end() :]
    pubspec.write_text(new_text, encoding="utf-8")
    print(f"{major}.{minor}.{patch}+{build}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
