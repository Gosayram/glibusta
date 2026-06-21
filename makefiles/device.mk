ifndef DEVICE_MK
DEVICE_MK := 1

ADB ?= adb
ANDROID_PACKAGE ?= com.gosayram.glibusta
ADB_LOGS_FILE ?= .gl-logs-docs.txt
ADB_LOGS_RUN_WAIT ?= 6

# Crash-resilient filter: matches the app package + Flutter/Dart + crash/native tags.
# Does NOT depend on a live PID, so it still captures the crash trail after the
# process dies (AndroidRuntime FATAL, DEBUG tombstones, libc fatal signals, etc.).
# Set ADB_LOGS_FILTER= to capture everything (unfiltered).
ADB_LOGS_FILTER ?= $(subst .,\.,$(ANDROID_PACKAGE))|flutter|AndroidRuntime|FATAL|DEBUG|libc|tombstone

# Markers scanned in adb-logs-run to detect a crash/failure.
ADB_CRASH_MARKERS ?= FATAL EXCEPTION|E/flutter|AndroidRuntime|signal [0-9]|SIGSEGV|SIGABRT|tombstone|has died|Force finishing|[0-9]+ fatal

##@ Device (adb)

.PHONY: adb-devices
adb-devices: ## List connected adb devices
	@$(call REQUIRE_TOOL,$(ADB))
	@$(PRINT_STEP) "Connected adb devices"
	@$(ADB) devices -l

.PHONY: adb-logs-clear
adb-logs-clear: ## Clear the adb logcat buffer
	@$(call REQUIRE_TOOL,$(ADB))
	@$(PRINT_STEP) "Clearing logcat buffer"
	@$(ADB) logcat -c
	@$(PRINT_OK) "Logcat buffer cleared"

.PHONY: adb-logs
adb-logs: ## Stream filtered app logs to terminal and .gl-logs-docs.txt (Ctrl+C to stop)
	@$(call REQUIRE_TOOL,$(ADB))
	@if ! $(ADB) get-state >/dev/null 2>&1; then $(PRINT_ERROR) "No adb device connected"; exit 1; fi
	@$(PRINT_STEP) "Streaming logs for $(ANDROID_PACKAGE) -> $(ADB_LOGS_FILE)"
	@printf "  filter: %s\n" "$(ADB_LOGS_FILTER)"
	@printf "  press Ctrl+C to stop.\n\n"
	@if [ -n "$(ADB_LOGS_FILTER)" ]; then \
		$(ADB) logcat -v time 2>&1 | grep --line-buffered -E "$(ADB_LOGS_FILTER)" | tee "$(ADB_LOGS_FILE)"; \
	else \
		$(ADB) logcat -v time 2>&1 | tee "$(ADB_LOGS_FILE)"; \
	fi || true

.PHONY: adb-logs-dump
adb-logs-dump: ## Dump current logcat buffer (filtered) once into .gl-logs-docs.txt
	@$(call REQUIRE_TOOL,$(ADB))
	@if ! $(ADB) get-state >/dev/null 2>&1; then $(PRINT_ERROR) "No adb device connected"; exit 1; fi
	@$(PRINT_STEP) "Dumping current logs -> $(ADB_LOGS_FILE)"
	@TMP="$(ADB_LOGS_FILE).full"; \
	$(ADB) logcat -d > "$$TMP"; \
	if [ -n "$(ADB_LOGS_FILTER)" ]; then \
		{ grep -E "$(ADB_LOGS_FILTER)" "$$TMP" > "$(ADB_LOGS_FILE)" || true; }; \
	else \
		mv "$$TMP" "$(ADB_LOGS_FILE)"; \
	fi; \
	[ -f "$$TMP" ] && rm -f "$$TMP"; \
	$(PRINT_OK) "Wrote $$(wc -l < "$(ADB_LOGS_FILE)" | tr -d ' ') lines -> $(ADB_LOGS_FILE)"

