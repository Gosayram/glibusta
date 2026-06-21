SHELL := /bin/bash

PROJECT_NAME := Glibusta

include makefiles/common.mk
include makefiles/bootstrap.mk
include makefiles/build.mk
include makefiles/quality.mk
include makefiles/upgrade.mk
include makefiles/signing.mk
include makefiles/device.mk

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@$(PYTHON) $(MAKE_HELP_SCRIPT) \
		--project-name "$(PROJECT_NAME)" \
		--version "$(APP_ARTIFACT_VERSION)" \
		$(MAKEFILE_LIST)
