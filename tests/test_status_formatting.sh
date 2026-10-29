#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=qbtupd.sh
source "$ROOT_DIR/qbtupd.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_badge() {
    local function_name="$1" expected_badge="$2" output plain
    output="$("$function_name" "sample status message" 2>&1)"
    plain="$(printf '%s\n' "$output" | sed -E $'s/\033\\[[0-9;]*[[:alpha:]]//g')"

    [[ "$plain" == " $expected_badge - sample status message" ]] ||
        fail "$function_name expected ' $expected_badge - sample status message', got '$plain'"
    [[ "${#expected_badge}" -eq 8 ]] ||
        fail "$function_name badge should occupy exactly 8 visible characters"
    printf 'PASS: %s uses the fixed-width %s badge\n' "$function_name" "$expected_badge"
}

assert_badge status_info '[ INFO ]'
assert_badge status_ok '[  OK  ]'
assert_badge status_warn '[ WARN ]'
assert_badge status_fail '[ FAIL ]'
