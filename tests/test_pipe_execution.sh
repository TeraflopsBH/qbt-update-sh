#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEST_TMP_DIR"' EXIT

fail() {
    printf 'FAIL: %s\\n' "$*" >&2
    exit 1
}

# Replace only the final main invocation with a marker. This tests Bash's
# execution context without entering the updater or touching the host system.
sed 's/^    main "\$@"$/    printf "MAIN_INVOKED\\\\n"/' "$ROOT_DIR/qbtupd.sh" > "$TEST_TMP_DIR/qbtupd.sh"

[[ -s "$TEST_TMP_DIR/qbtupd.sh" ]] || fail "could not prepare execution fixture"

# A file passed on stdin must execute the main-entry block.
pipe_output="$(cat "$TEST_TMP_DIR/qbtupd.sh" | bash 2>&1)"
[[ "$pipe_output" == *"MAIN_INVOKED"* ]] ||
    fail "piped execution did not invoke main"

# Sourcing the same file must define functions without invoking main.
source_output="$(bash -c 'source "$1"; printf "SOURCED_OK\\n"' _ "$TEST_TMP_DIR/qbtupd.sh" 2>&1)"
[[ "$source_output" == *"SOURCED_OK"* ]] ||
    fail "sourcing the script failed"
[[ "$source_output" != *"MAIN_INVOKED"* ]] ||
    fail "sourcing the script unexpectedly invoked main"

printf 'PASS: execution from stdin invokes main\\n'
printf 'PASS: sourcing the script does not invoke main\\n'
