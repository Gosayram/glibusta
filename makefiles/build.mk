ifndef BUILD_MK
BUILD_MK := 1

APP_NAME ?= glibusta
APP_VERSION := $(shell $(PYTHON) $(PUBSPEC_VALUE_SCRIPT) version 2>/dev/null || printf "0.0.0+0")
APP_ARTIFACT_VERSION := $(APP_VERSION)

DIST_DIR ?= dist/releases
BUILD_DIR ?= build
ANDROID_APK_SOURCE ?= $(BUILD_DIR)/app/outputs/flutter-apk/app-release.apk
ANDROID_AAB_SOURCE ?= $(BUILD_DIR)/app/outputs/bundle/release/app-release.aab
MACOS_APP_SOURCE ?= $(BUILD_DIR)/macos/Build/Products/Release/$(APP_NAME).app

ANDROID_APK_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-android-release-signed.apk
ANDROID_AAB_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-android-release-signed.aab
MACOS_ZIP_ARTIFACT ?= $(DIST_DIR)/$(APP_NAME)-$(APP_ARTIFACT_VERSION)-macos-release.zip

MACOS_CODESIGN_IDENTITY ?= -

FLUTTER_BUILD_APK := $(FLUTTER) build apk --release
FLUTTER_BUILD_AAB := $(FLUTTER) build appbundle --release
FLUTTER_BUILD_MACOS := $(FLUTTER) build macos --release

##@ Build

.PHONY: clean-artifacts
clean-artifacts: ## Remove generated release artifacts
	@$(PRINT_STEP) "Cleaning release artifacts"
	rm -rf "$(DIST_DIR)"

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
build-android-apk: require-flutter android-available sign-android prepare-artifacts ## Build signed Android release APK
	@$(PRINT_STEP) "Building signed Android APK $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_APK)
	@test -f "$(ANDROID_APK_SOURCE)" || { $(PRINT_ERROR) "APK not found: $(ANDROID_APK_SOURCE)"; exit 1; }
	cp "$(ANDROID_APK_SOURCE)" "$(ANDROID_APK_ARTIFACT)"
	@$(PRINT_OK) "APK: $(ANDROID_APK_ARTIFACT)"

.PHONY: build-android-aab
build-android-aab: require-flutter android-available sign-android prepare-artifacts ## Build signed Android release App Bundle
	@$(PRINT_STEP) "Building signed Android App Bundle $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_AAB)
	@test -f "$(ANDROID_AAB_SOURCE)" || { $(PRINT_ERROR) "AAB not found: $(ANDROID_AAB_SOURCE)"; exit 1; }
	cp "$(ANDROID_AAB_SOURCE)" "$(ANDROID_AAB_ARTIFACT)"
	@$(PRINT_OK) "AAB: $(ANDROID_AAB_ARTIFACT)"

.PHONY: build-android
build-android: build-android-apk build-android-aab ## Build all signed Android artifacts
	@$(PRINT_OK) "Android artifacts completed"

.PHONY: sign-macos
sign-macos: macos-available ## Sign macOS app bundle with MACOS_CODESIGN_IDENTITY
	@$(call REQUIRE_TOOL,$(CODESIGN))
	@test -d "$(MACOS_APP_SOURCE)" || { $(PRINT_ERROR) "macOS app not found: $(MACOS_APP_SOURCE)"; exit 1; }
	@$(PRINT_STEP) "Signing macOS app with identity '$(MACOS_CODESIGN_IDENTITY)'"
	$(CODESIGN) --force --deep --timestamp --options runtime --sign "$(MACOS_CODESIGN_IDENTITY)" "$(MACOS_APP_SOURCE)"
	@$(PRINT_OK) "macOS app signed"

.PHONY: build-macos
build-macos: require-flutter macos-available prepare-artifacts ## Build signed macOS release zip
	@$(call REQUIRE_TOOL,$(DITTO))
	@$(PRINT_STEP) "Building macOS release $(APP_ARTIFACT_VERSION)"
	$(FLUTTER_BUILD_MACOS)
	$(MAKE) sign-macos
	$(DITTO) -c -k --keepParent "$(MACOS_APP_SOURCE)" "$(MACOS_ZIP_ARTIFACT)"
	@$(PRINT_OK) "macOS zip: $(MACOS_ZIP_ARTIFACT)"

.PHONY: build-all
build-all: build-android build-macos ## Build signed release artifacts for all available platforms
	@$(PRINT_OK) "Release artifacts are in $(DIST_DIR)"

.PHONY: artifacts
artifacts: ## List generated release artifacts
	@$(PRINT_HEADER) "Release artifacts"
	@if [ -d "$(DIST_DIR)" ]; then \
		find "$(DIST_DIR)" -maxdepth 1 -type f -print | sort; \
	else \
		$(PRINT_WARN) "No artifacts directory yet: $(DIST_DIR)"; \
	fi

endif
