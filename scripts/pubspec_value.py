#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def read_scalar(path: Path, key: str) -> str:
    prefix = f"{key}:"
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not stripped.startswith(prefix):
            continue
        value = stripped[len(prefix) :].strip()
        return value.strip("\"'")
    raise KeyError(key)


def main() -> int:
    parser = argparse.ArgumentParser(description="Read a scalar value from pubspec.yaml.")
    parser.add_argument("key", help="Top-level pubspec key to read.")
    parser.add_argument(
        "--file",
        default="pubspec.yaml",
        type=Path,
        help="Path to pubspec.yaml.",
    )
    args = parser.parse_args()

    try:
        print(read_scalar(args.file, args.key))
    except FileNotFoundError:
        print(f"pubspec file not found: {args.file}", file=sys.stderr)
        return 1
    except KeyError:
        print(f"key not found in {args.file}: {args.key}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
