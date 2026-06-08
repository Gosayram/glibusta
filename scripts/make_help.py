#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

TARGET_RE = re.compile(r"^([A-Za-z0-9_.-]+)\s*:[^#]*##\s*(.+)$")
SECTION_RE = re.compile(r"^##@\s*(.+)$")


COLORS = {
    "reset": "\033[0m",
    "bold": "\033[1m",
    "blue": "\033[34m",
    "cyan": "\033[36m",
}


def emit_help(project_name: str, version: str, files: list[Path]) -> None:
    print(f"\n{COLORS['bold']}{COLORS['blue']}{project_name} make targets{COLORS['reset']}\n")
    print(f"{COLORS['bold']}Version:{COLORS['reset']} {version}")

    seen_targets: set[str] = set()
    for path in files:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except FileNotFoundError:
            continue

        for line in lines:
            section = SECTION_RE.match(line)
            if section:
                print(f"\n{COLORS['bold']}{section.group(1)}{COLORS['reset']}")
                continue

            target = TARGET_RE.match(line)
            if not target:
                continue

            name, description = target.groups()
            if name in seen_targets:
                continue
            seen_targets.add(name)
            print(f"  {COLORS['cyan']}{name:<28}{COLORS['reset']} {description}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Render Makefile help.")
    parser.add_argument("--project-name", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()

    emit_help(args.project_name, args.version, args.files)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
