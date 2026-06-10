#!/usr/bin/env python3
"""Parse flutter pub outdated --json and print a formatted version report."""
from __future__ import annotations

import json
import sys


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        print("  No data from flutter pub outdated", file=sys.stderr)
        return 0

    packages = data.get("packages", [])
    if not packages:
        print("  All dependencies are up to date!")
        return 0

    # Separate direct + dev from transitive
    direct = [p for p in packages if p.get("kind") in ("direct", "dev")]
    transitive = [p for p in packages if p.get("kind") == "transitive"]

    def _print_group(title: str, pkgs: list[dict]) -> None:
        if not pkgs:
            return
        outdated = 0
        print()
        print(f"  {title}")
        print(f"  {'Package':<38} {'Current':<16} {'Resolvable':<16} {'Latest':<16}")
        print("  " + "-" * 84)
        for p in pkgs:
            name = p["package"]
            cur = p.get("current", {}).get("version", "?")
            res = p.get("resolvable", {}).get("version", cur)
            lat = p.get("latest", {}).get("version", cur)
            if lat == cur:
                marker = ""
            elif res == cur:
                marker = "  ** major **"
                outdated += 1
            else:
                marker = "  * minor/patch *"
                outdated += 1
            print(f"  {name:<38} {cur:<16} {res:<16} {lat:<16}{marker}")
        print("  " + "-" * 84)
        print(f"  {len(pkgs)} packages, {outdated} upgrades available")

    _print_group("Direct dependencies:", direct)
    _print_group("Transitive dependencies:", transitive)
    print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
