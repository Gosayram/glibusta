ifndef COMMON_MK
COMMON_MK := 1

C_RESET := \033[0m
C_BOLD := \033[1m
C_DIM := \033[2m
C_RED := \033[31m
C_GREEN := \033[32m
C_YELLOW := \033[33m
C_BLUE := \033[34m
C_MAGENTA := \033[35m
C_CYAN := \033[36m

FLUTTER ?= flutter
DART ?= dart
NPM ?= npm
NPX ?= npx
PYTHON ?= python3
SHELLCHECK ?= shellcheck
PYTHON_TOOLS_VENV ?= .venv-tools
PYTHON_REQUIREMENTS ?= requirements.txt
PIP ?= $(PYTHON_TOOLS_VENV)/bin/pip
RUFF ?= $(PYTHON_TOOLS_VENV)/bin/ruff
CODESIGN ?= codesign
DITTO ?= ditto
NVM_DIR ?= $(HOME)/.nvm
NVM_SH ?= $(NVM_DIR)/nvm.sh

SCRIPTS_DIR ?= scripts
PUBSPEC_VALUE_SCRIPT ?= $(SCRIPTS_DIR)/pubspec_value.py
MAKE_HELP_SCRIPT ?= $(SCRIPTS_DIR)/make_help.py
BOOTSTRAP_SCRIPT ?= $(SCRIPTS_DIR)/bootstrap_tools.py
DIAGNOSTICS_SCRIPT ?= $(SCRIPTS_DIR)/dart_diagnostics.py

PUB_GET := $(FLUTTER) pub get
PUB_OUTDATED := $(FLUTTER) pub outdated
PUB_UPGRADE := $(FLUTTER) pub upgrade
PUB_UPGRADE_MAJOR := $(FLUTTER) pub upgrade --major-versions
DART_FORMAT := $(DART) format
DART_FIX := $(DART) fix
FLUTTER_ANALYZE := $(FLUTTER) analyze
FLUTTER_ANALYZE_NO_FATAL := $(FLUTTER) analyze --no-fatal-infos --no-fatal-warnings
FLUTTER_TEST := $(FLUTTER) test
PRETTIER := $(NPX) prettier
NPM_OUTDATED := $(NPM) outdated
NPM_UPDATE := $(NPM) update
RUFF_CHECK := $(RUFF) check
RUFF_FORMAT := $(RUFF) format
SHELLCHECK_RUN := $(SHELLCHECK)

DART_FORMAT_PATHS ?= lib test
PRETTIER_GLOBS ?= **/*.{md,yml,yaml,json}
PYTHON_PATHS ?= scripts
SHELL_SCRIPT_PATHS ?= $(shell find scripts -type f -name '*.sh' 2>/dev/null)

PRINT_HEADER = printf "\n$(C_BOLD)$(C_BLUE)%s$(C_RESET)\n\n"
PRINT_STEP = printf "$(C_BOLD)$(C_CYAN)==>$(C_RESET) %s\n"
PRINT_OK = printf "$(C_GREEN)OK$(C_RESET) %s\n"
PRINT_WARN = printf "$(C_YELLOW)WARN$(C_RESET) %s\n"
PRINT_ERROR = printf "$(C_RED)ERROR$(C_RESET) %s\n"

REQUIRE_TOOL = command -v "$(1)" >/dev/null 2>&1 || { $(PRINT_ERROR) "Required tool not found: $(1)"; exit 127; }
NVM_EXEC = bash -lc 'source "$(NVM_SH)" && (nvm use || (nvm install && nvm use)) && $(1)'

##@ Tooling

.PHONY: require-flutter
require-flutter: ## Verify Flutter is available
	@$(call REQUIRE_TOOL,$(FLUTTER))

.PHONY: require-dart
require-dart: ## Verify Dart is available
	@$(call REQUIRE_TOOL,$(DART))

.PHONY: require-node
require-node: ## Verify npm and npx are available
	@$(call REQUIRE_TOOL,$(NPM))
	@$(call REQUIRE_TOOL,$(NPX))

.PHONY: require-nvm
require-nvm: ## Verify nvm is available
	@test -f "$(NVM_SH)" || { $(PRINT_ERROR) "nvm not found: $(NVM_SH)"; exit 127; }

.PHONY: require-python
require-python: ## Verify Python is available
	@$(call REQUIRE_TOOL,$(PYTHON))

.PHONY: require-shellcheck
require-shellcheck: ## Verify ShellCheck is available
	@$(call REQUIRE_TOOL,$(SHELLCHECK))

.PHONY: require-ruff
require-ruff: ## Verify Ruff is available
	@$(call REQUIRE_TOOL,$(RUFF))

endif
