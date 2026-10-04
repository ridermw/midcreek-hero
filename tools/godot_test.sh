#!/usr/bin/env bash
# Usage: tools/godot_test.sh tests/name_test.gd NAME_TEST
set -euo pipefail
script="$1"
tag="$2"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
# shellcheck disable=SC2086
timeout 120s godot --headless --path . ${GODOT_EXTRA_ARGS:-} --script "$script" >"$log" 2>&1 || status=$?
cat "$log"
if grep -Eq '^(SCRIPT ERROR|ERROR|USER ERROR|Parse Error)' "$log"; then
	echo "godot_test: error lines in output" >&2
	exit 1
fi
if ! grep -Eq "^${tag}_COMPLETE: [1-9][0-9]* checks, 0 failures$" "$log"; then
	echo "godot_test: missing '${tag}_COMPLETE: N checks, 0 failures'" >&2
	exit 1
fi
exit "$status"
