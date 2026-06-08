ifndef BOOTSTRAP_MK
BOOTSTRAP_MK := 1

BOOTSTRAP_FLAGS ?=

##@ Bootstrap

.PHONY: bootstrap
bootstrap: require-python ## Check tools, ask for confirmation, then install/setup missing pieces
	@$(PYTHON) $(BOOTSTRAP_SCRIPT) $(BOOTSTRAP_FLAGS)

.PHONY: bootstrap-check
bootstrap-check: require-python ## Check required tools without installing anything
	@$(PYTHON) $(BOOTSTRAP_SCRIPT) --check-only

endif
