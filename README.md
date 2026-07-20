[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-02569B.svg)](https://riverpod.dev)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I2I81X6E3R)

# Glibusta

Cross-platform Flutter application for searching, reading, downloading, and organizing books from
Flibusta-compatible sources.

> [!WARNING]
>
> **Disclaimer**
>
> - This project is developed for **educational and informational purposes only**.
> - The authors are **not affiliated with, endorsed by, or connected to Flibusta or any of its
>   mirrors**.
> - Use this software only in accordance with applicable copyright laws and regulations in your
>   jurisdiction.

## Table of Contents

- [Status](#status)
- [Features](#features)
- [Platforms](#platforms)
- [Tech Stack](#tech-stack)
- [Quick Start](#quick-start)
- [Developer Tooling](#developer-tooling)
- [Build Artifacts](#build-artifacts)
- [Project Layout](#project-layout)
- [DjVu Compatibility](#djvu-compatibility)
- [License](#license)

## Status

| Area               | Status |
| ------------------ | ------ |
| Android app shell  | ✅     |
| macOS app shell    | ✅     |
| Search/parsing     | ✅     |
| Offline library    | ✅     |
| Reader             | ✅     |
| Downloads          | ✅     |
| Release automation | ✅     |
| CI                 | ✅     |

## Features

- Search books across Flibusta-compatible mirrors.
- Parse book metadata and available formats from HTML/OPDS.
- Organize books in a local library with collections, pinned books, and smart collections.
- Download books in common formats (FB2, EPUB, TXT, ZIP).
- Read books in-app with reader settings, theming, and annotations.
- Built-in comments system for books.
- Health diagnostics with device info, server probe, and exportable reports.
- Build signed Android APK/AAB and macOS release archives.

## Platforms

| Platform | Support | Notes                                         |
| -------- | :-----: | --------------------------------------------- |
| Android  |   ✅    | Primary mobile target. Signed APK/AAB builds. |
| macOS    |   ✅    | Desktop target. Signed release zip.           |
| iOS      | Planned |                                               |
| Linux    | Planned |                                               |
| Windows  | Planned |                                               |
| Web      | Planned |                                               |

## Tech Stack

| Layer            | Tooling                                                                        |
| ---------------- | ------------------------------------------------------------------------------ |
| UI               | Flutter, Material 3                                                            |
| State management | Riverpod 3                                                                     |
| Navigation       | Go Router                                                                      |
| HTTP             | Dio                                                                            |
| Local storage    | Drift SQLite                                                                   |
| Reader           | EPUB, FB2 parsers                                                              |
| DjVu reference   | [DjVuLibre](https://github.com/DjvuNet/DjVuLibre.git) + `djvu-rs` oracle tests |
| Quality          | `flutter_lints`, `riverpod_lint`, Ruff, ShellCheck, Prettier                   |
| Build            | Makefile modules under `makefiles/`                                            |

## Quick Start

```bash
make bootstrap-check
make bootstrap
make get
flutter run
```

`make bootstrap` first checks the local environment, then asks for `yes` or `y` before installing
or creating missing project-local tools.

> [!TIP]
> Run `make help` to see every available target. The help output includes the current version from
> `pubspec.yaml`.

## Developer Tooling

The Makefile is split into modules under `makefiles/` and is the preferred entry point for local
workflows.

| Command                | Purpose                                                   |
| ---------------------- | --------------------------------------------------------- |
| `make help`            | Show dynamic help with the current app version.           |
| `make bootstrap-check` | Check required tools without changing the machine.        |
| `make bootstrap`       | Check tools, then install/setup supported missing pieces. |
| `make versions`        | Show current vs latest versions of all dependencies.      |
| `make fix-all`         | Run automatic formatters and safe fixes.                  |
| `make check-all`       | Run formatting checks, linters, analyzer, and tests.      |
| `make shellcheck`      | Check shell scripts in `scripts/`.                        |
| `make ruff-check`      | Lint Python scripts in `scripts/`.                        |
| `make prettier-check`  | Check Markdown/YAML/JSON formatting.                      |

### Version Management

```bash
make versions          # Show available updates
make bump              # Bump PATCH:  0.1.0+3 → 0.1.1+0
make bump-minor        # Bump MINOR:  0.1.0+3 → 0.2.0+0
make bump-major        # Bump MAJOR:  0.1.0+3 → 1.0.0+0
```

Follows [Semantic Versioning 2.0.0](https://semver.org/). Build number (`+N`) resets to `0` on each
bump. `make release` auto-bumps before building.

### Quality Gates

```bash
make fix-all
make check-all
```

`fix-all` runs Flutter/Dart dependency setup, Node dependency setup, Dart formatting,
`dart fix --apply`, Prettier, Ruff formatting, and Ruff fixes.

`check-all` runs Dart format check, Prettier check, Ruff check, ShellCheck, `flutter analyze`,
and `flutter test`.

## Build Artifacts

Release artifacts are copied into `dist/releases/` with names based on the version in
`pubspec.yaml`.

| Command                        | Output                                                |
| ------------------------------ | ----------------------------------------------------- |
| `make build-android-apk-split` | Per-ABI APKs (arm64, armv7, x86_64, universal)        |
| `make build-android-apk`       | Universal APK                                         |
| `make build-android-aab`       | Android App Bundle                                    |
| `make build-macos`             | macOS release zip                                     |
| `make build-all`               | All platform artifacts                                |
| `make release`                 | Full pipeline: lint → test → bump → build → artifacts |

Android release signing uses `.signing/release.keystore` and `android/key.properties`.

macOS signing defaults to ad-hoc:

```bash
make build-macos
```

To use a Developer ID identity:

```bash
make build-macos MACOS_CODESIGN_IDENTITY="Developer ID Application: Name"
```

## Project Layout

```text
lib/
  app/                  # Router and application shell
  core/                 # Database, HTTP, platform services, config
  features/             # Feature-first modules
  l10n/                 # Localization ARB files
  shared/               # Shared models and widgets
makefiles/              # Modular Makefile targets
scripts/                # Signing, bootstrap, version bump, diagnostics
hack/                   # Python API exploration scripts
test/                   # Unit and widget tests
```

## DjVu Compatibility

The app's DjVu path is implemented with the pure-Rust `djvu-rs` crate. We use
[DjVuLibre](https://github.com/DjvuNet/DjVuLibre.git), the free and open-source
reference implementation, as an opt-in compatibility oracle for DjVu fixtures.
It is not bundled or linked into the application at present.

DjVuLibre is licensed under GPL-2.0-or-later. Consequently, any future native
Android/macOS linking is subject to a separate distribution and license-compliance
decision; the opt-in oracle test only invokes an already installed developer tool.

## License

Licensed under the [Apache License 2.0](LICENSE).
