SHELL := /bin/bash

PROJECT_NAME := Glibusta

include makefiles/common.mk
include makefiles/quality.mk
include makefiles/signing.mk

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@$(PRINT_HEADER) "$(PROJECT_NAME) make targets"
	@awk 'BEGIN {FS = ":.*##"; section = ""} \
		/^[a-zA-Z0-9_.-]+:.*##/ { \
			printf "  $(C_CYAN)%-28s$(C_RESET) %s\n", $$1, $$2; \
		} \
		/^##@/ { \
			printf "\n$(C_BOLD)%s$(C_RESET)\n", substr($$0, 5); \
		}' $(MAKEFILE_LIST)
