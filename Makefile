SHELL := /bin/bash

PROJECT_NAME := Glibusta

include makefiles/common.mk
include makefiles/bootstrap.mk
include makefiles/build.mk
include makefiles/quality.mk
include makefiles/signing.mk

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@$(PYTHON) $(MAKE_HELP_SCRIPT) \
		--project-name "$(PROJECT_NAME)" \
		--version "$(APP_ARTIFACT_VERSION)" \
		$(MAKEFILE_LIST)