.PHONY: adb-logs-run
adb-logs-run: ## Launch the app fresh and capture startup/crash logs into .gl-logs-docs.txt
	@$(call REQUIRE_TOOL,$(ADB))
	@if ! $(ADB) get-state >/dev/null 2>&1; then $(PRINT_ERROR) "No adb device connected"; exit 1; fi
	@$(PRINT_STEP) "Fresh launch + capture for $(ANDROID_PACKAGE)"
	@$(PRINT_STEP) "Clearing logcat buffer"
	@$(ADB) logcat -c
	@$(PRINT_STEP) "Stopping any previous instance"
	@$(ADB) shell am force-stop $(ANDROID_PACKAGE) 2>/dev/null || true
	@$(PRINT_STEP) "Launching $(ANDROID_PACKAGE)"
	@LAUNCH_OUT=$$($(ADB) shell monkey -p $(ANDROID_PACKAGE) -c android.intent.category.LAUNCHER 1 2>&1); \
	if ! echo "$$LAUNCH_OUT" | grep -qi "Events injected"; then \
		$(PRINT_ERROR) "Failed to launch $(ANDROID_PACKAGE)"; \
		printf "%s\n" "$$LAUNCH_OUT"; \
		printf "Is the app installed? Try 'make adb-install'.\n"; \
		exit 1; \
	fi
	@$(PRINT_STEP) "Waiting $(ADB_LOGS_RUN_WAIT)s for startup/crash..."
	@sleep $(ADB_LOGS_RUN_WAIT)
	@$(PRINT_STEP) "Capturing logs -> $(ADB_LOGS_FILE)"
	@TMP="$(ADB_LOGS_FILE).full"; \
	$(ADB) logcat -d > "$$TMP"; \
	if [ -n "$(ADB_LOGS_FILTER)" ]; then \
		{ grep -E "$(ADB_LOGS_FILTER)" "$$TMP" > "$(ADB_LOGS_FILE)" || true; }; \
	else \
		mv "$$TMP" "$(ADB_LOGS_FILE)"; \
	fi; \
	[ -f "$$TMP" ] && rm -f "$$TMP"; \
	CRASHES=$$(grep -Ec "$(ADB_CRASH_MARKERS)" "$(ADB_LOGS_FILE)" 2>/dev/null || echo 0); \
	PID=$$($(ADB) shell pidof $(ANDROID_PACKAGE) 2>/dev/null | tr -d '\r' | awk '{print $$1}'); \
	printf "\n$(C_BOLD)$(C_BLUE)Run report for $(ANDROID_PACKAGE)$(C_RESET)\n\n"; \
	if [ -n "$$PID" ]; then \
		$(PRINT_OK) "App is RUNNING (PID $$PID)"; \
	else \
		$(PRINT_ERROR) "App process NOT found -- likely crashed or exited"; \
	fi; \
	printf "$(C_BOLD)Crash markers:$(C_RESET) %s line(s)\n" "$$CRASHES"; \
	if [ "$$CRASHES" -gt 0 ]; then \
		printf "$(C_DIM)--- first matches ---$(C_RESET)\n"; \
		grep -nE "$(ADB_CRASH_MARKERS)" "$(ADB_LOGS_FILE)" | head -20; \
	fi; \
	printf "$(C_DIM)Full filtered log:$(C_RESET) %s (%s lines)\n" "$(ADB_LOGS_FILE)" "$$(wc -l < "$(ADB_LOGS_FILE)" | tr -d ' ')"

.PHONY: adb-install
adb-install: ## Install the latest built release APK onto a connected device
	@$(call REQUIRE_TOOL,$(ADB))
	@if ! $(ADB) get-state >/dev/null 2>&1; then $(PRINT_ERROR) "No adb device connected"; exit 1; fi
	@$(PRINT_STEP) "Installing latest APK for $(ANDROID_PACKAGE)"
	@APK="$$(ls -t $(DIST_DIR)/*.apk 2>/dev/null | head -1)"; \
	if [ -z "$$APK" ]; then \
		$(PRINT_ERROR) "No APK found in $(DIST_DIR). Run 'make build-android-apk' first."; \
		exit 1; \
	fi; \
	printf "  Installing: %s\n" "$$APK"; \
	$(ADB) install -r "$$APK"; \
	$(PRINT_OK) "Installed"

endif
