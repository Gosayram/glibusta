# ============================================================================
# Signing Commands — key generation and Gradle signing configuration
# ============================================================================

SIGNING_SCRIPT=.key-generate.conf

.PHONY: get
get: ## Install Flutter dependencies
	flutter pub get

.PHONY: format
format: ## Format Dart sources
	dart format .

.PHONY: format-check
format-check: ## Check Dart formatting
	dart format --set-exit-if-changed .

.PHONY: prettier
prettier: ## Format Markdown, YAML, and JSON files with Prettier
	npx prettier --write "**/*.{md,yml,yaml,json}"

.PHONY: prettier-check
prettier-check: ## Check Markdown, YAML, and JSON formatting with Prettier
	npx prettier --check "**/*.{md,yml,yaml,json}"

.PHONY: analyze
analyze: ## Run Flutter analyzer
	flutter analyze

.PHONY: test
test: ## Run Flutter tests
	flutter test

.PHONY: check
check: format-check prettier-check analyze test ## Run all local quality checks

.PHONY: sign-android
sign-android: ## Generate signing keys and setup Android signing
	@if [ -f "$(SIGNING_SCRIPT)" ]; then \
		./scripts/signing.sh; \
		echo "Android signing configured successfully"; \
		echo "Patching Gradle configuration..."; \
		./scripts/patch-gradle-signing.sh; \
		echo "Gradle configuration patched successfully"; \
	else \
		echo "Error: Signing config not found at $(SIGNING_SCRIPT)"; \
		echo "Please create $(SIGNING_SCRIPT) from .key-generate.example.conf"; \
		exit 1; \
	fi

.PHONY: use-existing-android-cert
use-existing-android-cert: ## Use existing Android certificate for signing
	@if [ -f ".key-generate.conf" ]; then \
		if [ -f ".signing/release.keystore" ]; then \
			echo "Existing certificate found, updating configuration..."; \
			./scripts/signing.sh; \
			echo "Android signing configuration updated with existing certificate"; \
		else \
			echo "Error: No existing certificate found in .signing/release.keystore"; \
			echo "Run 'make sign-android' first to generate a certificate"; \
			exit 1; \
		fi \
	else \
		echo "Error: Config file not found at .key-generate.conf"; \
		exit 1; \
	fi

.PHONY: patch-gradle-signing
patch-gradle-signing: ## Patch Gradle signing configuration
	@if [ -f "scripts/patch-gradle-signing.sh" ]; then \
		./scripts/patch-gradle-signing.sh; \
		echo "✅ Gradle configuration patched successfully"; \
	else \
		echo "Error: Patch script not found at scripts/patch-gradle-signing.sh"; \
		exit 1; \
	fi
