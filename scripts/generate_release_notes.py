#!/usr/bin/env python3
"""Generate release notes by finding version changes in pubspec.yaml.

Finds the commit where pubspec.yaml version was bumped to the current value,
then generates categorized release notes for all commits since then.

Usage:
    generate_release_notes.py                  # auto-detect range from pubspec
    generate_release_notes.py --range v1.0..v2.0  # explicit range
    generate_release_notes.py --output RELEASE_NOTES_v2.0.md
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

PUBSPEC = Path("pubspec.yaml")
VERSION_RE = re.compile(r"^version:\s*(\S+)", re.MULTILINE)
TAG_PATTERNS: dict[str, re.Pattern[str]] = {
    "Features": re.compile(r"\[FEATURE\]"),
    "Fixes": re.compile(r"\[FIX\]"),
    "Refactors": re.compile(r"\[REFACTOR\]"),
    "CI": re.compile(r"\[CI\]"),
    "Docs": re.compile(r"\[DOCS\]"),
    "Updates": re.compile(r"\[UPD\]"),
}


def _git(*args: str) -> str:
    result = subprocess.run(
        ["git"] + list(args), capture_output=True, text=True, check=True,
    )
    return result.stdout.strip()


def _get_version() -> str:
    text = PUBSPEC.read_text(encoding="utf-8")
    m = VERSION_RE.search(text)
    if not m:
        print("version: not found in pubspec.yaml", file=sys.stderr)
        sys.exit(1)
    return m.group(1)


def _find_version_boundary() -> str | None:
    """Find the commit that set the PREVIOUS version in pubspec.yaml.

    Strategy: compare HEAD and HEAD^ pubspec.yaml to find the old version string,
    then use git log -S to find when THAT string was the current value (the
    commit that last set it). All commits from there to HEAD are the release notes.
    """
    try:
        current = _git("show", "HEAD:pubspec.yaml")
        previous = _git("show", "HEAD^:pubspec.yaml")
    except subprocess.CalledProcessError:
        return None

    current_ver = (VERSION_RE.search(current) or re.search(r"version:\s*(\S+)", current))
    previous_ver = (VERSION_RE.search(previous) or re.search(r"version:\s*(\S+)", previous))
    if not current_ver or not previous_ver:
        return None

    old_version = previous_ver.group(1)
    if old_version == current_ver.group(1):
        # Build number only changed — find when old build was set
        old_line = f"version: {old_version}"
        log = _git("log", "--format=%H", "-S", old_line, "--", "pubspec.yaml")
        if log:
            lines = log.splitlines()
            # OLDEST commit = where old string was first set
            boundary = lines[-1].strip()
            return boundary

    # Semver changed — find when old version was set
    old_line = f"version: {old_version}"
    log = _git("log", "--format=%H", "-S", old_line, "--", "pubspec.yaml")
    if log:
        lines = log.splitlines()
        # OLDEST commit (last line) = where the old string was first introduced
        # = the boundary of the previous release
        return lines[-1].strip()

    return None


def _classify_commit(message: str) -> str:
    for category, pattern in TAG_PATTERNS.items():
        if pattern.search(message):
            return category
    return "Other"


def _format_commit_line(hash_full: str, message: str) -> str:
    short = hash_full[:7]
    # Strip tag prefix like [FEATURE] - ... → keep the meaningful part
    cleaned = re.sub(r"^\[[A-Z]+\]\s*[-–—]?\s*", "", message.strip())
    return f"- {cleaned} (`{short}`)"


def _collect_commits(git_range: str) -> list[dict[str, str]]:
    """Collect commits in range with hash, subject, and category."""
    raw = _git("log", "--format=%H||%s", "--no-merges", git_range)
    if not raw:
        return []
    commits = []
    for line in raw.splitlines():
        if "||" not in line:
            continue
        hash_full, subject = line.split("||", 1)
        commits.append({
            "hash": hash_full.strip(),
            "subject": subject.strip(),
            "category": _classify_commit(subject),
        })
    return commits


def _generate_markdown(
    version: str, commits: list[dict[str, str]], checksums_path: Path | None,
) -> str:
    lines: list[str] = []
    lines.append(f"# Release {version}")
    lines.append("")
    lines.append("## What's Changed")
    lines.append("")

    # Group by category, preserve git order within each group
    groups: dict[str, list[dict[str, str]]] = {}
    for c in commits:
        groups.setdefault(c["category"], []).append(c)

    # Render in a fixed order
    section_order = ["Features", "Fixes", "Refactors", "CI", "Docs", "Updates", "Other"]
    has_content = False
    for section in section_order:
        items = groups.get(section, [])
        if not items:
            continue
        has_content = True
        lines.append(f"### {section}")
        lines.append("")
        for c in items:
            lines.append(_format_commit_line(c["hash"], c["subject"]))
        lines.append("")

    if not has_content:
        lines.append("No categorized commits found.")
        lines.append("")

    # Embedded checksums
    if checksums_path and checksums_path.exists():
        lines.append("### Checksums")
        lines.append("")
        lines.append("```text")
        lines.append(checksums_path.read_text(encoding="utf-8").strip())
        lines.append("```")
        lines.append("")

    return "\n".join(lines) + "\n"


def _find_range_from_pubspec() -> str:
    """Build a git range: from the commit that set current version..HEAD."""
    boundary = _find_version_boundary()
    if boundary is None:
        return "HEAD"
    return f"{boundary}..HEAD"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate release notes from git log.",
    )
    parser.add_argument(
        "--range", dest="git_range",
        help="Explicit git range (e.g. v1.0..HEAD). Auto-detected if omitted.",
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file path. Prints to stdout if omitted.",
    )
    parser.add_argument(
        "--version",
        help="Version string for the header. Read from pubspec.yaml if omitted.",
    )
    parser.add_argument(
        "--checksums",
        help="Path to checksums.txt to embed in the notes.",
        type=Path,
    )
    args = parser.parse_args()

    version = args.version or _get_version()
    git_range = args.git_range or _find_range_from_pubspec()

    commits = _collect_commits(git_range)
    if not commits:
        print(f"No commits found in range: {git_range}", file=sys.stderr)
        return 1

    markdown = _generate_markdown(version, commits, args.checksums)

    if args.output:
        Path(args.output).write_text(markdown, encoding="utf-8")
        print(f"Release notes written to {args.output}")
    else:
        print(markdown)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
