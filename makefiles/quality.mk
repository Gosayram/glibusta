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

.PHONY: drift-schema-check
drift-schema-check: require-dart ## Regenerate Drift schema and verify no diff
	@$(PRINT_STEP) "Checking Drift schema consistency"
	$(DART) run drift_dev schema dump lib/core/database/app_database.dart schema/
	@cd schema && git diff --quiet drift_schema_v14.json || (echo "Schema drift detected! Run: dart run drift_dev schema dump" && exit 1)

.PHONY: rust-size
rust-size: ## Show Rust binary sizes
	@$(PRINT_STEP) "Rust binary sizes:"
	@ls -lh rust/target/release/libglibusta_core.* 2>/dev/null || echo "Run 'cargo build --release' first"

.PHONY: flutter-size
flutter-size: ## Analyze APK/AAB size
	@$(PRINT_STEP) "Analyzing Flutter build size"
	@TMP_LOG=$$(mktemp); \
	if flutter build apk --analyze-size --target-platform android-arm64 > "$$TMP_LOG" 2>&1; then \
		tail -5 "$$TMP_LOG"; \
		rm -f "$$TMP_LOG"; \
	else \
		tail -20 "$$TMP_LOG"; \
		rm -f "$$TMP_LOG"; \
		exit 1; \
	fi

.PHONY: rust-audit
rust-audit: ## Scan Rust dependencies for CVE vulnerabilities
	@$(PRINT_STEP) "Scanning Rust dependencies for vulnerabilities"
	cd rust && cargo audit

.PHONY: rust-deny
rust-deny: ## Check licenses, bans, advisories, sources via cargo-deny
	@$(PRINT_STEP) "Checking Rust dependency policy"
	cd rust && cargo deny check --allow no-license-field

.PHONY: rust-outdated
rust-outdated: ## Show outdated direct Rust dependencies
	@$(PRINT_STEP) "Checking outdated Rust dependencies"
	cd rust && cargo outdated --depth 1

.PHONY: rust-upgrade-check
rust-upgrade-check: ## Check available Rust dependency upgrades (dry run)
	@$(PRINT_STEP) "Checking Rust upgrade candidates"
	cd rust && cargo upgrade --dry-run

.PHONY: rust-sort
rust-sort: ## Sort Rust dependencies alphabetically
	@$(PRINT_STEP) "Sorting Rust dependencies"
	cd rust && cargo sort

.PHONY: rust-sort-check
rust-sort-check: ## Check Rust dependency sorting
	@$(PRINT_STEP) "Checking Rust dependency sorting"
	cd rust && cargo sort --check

.PHONY: rust-nextest
rust-nextest: ## Run Rust tests with cargo-nextest (faster)
	@$(PRINT_STEP) "Running Rust tests with nextest"
	cd rust && cargo nextest run

.PHONY: rust-nextest-ci
rust-nextest-ci: ## Run Rust tests with nextest (CI mode, no re-runs)
	@$(PRINT_STEP) "Running Rust tests (CI mode)"
	cd rust && cargo nextest run --failure-quick

.PHONY: miri-setup
miri-setup: require-rust ## Install Miri (nightly + component) for UB detection
	@$(PRINT_STEP) "Installing Miri"
	rustup toolchain install nightly --component miri 2>&1

.PHONY: miri-check
miri-check: require-rust ## Run Rust tests under Miri (UB detection, requires nightly)
	@$(PRINT_STEP) "Running Miri UB checks"
	@if rustup run nightly cargo miri --version >/dev/null 2>&1; then \
		cd rust && MIRIFLAGS="-Zmiri-tree-borrows -Zmiri-disable-isolation" rustup run nightly cargo miri test; \
		$(PRINT_OK) "Miri checks passed"; \
	else \
		$(PRINT_ERROR) "Miri is unavailable — install it with: make miri-setup"; \
		exit 1; \
	fi

# ── Benchmark ──────────────────────────────────────────────────────────────────

.PHONY: trace-startup
trace-startup: require-flutter ## Build profile APK with --trace-startup and launch
	@$(PRINT_STEP) "Building profile APK with startup tracing"
	@set -o pipefail; $(FLUTTER) build apk --profile --target lib/main.dart --trace-startup 2>&1 | tee build/startup_trace.log
	@if grep -q '"timeToFirstFrameMicros"' build/startup_trace.log 2>/dev/null; then \
		$(PRINT_OK) "Startup trace logged in build/startup_trace.log"; \
	else \
		$(PRINT_WARN) "Install build/app/outputs/flutter-apk/app-profile.apk and launch manually"; \
	fi

.PHONY: benchmark
benchmark: require-flutter ## Run integration benchmark on connected device
	@$(PRINT_STEP) "Running benchmark trace"
	@if [ -z "$$(adb devices 2>/dev/null | grep -v List | grep -v '^$$' | head -1)" ]; then \
		$(PRINT_WARN) "No device connected — run with a device attached"; exit 1; \
	fi
	@$(FLUTTER) test integration_test/benchmark_test.dart --profile \
		&& $(PRINT_OK) "Benchmark complete — trace in build/benchmark/"

# ── Fix / Check ────────────────────────────────────────────────────────────────

.PHONY: fix-all
fix-all: get npm-install-nvm install-python-tools format fix prettier ruff-format ruff-fix rustfmt rust-clippy-fix miri-check ## Apply all automatic fixes and formatting
	@$(PRINT_OK) "Automatic fixes completed"

.PHONY: check-all
check-all: install-python-tools format-check prettier-check ruff-check shellcheck diagnostics-strict rustfmt-check rust-clippy rust-deny rust-sort-check miri-check ## Run all local linting and formatting checks
	@$(PRINT_OK) "All checks completed"

.PHONY: check
check: check-all ## Alias for check-all

endif
