ifndef BUILD_MK
BUILD_MK := 1

APP_NAME ?= glibusta
APP_VERSION = $(shell $(PYTHON) $(PUBSPEC_VALUE_SCRIPT) version 2>/dev/null || printf "0.0.0+0")
APP_ARTIFACT_VERSION = $(subst +,_,$(APP_VERSION))

DIST_DIR ?= dist/releases
BUILD_DIR ?= build
ANDROID_APK_SOURCE ?= $(BUILD_DIR)/app/outputs/flutter-apk/app-release.apk
ANDROID_AAB_SOURCE ?= $(BUILD_DIR)/app/outputs/bundle/release/app-release.aab
MACOS_APP_SOURCE ?= $(BUILD_DIR)/macos/Build/Products/Release/$(APP_NAME).app

ANDROID_APK_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION).apk
ANDROID_APK_SPLIT_DIR ?= $(BUILD_DIR)/app/outputs/flutter-apk
ANDROID_AAB_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION).aab
MACOS_ZIP_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-macos.zip

MACOS_CODESIGN_IDENTITY ?= -

DEBUG_INFO_ANDROID ?= $(BUILD_DIR)/symbols/android
DEBUG_INFO_MACOS ?= $(BUILD_DIR)/symbols/macos

FLUTTER_BUILD_APK := $(FLUTTER) build apk --release --obfuscate --split-debug-info=$(DEBUG_INFO_ANDROID)
FLUTTER_BUILD_APK_SPLIT := $(FLUTTER) build apk --release --split-per-abi --obfuscate --split-debug-info=$(DEBUG_INFO_ANDROID)
FLUTTER_BUILD_AAB := $(FLUTTER) build appbundle --release --obfuscate --split-debug-info=$(DEBUG_INFO_ANDROID)
FLUTTER_BUILD_MACOS := $(FLUTTER) build macos --release --obfuscate --split-debug-info=$(DEBUG_INFO_MACOS)
CARGO_BUILD_RELEASE := cd rust && cargo build --release
CARGO_CHECK := cd rust && cargo check

##@ Build

.PHONY: rust-build-release
rust-build-release: require-rust ## Build Rust native library in release mode
	@$(PRINT_STEP) "Building Rust library (release)"
	$(CARGO_BUILD_RELEASE)
	@ls -lh rust/target/release/libglibusta_core.* 2>/dev/null || true
	@$(PRINT_OK) "Rust release build complete"

.PHONY: rust-build-check
rust-build-check: require-rust ## Verify Rust code compiles
	@$(PRINT_STEP) "Verifying Rust compilation"
	$(CARGO_CHECK)
	@$(PRINT_OK) "Rust compilation verified"

.PHONY: rust-sync-version
rust-sync-version: ## Sync Rust crate version with pubspec.yaml version
	@$(PRINT_STEP) "Syncing Rust version from pubspec.yaml"
	@CARGO_VER=$$($(PYTHON) -c "import re; \
		v=re.search(r'version:\s*(.+)', open('pubspec.yaml').read()).group(1).strip(); \
		ver=v.split('+')[0]; print(ver)"); \
	perl -pi -e "s/^version = .*/version = \"$$CARGO_VER\"/" rust/Cargo.toml; \
	echo "  Rust version: $$CARGO_VER"

.PHONY: bump
bump: require-python rust-sync-version ## Bump PATCH version (SemVer): 0.1.5+3 → 0.1.6+0
	@$(PRINT_STEP) "Bumping patch version"
	@NEW_VER=$$($(PYTHON) $(SCRIPTS_DIR)/bump_version.py); \
	echo "  $$NEW_VER"

.PHONY: bump-minor
bump-minor: require-python rust-sync-version ## Bump MINOR version (SemVer): 0.1.5+3 → 0.2.0+0
	@$(PRINT_STEP) "Bumping minor version"
	@NEW_VER=$$($(PYTHON) $(SCRIPTS_DIR)/bump_version.py --minor); \
	echo "  $$NEW_VER"

.PHONY: bump-major
bump-major: require-python rust-sync-version ## Bump MAJOR version (SemVer): 0.1.5+3 → 1.0.0+0
	@$(PRINT_STEP) "Bumping major version"
	@NEW_VER=$$($(PYTHON) $(SCRIPTS_DIR)/bump_version.py --major); \
	echo "  $$NEW_VER"

.PHONY: bump-build
bump-build: require-python rust-sync-version ## Bump build number only: 0.1.5+3 → 0.1.5+4
	@$(PRINT_STEP) "Bumping build number"
	@NEW_VER=$$($(PYTHON) $(SCRIPTS_DIR)/bump_version.py --build); \
	echo "  $$NEW_VER"

.PHONY: clean-artifacts
clean-artifacts: ## Remove generated release artifacts
	@$(PRINT_STEP) "Cleaning release artifacts"
	rm -rf "$(DIST_DIR)"

.PHONY: clean-build
clean-build: ## Remove all build artifacts and caches for a fresh build
	@$(PRINT_STEP) "Cleaning build artifacts and caches"
	rm -rf "$(BUILD_DIR)"
	rm -rf .dart_tool
	rm -rf .flutter-plugins
	rm -rf .flutter-plugins-dependencies
	rm -rf .packages
	rm -rf android/.gradle
	rm -rf android/build
	rm -rf android/app/build
	rm -rf ios/Pods
	rm -rf ios/.symlinks
	rm -rf ios/Flutter/Flutter.framework
	rm -rf ios/Flutter/Flutter.podspec
	rm -rf ios/Flutter/Generated.xcconfig
	rm -rf ios/Flutter/app.framework
	rm -rf ios/Flutter/flutter_export_environment.sh
	rm -rf ios/ServiceDefinitions.json
	rm -rf ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
	rm -rf macos/Pods
	rm -rf macos/Flutter/ephemeral
	rm -rf macos/Flutter/GeneratedPluginRegistrant.swift
	rm -rf macos/Flutter/ephemeral/
	rm -rf linux/flutter/ephemeral
	rm -rf windows/flutter/ephemeral
	rm -rf web/favicon.png
	rm -rf rust/target
	$(FLUTTER) pub get

