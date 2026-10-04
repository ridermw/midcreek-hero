#!/usr/bin/env bash
# Usage: tools/godot_test.sh tests/name_test.gd NAME_TEST
set -euo pipefail
script="$1"
tag="$2"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
# A test can request engine flags with a line such as: # godot_test_args: --fixed-fps 60
declared="$(sed -n 's/^# godot_test_args: //p' "$script" | head -1)"
# shellcheck disable=SC2086
timeout 60s godot --headless --path . ${declared} ${GODOT_EXTRA_ARGS:-} --script "$script" >"$log" 2>&1 || status=$?
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
