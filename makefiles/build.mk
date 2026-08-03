ifndef BUILD_MK
BUILD_MK := 1

APP_NAME ?= glibusta
APP_VERSION = $(shell $(PYTHON) $(PUBSPEC_VALUE_SCRIPT) version 2>/dev/null || printf "0.0.0+0")
APP_ARTIFACT_VERSION = $(subst +,_,$(APP_VERSION))

DIST_DIR ?= dist/releases
BUILD_DIR ?= build
ANDROID_APK_SOURCE ?= $(BUILD_DIR)/app/outputs/flutter-apk/app-release.apk
ANDROID_AAB_SOURCE ?= $(BUILD_DIR)/app/outputs/bundle/release/app-release.aab
ANDROID_APK_SPLIT_DIR ?= $(BUILD_DIR)/app/outputs/flutter-apk
MACOS_APP_SOURCE ?= $(BUILD_DIR)/macos/Build/Products/Release/$(APP_NAME).app

ANDROID_APK_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION).apk
ANDROID_AAB_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION).aab
MACOS_DMG_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-macos.dmg
MACOS_ENTITLEMENTS ?= macos/Runner/Release.entitlements
MACOS_DMG_STAGING ?= $(BUILD_DIR)/macos_dmg_staging

MACOS_CODESIGN_IDENTITY ?= GoSayram Glibusta

DEBUG_INFO_ANDROID ?= $(BUILD_DIR)/symbols/android
DEBUG_INFO_MACOS ?= $(BUILD_DIR)/symbols/macos

