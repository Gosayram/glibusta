ifndef SIGNING_MK
SIGNING_MK := 1

SIGNING_CONFIG ?= .key-generate.conf
SIGNING_KEYSTORE ?= .signing/release.keystore
SIGNING_SCRIPT ?= ./scripts/signing.sh
PATCH_GRADLE_SIGNING_SCRIPT ?= ./scripts/patch-gradle-signing.sh

##@ Signing

.PHONY: sign-android
sign-android: ## Generate Android signing keys and patch Gradle config
	@$(PRINT_STEP) "Configuring Android signing"
	@if [ -f "$(SIGNING_CONFIG)" ]; then \
		$(SIGNING_SCRIPT); \
		$(PATCH_GRADLE_SIGNING_SCRIPT); \
		$(PRINT_OK) "Android signing configured"; \
	else \
		$(PRINT_ERROR) "Signing config not found: $(SIGNING_CONFIG)"; \
		printf "Create $(SIGNING_CONFIG) from .key-generate.example.conf\n"; \
		exit 1; \
	fi

.PHONY: use-existing-android-cert
use-existing-android-cert: ## Reuse existing Android release certificate
	@$(PRINT_STEP) "Configuring existing Android certificate"
	@if [ ! -f "$(SIGNING_CONFIG)" ]; then \
		$(PRINT_ERROR) "Signing config not found: $(SIGNING_CONFIG)"; \
		exit 1; \
	fi
	@if [ ! -f "$(SIGNING_KEYSTORE)" ]; then \
		$(PRINT_ERROR) "Existing certificate not found: $(SIGNING_KEYSTORE)"; \
		printf "Run 'make sign-android' first to generate a certificate\n"; \
		exit 1; \
	fi
	@$(SIGNING_SCRIPT)
	@$(PRINT_OK) "Android signing configured with existing certificate"

.PHONY: patch-gradle-signing
patch-gradle-signing: ## Patch Gradle signing configuration
	@$(PRINT_STEP) "Patching Gradle signing configuration"
	@if [ -f "$(PATCH_GRADLE_SIGNING_SCRIPT)" ]; then \
		$(PATCH_GRADLE_SIGNING_SCRIPT); \
		$(PRINT_OK) "Gradle signing configuration patched"; \
	else \
		$(PRINT_ERROR) "Patch script not found: $(PATCH_GRADLE_SIGNING_SCRIPT)"; \
		exit 1; \
	fi

endif
