#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
worktree="$(mktemp -d "${TMPDIR:-/tmp}/glibusta-codegen.XXXXXX")"

if [[ ! -f "$repo_root/pubspec.lock" ]]; then
	echo "ERROR: pubspec.lock is required before running codegen-check." >&2
	exit 1
fi

cleanup() {
	local status=$?
	trap - EXIT INT TERM
	git -C "$repo_root" worktree remove --force "$worktree" >/dev/null 2>&1 || rm -rf "$worktree"
	exit "$status"
}
trap cleanup EXIT INT TERM

git -C "$repo_root" worktree add --detach "$worktree" HEAD >/dev/null
cp "$repo_root/pubspec.lock" "$worktree/pubspec.lock"

(
	cd "$worktree"
	git add -f pubspec.lock
	flutter pub get --enforce-lockfile
	flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml
	flutter gen-l10n
	git diff --exit-code
	if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
		git status --short
		exit 1
	fi
)