# Gradle's launcher loads its native platform support before it reads
# gradle.properties. Pass the Java 21 native-access flag through Flutter to
# the wrapper as well, so a clean Android build does not emit the warning.
GRADLE_NATIVE_ACCESS_OPTS := --enable-native-access=ALL-UNNAMED
FLUTTER_WITH_GRADLE_NATIVE_ACCESS := GRADLE_OPTS="$${GRADLE_OPTS:+$${GRADLE_OPTS} }$(GRADLE_NATIVE_ACCESS_OPTS)" $(FLUTTER)
FLUTTER_BUILD_APK := $(FLUTTER_WITH_GRADLE_NATIVE_ACCESS) build apk --release --obfuscate --split-debug-info=$(DEBUG_INFO_ANDROID)
FLUTTER_BUILD_APK_SPLIT := $(FLUTTER_WITH_GRADLE_NATIVE_ACCESS) build apk --release --split-per-abi --target-platform android-arm,android-arm64 --obfuscate --split-debug-info=$(DEBUG_INFO_ANDROID)
FLUTTER_BUILD_AAB := $(FLUTTER_WITH_GRADLE_NATIVE_ACCESS) build appbundle --release --obfuscate --split-debug-info=$(DEBUG_INFO_ANDROID)
FLUTTER_BUILD_MACOS := $(FLUTTER) build macos --release --obfuscate --split-debug-info=$(DEBUG_INFO_MACOS)
CARGO_BUILD_RELEASE := cd rust && cargo build --release
CARGO_CHECK := cd rust && cargo check
# The repository default is rust/.cargo/config.toml ([build] jobs = 4).
# CARGO_BUILD_JOBS remains an explicit per-invocation override for CI or a
# developer who deliberately wants a different limit.
ANDROID_NDK_HOME ?= $(or $(ANDROID_NDK_ROOT),$(ANDROID_NDK_LATEST_HOME),$(HOME)/Library/Android/sdk/ndk/29.0.13846066)
ANDROID_NDK_PREBUILT_DIR := $(firstword $(wildcard $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/*))
ANDROID_NDK_TOOLCHAIN_BIN := $(ANDROID_NDK_PREBUILT_DIR)/bin
ANDROID_NDK_SYSROOT_LIB := $(ANDROID_NDK_PREBUILT_DIR)/sysroot/usr/lib
ANDROID_RUST_API_LEVEL ?= 21
ANDROID_LINK_SHIMS := $(CURDIR)/rust/android-link-shims
JNILIBS_DIR := android/app/src/main/jniLibs
ANDROID_16K_RUSTFLAGS := -C link-arg=-Wl,-z,max-page-size=16384
ANDROID_CXX_RUNTIME_RUSTFLAGS := -C link-arg=-lc++_shared
ANDROID_ARM64_LIBCXX_SHARED := $(ANDROID_NDK_SYSROOT_LIB)/aarch64-linux-android/libc++_shared.so
ANDROID_ARMV7_LIBCXX_SHARED := $(ANDROID_NDK_SYSROOT_LIB)/arm-linux-androideabi/libc++_shared.so
ANDROID_16K_CHECK := $(PYTHON) scripts/check_android_16k.py
# Android's bionic libc has no `lutimes`.  UnRAR only reaches this call while
# restoring a symlink's metadata; CBR pages are read into memory instead.
UNRAR_NG_ANDROID_CXXFLAGS := -Dlutimes=utimes

##@ Build

.PHONY: rust-build-release
rust-build-release: require-rust ## Build Rust native library in release mode
	@$(PRINT_STEP) "Building Rust library (release)"
	$(CARGO_BUILD_RELEASE)
	@ls -lh rust/target/release/libglibusta_core.* 2>/dev/null || true
	@$(PRINT_OK) "Rust release build complete"

.PHONY: require-android-ndk
require-android-ndk:
	@test -d "$(ANDROID_NDK_HOME)" || { $(PRINT_ERROR) "Android NDK not found: $(ANDROID_NDK_HOME). Set ANDROID_NDK_HOME to an installed NDK."; exit 1; }
	@test -d "$(ANDROID_NDK_PREBUILT_DIR)" || { $(PRINT_ERROR) "Android NDK host toolchain not found under $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt. Install a host-compatible NDK or set ANDROID_NDK_HOME."; exit 1; }
	@test -x "$(ANDROID_NDK_TOOLCHAIN_BIN)/llvm-ar" || { $(PRINT_ERROR) "Android NDK host toolchain is incomplete: $(ANDROID_NDK_TOOLCHAIN_BIN)."; exit 1; }

.PHONY: rust-build-android
rust-build-android: require-rust require-android-ndk ## Build Rust native libraries for Android (arm64-v8a + armeabi-v7a)
	@$(PRINT_STEP) "Building Rust libraries for Android"
	@export ANDROID_NDK_HOME="$(ANDROID_NDK_HOME)"; \
	export CXXFLAGS="$${CXXFLAGS:+$${CXXFLAGS} }$(UNRAR_NG_ANDROID_CXXFLAGS)"; \
	export PATH="$${HOME}/.cargo/bin:$${HOME}/.rustup/toolchains/stable-aarch64-apple-darwin/bin:$${PATH}"; \
	mkdir -p $(JNILIBS_DIR)/arm64-v8a $(JNILIBS_DIR)/armeabi-v7a $(ANDROID_LINK_SHIMS); \
	cd rust && \
	RUSTFLAGS="$${RUSTFLAGS:+$${RUSTFLAGS} }$(ANDROID_16K_RUSTFLAGS) $(ANDROID_CXX_RUNTIME_RUSTFLAGS) -Lnative=$(ANDROID_LINK_SHIMS)" \
	CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$(ANDROID_NDK_TOOLCHAIN_BIN)/aarch64-linux-android$(ANDROID_RUST_API_LEVEL)-clang" \
	CC_aarch64_linux_android="$(ANDROID_NDK_TOOLCHAIN_BIN)/aarch64-linux-android$(ANDROID_RUST_API_LEVEL)-clang" \
	CXX_aarch64_linux_android="$(ANDROID_NDK_TOOLCHAIN_BIN)/aarch64-linux-android$(ANDROID_RUST_API_LEVEL)-clang++" \
	AR_aarch64_linux_android="$(ANDROID_NDK_TOOLCHAIN_BIN)/llvm-ar" \
	cargo build --target aarch64-linux-android --release && \
	RUSTFLAGS="$${RUSTFLAGS:+$${RUSTFLAGS} }$(ANDROID_16K_RUSTFLAGS) $(ANDROID_CXX_RUNTIME_RUSTFLAGS) -Lnative=$(ANDROID_LINK_SHIMS)" \
	CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER="$(ANDROID_NDK_TOOLCHAIN_BIN)/armv7a-linux-androideabi$(ANDROID_RUST_API_LEVEL)-clang" \
	CC_armv7_linux_androideabi="$(ANDROID_NDK_TOOLCHAIN_BIN)/armv7a-linux-androideabi$(ANDROID_RUST_API_LEVEL)-clang" \
	CXX_armv7_linux_androideabi="$(ANDROID_NDK_TOOLCHAIN_BIN)/armv7a-linux-androideabi$(ANDROID_RUST_API_LEVEL)-clang++" \
	AR_armv7_linux_androideabi="$(ANDROID_NDK_TOOLCHAIN_BIN)/llvm-ar" \
	cargo build --target armv7-linux-androideabi --release
	cp rust/target/aarch64-linux-android/release/libglibusta_core.so $(JNILIBS_DIR)/arm64-v8a/
	cp rust/target/armv7-linux-androideabi/release/libglibusta_core.so $(JNILIBS_DIR)/armeabi-v7a/
	cp $(ANDROID_ARM64_LIBCXX_SHARED) $(JNILIBS_DIR)/arm64-v8a/
	cp $(ANDROID_ARMV7_LIBCXX_SHARED) $(JNILIBS_DIR)/armeabi-v7a/
	@$(PRINT_OK) "Android Rust libraries built and copied to $(JNILIBS_DIR)"

.PHONY: check-android-16k
check-android-16k: ## Verify arm64 native libraries in APK/AAB for 16 KiB page compatibility (ARTIFACT=path)
	@test -n "$(ARTIFACT)" || { $(PRINT_ERROR) "Set ARTIFACT to a release APK or AAB"; exit 1; }
	$(ANDROID_16K_CHECK) --scan-page-size-assumptions rust/src "$(ARTIFACT)"

.PHONY: rust-build-check
rust-build-check: require-rust ## Verify Rust code compiles
	@$(PRINT_STEP) "Verifying Rust compilation"
	$(CARGO_CHECK)
	@$(PRINT_OK) "Rust compilation verified"

.PHONY: pdfium
pdfium: ## Download and verify PDFium binaries (v152.0.7934.0) from GitHub release with Sigstore attestation
	@$(PRINT_STEP) "Downloading PDFium binaries"
	@$(SCRIPTS_DIR)/download-pdfium.sh

.PHONY: rust-sync-version
rust-sync-version: ## Sync Rust crate version with pubspec.yaml
	@$(PRINT_STEP) "Syncing Rust version from pubspec.yaml"
	@CARGO_VER=$$($(PYTHON) -c "import re; \
		v=re.search(r'version:\s*(.+)', open('pubspec.yaml').read()).group(1).strip(); \
		ver=v.split('+')[0]; print(ver)"); \
	perl -pi -e "s/^version = .*/version = \"$$CARGO_VER\"/" rust/Cargo.toml; \
	echo "  Rust version: $$CARGO_VER"

.PHONY: bump
bump: require-python ## Bump PATCH version (SemVer): 0.1.5+3 → 0.1.6+0
	@$(PRINT_STEP) "Bumping patch version"
	@NEW_VER=$$($(PYTHON) $(SCRIPTS_DIR)/bump_version.py); \
	echo "  $$NEW_VER"
	@$(MAKE) rust-sync-version

.PHONY: bump-minor
bump-minor: require-python ## Bump MINOR version (SemVer): 0.1.5+3 → 0.2.0+0
	@$(PRINT_STEP) "Bumping minor version"
	@NEW_VER=$$($(PYTHON) $(SCRIPTS_DIR)/bump_version.py --minor); \
	echo "  $$NEW_VER"
	@$(MAKE) rust-sync-version

.PHONY: bump-major
bump-major: require-python ## Bump MAJOR version (SemVer): 0.1.5+3 → 1.0.0+0
	@$(PRINT_STEP) "Bumping major version"
	@NEW_VER=$$($(PYTHON) $(SCRIPTS_DIR)/bump_version.py --major); \
	echo "  $$NEW_VER"
	@$(MAKE) rust-sync-version

.PHONY: bump-build
bump-build: require-python ## Bump build number only: 0.1.5+3 → 0.1.5+4
	@$(PRINT_STEP) "Bumping build number"
	@NEW_VER=$$($(PYTHON) $(SCRIPTS_DIR)/bump_version.py --build); \
	echo "  $$NEW_VER"
	@$(MAKE) rust-sync-version

.PHONY: subset-fonts
subset-fonts: ## Subset font files to reduce APK size (Cyrillic + Latin + punctuation only)
	@$(PRINT_STEP) "Subsetting fonts (fonttools)"
	@$(PYTHON_TOOLS_VENV)/bin/python $(SCRIPTS_DIR)/subset_fonts.py

.PHONY: restore-fonts
restore-fonts: ## Restore original fonts from git
	@$(PRINT_STEP) "Restoring original fonts"
	@git checkout assets/fonts/

.PHONY: clean-artifacts
clean-artifacts: ## Remove generated release artifacts
	@$(PRINT_STEP) "Cleaning release artifacts"
	rm -rf "$(DIST_DIR)"

.PHONY: clean-build
clean-build: ## Remove all build artifacts, caches and release artifacts for a fresh build
	@$(PRINT_STEP) "Cleaning build artifacts and caches"
	rm -rf "$(BUILD_DIR)"
	rm -rf "$(DIST_DIR)"
	rm -rf "$(MACOS_DMG_STAGING)"
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
build-android-apk: clean-build rust-build-android subset-fonts bump-build require-flutter android-available sign-android prepare-artifacts ## Build signed Android release APK
	@$(PRINT_STEP) "Building signed Android APK $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_APK)
	@test -f "$(ANDROID_APK_SOURCE)" || { $(PRINT_ERROR) "APK not found: $(ANDROID_APK_SOURCE)"; exit 1; }
	cp "$(ANDROID_APK_SOURCE)" "$(ANDROID_APK_ARTIFACT)"
	$(ANDROID_16K_CHECK) --scan-page-size-assumptions rust/src "$(ANDROID_APK_ARTIFACT)"
	@$(PRINT_OK) "APK: $(ANDROID_APK_ARTIFACT)"

.PHONY: build-android-apk-split
build-android-apk-split: clean-build rust-build-android subset-fonts bump-build require-flutter android-available sign-android prepare-artifacts ## Build signed split APKs (per-ABI)
	@$(PRINT_STEP) "Building signed split Android APKs $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_APK_SPLIT) || true
	@for abi in arm64-v8a armeabi-v7a; do \
		src="$(ANDROID_APK_SPLIT_DIR)/app-$$abi-release.apk"; \
		dst="$(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-$$abi.apk"; \
		if [ -f "$$src" ]; then cp "$$src" "$$dst"; else echo "Warning: Missing $$abi APK"; fi; \
	done
	@[ -f "$(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-arm64-v8a.apk" ] || { $(PRINT_ERROR) "No APKs produced"; exit 1; }
	$(ANDROID_16K_CHECK) --scan-page-size-assumptions rust/src "$(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-arm64-v8a.apk"
	@$(PRINT_OK) "Split APKs: $(DIST_DIR)"

.PHONY: build-android-aab
build-android-aab: clean-build rust-build-android subset-fonts bump-build require-flutter android-available sign-android prepare-artifacts ## Build signed Android release App Bundle
	@$(PRINT_STEP) "Building signed Android App Bundle $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_AAB)
	@test -f "$(ANDROID_AAB_SOURCE)" || { $(PRINT_ERROR) "AAB not found: $(ANDROID_AAB_SOURCE)"; exit 1; }
	cp "$(ANDROID_AAB_SOURCE)" "$(ANDROID_AAB_ARTIFACT)"
	$(ANDROID_16K_CHECK) --scan-page-size-assumptions rust/src "$(ANDROID_AAB_ARTIFACT)"
	@$(PRINT_OK) "AAB: $(ANDROID_AAB_ARTIFACT)"

.PHONY: build-android
build-android: build-android-apk build-android-apk-split build-android-aab ## Build all signed Android artifacts
	@$(PRINT_OK) "Android artifacts completed"

.PHONY: sign-macos
sign-macos: macos-available ## Sign macOS app bundle with MACOS_CODESIGN_IDENTITY + entitlements
	@$(call REQUIRE_TOOL,$(CODESIGN))
	@test -d "$(MACOS_APP_SOURCE)" || { $(PRINT_ERROR) "macOS app not found: $(MACOS_APP_SOURCE)"; exit 1; }
	@test -f "$(MACOS_ENTITLEMENTS)" || { $(PRINT_ERROR) "Entitlements not found: $(MACOS_ENTITLEMENTS)"; exit 1; }
	@$(PRINT_STEP) "Signing macOS app with identity '$(MACOS_CODESIGN_IDENTITY)'"
	$(CODESIGN) --force --deep --timestamp --options runtime \
		--entitlements "$(MACOS_ENTITLEMENTS)" \
		--sign "$(MACOS_CODESIGN_IDENTITY)" "$(MACOS_APP_SOURCE)"
	@$(PRINT_OK) "macOS app signed"

.PHONY: verify-macos
verify-macos: macos-available ## Verify macOS app signature
	@$(call REQUIRE_TOOL,$(CODESIGN))
	@$(call REQUIRE_TOOL,spctl)
	@test -d "$(MACOS_APP_SOURCE)" || { $(PRINT_ERROR) "macOS app not found: $(MACOS_APP_SOURCE)"; exit 1; }
	@$(PRINT_STEP) "Verifying macOS app signature"
	$(CODESIGN) --verify --deep --strict --verbose=2 "$(MACOS_APP_SOURCE)"
	@$(PRINT_STEP) "Assessing macOS app with Gatekeeper"
	-spctl -a -vvv "$(MACOS_APP_SOURCE)" 2>&1 || $(PRINT_WARN) "Gatekeeper rejected (self-signed cert is normal)"
	@$(PRINT_OK) "macOS signature verified"

.PHONY: build-macos
build-macos: clean-build subset-fonts bump-build require-flutter macos-available prepare-artifacts ## Build signed macOS DMG
	@$(call REQUIRE_TOOL,hdiutil)
	@$(PRINT_STEP) "Building macOS release $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_MACOS)
	$(MAKE) sign-macos
	$(MAKE) verify-macos
	@$(PRINT_STEP) "Creating DMG with Applications symlink"
	rm -rf "$(MACOS_DMG_STAGING)"
	mkdir -p "$(MACOS_DMG_STAGING)"
	cp -R "$(MACOS_APP_SOURCE)" "$(MACOS_DMG_STAGING)/"
	ln -s /Applications "$(MACOS_DMG_STAGING)/Applications"
	hdiutil create -volname "$(PROJECT_NAME)" \
		-srcfolder "$(MACOS_DMG_STAGING)" \
		-ov -format UDZO "$(MACOS_DMG_ARTIFACT)"
	rm -rf "$(MACOS_DMG_STAGING)"
	$(CODESIGN) --force --sign "$(MACOS_CODESIGN_IDENTITY)" "$(MACOS_DMG_ARTIFACT)"
	@$(PRINT_OK) "macOS DMG: $(MACOS_DMG_ARTIFACT)"

.PHONY: build-release
build-release: clean-build rust-build-android subset-fonts bump-build require-flutter android-available sign-android macos-available prepare-artifacts ## Build split APKs + signed macOS DMG in one pass (single clean)
	@$(call REQUIRE_TOOL,hdiutil)
	@$(PRINT_STEP) "Building split Android APKs $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_APK_SPLIT) || true
	@for abi in arm64-v8a armeabi-v7a; do \
		src="$(ANDROID_APK_SPLIT_DIR)/app-$$abi-release.apk"; \
		dst="$(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-$$abi.apk"; \
		if [ -f "$$src" ]; then cp "$$src" "$$dst"; fi; \
	done
	@[ -f "$(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-arm64-v8a.apk" ] || { $(PRINT_ERROR) "No APKs produced"; exit 1; }
	$(ANDROID_16K_CHECK) --scan-page-size-assumptions rust/src "$(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-arm64-v8a.apk"
	@$(PRINT_OK) "Split APKs done"
	@$(PRINT_STEP) "Building macOS release $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_MACOS)
	@$(PRINT_STEP) "Signing macOS app with identity '$(MACOS_CODESIGN_IDENTITY)'"
	$(CODESIGN) --force --deep --timestamp --options runtime \
		--entitlements "$(MACOS_ENTITLEMENTS)" \
		--sign "$(MACOS_CODESIGN_IDENTITY)" "$(MACOS_APP_SOURCE)"
	@$(PRINT_STEP) "Verifying macOS app signature"
	$(CODESIGN) --verify --deep --strict --verbose=2 "$(MACOS_APP_SOURCE)"
	@$(PRINT_STEP) "Creating DMG with Applications symlink"
	rm -rf "$(MACOS_DMG_STAGING)"
	mkdir -p "$(MACOS_DMG_STAGING)"
	cp -R "$(MACOS_APP_SOURCE)" "$(MACOS_DMG_STAGING)/"
	ln -s /Applications "$(MACOS_DMG_STAGING)/Applications"
	hdiutil create -volname "$(PROJECT_NAME)" \
		-srcfolder "$(MACOS_DMG_STAGING)" \
		-ov -format UDZO "$(MACOS_DMG_ARTIFACT)"
	rm -rf "$(MACOS_DMG_STAGING)"
	$(CODESIGN) --force --sign "$(MACOS_CODESIGN_IDENTITY)" "$(MACOS_DMG_ARTIFACT)"
	@$(PRINT_OK) "macOS DMG: $(MACOS_DMG_ARTIFACT)"
	@$(PRINT_OK) "All signed release artifacts in $(DIST_DIR)"
	@ls -lh "$(DIST_DIR)"/ 2>/dev/null || true

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
