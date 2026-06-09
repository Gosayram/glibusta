ifndef QUALITY_MK
QUALITY_MK := 1

##@ Quality

.PHONY: get
get: require-flutter ## Install Flutter dependencies
	@$(PRINT_STEP) "Installing Flutter dependencies"
	$(PUB_GET)

.PHONY: npm-install
npm-install: require-node ## Install Node dependencies for docs/config formatting
	@$(PRINT_STEP) "Installing Node dependencies"
	$(NPM) install

.PHONY: nvm-use
nvm-use: require-nvm ## Install/use the Node version from .nvmrc
	@$(PRINT_STEP) "Installing and selecting Node via nvm"
	@$(call NVM_EXEC,node --version && npm --version)

.PHONY: npm-install-nvm
npm-install-nvm: require-nvm ## Install Node dependencies using nvm-selected Node
	@$(PRINT_STEP) "Installing Node dependencies via nvm"
	@$(call NVM_EXEC,npm install)

.PHONY: install-python-tools
install-python-tools: require-python ## Install local Python quality tools
	@$(PRINT_STEP) "Installing Python quality tools"
	@if [ ! -d "$(PYTHON_TOOLS_VENV)" ]; then \
		$(PYTHON) -m venv "$(PYTHON_TOOLS_VENV)"; \
	fi
	$(PIP) install --upgrade pip
	$(PIP) install --upgrade -r "$(PYTHON_REQUIREMENTS)"

.PHONY: format
format: require-dart ## Format Dart sources
	@$(PRINT_STEP) "Formatting Dart sources"
	$(DART_FORMAT) $(DART_FORMAT_PATHS)

.PHONY: format-check
format-check: require-dart ## Check Dart formatting
	@$(PRINT_STEP) "Checking Dart formatting"
	$(DART_FORMAT) --set-exit-if-changed $(DART_FORMAT_PATHS)

.PHONY: fix
fix: require-dart ## Apply Dart automated fixes
	@$(PRINT_STEP) "Applying Dart fixes"
	$(DART_FIX) --apply .

.PHONY: prettier
prettier: require-node ## Format Markdown, YAML, and JSON files
	@$(PRINT_STEP) "Formatting docs/config files"
	$(PRETTIER) --write "$(PRETTIER_GLOBS)"

.PHONY: prettier-check
prettier-check: require-node ## Check Markdown, YAML, and JSON formatting
	@$(PRINT_STEP) "Checking docs/config formatting"
	$(PRETTIER) --check "$(PRETTIER_GLOBS)"

.PHONY: ruff-format
ruff-format: require-ruff ## Format Python scripts with Ruff
	@$(PRINT_STEP) "Formatting Python scripts"
	$(RUFF_FORMAT) $(PYTHON_PATHS)

.PHONY: ruff-check
ruff-check: require-ruff ## Lint Python scripts with Ruff
	@$(PRINT_STEP) "Checking Python scripts"
	$(RUFF_CHECK) $(PYTHON_PATHS)

.PHONY: ruff-fix
ruff-fix: require-ruff ## Apply Ruff fixes to Python scripts
	@$(PRINT_STEP) "Applying Ruff fixes"
	$(RUFF_CHECK) --fix $(PYTHON_PATHS)

.PHONY: shellcheck
shellcheck: require-shellcheck ## Check shell scripts with ShellCheck
	@$(PRINT_STEP) "Checking shell scripts"
	@if [ -n "$(SHELL_SCRIPT_PATHS)" ]; then \
		$(SHELLCHECK_RUN) $(SHELL_SCRIPT_PATHS); \
	else \
		$(PRINT_WARN) "No shell scripts found"; \
	fi

.PHONY: analyze
analyze: require-flutter ## Run Flutter analyzer
	@$(PRINT_STEP) "Running Flutter analyzer"
	$(FLUTTER_ANALYZE)

.PHONY: diagnostics
diagnostics: require-flutter require-python ## Summarize Dart analyzer diagnostics with docs links
	@$(PRINT_STEP) "Collecting Dart analyzer diagnostics"
	@$(PYTHON) $(DIAGNOSTICS_SCRIPT) -- $(FLUTTER_ANALYZE_NO_FATAL)

.PHONY: diagnostics-strict
diagnostics-strict: require-flutter require-python ## Summarize diagnostics and fail on any analyzer issue
	@$(PRINT_STEP) "Collecting strict Dart analyzer diagnostics"
	@$(PYTHON) $(DIAGNOSTICS_SCRIPT) --strict -- $(FLUTTER_ANALYZE_NO_FATAL)

.PHONY: test
test: require-flutter ## Run Flutter tests
	@$(PRINT_STEP) "Running Flutter tests"
	$(FLUTTER_TEST)

.PHONY: fix-all
fix-all: get npm-install-nvm install-python-tools format fix prettier ruff-format ruff-fix ## Apply all automatic fixes and formatting
	@$(PRINT_OK) "Automatic fixes completed"

.PHONY: check-all
check-all: install-python-tools format-check prettier-check ruff-check shellcheck diagnostics-strict ## Run all local linting and formatting checks
	@$(PRINT_OK) "All checks completed"

.PHONY: check
check: check-all ## Alias for check-all

endif
