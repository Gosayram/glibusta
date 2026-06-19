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

.PHONY: rustfmt
rustfmt: ## Format Rust sources
	@$(PRINT_STEP) "Formatting Rust sources"
	cd rust && cargo fmt

.PHONY: rustfmt-check
rustfmt-check: ## Check Rust formatting
	@$(PRINT_STEP) "Checking Rust formatting"
	cd rust && cargo fmt -- --check

.PHONY: rust-clippy
rust-clippy: ## Run Clippy on Rust code
	@$(PRINT_STEP) "Running Clippy on Rust code"
	cd rust && cargo clippy --all-targets

.PHONY: rust-clippy-fix
rust-clippy-fix: ## Run Clippy and auto-fix
	@$(PRINT_STEP) "Running Clippy auto-fix on Rust code"
	cd rust && cargo clippy --fix --allow-dirty --allow-staged 2>&1
	cd rust && cargo fmt

.PHONY: rust-check
rust-check: ## Full Rust build check
	@$(PRINT_STEP) "Running cargo check"
	cd rust && cargo check

.PHONY: rust-lints
rust-lints: ## Run ltrs spell-check on Rust comments/strings
	@$(PRINT_STEP) "Checking Rust strings with LanguageTool"
	@find rust/src -name "*.rs" ! -name "frb_generated*" -exec grep -l '"[^"]*[а-яА-ЯёЁ]' {} + 2>/dev/null | \
		xargs -I{} ltrs check --language ru-RU "{}" 2>/dev/null || true

.PHONY: rust-bloat
rust-bloat: ## Analyze Rust binary size breakdown
	@$(PRINT_STEP) "Analyzing Rust binary size"
	cd rust && cargo bloat --release -n 30

.PHONY: rust-size
rust-size: ## Show Rust binary sizes
	@$(PRINT_STEP) "Rust binary sizes:"
	@ls -lh rust/target/release/libglibusta_core.* 2>/dev/null || echo "Run 'cargo build --release' first"

.PHONY: flutter-size
flutter-size: ## Analyze APK/AAB size
	@$(PRINT_STEP) "Analyzing Flutter build size"
	flutter build apk --analyze-size --target-platform android-arm64 2>&1 | tail -5

.PHONY: fix-all
fix-all: get npm-install-nvm install-python-tools format fix prettier ruff-format ruff-fix rustfmt rust-clippy-fix ## Apply all automatic fixes and formatting
	@$(PRINT_OK) "Automatic fixes completed"

.PHONY: check-all
check-all: install-python-tools format-check prettier-check ruff-check shellcheck diagnostics-strict rustfmt-check rust-clippy ## Run all local linting and formatting checks
	@$(PRINT_OK) "All checks completed"

.PHONY: check
check: check-all ## Alias for check-all

endif
