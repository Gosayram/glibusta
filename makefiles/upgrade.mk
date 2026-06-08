ifndef UPGRADE_MK
UPGRADE_MK := 1

UPGRADE_CONFIRM ?=

##@ Upgrade

.PHONY: upgrade-check-dart
upgrade-check-dart: require-flutter ## Show available Flutter/Dart package upgrades
	@$(PRINT_STEP) "Checking Flutter/Dart package upgrades"
	$(PUB_OUTDATED) || true

.PHONY: upgrade-check-node
upgrade-check-node: require-nvm ## Show available npm package upgrades
	@$(PRINT_STEP) "Checking npm package upgrades"
	@$(call NVM_EXEC,$(NPM_OUTDATED) || true)

.PHONY: upgrade-check-python-tools
upgrade-check-python-tools: install-python-tools ## Show available Python tool upgrades
	@$(PRINT_STEP) "Checking Python tool upgrades"
	$(PIP) list --outdated || true

.PHONY: upgrade-check
upgrade-check: upgrade-check-dart upgrade-check-node upgrade-check-python-tools ## Show all available package upgrades
	@$(PRINT_OK) "Upgrade check completed"

.PHONY: upgrade-dart
upgrade-dart: require-flutter ## Upgrade Flutter/Dart packages within current constraints
	@$(PRINT_STEP) "Upgrading Flutter/Dart packages within current constraints"
	$(PUB_UPGRADE)

.PHONY: upgrade-node
upgrade-node: require-nvm ## Upgrade npm packages within current semver ranges
	@$(PRINT_STEP) "Upgrading npm packages within current semver ranges"
	@$(call NVM_EXEC,$(NPM_UPDATE))

.PHONY: upgrade-python-tools
upgrade-python-tools: install-python-tools ## Upgrade local Python quality tools
	@$(PRINT_STEP) "Upgrading Python quality tools"
	$(PIP) install --upgrade pip ruff

.PHONY: upgrade-all
upgrade-all: upgrade-check upgrade-dart upgrade-node upgrade-python-tools get npm-install-nvm ## Safely upgrade packages within current constraints
	@$(PRINT_OK) "Safe package upgrade completed"

.PHONY: upgrade-major
upgrade-major: require-flutter require-nvm install-python-tools ## Interactively upgrade Dart/npm/Python packages to latest major versions
	@$(PRINT_WARN) "This may rewrite dependency constraints and introduce breaking changes."
	@if [ "$(UPGRADE_CONFIRM)" != "yes" ]; then \
		printf "Type 'yes' to continue: "; \
		read -r answer; \
		if [ "$$answer" != "yes" ] && [ "$$answer" != "y" ]; then \
			printf "Cancelled.\n"; \
			exit 0; \
		fi; \
	fi
	@$(PRINT_STEP) "Upgrading Flutter/Dart packages to latest compatible major versions"
	$(PUB_UPGRADE_MAJOR)
	@$(PRINT_STEP) "Upgrading npm packages to latest versions"
	@$(call NVM_EXEC,$(NPX) npm-check-updates -u && $(NPM) install)
	@$(PRINT_STEP) "Upgrading Python quality tools"
	$(PIP) install --upgrade pip ruff
	@$(PRINT_WARN) "Run 'make check-all' and review generated diffs before committing."

endif
