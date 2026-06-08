#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass

DIAGNOSTIC_RE = re.compile(
    r"^\s*(?P<severity>error|warning|info)\s+•\s+"
    r"(?P<message>.*?)\s+•\s+"
    r"(?P<location>[^•]+?)\s+•\s+"
    r"(?P<code>[A-Za-z0-9_]+)\s*$",
)


@dataclass(frozen=True)
class Diagnostic:
    severity: str
    message: str
    location: str
    code: str

    @property
    def docs_url(self) -> str:
        return f"https://dart.dev/tools/diagnostics/{self.code}"


def color(code: str, value: str) -> str:
    if not sys.stdout.isatty():
        return value
    return f"\033[{code}m{value}\033[0m"


def parse_diagnostics(output: str) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    for line in output.splitlines():
        match = DIAGNOSTIC_RE.match(line)
        if not match:
            continue
        diagnostics.append(
            Diagnostic(
                severity=match.group("severity"),
                message=match.group("message"),
                location=match.group("location").strip(),
                code=match.group("code"),
            ),
        )
    return diagnostics


def run_analyzer(command: list[str]) -> tuple[int, str]:
    completed = subprocess.run(
        command,
        check=False,
        stderr=subprocess.STDOUT,
        stdout=subprocess.PIPE,
        text=True,
    )
    return completed.returncode, completed.stdout


def print_summary(diagnostics: list[Diagnostic]) -> None:
    if not diagnostics:
        print(color("32", "No analyzer diagnostics found."))
        return

    by_severity = Counter(item.severity for item in diagnostics)
    by_code = Counter(item.code for item in diagnostics)

    print()
    print(color("1;34", "Dart analyzer diagnostics"))
    print(
        "Total: {total} | errors: {errors} | warnings: {warnings} | infos: {infos}".format(
            total=len(diagnostics),
            errors=by_severity["error"],
            warnings=by_severity["warning"],
            infos=by_severity["info"],
        ),
    )
    print()

    for code, count in by_code.most_common():
        first = next(item for item in diagnostics if item.code == code)
        print(f"{count:>3}  {first.severity:<7} {code}")
        print(f"     {first.docs_url}")

    print()
    print(color("1;34", "First occurrences"))
    for item in diagnostics[:20]:
        print(f"- [{item.severity}] {item.code} at {item.location}")
        print(f"  {item.message}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run flutter analyze and summarize Dart diagnostics.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero if any diagnostic is found.",
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Analyzer command after '--'.",
    )
    args = parser.parse_args()

    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        command = ["flutter", "analyze", "--no-fatal-infos", "--no-fatal-warnings"]

    return_code, output = run_analyzer(command)
    diagnostics = parse_diagnostics(output)

    if not diagnostics and return_code != 0:
        print(output)
        return return_code

    print_summary(diagnostics)
    if args.strict and diagnostics:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
