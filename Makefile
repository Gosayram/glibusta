SHELL := /bin/bash

PROJECT_NAME := Glibusta
CODEGEN_CHECK_SCRIPT ?= scripts/codegen_check.sh

include makefiles/common.mk
include makefiles/bootstrap.mk
include makefiles/build.mk
include makefiles/quality.mk
include makefiles/upgrade.mk
include makefiles/signing.mk
include makefiles/device.mk
include makefiles/secrets.mk

.DEFAULT_GOAL := help

.PHONY: codegen-check
codegen-check: require-flutter require-rust ## Regenerate FRB and l10n in a temporary worktree and fail on drift
	@$(PRINT_STEP) "Checking generated FRB bridge and l10n files"
	@$(CODEGEN_CHECK_SCRIPT)

.PHONY: help
help: ## Show this help
	@$(PYTHON) $(MAKE_HELP_SCRIPT) \
		--project-name "$(PROJECT_NAME)" \
		--version "$(APP_ARTIFACT_VERSION)" \
		$(MAKEFILE_LIST)
