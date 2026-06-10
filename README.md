[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-02569B.svg)](https://riverpod.dev)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I2I81X6E3R)

# Glibusta

Cross-platform Flutter application for searching, reading, downloading, and organizing books from
Flibusta-compatible sources.

> [!WARNING]
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
- [Roadmap](#roadmap)
- [License](#license)

## Status

Glibusta is under active development. The repository already contains the application shell,
navigation, search/parser work, local tooling, signing helpers, and release artifact targets. Some
product features are still being implemented.

| Area               | Status          |
| ------------------ | --------------- |
| Android app shell  | In progress     |
| macOS app shell    | In progress     |
| Search/parsing     | In progress     |
| Offline library    | In progress     |
| Reader             | MVP/in progress |
| Downloads          | In progress     |
| Release automation | In progress     |

## Features

- Search books across Flibusta-compatible mirrors.
- Parse book metadata and available formats from HTML fixtures/pages.
- Organize books in a local library.
- Download books in common formats such as FB2, EPUB, TXT, and ZIP.
- Read books in-app with reader settings and theming.
- Build signed Android artifacts and signed macOS release archives.

## Platforms

| Platform | Repository support | Notes                                                              |
| -------- | :----------------: | ------------------------------------------------------------------ |
| Android  |         ✅         | Primary mobile target. Signed APK/AAB build targets are available. |
| macOS    |         ✅         | Desktop target. Release zip target is available.                   |
| iOS      |      Planned       | Platform directory is not currently present.                       |
| Linux    |      Planned       | Platform directory is not currently present.                       |
| Windows  |      Planned       | Platform directory is not currently present.                       |
| Web      |      Planned       | Platform directory is not currently present.                       |

## Tech Stack

| Layer            | Tooling                                                      |
| ---------------- | ------------------------------------------------------------ |
| UI               | Flutter, Material 3                                          |
| State management | Riverpod 3                                                   |
| Navigation       | Go Router                                                    |
| HTTP             | Dio                                                          |
| Local storage    | Drift SQLite                                                 |
| Parsing          | `package:html`                                               |
| Quality          | `flutter_lints`, `riverpod_lint`, Ruff, ShellCheck, Prettier |
| Build automation | Makefile modules under `makefiles/`                          |

## Quick Start

```bash
make bootstrap-check
make bootstrap
make get
flutter run
```

`make bootstrap` first checks the local environment, then asks for `yes` or `y` before installing or
creating missing project-local tools.

> [!TIP] Run `make help` to see every available target. The help output includes the current version
> from `pubspec.yaml`.

## Developer Tooling

The Makefile is split into modules under `makefiles/` and is the preferred entry point for local
workflows.

| Command                | Purpose                                                                         |
| ---------------------- | ------------------------------------------------------------------------------- |
| `make help`            | Show dynamic help with the current app version.                                 |
| `make bootstrap-check` | Check required tools without changing the machine.                              |
| `make bootstrap`       | Check tools, ask for confirmation, then install/setup supported missing pieces. |
| `make fix-all`         | Run automatic formatters and safe fixes.                                        |
| `make check-all`       | Run formatting checks, linters, analyzer, and tests.                            |
| `make shellcheck`      | Check shell scripts in `scripts/`.                                              |
| `make ruff-check`      | Lint Python scripts in `scripts/`.                                              |
| `make prettier-check`  | Check Markdown/YAML/JSON formatting.                                            |

### Quality Gates

```bash
make fix-all
make check-all
```

`fix-all` currently runs Flutter/Dart dependency setup, Node dependency setup, Dart formatting,
`dart fix --apply`, Prettier, Ruff formatting, and Ruff fixes.

`check-all` currently runs Dart format check, Prettier check, Ruff check, ShellCheck,
`flutter analyze`, and `flutter test`.

## Build Artifacts

Release artifacts are copied into `dist/releases/` with names based on the version in
`pubspec.yaml`.

| Command                  | Output                                                        |
| ------------------------ | ------------------------------------------------------------- |
| `make build-android-apk` | `dist/releases/glibusta-<version>-android-release-signed.apk` |
| `make build-android-aab` | `dist/releases/glibusta-<version>-android-release-signed.aab` |
| `make build-android`     | APK and AAB                                                   |
| `make build-macos`       | `dist/releases/glibusta-<version>-macos-release.zip`          |
| `make build-all`         | All currently available platform artifacts                    |
| `make artifacts`         | List generated release artifacts                              |

Android release signing uses `.key-generate.conf`, `scripts/signing.sh`, and
`android/key.properties`.

macOS signing defaults to ad-hoc signing:

```bash
make build-macos
```

To use a Developer ID identity:

```bash
make build-macos MACOS_CODESIGN_IDENTITY="Developer ID Application: Example Name"
```

## Project Layout

```text
lib/
  app/                 # Router and application shell
  core/                # Database, HTTP, platform services, shared config
  features/            # Feature-first modules
  l10n/                # Localization ARB files
  shared/              # Shared models and widgets
makefiles/             # Modular Makefile targets
scripts/               # Signing, icon generation, bootstrap, helper scripts
test/                  # Unit and widget tests
```

## Roadmap

Tracked locally in `.rechange-docs.md`.

- [ ] Stabilize `flutter analyze` and `flutter test`.
- [ ] Finish Drift-backed offline library.
- [ ] Harden parser fixtures and mirror fallback.
- [ ] Complete reader MVP.
- [ ] Complete download queue controls and persistence.
- [ ] Add CI for `make check-all`.
- [ ] Expand platform support beyond Android and macOS.

## License

Licensed under the [Apache License 2.0](LICENSE).
