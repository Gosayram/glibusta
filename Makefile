SHELL := /bin/bash

PROJECT_NAME := Glibusta
CODEGEN_CHECK_SCRIPT ?= scripts/codegen_check.sh
HACK_VENV ?= .venv-hack
HACK_PYTHON ?= $(HACK_VENV)/bin/python
HACK_REQUIREMENTS ?= hack/requirements.txt
SNAPSHOT_BACKEND ?= crawl4ai

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

.PHONY: install-hack-tools flibusta-audit
install-hack-tools: require-python ## Install isolated dependencies for public Flibusta audit tools
	@if [ ! -x "$(HACK_PYTHON)" ]; then $(PYTHON) -m venv "$(HACK_VENV)"; fi
	@$(HACK_PYTHON) -m pip install --requirement "$(HACK_REQUIREMENTS)"

flibusta-audit: install-hack-tools ## Audit public Flibusta metadata only when robots.txt allows it
	@$(HACK_PYTHON) hack/public_surface_audit.py

.PHONY: flibusta-snapshots
flibusta-snapshots: install-hack-tools ## Collect bare HTML/XML fixtures via crawl4ai (robots-gated). Override backend: make flibusta-snapshots SNAPSHOT_BACKEND=requests
	@$(HACK_PYTHON) hack/snapshot.py --backend $(SNAPSHOT_BACKEND)

.PHONY: help
help: ## Show this help
	@$(PYTHON) $(MAKE_HELP_SCRIPT) \
		--project-name "$(PROJECT_NAME)" \
		--version "$(APP_ARTIFACT_VERSION)" \
		$(MAKEFILE_LIST)