.PHONY: clean-all
clean-all: clean-build clean-artifacts ## Remove everything: build + artifacts + caches
	@$(PRINT_OK) "All cleaned"

.PHONY: prepare-artifacts
prepare-artifacts: require-python ## Create release artifact directory
	@mkdir -p "$(DIST_DIR)"

.PHONY: android-available
android-available: ## Verify Android platform files exist
	@test -d android || { $(PRINT_ERROR) "Android platform directory is missing"; exit 1; }

.PHONY: macos-available
macos-available: ## Verify macOS platform files exist
	@test -d macos || { $(PRINT_ERROR) "macOS platform directory is missing"; exit 1; }

.PHONY: build-android-apk
build-android-apk: clean-build bump-build require-flutter android-available sign-android prepare-artifacts ## Build signed Android release APK
	@$(PRINT_STEP) "Building signed Android APK $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_APK)
	@test -f "$(ANDROID_APK_SOURCE)" || { $(PRINT_ERROR) "APK not found: $(ANDROID_APK_SOURCE)"; exit 1; }
	cp "$(ANDROID_APK_SOURCE)" "$(ANDROID_APK_ARTIFACT)"
	@$(PRINT_OK) "APK: $(ANDROID_APK_ARTIFACT)"

.PHONY: build-android-apk-split
build-android-apk-split: clean-build bump-build require-flutter android-available sign-android prepare-artifacts ## Build signed split APKs (per-ABI)
	@$(PRINT_STEP) "Building signed split Android APKs $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_APK_SPLIT)
	@for abi in arm64-v8a armeabi-v7a x86_64 universal; do \
		src="$(ANDROID_APK_SPLIT_DIR)/app-$$abi-release.apk"; \
		dst="$(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-$$abi.apk"; \
		if [ -f "$$src" ]; then cp "$$src" "$$dst"; fi; \
	done
	@$(PRINT_OK) "Split APKs: $(DIST_DIR)"

.PHONY: build-android-aab
build-android-aab: clean-build bump-build require-flutter android-available sign-android prepare-artifacts ## Build signed Android release App Bundle
	@$(PRINT_STEP) "Building signed Android App Bundle $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_AAB)
	@test -f "$(ANDROID_AAB_SOURCE)" || { $(PRINT_ERROR) "AAB not found: $(ANDROID_AAB_SOURCE)"; exit 1; }
	cp "$(ANDROID_AAB_SOURCE)" "$(ANDROID_AAB_ARTIFACT)"
	@$(PRINT_OK) "AAB: $(ANDROID_AAB_ARTIFACT)"

.PHONY: build-android
build-android: build-android-apk build-android-apk-split build-android-aab ## Build all signed Android artifacts
	@$(PRINT_OK) "Android artifacts completed"

.PHONY: sign-macos
sign-macos: macos-available ## Sign macOS app bundle with MACOS_CODESIGN_IDENTITY
	@$(call REQUIRE_TOOL,$(CODESIGN))
	@test -d "$(MACOS_APP_SOURCE)" || { $(PRINT_ERROR) "macOS app not found: $(MACOS_APP_SOURCE)"; exit 1; }
	@$(PRINT_STEP) "Signing macOS app with identity '$(MACOS_CODESIGN_IDENTITY)'"
	$(CODESIGN) --force --deep --timestamp --options runtime --sign "$(MACOS_CODESIGN_IDENTITY)" "$(MACOS_APP_SOURCE)"
	@$(PRINT_OK) "macOS app signed"

.PHONY: build-macos
build-macos: clean-build bump-build require-flutter macos-available prepare-artifacts ## Build signed macOS release zip
	@$(call REQUIRE_TOOL,$(DITTO))
	@$(PRINT_STEP) "Building macOS release $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_MACOS)
	$(MAKE) sign-macos
	$(DITTO) -c -k --keepParent "$(MACOS_APP_SOURCE)" "$(MACOS_ZIP_ARTIFACT)"
	@$(PRINT_OK) "macOS zip: $(MACOS_ZIP_ARTIFACT)"

.PHONY: build-all
build-all: build-android build-macos ## Build signed release artifacts for all available platforms
	@$(PRINT_OK) "Release artifacts are in $(DIST_DIR)"

.PHONY: release
release: check test bump build-all artifacts ## Full release pipeline: lint + test + bump + build all artifacts
	@$(PRINT_HEADER) "Release $(APP_ARTIFACT_VERSION) ready"
	@$(PRINT_OK) "Artifacts in $(DIST_DIR)"

.PHONY: artifacts
artifacts: ## List generated release artifacts
	@$(PRINT_HEADER) "Release artifacts"
	@if [ -d "$(DIST_DIR)" ]; then \
		find "$(DIST_DIR)" -maxdepth 1 -type f -print | sort; \
	else \
		$(PRINT_WARN) "No artifacts directory yet: $(DIST_DIR)"; \
	fi

endif
