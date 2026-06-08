#!/usr/bin/env python3
from __future__ import annotations

import argparse
import platform
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENV_DIR = ROOT / ".venv-tools"
NVMRC = ROOT / ".nvmrc"
PYTHON_REQUIREMENTS = ROOT / "requirements.txt"


@dataclass(frozen=True)
class Tool:
    name: str
    command: str
    required: bool = True
    install_hint: str = ""


TOOLS = [
    Tool("Flutter", "flutter", install_hint="Install Flutter SDK and add it to PATH."),
    Tool("Dart", "dart", install_hint="Usually installed with Flutter."),
    Tool("Node npm", "npm", install_hint="Install/select Node through nvm."),
    Tool("Node npx", "npx", install_hint="Install/select Node through nvm."),
    Tool("Python", "python3", install_hint="Install Python 3."),
    Tool("ShellCheck", "shellcheck", install_hint="Install with Homebrew/apt/winget."),
]


def color(code: str, value: str) -> str:
    if not sys.stdout.isatty():
        return value
    return f"\033[{code}m{value}\033[0m"


def ok(value: str) -> str:
    return color("32", value)


def warn(value: str) -> str:
    return color("33", value)


def err(value: str) -> str:
    return color("31", value)


def step(value: str) -> None:
    print(color("1;36", "==>"), value)


def run(command: list[str], *, cwd: Path = ROOT) -> None:
    print("+", " ".join(command))
    subprocess.run(command, cwd=cwd, check=True)


def has(command: str) -> bool:
    return shutil.which(command) is not None


def host_os() -> str:
    system = platform.system().lower()
    if system == "darwin":
        return "macos"
    if system == "linux":
        return "linux"
    if system.startswith(("mingw", "msys", "cygwin")) or system == "windows":
        return "windows"
    return system


def package_manager() -> str | None:
    for candidate in ("brew", "apt-get", "winget", "choco"):
        if has(candidate):
            return candidate
    return None


def nvm_sh_path() -> Path:
    home = Path.home()
    return home / ".nvm" / "nvm.sh"


def has_nvm() -> bool:
    return nvm_sh_path().exists()


def nvm_command(command: str) -> list[str]:
    return ["bash", "-lc", f'source "{nvm_sh_path()}" && {command}']


def print_status() -> dict[str, bool]:
    status = {tool.command: has(tool.command) for tool in TOOLS}
    ruff_path = VENV_DIR / ("Scripts/ruff.exe" if host_os() == "windows" else "bin/ruff")
    status["ruff"] = ruff_path.exists()
    status["nvm"] = has_nvm()

    print()
    print(color("1;34", "Bootstrap environment check"))
    print(f"OS: {host_os()}")
    print(f"Package manager: {package_manager() or 'not detected'}")
    print()

    for tool in TOOLS:
        marker = ok("OK") if status[tool.command] else err("MISS")
        location = shutil.which(tool.command) or tool.install_hint
        print(f"{marker:>4} {tool.name:<14} {location}")

    marker = ok("OK") if status["nvm"] else err("MISS")
    print(f"{marker:>4} {'nvm':<14} {nvm_sh_path()}")

    if NVMRC.exists():
        print(f"     {'.nvmrc':<14} {NVMRC.read_text(encoding='utf-8').strip()}")

    marker = ok("OK") if status["ruff"] else err("MISS")
    print(f"{marker:>4} {'Ruff local':<14} {ruff_path}")
    print()
    return status


def confirm() -> bool:
    answer = input("Install/setup missing tools now? Type 'yes' or 'y' to continue: ")
    return answer.strip().lower() in {"y", "yes"}


def install_shellcheck(manager: str | None) -> None:
    if has("shellcheck"):
        return
    if manager == "brew":
        run(["brew", "install", "shellcheck"])
    elif manager == "apt-get":
        run(["sudo", "apt-get", "update"])
        run(["sudo", "apt-get", "install", "-y", "shellcheck"])
    elif manager == "winget":
        run(["winget", "install", "--id", "koalaman.shellcheck", "-e"])
    elif manager == "choco":
        run(["choco", "install", "shellcheck", "-y"])
    else:
        print(warn("ShellCheck was not installed: no supported package manager detected."))


