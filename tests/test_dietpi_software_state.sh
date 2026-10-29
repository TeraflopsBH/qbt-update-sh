#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=qbtupd.sh
source "$SCRIPT_DIR/qbtupd.sh"

assert_state() {
    local description="$1" input="$2" expected="$3" actual
    actual="$(parse_dietpi_qbt_software_state "$input")"
    if [[ "$actual" != "$expected" ]]; then
        printf 'FAIL: %s: expected <%s>, got <%s>\n' "$description" "$expected" "$actual" >&2
        exit 1
    fi
    printf 'PASS: %s\n' "$description"
}

assert_state "current named ID, installed" $'samba|2|Samba|\nqbittorrent|2|qBittorrent|description' "2"
assert_state "current named ID, not installed" 'qbittorrent|0|qBittorrent|description' "0"
assert_state "named ID with disabled suffix" 'qbittorrent DISABLED|2|qBittorrent|description' "2"
assert_state "legacy numeric machine-readable ID" '46|2|qBittorrent|description' "2"
assert_state "legacy human-readable uppercase ID" 'ID 46 | =2 | qBittorrent |' "2"
assert_state "legacy human-readable lowercase ID" 'id 46 | =0 | qBittorrent |' "0"
assert_state "unrelated list without qBittorrent" 'samba|2|Samba|description' "unknown"

# Binary restore points created by the updater must map to the exact config
# snapshot carrying the same timestamp/PID suffix.
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
binary_backup="/usr/bin/qbittorrent-nox.20261029_123456_321.bak"
expected_config="$tmp_dir/qBittorrent.conf.20261029_123456_321.bak"
printf 'test config\n' > "$expected_config"
actual_config="$(config_snapshot_for_binary "$binary_backup" "$tmp_dir")"
if [[ "$actual_config" != "$expected_config" ]]; then
    printf 'FAIL: paired config lookup: expected <%s>, got <%s>\n' "$expected_config" "$actual_config" >&2
    exit 1
fi
printf 'PASS: binary backup finds its paired configuration snapshot\n'

rm -f -- "$expected_config"
if config_snapshot_for_binary "$binary_backup" "$tmp_dir" >/dev/null; then
    printf 'FAIL: missing paired config should not resolve\n' >&2
    exit 1
fi
printf 'PASS: legacy executable backup without config snapshot is detected\n'

assert_value() {
    local description="$1" actual="$2" expected="$3"
    if [[ "$actual" != "$expected" ]]; then
        printf 'FAIL: %s: expected <%s>, got <%s>\\n' "$description" "$expected" "$actual" >&2
        exit 1
    fi
    printf 'PASS: %s\\n' "$description"
}

assert_value "both qBittorrent components absent routes to install menu" "$(qbt_component_mode 0 0)" "absent"
assert_value "binary without service routes to repair menu" "$(qbt_component_mode 1 0)" "inconsistent"
assert_value "service without binary routes to repair menu" "$(qbt_component_mode 0 1)" "inconsistent"
assert_value "binary and service present permits update menu" "$(qbt_component_mode 1 1)" "present"
assert_value "software not installed selects DietPi install" "$(dietpi_qbt_install_command 0)" "install"
assert_value "unknown DietPi state selects DietPi install" "$(dietpi_qbt_install_command unknown)" "install"
assert_value "DietPi installed state with missing files selects reinstall" "$(dietpi_qbt_install_command 2)" "reinstall"
