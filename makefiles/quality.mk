ifndef QUALITY_MK
QUALITY_MK := 1

##@ Quality

.PHONY: get
get: ## Install Flutter dependencies
	@$(PRINT_STEP) "Installing Flutter dependencies"
	$(PUB_GET)

.PHONY: npm-install
npm-install: ## Install Node dependencies for docs/config formatting
	@$(PRINT_STEP) "Installing Node dependencies"
	$(NPM) install

.PHONY: format
format: ## Format Dart sources
	@$(PRINT_STEP) "Formatting Dart sources"
	$(DART_FORMAT) $(DART_FORMAT_PATHS)

.PHONY: format-check
format-check: ## Check Dart formatting
	@$(PRINT_STEP) "Checking Dart formatting"
	$(DART_FORMAT) --set-exit-if-changed $(DART_FORMAT_PATHS)

.PHONY: fix
fix: ## Apply Dart automated fixes
	@$(PRINT_STEP) "Applying Dart fixes"
	$(DART_FIX) --apply .

.PHONY: prettier
prettier: ## Format Markdown, YAML, and JSON files
	@$(PRINT_STEP) "Formatting docs/config files"
	$(PRETTIER) --write "$(PRETTIER_GLOBS)"

.PHONY: prettier-check
prettier-check: ## Check Markdown, YAML, and JSON formatting
	@$(PRINT_STEP) "Checking docs/config formatting"
	$(PRETTIER) --check "$(PRETTIER_GLOBS)"

.PHONY: analyze
analyze: ## Run Flutter analyzer
	@$(PRINT_STEP) "Running Flutter analyzer"
	$(FLUTTER_ANALYZE)

.PHONY: test
test: ## Run Flutter tests
	@$(PRINT_STEP) "Running Flutter tests"
	$(FLUTTER_TEST)

.PHONY: fix-all
fix-all: get npm-install format fix prettier ## Apply all automatic fixes and formatting
	@$(PRINT_OK) "Automatic fixes completed"

.PHONY: check-all
check-all: format-check prettier-check analyze test ## Run all local verification checks
	@$(PRINT_OK) "All checks completed"

.PHONY: check
check: check-all ## Alias for check-all

endif