def install_nvm(manager: str | None) -> None:
    if has_nvm():
        return
    if manager == "brew":
        run(["brew", "install", "nvm"])
        print(
            warn(
                "Homebrew installed nvm. Ensure your shell sources nvm.sh, "
                "then rerun make bootstrap.",
            ),
        )
    elif host_os() in {"macos", "linux"}:
        run(
            [
                "bash",
                "-lc",
                "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash",
            ],
        )
    elif manager == "winget":
        run(["winget", "install", "--id", "CoreyButler.NVMforWindows", "-e"])
        print(warn("Restart your shell after installing nvm-windows, then rerun make bootstrap."))
    elif manager == "choco":
        run(["choco", "install", "nvm", "-y"])
        print(warn("Restart your shell after installing nvm-windows, then rerun make bootstrap."))
    else:
        print(warn("nvm was not installed: no supported installer detected."))


def use_node_from_nvmrc() -> bool:
    if not NVMRC.exists():
        print(warn("Skipping nvm use: .nvmrc is missing."))
        return False
    if not has_nvm():
        print(warn("Skipping nvm use: nvm is missing."))
        return False
    run(nvm_command("(nvm use || (nvm install && nvm use)) && node --version && npm --version"))
    return True


def install_python_tools() -> None:
    if not has("python3"):
        print(warn("Skipping Python tools: python3 is missing."))
        return
    if not VENV_DIR.exists():
        run(["python3", "-m", "venv", str(VENV_DIR)])

    pip = VENV_DIR / ("Scripts/pip.exe" if host_os() == "windows" else "bin/pip")
    run([str(pip), "install", "--upgrade", "pip"])
    if PYTHON_REQUIREMENTS.exists():
        run([str(pip), "install", "--upgrade", "-r", str(PYTHON_REQUIREMENTS)])
    else:
        run([str(pip), "install", "--upgrade", "ruff"])


def install_node_deps() -> None:
    if use_node_from_nvmrc():
        if (ROOT / "package.json").exists():
            run(nvm_command("npm install"))
        return

    if not has("npm"):
        print(warn("Skipping npm install: npm is missing."))
        return
    if (ROOT / "package.json").exists():
        run(["npm", "install"])


def install_flutter_deps() -> None:
    if not has("flutter"):
        print(warn("Skipping flutter pub get: Flutter is missing."))
        return
    run(["flutter", "pub", "get"])


def print_manual_notes(status: dict[str, bool]) -> None:
    if not status.get("flutter"):
        print(
            warn(
                "Flutter SDK must be installed manually: "
                "https://docs.flutter.dev/get-started/install",
            ),
        )
    if host_os() == "macos" and not has("xcodebuild"):
        print(
            warn(
                "Xcode command line tools are missing. "
                "Install Xcode or run: xcode-select --install",
            ),
        )
    if host_os() == "windows":
        print(
            warn(
                "Windows support is best used from PowerShell or WSL. "
                "Install Flutter and Visual Studio manually.",
            ),
        )
    if not status.get("nvm"):
        print(warn("nvm is recommended for Node selection. Bootstrap can install it if confirmed."))


def main() -> int:
    parser = argparse.ArgumentParser(description="Bootstrap local development tools.")
    parser.add_argument("--check-only", action="store_true", help="Only print tool status.")
    parser.add_argument("--yes", action="store_true", help="Skip confirmation prompt.")
    args = parser.parse_args()

    status = print_status()
    print_manual_notes(status)

    if args.check_only:
        missing_required = [
            tool.name for tool in TOOLS if tool.required and not status.get(tool.command, False)
        ]
        return 1 if missing_required else 0

    if not args.yes and not confirm():
        print("Cancelled.")
        return 0

    manager = package_manager()
    step("Installing supported missing tools")
    install_nvm(manager)
    install_shellcheck(manager)

    step("Installing project-local dependencies")
    install_python_tools()
    install_node_deps()
    install_flutter_deps()

    print_status()
    print(ok("Bootstrap completed."))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
