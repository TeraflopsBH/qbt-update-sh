#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=qbtupd.sh
source "$ROOT_DIR/qbtupd.sh"

TEST_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEST_TMP_DIR"' EXIT

export MENU_ACTIONS_FILE="$TEST_TMP_DIR/actions"
export MENU_CALLS_FILE="$TEST_TMP_DIR/menu-calls"
export MENU_EVENTS_FILE="$TEST_TMP_DIR/events"

# Replace system-dependent setup and interactive operations with controlled
# responses so the dispatcher can be tested without a DietPi host or /dev/tty.
print_logo() { :; }
check_root() { :; }
dietpi_marker_present() { return 0; }
echo_err() { :; }
echo_n_err() { :; }
sleep() { :; }

get_main_menu_choice() {
    local action
    printf 'menu\n' >> "$MENU_CALLS_FILE"
    if ! IFS= read -r action < "$MENU_ACTIONS_FILE"; then
        action="exit"
    fi
    tail -n +2 "$MENU_ACTIONS_FILE" > "${MENU_ACTIONS_FILE}.next"
    mv -- "${MENU_ACTIONS_FILE}.next" "$MENU_ACTIONS_FILE"
    printf '%s\n' "$action"
}

ensure_dependencies() {
    printf 'dependencies:%s\n' "$1" >> "$MENU_EVENTS_FILE"
    return "$TEST_DEP_STATUS"
}
install_qbittorrent_via_dietpi() {
    printf 'install\n' >> "$MENU_EVENTS_FILE"
    return "$TEST_INSTALL_STATUS"
}
restore_backup() {
    printf 'restore\n' >> "$MENU_EVENTS_FILE"
    return "$TEST_RESTORE_STATUS"
}
uninstall_qbittorrent() {
    printf 'uninstall\n' >> "$MENU_EVENTS_FILE"
    return "$TEST_UNINSTALL_STATUS"
}
run_update_workflow() {
    printf 'update\n' >> "$MENU_EVENTS_FILE"
    return "$TEST_UPDATE_STATUS"
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}
assert_event() {
    local expected="$1"
    grep -Fqx -- "$expected" "$MENU_EVENTS_FILE" || fail "expected event '$expected'; got: $(cat "$MENU_EVENTS_FILE")"
}
run_case() {
    local name="$1" actions="$2" dep_status="$3" install_status="$4"
    local restore_status="$5" uninstall_status="$6" update_status="$7"
    local expected_event="$8" expected_menu_calls="${9:-2}" menu_calls

    printf '%s\n' "$actions" > "$MENU_ACTIONS_FILE"
    : > "$MENU_CALLS_FILE"
    : > "$MENU_EVENTS_FILE"
    TEST_DEP_STATUS="$dep_status"
    TEST_INSTALL_STATUS="$install_status"
    TEST_RESTORE_STATUS="$restore_status"
    TEST_UNINSTALL_STATUS="$uninstall_status"
    TEST_UPDATE_STATUS="$update_status"

    if ! main >/dev/null 2>&1; then
        fail "$name: main returned failure after cancellation/operation"
    fi

    menu_calls="$(wc -l < "$MENU_CALLS_FILE")"
    [[ "$menu_calls" -eq "$expected_menu_calls" ]] ||
        fail "$name: expected $expected_menu_calls menu visits, got $menu_calls"
    [[ ! -s "$MENU_ACTIONS_FILE" ]] || fail "$name: not all scripted menu actions were consumed"
    assert_event "$expected_event"
    printf 'PASS: %s returns to the main menu\n' "$name"
}

run_case "cancelled restore confirmation" $'restore\nexit' 0 2 0 0 0 "restore"
run_case "cancelled uninstall confirmation" $'uninstall\nexit' 0 2 0 0 0 "uninstall"
run_case "cancelled update workflow" $'update\nexit' 0 2 0 0 2 "update"
run_case "cancelled install/repair" $'install\nexit' 0 2 0 0 0 "install"
run_case "declined dependency bootstrap during restore" $'restore\nexit' 2 2 0 0 0 "dependencies:restore"
run_case "successful operation also returns to menu" $'restore\nexit' 0 2 0 0 0 "restore"
