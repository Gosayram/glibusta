ifndef SECRETS_MK
SECRETS_MK := 1

SOPS ?= sops
ENV_FILE ?= .env
ENV_ENCRYPTED_FILE ?= .env.enc
ENV_KEY ?=
ENV_VALUE_FILE ?=

.PHONY: env-status env-encrypt env-decrypt env-sync env-set env-unset

env-status: ## Show whether .env.enc is valid SOPS data
	@$(SOPS) filestatus --input-type dotenv "$(ENV_ENCRYPTED_FILE)"

env-encrypt: ## Create a missing/empty .env.enc, or verify and sync its changed keys
	@test -f "$(ENV_FILE)" || { echo "ERROR: $(ENV_FILE) is required" >&2; exit 1; }
	@if test -s "$(ENV_ENCRYPTED_FILE)"; then \
		status="$$( $(SOPS) filestatus --input-type dotenv "$(ENV_ENCRYPTED_FILE)" )" || { echo "ERROR: $(ENV_ENCRYPTED_FILE) is not valid SOPS data" >&2; exit 1; }; \
		test "$$status" = '{"encrypted":true}' || { echo "ERROR: $(ENV_ENCRYPTED_FILE) is not encrypted SOPS data" >&2; exit 1; }; \
		echo "Verified $(ENV_ENCRYPTED_FILE); syncing only changed keys"; \
		$(MAKE) --no-print-directory env-sync; \
	else \
		tmp_file="$$(mktemp)"; trap 'rm -f "$$tmp_file"' EXIT; \
		$(SOPS) --encrypt --input-type dotenv --output-type dotenv --filename-override "$(ENV_ENCRYPTED_FILE)" --output "$$tmp_file" "$(ENV_FILE)"; \
		mv "$$tmp_file" "$(ENV_ENCRYPTED_FILE)"; \
		echo "Created encrypted $(ENV_ENCRYPTED_FILE)"; \
	fi

env-decrypt: ## Explicitly restore .env from .env.enc
	@umask 077; $(SOPS) --decrypt --input-type dotenv --output-type dotenv --output "$(ENV_FILE)" "$(ENV_ENCRYPTED_FILE)"
	@chmod 600 "$(ENV_FILE)"

env-sync: ## Encrypt only changed KEY=value entries from .env into .env.enc
	@test -f "$(ENV_FILE)" && test -f "$(ENV_ENCRYPTED_FILE)" || { echo "ERROR: both $(ENV_FILE) and $(ENV_ENCRYPTED_FILE) are required" >&2; exit 1; }
	@decrypted_file="$$(mktemp)"; value_file="$$(mktemp)"; trap 'rm -f "$$decrypted_file" "$$value_file"' EXIT; \
		$(SOPS) --decrypt --input-type dotenv --output-type dotenv --output "$$decrypted_file" "$(ENV_ENCRYPTED_FILE)"; \
		while IFS='=' read -r key value; do \
			case "$$key" in ''|\#*) continue ;; *[!A-Za-z0-9_]*|[0-9]*) echo "ERROR: unsupported dotenv key: $$key" >&2; exit 1 ;; esac; \
			current="$$(sed -n "s/^$${key}=//p" "$$decrypted_file")"; \
			[ "$$value" = "$$current" ] && continue; \
			printf '%s' "$$value" | python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))' > "$$value_file"; \
			$(SOPS) --in-place set --input-type dotenv --output-type dotenv --value-file "$$value_file" "$(ENV_ENCRYPTED_FILE)" '["'"$$key"'"]'; \
		done < "$(ENV_FILE)"

env-set: ## Set one encrypted key: ENV_KEY=NAME ENV_VALUE_FILE=/safe/value.json
	@test -n "$(ENV_KEY)" && test -f "$(ENV_VALUE_FILE)" || { echo "ERROR: set ENV_KEY and ENV_VALUE_FILE" >&2; exit 1; }
	$(SOPS) --in-place set --input-type dotenv --output-type dotenv --value-file "$(ENV_VALUE_FILE)" "$(ENV_ENCRYPTED_FILE)" '["$(ENV_KEY)"]'

env-unset: ## Remove one encrypted key: ENV_KEY=NAME
	@test -n "$(ENV_KEY)" || { echo "ERROR: set ENV_KEY" >&2; exit 1; }
	$(SOPS) --in-place unset --input-type dotenv --output-type dotenv "$(ENV_ENCRYPTED_FILE)" '["$(ENV_KEY)"]'

endif
