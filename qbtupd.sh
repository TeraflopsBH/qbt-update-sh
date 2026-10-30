#!/usr/bin/env bash

# qBitTorrent Updater for DietPi by TeraflopsBH
# Optimized & Refactored Version v2.0

# GitHub Repository: https://github.com/TeraflopsBH/qbt-update-sh

################################################################
# SAFETY & CONFIGURATION
################################################################

# Strict Mode
set -o errexit   # Exit on error
set -o nounset   # Exit on unset variables
set -o pipefail  # Exit if pipe fails

# Constants
readonly QBT_SERVICE="qbittorrent.service"
readonly BIN_PATH="/usr/bin/qbittorrent-nox"
readonly DIETPI_SERVICES="/boot/dietpi/dietpi-services"
readonly CONFIG_BACKUP_DIR="/var/backups/qbt-update-sh"
readonly VERSION_JSON_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/latest/download/dependency-version.json"

################################################################
# VISUAL STYLING
################################################################

# Standard Colors
readonly LRED='\033[1;31m'
readonly GREEN='\033[0;92m'
readonly LGREEN='\033[1;32m'
readonly LBLUE='\033[1;34m'
readonly LCYAN='\033[1;36m'
readonly LMAGENTA='\033[1;35m'
readonly YELLOW='\033[0;93m'
readonly LYELLOW='\033[1;33m'
readonly LGRAY='\033[0;37m'

# Background Colors
readonly DB_RED='\033[41;1;37m'
readonly DB_MAGENTA='\033[45;1;37m'
readonly DB_YELLOW='\033[43;1;37m'

# Fixed-width status badges (all labels are eight visible characters).
readonly BADGE_RED='\033[41;37m'
readonly BADGE_YELLOW='\033[43;30m'
readonly BADGE_GREEN='\033[42;30m'
readonly BADGE_CYAN='\033[46;30m'

# Formatting
readonly NC='\033[0m'
readonly ULINE='\033[4m'
readonly BOLD='\033[1m'

# Shared status-message prefixes. Badge labels are deliberately fixed-width.
readonly MSG_WR=" ${BADGE_RED}[ WARN ]${NC} - ${LRED}"
readonly MSG_WY=" ${BADGE_YELLOW}[ WARN ]${NC} - ${LYELLOW}"
readonly MSG_IG=" ${BADGE_CYAN}[ INFO ]${NC} - ${LGREEN}"
readonly MSG_OK=" ${BADGE_GREEN}[  OK  ]${NC} - ${LGREEN}"
readonly MSG_FAIL=" ${BADGE_RED}[ FAIL ]${NC} - ${LRED}"

################################################################
# SYSTEM FUNCTIONS
################################################################

TMP_DIR=""
BACKUP_FILE=""
STAGED_PATH=""
QBT_CONFIG_PATH=""
CONFIG_BACKUP_FILE=""
CONFIG_RESTORE_FILE=""
CONFIG_RESTORE_PAIRED=0
UPDATE_IN_PROGRESS=0
SERVICE_WAS_ACTIVE=0
TARGET_MISSING_BEFORE=0

cleanup() {
    local status=$?
    local restore_path="/usr/bin/.qbittorrent-nox.rollback.${BASHPID}"
    local rollback_ok=0

    if [[ $status -ne 0 && "${UPDATE_IN_PROGRESS:-0}" -eq 1 ]] &&
       { [[ -n "${BACKUP_FILE:-}" && -f "$BACKUP_FILE" ]] || [[ "${TARGET_MISSING_BEFORE:-0}" -eq 1 ]]; }; then
        echo_err "\n${MSG_WR}Operation failed; attempting to restore the previous executable state... ${NC}"
        systemctl stop "$QBT_SERVICE" >/dev/null 2>&1 || true

        if [[ -n "${BACKUP_FILE:-}" && -f "$BACKUP_FILE" ]]; then
            if cp -p "$BACKUP_FILE" "$restore_path" && chmod 755 "$restore_path" && mv -f "$restore_path" "$BIN_PATH"; then
                rollback_ok=1
            fi
        elif [[ "${TARGET_MISSING_BEFORE:-0}" -eq 1 ]]; then
            if rm -f -- "$BIN_PATH"; then rollback_ok=1; fi
        fi

        if [[ "$rollback_ok" -eq 1 ]]; then
            if [[ -n "${CONFIG_BACKUP_FILE:-}" && -f "$CONFIG_BACKUP_FILE" && -n "${QBT_CONFIG_PATH:-}" ]]; then
                if cp -p -- "$CONFIG_BACKUP_FILE" "$QBT_CONFIG_PATH"; then
                    echo_err "${MSG_IG}Pre-operation qBittorrent configuration restored from $CONFIG_BACKUP_FILE.${NC}"
                else
                    echo_err "${MSG_WR}Could not restore the pre-operation qBittorrent configuration. Backup remains at: $CONFIG_BACKUP_FILE${NC}"
                fi
            fi
            if [[ "$SERVICE_WAS_ACTIVE" -eq 1 ]]; then
                systemctl reset-failed "$QBT_SERVICE" >/dev/null 2>&1 || true
                if systemctl start "$QBT_SERVICE"; then
                    local retries=10
                    while (( retries > 0 )); do
                        if systemctl is-active --quiet "$QBT_SERVICE"; then break; fi
                        sleep 1
                        retries=$((retries - 1))
                    done
                    if systemctl is-active --quiet "$QBT_SERVICE"; then
                        echo_err "${MSG_IG}Previous executable state restored and service is active again.${NC}"
                    else
                        echo_err "${MSG_WR}Executable state restored, but service did not become active. Check journalctl -u $QBT_SERVICE.${NC}"
                    fi
                else
                    echo_err "${MSG_WR}Executable state restored, but service restart failed. Check journalctl -u $QBT_SERVICE.${NC}"
                fi
            else
                echo_err "${MSG_IG}Previous executable state restored. The service was inactive before the operation and has been left stopped.${NC}"
            fi
        else
            rm -f -- "$restore_path"
            if [[ -n "${BACKUP_FILE:-}" ]]; then
                echo_err "${MSG_WR}AUTOMATIC ROLLBACK FAILED. Safety backup remains at: $BACKUP_FILE${NC}"
            else
                echo_err "${MSG_WR}AUTOMATIC ROLLBACK FAILED. The target was originally absent; inspect $BIN_PATH and the service manually.${NC}"
            fi
        fi
    fi
    if [[ -n "${STAGED_PATH:-}" && -e "$STAGED_PATH" ]]; then rm -f -- "$STAGED_PATH"; fi
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then rm -rf -- "$TMP_DIR"; fi
    return "$status"
}
trap cleanup EXIT

echo_err() {
    echo -e "$@" >&2
}

echo_n_err() {
    echo -ne "$@" >&2
}

# Keep one-line status output consistent and avoid detached trailing badges.
status_info() { echo_err "${MSG_IG}$*${NC}"; }
status_ok()   { echo_err "${MSG_OK}$*${NC}"; }
status_warn() { echo_err "${MSG_WY}$*${NC}"; }
status_fail() { echo_err "${MSG_FAIL}$*${NC}"; }

confirm_action() {
    local prompt="$1"
    local answer

    while true; do
        echo_n_err "\n  ${LYELLOW}${prompt} [y/N]: ${NC}"
        if ! IFS= read -r answer < /dev/tty; then
            answer=""
        fi

        case "$answer" in
            y|Y|yes|YES|Yes) return 0 ;;
            ""|n|N|no|NO|No) return 1 ;;
            *) echo_err "${MSG_WY}Please enter y or n. The default is No.${NC}" ;;
        esac
    done
}

check_root() {
    status_info "Checking for root privileges..."
    if [[ $EUID -ne 0 ]]; then
        status_fail "This script must be run with root privileges."
        exit 1
    fi
    status_ok "Root privileges confirmed."
}

check_internet() {
    status_info "Checking HTTPS access to GitHub..."
    if ! curl -fLsS --connect-timeout 10 --max-time 30 "https://github.com/" -o /dev/null; then
        status_fail "Cannot reach GitHub over HTTPS. Check DNS, HTTPS access, and system time."
        exit 1
    fi
    status_ok "GitHub HTTPS access confirmed."
}

ensure_dependencies() {
    # Restore mode omits the network/update-only curl and jq helpers.
    # APT and systemctl are prerequisites for bootstrapping/system management.
    local mode="${1:-update}"
    local required_command package
    local -a required_commands=(
        file grep head sort du cut basename sleep mktemp
        cp chmod mv rm mkdir cmp date uname
    )
    if [[ "$mode" == "update" ]]; then required_commands+=(curl jq); fi
    local -a missing_commands=()
    local -a missing_packages=()

    if ! command -v apt-get >/dev/null 2>&1; then
        echo_err "${MSG_WR}Cannot install missing dependencies automatically: apt-get is unavailable.${NC}"
        echo_err "  This updater requires a DietPi/Debian system with APT available."
        exit 1
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        echo_err "${MSG_WR}systemctl is unavailable. The expected systemd service manager was not found.${NC}"
        exit 1
    fi

    for required_command in "${required_commands[@]}"; do
        if ! command -v "$required_command" >/dev/null 2>&1; then
            missing_commands+=("$required_command")
            case "$required_command" in
                curl) package="curl" ;;
                jq) package="jq" ;;
                file) package="file" ;;
                grep) package="grep" ;;
                *) package="coreutils" ;;
            esac

            case " ${missing_packages[*]} " in
                *" $package "*) ;;
                *) missing_packages+=("$package") ;;
            esac
        fi
    done

    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        echo_err
        echo_err "${MSG_IG}All required helper commands are available.${NC}"
        echo_err
        return 0
    fi

    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_YELLOW}                    DEPENDENCY INSTALLATION                    ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err
    echo_err "  The updater cannot continue until the following commands are available:"
    echo_err
    for required_command in "${missing_commands[@]}"; do
        echo_err "      - $required_command"
    done
    echo_err
    echo_err "  APT packages to be installed:"
    for package in "${missing_packages[@]}"; do
        echo_err "      - $package"
    done
    echo_err
    echo_err "  If you approve, the script will run:"
    echo_err "      apt-get update"
    echo_err "      apt-get install --no-install-recommends --no-upgrade ..."
    echo_err
    echo_err "  No qBittorrent executable will be replaced during this step."
    echo_err "  If you decline, no helper packages will be installed and the main menu will reappear."
    echo_err
    echo_err "${YELLOW}----------------------------------------------------------------------${NC}"

    if ! confirm_action "Install the missing helper packages now using APT?"; then
        echo_err
        echo_err "${MSG_WY}Dependency installation declined. Nothing has been installed by this updater.${NC}"
        return 2
    fi

    echo_err
    echo_err "${MSG_IG}Refreshing APT package lists...${NC}"
    if ! apt-get update; then
        echo_err
        echo_err "${MSG_WR}APT update failed. Check network and repository configuration, then rerun the updater.${NC}"
        exit 1
    fi

    echo_err
    echo_err "${MSG_IG}Installing approved package(s): ${LYELLOW}${missing_packages[*]}${NC}"
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-upgrade "${missing_packages[@]}"; then
        echo_err
        echo_err "${MSG_WR}Dependency installation failed. Fix APT and rerun the updater.${NC}"
        exit 1
    fi

    for required_command in "${required_commands[@]}"; do
        if ! command -v "$required_command" >/dev/null 2>&1; then
            echo_err "${MSG_WR}The command '$required_command' is still unavailable after installing dependencies. Aborting.${NC}"
            exit 1
        fi
    done

    echo_err
    echo_err "${MSG_IG}Dependency installation and verification completed.${NC}"
    echo_err
}

print_startup_warning() {
    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_YELLOW}                    QBITTORRENT UPDATER FOR DIETPI                    ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err
    echo_err "  This script replaces DietPi's qBittorrent executable with a static"
    echo_err "  build downloaded from userdocs/qbittorrent-nox-static on GitHub."
    echo_err
    echo_err "  During this session, the updater may:"
    echo_err "      - Ask permission to install missing helper packages through APT."
    echo_err "      - Ask permission to install qBittorrent through DietPi, if absent."
    echo_err "      - Download and validate a replacement executable."
    echo_err "      - Back up the current executable, then stop and restart the service."
    echo_err
    echo_err "  Safety measures:"
    echo_err "      - The candidate is validated before the installed binary is changed."
    echo_err "      - A timestamped backup is retained for recovery."
    echo_err "      - Rollback is attempted if replacement or service startup fails."
    echo_err "      - The update itself does not intentionally modify existing settings."
    echo_err
    echo_err "  This is a work-in-progress updater using a third-party binary."
    echo_err "  Rollback is best-effort; keep a separate, known-good backup."
    echo_err
    echo_err "${YELLOW}----------------------------------------------------------------------${NC}"
}
print_update_warning() {
    local current_version="$1"
    local latest_version="$2"
    local selected_arch="$3"
    local selected_libtorrent="$4"

    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_YELLOW}                      FINAL UPDATE CONFIRMATION                       ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err
    echo_err "  qBittorrent version : ${LYELLOW}${current_version}${NC}  ->  ${LGREEN}${latest_version}${NC}"
    echo_err "  Selected build      : ${LCYAN}${selected_arch}${NC}, libtorrent ${LCYAN}${selected_libtorrent}${NC}"
    echo_err "  Target executable   : ${LBLUE}$BIN_PATH${NC}"
    echo_err
    echo_err "  If approved, the updater will:"
    echo_err "      1. Download and validate the selected third-party binary."
    echo_err "      2. Create a timestamped backup of the existing executable."
    echo_err "      3. Stop the service, replace the binary, and restart the service."
    echo_err
    echo_err "  On failure, it attempts to restore the old binary and prior service state."
    echo_err "  No replacement or service stop occurs before validation."
    echo_err "  Rollback is best-effort; qBittorrent settings are not intentionally changed."
    echo_err
    echo_err "${YELLOW}----------------------------------------------------------------------${NC}"
    echo_err
}
print_logo() {
    if command -v clear >/dev/null 2>&1; then
        clear >&2 || true
    else
        printf '\033[2J\033[H' >&2
    fi
    local line
    while IFS= read -r line; do
        printf '%s\n' "$line" >&2
    done << "EOF"

             ___  _ __ ______                      __      _  __
       ___ _/ _ )(_) //_  __/__  ___________ ___  / /_  NO| |/_/
      / _ `/ _  / / __// / / _ \/ __/ __/ -_) _ \/ __/   _>  <  
      \_, /____/_/\__//_/__\___/_/ /_/  \__/_//_/\__/ _ /_/|_|_ 
       /_// / / /__  ___/ /__ _/ /____   / __/_______(_)__  / /_
         / /_/ / _ \/ _  / _ `/ __/ -_) _\ \/ __/ __/ / _ \/ __/
         \____/ .__/\_,_/\_,_/\__/\__/ /___/\__/_/ /_/ .__/\__/ 
             /_/                                    /_/Teraflops

EOF
}

################################################################
# INTERACTIVE FUNCTIONS
################################################################

get_architecture_interactive() {
    local raw detected selected_arch=""
    raw="$(uname -m)"
    case "$raw" in
        armv7l|armv7) detected="armv7" ;;
        arm64|aarch64) detected="aarch64" ;;
        x86_64|amd64) detected="x86_64" ;;
        armhf) detected="armhf" ;;
        *) detected="$raw" ;;
    esac

    echo_err
    echo_err "${MSG_IG}Detected system architecture..............................${DB_MAGENTA} $raw ${NC}"

    if [[ "$detected" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
        echo_err "\n${MSG_IG}Type \"0\" and press ENTER to use the detected architecture: ${DB_MAGENTA}$detected${NC}"
        echo_err "          Or choose an alternative architecture, or select Abort."
    else
        echo_err "${MSG_WY}${LMAGENTA}$raw${NC} is not a supported artifact architecture."
        echo_err "${MSG_WR}Choose Cancel. No binary will be replaced.${NC}"
    fi

    while true; do
        echo_err
        echo_err "${YELLOW}          -----------------------${NC}"
        if [[ "$detected" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
            echo_err "           0. ${LMAGENTA}$detected${NC} ${LGREEN}(${LCYAN}detected${NC}${LGREEN})${NC}"
        fi
        echo_err "           1. ${LBLUE}aarch64${NC}"
        echo_err "           2. ${LYELLOW}x86_64${NC}"
        echo_err "           3. ${LRED}Cancel and return to main menu${NC}"
        echo_err "${YELLOW}          -----------------------${NC}"
        echo_err
        echo_n_err " ${LYELLOW}Choice: ${NC}"

        local selection
        read -r selection < /dev/tty || selection="3"
        selection=${selection:-3}

        case "$selection" in
            0)
                if [[ "$detected" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
                    selected_arch="$detected"
                    break
                else
                    echo_err "${MSG_WY}Option 0 is not available for an unsupported architecture.${NC}"
                fi
                ;;
            1) selected_arch="aarch64"; break ;;
            2) selected_arch="x86_64"; break ;;
            3) echo_err "${MSG_WY}Architecture selection cancelled.${NC}\n"; return 1 ;;
            *) echo_err "${MSG_WY}Invalid selection.${NC}\n" ;;
        esac
    done

    echo_err "\n${MSG_IG}Selected artifact architecture: ${DB_MAGENTA}$selected_arch${NC}"
    echo_err "  The downloaded executable must pass its self-test on this host.\n"
    echo "$selected_arch"
}

get_libtorrent_version() {
    local choice
    local ver=""
    
    while true; do
        echo_err "${MSG_IG}Please choose the desired ${YELLOW}libtorrent${NC} ${GREEN}version to be installed"
        echo_err "${GREEN}          (if not sure, choose libtorrent 2.0):${NC}\n"
        echo_err "${YELLOW}          -----------------------------${NC}"
        echo_err "           1. ${LMAGENTA}libtorrent 2.0${NC} ${GREEN}(${LCYAN}default${GREEN})${NC}"
        echo_err "           2. ${LBLUE}libtorrent 1.2${NC}"
        echo_err "           0. ${LRED}Cancel and return to main menu${NC}"
        echo_err "${YELLOW}          -----------------------------${NC}"
        echo_err
        echo_n_err "\n ${GREEN}Enter choice ${LYELLOW}${BOLD}${ULINE}[1]${NC}${GREEN}, ${LYELLOW}${BOLD}${ULINE}[2]${NC}, or ${LYELLOW}${BOLD}${ULINE}[0]${NC}: "
        
        if ! read -r choice < /dev/tty; then
            echo_err "${MSG_WY}Libtorrent selection cancelled (input closed).${NC}"
            return 1
        fi

        case "$choice" in
            1|"") ver="2.0"; break ;;
            2)    ver="1.2"; break ;;
            0)    echo_err "\n${MSG_WY}Libtorrent selection cancelled.${NC}\n"; return 1 ;;
            *)    echo_err "\n${MSG_WY}Invalid choice.${NC}\n" ;;
        esac
    done
    
    echo_err "\n${MSG_IG}Chosen libtorrent version: ${LYELLOW} $ver ${NC}\n"
    echo "$ver"
}

manage_backups() {
    local current_backup="$1"
    local backups=()
    
    # Expand the backup glob safely; a missing match must not become a literal filename.
    local backup_files=()
    local line b size i
    shopt -s nullglob
    backup_files=("${BIN_PATH}".*.bak)
    shopt -u nullglob
    if [[ ${#backup_files[@]} -gt 0 ]]; then
        while IFS= read -r line; do
            if [[ "$line" != "$current_backup" ]]; then
                backups+=("$line")
            fi
        done < <(printf '%s\n' "${backup_files[@]}" | sort -r)
    fi

    if [[ ${#backups[@]} -eq 0 ]]; then
        return 0
    fi

    echo_err "\n${MSG_IG}Detected ${LCYAN}${#backups[@]}${NC} ${GREEN}previous backup file(s):${NC}"
    for b in "${backups[@]}"; do
        if ! size="$(du -h "$b" | cut -f1)"; then size="unknown"; fi
        echo_err "          ${LGRAY}$(basename "$b") ${LYELLOW}($size)"
    done

    echo_err "\n          ${GREEN}How would you like to manage them?${NC}\n"
    echo_err "          ${YELLOW}-----------------------------------------${NC}"
    echo_err "           1. ${LGREEN}Keep all${NC}"
    echo_err "           2. ${LYELLOW}Keep current + newest previous backup${NC}"
    echo_err "           3. ${LRED}Delete all previous backups (keep current)${NC}"
    echo_err "           0. ${LCYAN}Skip cleanup and return to main menu${NC}"
    echo_err "          ${YELLOW}-----------------------------------------${NC}"
    echo_n_err "\n${GREEN}Enter choice ${LYELLOW}${BOLD}${ULINE}[1]${NC}: "
    
    local choice
    read -r choice < /dev/tty || choice="1"
    choice=${choice:-1}

    case "$choice" in
        0) echo_err "\n${MSG_IG}Backup cleanup skipped; all backups were left unchanged.${NC}" ;;
        1) echo_err "\n${MSG_IG}Keeping current and all previous backups.${NC}" ;;
        2)
            status_info "Cleaning up old backups..."
            for ((i=1; i<${#backups[@]}; i++)); do
                rm -f -- "${backups[$i]}"
                remove_config_snapshot_for_binary "${backups[$i]}"
            done
            status_ok "Old backup cleanup completed."
            ;;
        3)
            status_info "Deleting previous backups while retaining the current backup..."
            for b in "${backups[@]}"; do
                rm -f -- "$b"
                remove_config_snapshot_for_binary "$b"
            done
            status_ok "Previous backup cleanup completed."
            ;;
        *) echo_err "${MSG_WY}Invalid choice. Keeping all.${NC}" ;;
    esac
}

################################################################
# DIETPI INSTALL STATE AND QBITTORRENT CONFIGURATION
################################################################

dietpi_qbt_software_state() {
    local output
    if [[ ! -x "/boot/dietpi/dietpi-software" ]]; then
        printf '%s\n' "unknown"
        return 0
    fi
    if ! output="$(/boot/dietpi/dietpi-software list --machine-readable 2>/dev/null)"; then
        printf '%s\n' "unknown"
        return 0
    fi
    parse_dietpi_qbt_software_state "$output"
}

# Parse both current DietPi output (e.g. "qbittorrent|2|...") and legacy
# numeric/display formats (e.g. "46|2|..." or "ID 46 | =2 | ...").
# State 2 means installed; state 0 means not installed.
parse_dietpi_qbt_software_state() {
    local output="$1" line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Current DietPi uses named software IDs in machine-readable output.
        if [[ "$line" =~ ^[[:space:]]*qbittorrent([[:space:]]+DISABLED)?\|([0-9]+)\| ]]; then
            printf '%s\n' "${BASH_REMATCH[2]}"
            return 0
        fi
        # Older machine-readable output used numeric software IDs.
        if [[ "$line" =~ ^[[:space:]]*46([[:space:]]+DISABLED)?\|([0-9]+)\| ]]; then
            printf '%s\n' "${BASH_REMATCH[2]}"
            return 0
        fi
        # Older human-readable output used "ID 46 | =2 | ..." (or "id").
        if [[ "$line" =~ ^[[:space:]]*[iI][dD][[:space:]]+46[[:space:]]*\|[[:space:]]*=?([0-9]+)[[:space:]]*\| ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return 0
        fi
        # Also accept a plain numeric row in older/alternate output.
        if [[ "$line" =~ ^[[:space:]]*46[[:space:]]*\|[[:space:]]*=?([0-9]+)[[:space:]]*\| ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return 0
        fi
    done <<< "$output"
    printf '%s\n' "unknown"
}

require_dietpi_qbt_installed() {
    local purpose="$1"
    local state
    state="$(dietpi_qbt_software_state)"
    if [[ "$state" == "2" ]]; then return 0; fi

    echo_err
    if [[ "$state" == "0" || "$state" =~ ^[0-9]+$ ]]; then
        echo_err "${MSG_WR}DietPi does not report qBittorrent software ID 46 as installed. Refusing to $purpose a backup executable into an incomplete installation.${NC}"
        echo_err "  Reinstall qBittorrent through DietPi first, then rerun this operation."
    else
        echo_err "${MSG_WR}Could not verify the DietPi installation state for qBittorrent software ID 46. Refusing to $purpose until the state can be confirmed.${NC}"
        echo_err "  Check: /boot/dietpi/dietpi-software list --machine-readable"
    fi
    return 1
}

resolve_qbt_config_path() {
    local service_user service_home passwd_name passwd_uid passwd_home
    local service_env service_execstart config_root profile_dir config_name candidate

    service_user="$(systemctl show -p User --value "$QBT_SERVICE" 2>/dev/null || true)"
    service_user="${service_user:-root}"
    service_home=""
    while IFS=: read -r passwd_name _ passwd_uid _ _ passwd_home _; do
        if [[ "$passwd_name" == "$service_user" || "$passwd_uid" == "$service_user" ]]; then
            service_home="$passwd_home"
            break
        fi
    done < /etc/passwd
    [[ -n "$service_home" ]] || return 1

    service_env="$(systemctl show -p Environment --value "$QBT_SERVICE" 2>/dev/null || true)"
    if [[ "$service_env" =~ (^|[[:space:]])HOME=([^[:space:]]+) ]]; then
        service_home="${BASH_REMATCH[2]}"
    fi
    config_root="$service_home/.config"
    if [[ "$service_env" =~ (^|[[:space:]])XDG_CONFIG_HOME=([^[:space:]]+) ]]; then
        config_root="${BASH_REMATCH[2]}"
    fi

    service_execstart="$(systemctl show -p ExecStart --value "$QBT_SERVICE" 2>/dev/null || true)"
    if [[ "$service_execstart" =~ --profile=([^[:space:]\;]+) ]]; then
        profile_dir="${BASH_REMATCH[1]}"
        [[ "$profile_dir" == /* ]] || profile_dir="$service_home/$profile_dir"
        for candidate in "$profile_dir/qBittorrent.conf" "$profile_dir/qBittorrent/qBittorrent.conf"; do
            if [[ -f "$candidate" && ! -L "$candidate" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
        return 1
    fi
    if [[ "$service_execstart" =~ --configuration=([^[:space:]\;]+) ]]; then
        config_name="${BASH_REMATCH[1]}"
        candidate="$config_root/qBittorrent_$config_name/qBittorrent.conf"
    else
        candidate="$config_root/qBittorrent/qBittorrent.conf"
    fi

    [[ -f "$candidate" && ! -L "$candidate" ]] || return 1
    printf '%s\n' "$candidate"
}

save_qbt_config_backup() {
    local source_path="$1"
    local snapshot_id="${2:-}" destination

    if [[ ! -f "$source_path" || -L "$source_path" || ! -s "$source_path" ]]; then
        echo_err "${MSG_WR}The qBittorrent configuration is missing, empty, or not a regular file: $source_path${NC}"
        return 1
    fi
    umask 077
    if ! mkdir -p -- "$CONFIG_BACKUP_DIR" || ! chmod 700 -- "$CONFIG_BACKUP_DIR"; then
        echo_err "${MSG_WR}Could not create the private configuration-backup directory: $CONFIG_BACKUP_DIR${NC}"
        return 1
    fi
    if [[ -z "$snapshot_id" ]]; then
        snapshot_id="$(date +'%Y%m%d_%H%M%S')_${BASHPID}_$RANDOM"
    fi
    if [[ ! "$snapshot_id" =~ ^[[:alnum:]_-]+$ ]]; then
        echo_err "${MSG_WR}Invalid configuration snapshot identifier.${NC}"
        return 1
    fi
    destination="$CONFIG_BACKUP_DIR/qBittorrent.conf.$snapshot_id.bak"
    if [[ -e "$destination" || -L "$destination" ]]; then
        echo_err "${MSG_WR}A configuration snapshot already exists for identifier '$snapshot_id'; refusing to overwrite it.${NC}"
        return 1
    fi
    if ! cp -p -- "$source_path" "$destination"; then
        echo_err "${MSG_WR}Could not back up qBittorrent configuration. No replacement/uninstall will proceed.${NC}"
        return 1
    fi
    if ! chmod 600 -- "$destination"; then
        rm -f -- "$destination"
        echo_err "${MSG_WR}Could not secure the configuration backup permissions. Aborting.${NC}"
        return 1
    fi
    printf '%s\n' "$destination"
}

# Each updater executable backup is named qbittorrent-nox.<ID>.bak. New updates
# store the matching pre-update qBittorrent.conf as qBittorrent.conf.<ID>.bak.
# Older executable backups may not have a paired config snapshot.
config_snapshot_for_binary() {
    local binary_backup="$1" config_dir="${2:-$CONFIG_BACKUP_DIR}"
    local name snapshot_id candidate
    name="${binary_backup##*/}"
    [[ "$name" == qbittorrent-nox.*.bak ]] || return 1
    snapshot_id="${name#qbittorrent-nox.}"
    snapshot_id="${snapshot_id%.bak}"
    [[ -n "$snapshot_id" ]] || return 1
    candidate="$config_dir/qBittorrent.conf.$snapshot_id.bak"
    [[ -f "$candidate" && ! -L "$candidate" && -s "$candidate" ]] || return 1
    printf '%s\n' "$candidate"
}

remove_config_snapshot_for_binary() {
    local snapshot
    if snapshot="$(config_snapshot_for_binary "$1")"; then
        rm -f -- "$snapshot"
    fi
}

select_legacy_config_snapshot() {
    local -a snapshot_files=() snapshots=()
    local candidate name snapshot_id linked_binary choice i

    shopt -s nullglob
    snapshot_files=("$CONFIG_BACKUP_DIR"/qBittorrent.conf.*.bak)
    shopt -u nullglob
    if (( ${#snapshot_files[@]} == 0 )); then
        echo_err "${MSG_WY}No saved configuration snapshots are available for this legacy executable backup.${NC}"
        return 0
    fi

    while IFS= read -r candidate; do
        if [[ -f "$candidate" && ! -L "$candidate" && -s "$candidate" ]]; then
            snapshots+=("$candidate")
        fi
    done < <(printf '%s\n' "${snapshot_files[@]}" | sort -r)

    if (( ${#snapshots[@]} == 0 )); then
        echo_err "${MSG_WY}No valid saved configuration snapshots were found.${NC}"
        return 0
    fi

    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_YELLOW}              OPTIONAL CONFIG SNAPSHOT FOR LEGACY BACKUP              ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "  This executable backup has no matching pre-update config snapshot."
    echo_err "  You may select an older saved config if you know it contains the"
    echo_err "  settings you want. These snapshots are not guaranteed to match this"
    echo_err "  executable version; choose 0 if unsure and keep the current config."
    echo_err
    echo_err "  0. Keep current configuration"
    for ((i=0; i<${#snapshots[@]}; i++)); do
        candidate="${snapshots[$i]}"
        name="${candidate##*/}"
        snapshot_id="${name#qBittorrent.conf.}"
        snapshot_id="${snapshot_id%.bak}"
        linked_binary="/usr/bin/qbittorrent-nox.${snapshot_id}.bak"
        echo_err "  $((i + 1)). $name"
        if [[ -f "$linked_binary" && ! -L "$linked_binary" ]]; then
            echo_err "     ${LGRAY}A matching executable backup exists: ${linked_binary##*/}${NC}"
        else
            echo_err "     ${LGRAY}Unpaired config snapshot (created by a previous recovery/operation)${NC}"
        fi
    done

    while true; do
        echo_n_err "\n  ${LYELLOW}Choose a config snapshot [0-${#snapshots[@]}]: ${NC}"
        read -r choice < /dev/tty || choice="0"
        choice="${choice:-0}"
        if [[ "$choice" == "0" ]]; then
            CONFIG_RESTORE_FILE=""
            CONFIG_RESTORE_PAIRED=0
            echo_err "${MSG_IG}Keeping the current config as the starting point for this legacy restore.${NC}"
            return 0
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#snapshots[@]} )); then
            CONFIG_RESTORE_FILE="${snapshots[$((choice - 1))]}"
            CONFIG_RESTORE_PAIRED=0
            echo_err "${MSG_IG}Selected saved config snapshot: ${LYELLOW}$CONFIG_RESTORE_FILE${NC}"
            return 0
        fi
        echo_err "${MSG_WY}Invalid selection. Choose a listed number or 0.${NC}"
    done
}

restore_saved_qbt_config() {
    local post_start_config_backup retries=10
    local restore_source="${CONFIG_RESTORE_FILE:-$CONFIG_BACKUP_FILE}"

    # Preserve the config produced by the restored binary so it can be put back
    # if the selected config snapshot is not readable by that binary.
    if ! post_start_config_backup="$(save_qbt_config_backup "$QBT_CONFIG_PATH")"; then
        echo_err "${MSG_WR}Could not preserve the current post-start config. Leaving it untouched.${NC}"
        return 1
    fi
    if ! systemctl stop "$QBT_SERVICE"; then
        echo_err "${MSG_WR}Could not stop $QBT_SERVICE to restore the saved configuration.${NC}"
        return 1
    fi
    while systemctl is-active --quiet "$QBT_SERVICE" && (( retries > 0 )); do
        sleep 1
        retries=$((retries - 1))
    done
    if systemctl is-active --quiet "$QBT_SERVICE"; then
        echo_err "${MSG_WR}$QBT_SERVICE did not stop. Cannot safely replace its config.${NC}"
        return 1
    fi

    if [[ -z "$restore_source" || ! -f "$restore_source" || -L "$restore_source" || ! -s "$restore_source" ]]; then
        echo_err "${MSG_WR}The selected configuration snapshot is unavailable: ${restore_source:-not set}${NC}"
        return 1
    fi
    if ! cp -p -- "$restore_source" "$QBT_CONFIG_PATH"; then
        echo_err "${MSG_WR}Could not copy the selected configuration snapshot back into place.${NC}"
        systemctl start "$QBT_SERVICE" >/dev/null 2>&1 || true
        return 1
    fi
    systemctl reset-failed "$QBT_SERVICE" >/dev/null 2>&1 || true
    if systemctl start "$QBT_SERVICE"; then
        retries=10
        while (( retries > 0 )); do
            systemctl is-active --quiet "$QBT_SERVICE" && break
            sleep 1
            retries=$((retries - 1))
        done
        if systemctl is-active --quiet "$QBT_SERVICE"; then
            echo_err "${MSG_IG}Configuration snapshot reapplied from $restore_source and service is active.${NC}"
            return 0
        fi
    fi

    echo_err "${MSG_WY}The restored binary did not start with the selected configuration snapshot. Reverting to the config it generated at startup...${NC}"
    if ! systemctl stop "$QBT_SERVICE"; then
        echo_err "${MSG_WR}Could not stop $QBT_SERVICE before reverting its config. Automatic executable rollback will be attempted.${NC}"
        return 1
    fi
    retries=10
    while systemctl is-active --quiet "$QBT_SERVICE" && (( retries > 0 )); do
        sleep 1
        retries=$((retries - 1))
    done
    if systemctl is-active --quiet "$QBT_SERVICE"; then
        echo_err "${MSG_WR}$QBT_SERVICE remained active; refusing to replace its configuration file.${NC}"
        return 1
    fi
    if ! cp -p -- "$post_start_config_backup" "$QBT_CONFIG_PATH"; then
        echo_err "${MSG_WR}Could not restore the config generated by the selected binary. Automatic executable rollback will be attempted.${NC}"
        return 1
    fi
    systemctl reset-failed "$QBT_SERVICE" >/dev/null 2>&1 || true
    if systemctl start "$QBT_SERVICE"; then
        retries=10
        while (( retries > 0 )); do
            systemctl is-active --quiet "$QBT_SERVICE" && break
            sleep 1
            retries=$((retries - 1))
        done
        if systemctl is-active --quiet "$QBT_SERVICE"; then
            echo_err "${MSG_WY}Service recovered with its post-start configuration. Configuration snapshot remains available at: $restore_source${NC}"
            return 0
        fi
    fi

    echo_err "${MSG_WR}Service did not recover with either configuration. Automatic executable rollback will be attempted.${NC}"
    return 1
}

################################################################
# MAIN MENU AND LOCAL BACKUP RESTORE
################################################################

count_backup_files() {
    local -a files=()
    shopt -s nullglob
    files=("${BIN_PATH}".*.bak)
    shopt -u nullglob
    printf '%s' "${#files[@]}"
}

qbt_component_mode() {
    local binary_exists="$1" unit_exists="$2"
    if [[ "$binary_exists" == "1" && "$unit_exists" == "1" ]]; then
        printf '%s\n' "present"
    elif [[ "$binary_exists" == "0" && "$unit_exists" == "0" ]]; then
        printf '%s\n' "absent"
    else
        printf '%s\n' "inconsistent"
    fi
}

dietpi_qbt_install_command() {
    # If DietPi already marks ID 46 installed but its executable/service is
    # missing, use DietPi's explicit reinstall operation to repair the setup.
    if [[ "$1" == "2" ]]; then
        printf '%s\n' "reinstall"
    else
        printf '%s\n' "install"
    fi
}

install_qbittorrent_via_dietpi() {
    local software_state command_name binary_exists=0 unit_exists=0

    if [[ ! -x "/boot/dietpi/dietpi-software" ]]; then
        echo_err "${MSG_WR}DietPi software manager is unavailable at /boot/dietpi/dietpi-software. No installation was attempted.${NC}"
        exit 1
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        echo_err "${MSG_WR}systemctl is unavailable, so the installation cannot be verified safely.${NC}"
        exit 1
    fi

    software_state="$(dietpi_qbt_software_state)"
    command_name="$(dietpi_qbt_install_command "$software_state")"

    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_YELLOW}                   DIETPI QBITTORRENT INSTALLATION                     ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    if [[ "$command_name" == "reinstall" ]]; then
        echo_err "  DietPi marks qBittorrent software ID 46 as installed, but the"
        echo_err "  expected executable/service is missing or incomplete."
        echo_err "  DietPi will be asked to repair/reinstall software ID 46."
    else
        echo_err "  qBittorrent is missing. DietPi will install software ID 46."
    fi
    echo_err "  Command: /boot/dietpi/dietpi-software $command_name 46"
    echo_err "  The updater will not download or replace a static binary in this step."
    echo_err "${YELLOW}----------------------------------------------------------------------${NC}"

    if ! confirm_action "Run DietPi's $command_name command for qBittorrent (ID 46) now?"; then
        echo_err "${MSG_WY}Installation/repair declined. No update was attempted.${NC}"
        return 2
    fi

    echo_err "${MSG_IG}Running DietPi qBittorrent $command_name...${NC}"
    if ! /boot/dietpi/dietpi-software "$command_name" 46; then
        echo_err "${MSG_WR}DietPi reported an installation/repair failure. No updater binary replacement was attempted. Review the DietPi output before rerunning.${NC}"
        exit 1
    fi

    [[ -f "$BIN_PATH" && -x "$BIN_PATH" ]] && binary_exists=1
    if systemctl cat "$QBT_SERVICE" >/dev/null 2>&1; then unit_exists=1; fi
    if [[ "$(qbt_component_mode "$binary_exists" "$unit_exists")" != "present" ]]; then
        echo_err "${MSG_WR}DietPi's command returned, but qBittorrent is still incomplete (binary=$binary_exists, service=$unit_exists). No update will be offered. Inspect DietPi's output and repair the installation first.${NC}"
        exit 1
    fi

    echo_err "${MSG_IG}DietPi qBittorrent installation/repair verified. Returning to the main menu; choose Update when ready.${NC}"
    return 0
}

get_main_menu_choice() {
    local backup_count current_version="UNKNOWN" current_output="" service_status="Unknown"
    local software_state software_display choice next_choice=2
    local restore_choice=0 uninstall_choice=0 exit_choice
    local binary_exists=0 unit_exists=0 component_mode

    backup_count="$(count_backup_files)"
    software_state="$(dietpi_qbt_software_state)"
    case "$software_state" in
        2) software_display="Installed (ID 46)" ;;
        0) software_display="Not installed" ;;
        unknown) software_display="Unknown — could not verify" ;;
        *) software_display="Not confirmed installed (state $software_state)" ;;
    esac

    [[ -f "$BIN_PATH" && -x "$BIN_PATH" ]] && binary_exists=1
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl cat "$QBT_SERVICE" >/dev/null 2>&1; then unit_exists=1; fi
        if systemctl is-active --quiet "$QBT_SERVICE"; then service_status="Active"
        elif (( unit_exists == 1 )); then service_status="Inactive"
        else service_status="Unit not found"; fi
    fi
    component_mode="$(qbt_component_mode "$binary_exists" "$unit_exists")"

    if [[ -x "$BIN_PATH" ]] && current_output="$("$BIN_PATH" --version 2>&1)"; then
        if [[ "$current_output" =~ ([0-9]+\.[0-9]+(\.[0-9]+)?) ]]; then current_version="${BASH_REMATCH[1]}"; fi
    elif [[ ! -e "$BIN_PATH" ]]; then
        current_version="Not installed"
    fi

    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_MAGENTA}                       QBITTORRENT UPDATER MENU                        ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err
    echo_err "  Installed version : ${LYELLOW}$current_version${NC}"
    echo_err "  Service status    : ${LCYAN}$service_status${NC}"
    echo_err "  DietPi software   : ${LCYAN}$software_display${NC}"
    echo_err "  Local backups     : ${LCYAN}$backup_count${NC}"
    echo_err
    echo_err "${YELLOW}----------------------------------------------------------------------${NC}"

    # Never offer an update until both the binary and service are present.
    # For an absent or incomplete installation, offer only DietPi repair/install
    # and the menu's Exit option. Once the action succeeds, main() loops here.
    if [[ "$component_mode" != "present" ]]; then
        if [[ "$component_mode" == "absent" ]]; then
            echo_err "  qBittorrent executable and service are both missing."
            if [[ "$software_state" == "2" ]]; then
                echo_err "  DietPi still marks software ID 46 as installed; choose repair/reinstall."
                echo_err "  1. ${LYELLOW}Repair qBittorrent through DietPi (reinstall ID 46)${NC}"
            else
                echo_err "  1. ${LGREEN}Install qBittorrent through DietPi (software ID 46)${NC}"
            fi
        else
            echo_err "  Only one qBittorrent component is present; updating is disabled."
            echo_err "  Use DietPi to repair the incomplete installation first."
            echo_err "  1. ${LYELLOW}Repair qBittorrent through DietPi${NC}"
        fi
        echo_err "  2. Exit"
        echo_err "${YELLOW}----------------------------------------------------------------------${NC}"
        while true; do
            echo_n_err "\n  ${LYELLOW}Select an action [1-2]: ${NC}"
            read -r choice < /dev/tty || choice="2"
            choice="${choice:-2}"
            case "$choice" in
                1) echo "install"; return 0 ;;
                2) echo "exit"; return 0 ;;
                *) echo_err "${MSG_WY}Invalid selection. Choose 1 or 2.${NC}" ;;
            esac
        done
    fi

    echo_err "  1. ${LGREEN}Update qBittorrent${NC}"

    if [[ "$software_state" == "2" && "$backup_count" -gt 0 ]]; then
        restore_choice=$next_choice
        echo_err "  $restore_choice. ${LYELLOW}Restore a previous backup${NC}"
        next_choice=$((next_choice + 1))
    elif (( backup_count > 0 )); then
        echo_err "  ${LGRAY}Backup files exist, but restore is disabled because DietPi does not confirm qBittorrent is installed.${NC}"
    fi

    if [[ "$software_state" == "2" ]]; then
        uninstall_choice=$next_choice
        echo_err "  $uninstall_choice. ${LRED}Uninstall qBittorrent through DietPi${NC}"
        next_choice=$((next_choice + 1))
    fi

    exit_choice=$next_choice
    echo_err "  $exit_choice. Exit"
    echo_err "${YELLOW}----------------------------------------------------------------------${NC}"

    while true; do
        echo_n_err "\n  ${LYELLOW}Select an action [1-$exit_choice]: ${NC}"
        read -r choice < /dev/tty || choice="$exit_choice"
        choice="${choice:-$exit_choice}"
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if (( choice == 1 )); then echo "update"; return 0; fi
            if (( restore_choice > 0 && choice == restore_choice )); then echo "restore"; return 0; fi
            if (( uninstall_choice > 0 && choice == uninstall_choice )); then echo "uninstall"; return 0; fi
            if (( choice == exit_choice )); then echo "exit"; return 0; fi
        fi
        echo_err "${MSG_WY}Invalid selection. Choose a listed option.${NC}"
    done
}
print_restore_warning() {
    local selected_path="$1" selected_version="$2" current_version="$3" target_existed="$4" config_snapshot="$5" config_paired="$6"
    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_YELLOW}                       BACKUP RESTORE CONFIRMATION                     ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err
    echo_err "  Installed version : ${LYELLOW}$current_version${NC}"
    echo_err "  Restore version   : ${LGREEN}$selected_version${NC}"
    echo_err "  Selected backup   : ${LCYAN}$selected_path${NC}"
    echo_err "  Target executable : ${LBLUE}$BIN_PATH${NC}"
    echo_err
    if [[ "$target_existed" -eq 1 ]]; then
        echo_err "  If approved, the updater validates and stages this backup, saves the"
        echo_err "  current executable as a new safety backup, then replaces the binary."
    else
        echo_err "  The installed executable is currently absent. If approved, the updater"
        echo_err "  stages this backup and restores the missing binary. On failure, rollback"
        echo_err "  will return the target to its original absent state."
    fi
    echo_err "  The service will be stopped only for replacement and its prior state"
    echo_err "  will be restored after a successful operation."
    echo_err
    echo_err "  qBittorrent config : ${LCYAN}$QBT_CONFIG_PATH${NC}"
    if [[ "$config_paired" -eq 1 && -n "$config_snapshot" ]]; then
        echo_err "  Paired config      : ${LGREEN}$config_snapshot${NC}"
        echo_err "  The pre-update config saved with this executable will be restored too."
    elif [[ -n "$config_snapshot" ]]; then
        echo_err "  Selected config    : ${LYELLOW}$config_snapshot${NC}"
        echo_err "  This is a manually selected saved snapshot, not automatically linked"
        echo_err "  to this executable. Confirm it contains the settings you need."
    else
        echo_err "  Paired config      : ${LYELLOW}Unavailable for this older backup${NC}"
        echo_err "  The current config will be kept as the starting point. If this backup"
        echo_err "  predates config-aware updates, it cannot recover unsaved pre-upgrade settings."
    fi
    echo_err "  A separate private snapshot of the current config is saved for rollback."
    echo_err
    echo_err "  This restores the executable and the selected config snapshot (if any)."
    echo_err "  It does not restore torrent state, downloads or other application data."
    if [[ "$target_existed" -eq 1 ]]; then
        echo_err "  The selected source backup and new safety backup are retained."
    else
        echo_err "  The selected source backup is retained; no pre-restore executable"
        echo_err "  copy exists because the target was absent."
    fi
    echo_err "  If restoration or service startup fails, rollback is best-effort."
    echo_err
    echo_err "${YELLOW}----------------------------------------------------------------------${NC}"
}

restore_backup() {
    local raw_arch detected_arch backup description output version size
    local current_version="UNKNOWN" current_output="" service_execstart
    local selected_index="" selected_path="" selected_version="" timestamp retries config_snapshot config_snapshot_id
    local -a backup_files=() sorted_backups=() restore_candidates=() restore_versions=() restore_config_snapshots=()

    if ! require_dietpi_qbt_installed "restore"; then exit 1; fi
    if [[ -L "$BIN_PATH" || ( -e "$BIN_PATH" && ! -f "$BIN_PATH" ) ]]; then
        echo_err "${MSG_WR}Target path is a symlink or non-regular file. Refusing to replace it: $BIN_PATH${NC}"
        exit 1
    fi
    if ! systemctl cat "$QBT_SERVICE" >/dev/null 2>&1; then
        echo_err "${MSG_WR}$QBT_SERVICE is unavailable. Repair the DietPi qBittorrent service before restoring.${NC}"
        exit 1
    fi
    service_execstart="$(systemctl show -p ExecStart --value "$QBT_SERVICE" 2>/dev/null || true)"
    if [[ "$service_execstart" != *"$BIN_PATH"* ]]; then
        echo_err "${MSG_WR}$QBT_SERVICE does not appear to execute $BIN_PATH. Refusing to restore a binary the service may not use.${NC}"
        echo_err "  ExecStart: ${service_execstart:-unavailable}"
        exit 1
    fi

    if ! QBT_CONFIG_PATH="$(resolve_qbt_config_path)"; then
        echo_err
        echo_err "${MSG_WR}Could not locate the existing qBittorrent configuration for the service account/profile.${NC}"
        echo_err "  Refusing to restore and start a binary without confirming the existing configuration."
        echo_err "  Otherwise qBittorrent could start with a fresh profile and default WebUI credentials/port."
        echo_err "  Expected default location for the service account: ~/.config/qBittorrent/qBittorrent.conf"
        exit 1
    fi
    if [[ ! -s "$QBT_CONFIG_PATH" ]]; then
        echo_err "${MSG_WR}The qBittorrent configuration is missing or empty: $QBT_CONFIG_PATH${NC}"
        echo_err "  Refusing to start the restored binary with a potentially new profile."
        exit 1
    fi

    raw_arch="$(uname -m)"
    case "$raw_arch" in
        armv7l|armv7) detected_arch="armv7" ;;
        arm64|aarch64) detected_arch="aarch64" ;;
        x86_64|amd64) detected_arch="x86_64" ;;
        armhf) detected_arch="armhf" ;;
        *) detected_arch="$raw_arch" ;;
    esac

    shopt -s nullglob
    backup_files=("${BIN_PATH}".*.bak)
    shopt -u nullglob
    if (( ${#backup_files[@]} > 0 )); then
        while IFS= read -r backup; do sorted_backups+=("$backup"); done < <(printf '%s\n' "${backup_files[@]}" | sort -r)
    fi

    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_MAGENTA}                       AVAILABLE LOCAL BACKUPS                         ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err
    echo_err "  Backups are checked for regular-file status, ELF format, architecture"
    echo_err "  compatibility and a successful qBittorrent --version self-test."
    echo_err

    for backup in "${sorted_backups[@]}"; do
        if [[ ! -f "$backup" || -L "$backup" || ! -s "$backup" ]]; then
            echo_err "${MSG_WY}Skipping invalid backup file: $backup${NC}"
            continue
        fi
        description="$(file -b -- "$backup" 2>/dev/null || true)"
        if [[ "$description" != *ELF* ]]; then
            echo_err "${MSG_WY}Skipping non-ELF backup: $(basename "$backup")${NC}"
            continue
        fi
        case "$detected_arch:$description" in
            aarch64:*aarch64*|x86_64:*x86-64*|armv7:*ARM*|armhf:*ARM*) ;;
            *) echo_err "${MSG_WY}Skipping architecture-mismatched backup: $(basename "$backup") ($description)${NC}"; continue ;;
        esac
        if ! output="$("$backup" --version 2>&1)"; then
            echo_err "${MSG_WY}Skipping backup that failed its --version self-test: $(basename "$backup")${NC}"
            continue
        fi
        version="$(printf '%s\n' "$output" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || true)"
        if [[ -z "$version" ]]; then
            echo_err "${MSG_WY}Skipping backup with an unrecognised version: $(basename "$backup")${NC}"
            continue
        fi
        restore_candidates+=("$backup")
        restore_versions+=("$version")
        if config_snapshot="$(config_snapshot_for_binary "$backup")"; then
            restore_config_snapshots+=("$config_snapshot")
        else
            restore_config_snapshots+=("")
        fi
    done

    if (( ${#restore_candidates[@]} == 0 )); then
        echo_err
        echo_err "${MSG_WR}No valid, compatible backups were found. No changes have been made.${NC}"
        exit 1
    fi
    for ((i=0; i<${#restore_candidates[@]}; i++)); do
        backup="${restore_candidates[$i]}"
        size="$(du -h -- "$backup" 2>/dev/null | cut -f1 || true)"
        echo_err "  $((i + 1)). qBittorrent ${LYELLOW}${restore_versions[$i]}${NC}"
        echo_err "     ${LGRAY}$(basename "$backup")  (${size:-size unknown})${NC}"
        if [[ -n "${restore_config_snapshots[$i]}" ]]; then
            echo_err "     ${LGREEN}Paired pre-update config snapshot available${NC}"
        else
            echo_err "     ${LYELLOW}No paired config snapshot (legacy backup)${NC}"
        fi
    done
    echo_err
    echo_err "  0. ${LRED}Cancel and return to the main menu${NC}"
    while true; do
        echo_n_err "\n  ${LYELLOW}Select a backup [0-${#restore_candidates[@]}]: ${NC}"
        read -r selected_index < /dev/tty || selected_index="0"
        selected_index="${selected_index:-0}"
        if [[ "$selected_index" == "0" ]]; then
            echo_err "\n${MSG_WY}Restore cancelled. No files or service state were changed.${NC}"
            return 0
        fi
        if [[ "$selected_index" =~ ^[0-9]+$ ]] && (( selected_index >= 1 && selected_index <= ${#restore_candidates[@]} )); then break; fi
        echo_err "${MSG_WY}Invalid selection. Choose a listed number or 0 to cancel.${NC}"
    done

    selected_path="${restore_candidates[$((selected_index - 1))]}"
    selected_version="${restore_versions[$((selected_index - 1))]}"
    CONFIG_RESTORE_FILE="${restore_config_snapshots[$((selected_index - 1))]}"
    if [[ -n "$CONFIG_RESTORE_FILE" ]]; then
        CONFIG_RESTORE_PAIRED=1
    else
        CONFIG_RESTORE_PAIRED=0
        select_legacy_config_snapshot
    fi
    if [[ -x "$BIN_PATH" ]] && current_output="$("$BIN_PATH" --version 2>&1)" && [[ "$current_output" =~ ([0-9]+\.[0-9]+(\.[0-9]+)?) ]]; then
        current_version="${BASH_REMATCH[1]}"
    elif [[ ! -e "$BIN_PATH" ]]; then
        current_version="Not installed"
    fi
    local target_existed=0
    [[ -f "$BIN_PATH" ]] && target_existed=1
    print_restore_warning "$selected_path" "$selected_version" "$current_version" "$target_existed" "$CONFIG_RESTORE_FILE" "$CONFIG_RESTORE_PAIRED"
    if ! confirm_action "Restore qBittorrent $selected_version from this backup?"; then
        echo_err "\n${MSG_WY}Restore cancelled. The installed executable and service were not changed.${NC}"
        return 0
    fi

    # Stage and validate the selected backup before stopping the service.
    STAGED_PATH="/usr/bin/.qbittorrent-nox.restore.$BASHPID"
    if ! cp -- "$selected_path" "$STAGED_PATH" || ! chmod 755 "$STAGED_PATH"; then
        rm -f -- "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Could not stage the selected backup. The installed executable was not changed.${NC}"
        exit 1
    fi
    if [[ "$target_existed" -eq 1 ]]; then
        timestamp="$(date +'%Y%m%d_%H%M%S')_${BASHPID}"
        BACKUP_FILE="${BIN_PATH}.${timestamp}.bak"
        if ! cp -p -- "$BIN_PATH" "$BACKUP_FILE"; then
            rm -f -- "$STAGED_PATH"
            STAGED_PATH=""
            BACKUP_FILE=""
            echo_err "${MSG_WR}Could not create a safety backup of the installed executable. Restore aborted.${NC}"
            exit 1
        fi
        echo_err "\n${MSG_IG}Created safety backup of the installed executable: ${LYELLOW}$BACKUP_FILE${NC}"
    else
        BACKUP_FILE=""
        TARGET_MISSING_BEFORE=1
        echo_err "\n${MSG_WY}The executable was absent before restore; failure recovery will return the target to that absent state.${NC}"
    fi

    if systemctl is-active --quiet "$QBT_SERVICE"; then SERVICE_WAS_ACTIVE=1; else SERVICE_WAS_ACTIVE=0; fi
    UPDATE_IN_PROGRESS=1
    stop_service

    if [[ -n "$BACKUP_FILE" ]]; then
        # The current executable's safety backup also gets its own matching
        # config snapshot, so that backup remains a complete restore point later.
        config_snapshot_id="${BACKUP_FILE##*/}"
        config_snapshot_id="${config_snapshot_id#qbittorrent-nox.}"
        config_snapshot_id="${config_snapshot_id%.bak}"
        if ! CONFIG_BACKUP_FILE="$(save_qbt_config_backup "$QBT_CONFIG_PATH" "$config_snapshot_id")"; then
            echo_err "${MSG_WR}Restore aborted because qBittorrent configuration could not be preserved.${NC}"
            exit 1
        fi
    else
        if ! CONFIG_BACKUP_FILE="$(save_qbt_config_backup "$QBT_CONFIG_PATH")"; then
            echo_err "${MSG_WR}Restore aborted because qBittorrent configuration could not be preserved.${NC}"
            exit 1
        fi
    fi
    echo_err "${MSG_IG}Pre-restore configuration safety snapshot saved: ${LYELLOW}$CONFIG_BACKUP_FILE${NC}"
    if [[ -n "$CONFIG_RESTORE_FILE" ]]; then
        if ! cp -p -- "$CONFIG_RESTORE_FILE" "$QBT_CONFIG_PATH"; then
            echo_err "${MSG_WR}Could not apply the configuration snapshot paired with the selected executable. Automatic rollback will be attempted.${NC}"
            exit 1
        fi
        if [[ "$CONFIG_RESTORE_PAIRED" -eq 1 ]]; then
            echo_err "${MSG_IG}Applied the matching pre-update config snapshot: ${LYELLOW}$CONFIG_RESTORE_FILE${NC}"
        else
            echo_err "${MSG_IG}Applied the manually selected saved config snapshot: ${LYELLOW}$CONFIG_RESTORE_FILE${NC}"
        fi
    else
        CONFIG_RESTORE_FILE="$CONFIG_BACKUP_FILE"
        echo_err "${MSG_WY}This legacy executable backup has no paired pre-update config. The current configuration will be used; any settings already lost or reset cannot be reconstructed from this backup.${NC}"
    fi

    echo_err "\n${MSG_IG}Restoring qBittorrent ${LYELLOW}$selected_version${NC}..."
    if ! mv -f -- "$STAGED_PATH" "$BIN_PATH"; then
        echo_err "${MSG_WR}Replacement failed. Automatic rollback will be attempted.${NC}"
        exit 1
    fi
    STAGED_PATH=""

    if [[ "$SERVICE_WAS_ACTIVE" -eq 1 ]]; then
        status_info "Starting and verifying $QBT_SERVICE after restore..."
        systemctl reset-failed "$QBT_SERVICE" >/dev/null 2>&1 || true
        if ! systemctl start "$QBT_SERVICE"; then
            status_fail "Service start failed; automatic rollback will be attempted."
            exit 1
        fi
        retries=10
        while (( retries > 0 )); do systemctl is-active --quiet "$QBT_SERVICE" && break; sleep 1; retries=$((retries - 1)); done
        if ! systemctl is-active --quiet "$QBT_SERVICE"; then
            status_fail "Service did not become active; automatic rollback will be attempted. Inspect journalctl -u $QBT_SERVICE."
            exit 1
        fi
    else
        # Respect the original inactive state; restoration does not start services unexpectedly.
        systemctl stop "$QBT_SERVICE" >/dev/null 2>&1 || true
    fi

    UPDATE_IN_PROGRESS=0
    echo_err
    status_ok "Restore successful: qBittorrent $selected_version is installed."
    if [[ -f "$QBT_CONFIG_PATH" && -f "$CONFIG_RESTORE_FILE" ]]; then
        if cmp -s -- "$QBT_CONFIG_PATH" "$CONFIG_RESTORE_FILE"; then
            echo_err "${MSG_IG}Configuration matches the snapshot selected for qBittorrent $selected_version.${NC}"
        elif [[ "$SERVICE_WAS_ACTIVE" -eq 1 ]]; then
            echo_err "${MSG_WY}qBittorrent changed its configuration when the restored binary started.${NC}"
            if confirm_action "Reapply the configuration snapshot selected for qBittorrent $selected_version and restart the service?"; then
                if ! restore_saved_qbt_config; then
                    echo_err "${MSG_WR}Configuration recovery failed. The updater will roll back the executable and attempt to restore the previous service state.${NC}"
                    UPDATE_IN_PROGRESS=1
                    exit 1
                fi
            else
                echo_err "  Selected config retained at: ${LYELLOW}$CONFIG_RESTORE_FILE${NC}"
                echo_err "  Pre-restore safety copy retained at: ${LYELLOW}$CONFIG_BACKUP_FILE${NC}"
                echo_err "  If WebUI credentials or ports changed, stop the service before recovering a config."
            fi
        else
            echo_err "${MSG_WY}The configuration differs from the selected snapshot, but the service was inactive before restore so it was not started for verification.${NC}"
            echo_err "  Selected config retained at: ${LYELLOW}$CONFIG_RESTORE_FILE${NC}"
            echo_err "  Pre-restore safety copy retained at: ${LYELLOW}$CONFIG_BACKUP_FILE${NC}"
        fi
    fi
    if [[ "$SERVICE_WAS_ACTIVE" -eq 1 ]]; then
        echo_err "${MSG_IG}$QBT_SERVICE is active.${NC}"
    else
        echo_err "${MSG_IG}$QBT_SERVICE was inactive before restore and remains stopped.${NC}"
    fi
    if [[ -n "$BACKUP_FILE" ]]; then
        echo_err "${MSG_IG}Pre-restore safety backup retained at: ${LYELLOW}$BACKUP_FILE${NC}"
    else
        echo_err "${MSG_IG}No pre-restore executable backup was needed because the target was absent.${NC}"
    fi
    echo_err "${MSG_IG}The selected source backup was retained: ${LYELLOW}$selected_path${NC}"
}

uninstall_qbittorrent() {
    local service_execstart was_active=0 config_path=""
    local result_state

    if ! require_dietpi_qbt_installed "uninstall"; then exit 1; fi

    if systemctl cat "$QBT_SERVICE" >/dev/null 2>&1; then
        service_execstart="$(systemctl show -p ExecStart --value "$QBT_SERVICE" 2>/dev/null || true)"
        if [[ -n "$service_execstart" && "$service_execstart" != *"$BIN_PATH"* ]]; then
            echo_err "${MSG_WR}$QBT_SERVICE does not appear to execute $BIN_PATH.${NC}"
            echo_err "  ExecStart: $service_execstart"
            echo_err "  DietPi software ID 46 is installed, but the service looks customized."
            if ! confirm_action "Continue with DietPi's uninstall anyway?"; then
                echo_err "${MSG_WY}Uninstall cancelled. No changes were made.${NC}"
                return 0
            fi
        fi
        if systemctl is-active --quiet "$QBT_SERVICE"; then was_active=1; fi
        config_path="$(resolve_qbt_config_path 2>/dev/null || true)"
    else
        # DietPi documents this as the default qBittorrent profile path.
        config_path="/home/qbittorrent/.config/qBittorrent/qBittorrent.conf"
        [[ -s "$config_path" ]] || config_path=""
    fi

    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_RED}                         UNINSTALL CONFIRMATION                         ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err
    echo_err "  Operation : dietpi-software uninstall 46"
    echo_err "  Service   : $QBT_SERVICE"
    if [[ "$was_active" -eq 1 ]]; then
        echo_err "  State     : currently active; it will be stopped before uninstall."
    elif [[ -n "$config_path" ]]; then
        echo_err "  State     : currently inactive."
    else
        echo_err "  State     : service unit or standard config profile was not detected."
    fi
    if [[ -n "$config_path" && -s "$config_path" ]]; then
        echo_err "  Config    : ${LCYAN}$config_path${NC}"
        echo_err "  A private copy of qBittorrent.conf will be saved under:"
        echo_err "            ${LYELLOW}$CONFIG_BACKUP_DIR${NC}"
    else
        echo_err "  ${LYELLOW}No existing qBittorrent.conf was located; there will be no config safety copy.${NC}"
    fi
    echo_err
    echo_err "  DietPi will manage removal of software ID 46 and its service."
    echo_err "  This updater will NOT delete downloaded files or updater executable backups."
    echo_err "  However, DietPi may remove qBittorrent's user/profile data. This operation"
    echo_err "  does not back up downloaded payloads or the complete torrent session state."
    echo_err "  Any retained config copy contains sensitive WebUI settings and is root-protected."
    echo_err
    echo_err "${YELLOW}----------------------------------------------------------------------${NC}"

    if ! confirm_action "Uninstall qBittorrent through DietPi now?"; then
        echo_err "${MSG_WY}Uninstall cancelled. No changes were made.${NC}"
        return 0
    fi

    if [[ "$was_active" -eq 1 ]]; then
        echo_err "${MSG_IG}Stopping $QBT_SERVICE before preserving its configuration...${NC}"
        if ! systemctl stop "$QBT_SERVICE"; then
            echo_err "${MSG_WR}Could not stop $QBT_SERVICE. Uninstall cancelled.${NC}"
            exit 1
        fi
        local retries=10
        while systemctl is-active --quiet "$QBT_SERVICE" && (( retries > 0 )); do
            sleep 1
            retries=$((retries - 1))
        done
        if systemctl is-active --quiet "$QBT_SERVICE"; then
            echo_err "${MSG_WR}$QBT_SERVICE did not stop. Uninstall cancelled.${NC}"
            systemctl start "$QBT_SERVICE" >/dev/null 2>&1 || true
            exit 1
        fi
    fi

    if [[ -n "$config_path" && -s "$config_path" ]]; then
        CONFIG_BACKUP_FILE="$(save_qbt_config_backup "$config_path")" || {
            echo_err "${MSG_WR}Could not preserve qBittorrent.conf. Uninstall cancelled.${NC}"
            if [[ "$was_active" -eq 1 ]]; then systemctl start "$QBT_SERVICE" >/dev/null 2>&1 || true; fi
            exit 1
        }
        echo_err "${MSG_IG}Configuration safety copy saved: ${LYELLOW}$CONFIG_BACKUP_FILE${NC}"
    fi

    echo_err
    echo_err "${MSG_IG}Running DietPi software uninstall for qBittorrent (ID 46)...${NC}"
    if ! /boot/dietpi/dietpi-software uninstall 46; then
        echo_err "${MSG_WR}DietPi reported an uninstall failure. The installation may be partially removed; inspect DietPi output before retrying.${NC}"
        if [[ "$was_active" -eq 1 && -x "$BIN_PATH" ]] && systemctl cat "$QBT_SERVICE" >/dev/null 2>&1; then
            systemctl start "$QBT_SERVICE" >/dev/null 2>&1 || true
        fi
        exit 1
    fi

    result_state="$(dietpi_qbt_software_state)"
    if [[ "$result_state" == "2" ]]; then
        echo_err "${MSG_WR}DietPi still reports qBittorrent software ID 46 as installed. No files were manually deleted; inspect the DietPi software status.${NC}"
        if [[ "$was_active" -eq 1 && -x "$BIN_PATH" ]] && systemctl cat "$QBT_SERVICE" >/dev/null 2>&1; then
            systemctl start "$QBT_SERVICE" >/dev/null 2>&1 || true
        fi
        exit 1
    elif [[ "$result_state" == "unknown" ]]; then
        echo_err "${MSG_WY}DietPi's uninstall command returned, but the final software state could not be verified.${NC}"
    fi

    echo_err
    status_ok "DietPi qBittorrent uninstall completed."
    if [[ -n "$CONFIG_BACKUP_FILE" ]]; then
        echo_err "${MSG_IG}Configuration backup retained at: ${LYELLOW}$CONFIG_BACKUP_FILE${NC}"
    fi
    echo_err "${MSG_IG}Updater executable backups were left untouched.${NC}"
    echo_err "  Reinstall qBittorrent through DietPi before using the binary restore menu."
}

################################################################
# CORE LOGIC
################################################################

stop_service() {
    if systemctl is-active --quiet "$QBT_SERVICE"; then
        status_info "Stopping $QBT_SERVICE..."
        if ! systemctl stop "$QBT_SERVICE"; then
            status_fail "systemctl could not stop $QBT_SERVICE; the existing executable will be restored if necessary."
            exit 1
        fi

        local retries=10
        while systemctl is-active --quiet "$QBT_SERVICE" && ((retries > 0)); do
            sleep 1
            retries=$((retries - 1))
        done

        if systemctl is-active --quiet "$QBT_SERVICE"; then
            status_fail "$QBT_SERVICE did not stop within the expected time."
            exit 1
        else
            status_ok "$QBT_SERVICE stopped."
        fi
    fi
}

fetch_release_data() {
    local json_content
    if ! json_content=$(curl -fsSL --connect-timeout 10 --max-time 30 "$VERSION_JSON_URL"); then
        echo_err "${MSG_WR}Failed to fetch valid release metadata from GitHub (HTTP/network error).${NC}"; exit 1
    fi
    if ! printf '%s' "$json_content" | jq -e 'type == "object"' >/dev/null 2>&1; then
        echo_err "${MSG_WR}GitHub returned invalid JSON release metadata.${NC}"; exit 1
    fi
    echo "$json_content"
}

perform_update() {
    local url="$1" expected_version="$2" expected_arch="$3"
    local download_path candidate_version candidate_version_number expected_version_number file_description timestamp retries
    status_info "Creating temporary download directory..."
    TMP_DIR="$(mktemp -d)"; download_path="$TMP_DIR/qbittorrent-nox"
    status_ok "Temporary download directory created."
    echo_err
    status_info "Downloading and validating the candidate binary..."
    if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 600 --progress-bar "$url" -o "$download_path"; then
        echo_err "\n${MSG_WR}Download failed (HTTP error, timeout, or network failure). Existing executable was not changed.${NC}"; exit 1
    fi
    if [[ ! -s "$download_path" ]]; then echo_err "${MSG_WR}Downloaded file is empty. Existing executable was not changed.${NC}"; exit 1; fi
    file_description="$(file -b "$download_path" 2>/dev/null || true)"
    if [[ "$file_description" != *ELF* ]]; then echo_err "${MSG_WR}Downloaded file is not a recognized ELF executable ($file_description). Existing executable was not changed.${NC}"; exit 1; fi
    case "$expected_arch:$file_description" in
        aarch64:*aarch64*|x86_64:*x86-64*|armv7:*ARM*|armhf:*ARM*) ;;
        *) echo_err "${MSG_WR}Downloaded ELF architecture does not match requested '$expected_arch' artifact: $file_description. Existing executable was not changed.${NC}"; exit 1 ;;
    esac
    # curl creates downloads as non-executable files by default. Set the
    # executable bit before running the candidate's --version self-test.
    if ! chmod 755 "$download_path"; then
        echo_err "${MSG_WR}Could not mark the candidate executable for validation. Existing executable was not changed.${NC}"
        exit 1
    fi
    if ! candidate_version="$("$download_path" --version 2>&1)"; then
        echo_err "${MSG_WR}Downloaded executable failed its --version self-test. Existing executable was not changed.${NC}"
        exit 1
    fi
    candidate_version_number="$(printf '%s\n' "$candidate_version" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || true)"
    expected_version_number="${expected_version%%[-+]*}"
    if [[ -z "$candidate_version_number" || "$candidate_version_number" != "$expected_version_number" ]]; then
        echo_err "${MSG_WR}Downloaded executable version does not match metadata version $expected_version. Existing executable was not changed.${NC}"
        echo_err "          Parsed candidate version: ${candidate_version_number:-unrecognized}"
        echo_err "          Reported version: $candidate_version"
        exit 1
    fi
    STAGED_PATH="/usr/bin/.qbittorrent-nox.new.$BASHPID"
    if ! cp "$download_path" "$STAGED_PATH" || ! chmod 755 "$STAGED_PATH"; then
        rm -f "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Could not stage executable in /usr/bin. Existing executable was not changed.${NC}"
        exit 1
    fi
    if [[ ! -f "$BIN_PATH" || ! -x "$BIN_PATH" ]]; then
        rm -f "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Existing qBittorrent executable is missing; refusing an unbacked replacement. Repair/install it with DietPi first.${NC}"
        exit 1
    fi
    if ! QBT_CONFIG_PATH="$(resolve_qbt_config_path)" ||
       [[ ! -f "$QBT_CONFIG_PATH" || -L "$QBT_CONFIG_PATH" || ! -s "$QBT_CONFIG_PATH" ]]; then
        rm -f -- "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Cannot locate a non-empty qBittorrent configuration. Update aborted because a future executable restore could not be paired with the pre-update settings.${NC}"
        echo_err "  Check the service user/profile and DietPi's documented config path: /home/qbittorrent/.config/qBittorrent/qBittorrent.conf"
        exit 1
    fi
    timestamp="$(date +'%Y%m%d_%H%M%S')_${BASHPID}"; BACKUP_FILE="${BIN_PATH}.${timestamp}.bak"
    if ! cp -p "$BIN_PATH" "$BACKUP_FILE"; then
        rm -f "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Cannot create backup. Update aborted for safety.${NC}"
        exit 1
    fi
    echo_err "${MSG_IG}Created rollback backup: ${LYELLOW}$BACKUP_FILE${NC}"
    if systemctl is-active --quiet "$QBT_SERVICE"; then
        SERVICE_WAS_ACTIVE=1
    else
        SERVICE_WAS_ACTIVE=0
    fi
    UPDATE_IN_PROGRESS=1
    stop_service
    if ! CONFIG_BACKUP_FILE="$(save_qbt_config_backup "$QBT_CONFIG_PATH" "$timestamp")"; then
        echo_err "${MSG_WR}Update aborted because the pre-update qBittorrent configuration could not be saved.${NC}"
        exit 1
    fi
    echo_err "${MSG_IG}Pre-update configuration snapshot paired with this executable backup: ${LYELLOW}$CONFIG_BACKUP_FILE${NC}"
    echo_err "\n${MSG_IG}Atomically replacing the executable... ${NC}"
    if ! mv -f "$STAGED_PATH" "$BIN_PATH"; then
        rm -f "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Replacement failed; rollback will be attempted.${NC}"
        exit 1
    fi
    STAGED_PATH=""
    status_info "Starting and verifying $QBT_SERVICE..."
    systemctl reset-failed "$QBT_SERVICE" >/dev/null 2>&1 || true
    if ! systemctl start "$QBT_SERVICE"; then
        status_fail "Service start failed; rollback will be attempted."
        exit 1
    fi
    retries=10
    while (( retries > 0 )); do systemctl is-active --quiet "$QBT_SERVICE" && break; sleep 1; retries=$((retries - 1)); done
    if ! systemctl is-active --quiet "$QBT_SERVICE"; then
        status_fail "Service did not become active; rollback will be attempted. Inspect journalctl -u $QBT_SERVICE."
        exit 1
    fi
    UPDATE_IN_PROGRESS=0
    echo_err
    status_ok "Update successful: qBittorrent $expected_version is active."
    echo_err "${MSG_IG}Rollback backup retained at: ${LYELLOW}$BACKUP_FILE${NC}"
    manage_backups "$BACKUP_FILE"
}

################################################################
# MAIN
################################################################

run_update_workflow() {
    local dependency_status

    print_startup_warning
    if ! confirm_action "Continue with the update workflow?"; then
        echo_err "\n${MSG_WY}Update cancelled. No changes have been made; returning to main menu.${NC}\n"
        return 2
    fi

    if ensure_dependencies update; then
        :
    else
        dependency_status=$?
        if (( dependency_status == 2 )); then
            echo_err "${MSG_IG}Returning to main menu without updating.${NC}"
            return 2
        fi
        return "$dependency_status"
    fi
    check_internet

    # The main menu only returns "update" when both components exist. Keep
    # this independent guard in case the installation changes after selection.
    status_info "Rechecking the qBittorrent installation..."
    local binary_exists=0 unit_exists=0
    [[ -f "$BIN_PATH" && -x "$BIN_PATH" ]] && binary_exists=1
    systemctl cat "$QBT_SERVICE" >/dev/null 2>&1 && unit_exists=1
    if [[ "$(qbt_component_mode "$binary_exists" "$unit_exists")" != "present" ]]; then
        status_fail "The qBittorrent executable/service changed after the menu was displayed. No update will be attempted; repair the installation through DietPi first."
        exit 1
    fi
    status_ok "qBittorrent executable and service are present."
    local service_execstart
    service_execstart="$(systemctl show -p ExecStart --value "$QBT_SERVICE" 2>/dev/null || true)"
    if [[ "$service_execstart" != *"$BIN_PATH"* ]]; then
        echo_err "${MSG_WR}$QBT_SERVICE does not appear to execute $BIN_PATH. Refusing to replace a binary the service may not use.${NC}"
        echo_err "          ExecStart: ${service_execstart:-unavailable}"
        exit 1
    fi

    # VERSION CHECKING LOGIC
    echo_err "\n\n${MSG_IG}Checking for available updates...      ${NC}"
    local json_data
    json_data=$(fetch_release_data)
    local latest_ver
    if ! latest_ver="$(printf '%s' "$json_data" | jq -er '.qbittorrent | strings | select(length > 0)')"; then echo_err "${MSG_WR}Metadata is missing a qBittorrent version. Aborting before stopping the service.${NC}"; exit 1; fi
    if [[ ! "$latest_ver" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?([.-][0-9A-Za-z.+-]+)?$ ]]; then echo_err "${MSG_WR}Unexpected qBittorrent version format: '$latest_ver'. Aborting.${NC}"; exit 1; fi
    local current_ver="UNKNOWN" current_output=""
    if current_output="$("$BIN_PATH" --version 2>&1)"; then
        current_ver="$(printf '%s\n' "$current_output" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || true)"
        [[ -n "$current_ver" ]] || current_ver="UNKNOWN"
    fi

    echo_err
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err "${DB_MAGENTA}                        RELEASE VERSION CHECK                         ${NC}"
    echo_err "${YELLOW}======================================================================${NC}"
    echo_err
    echo_err "  Installed qBittorrent : ${LYELLOW}${current_ver}${NC}"
    echo_err "  Latest qBittorrent    : ${LGREEN}${latest_ver}${NC}"
    echo_err

    if [[ "$current_ver" == "$latest_ver" ]]; then
        echo_err "  Status: qBittorrent's version matches the latest release."
        echo_err "          The static build can still differ by libtorrent version."
    elif [[ "$current_ver" == "UNKNOWN" ]]; then
        echo_err "  ${LYELLOW}Status: the installed version could not be determined.${NC}"
    else
        echo_err "  Status: the installed and latest versions differ."
    fi

    echo_err
    echo_err "  Next, choose the target architecture and libtorrent version."
    echo_err "  The updater will ask for final confirmation before downloading"
    echo_err "  or replacing the installed executable."
    echo_err
    local arch
    if ! arch="$(get_architecture_interactive)"; then
        echo_err "${MSG_WY}Update cancelled during architecture selection. Returning to main menu.${NC}"
        return 2
    fi
    local lib_ver
    if ! lib_ver="$(get_libtorrent_version)"; then
        echo_err "${MSG_WY}Update cancelled during libtorrent selection. Returning to main menu.${NC}"
        return 2
    fi
    local lib_ver_id
    if [[ "$lib_ver" == "2.0" ]]; then
        lib_ver_id="$(printf '%s' "$json_data" | jq -er '.libtorrent_2_0 | strings | select(length > 0)')" || { echo_err "${MSG_WR}Metadata is missing libtorrent_2_0. Aborting before stopping the service.${NC}"; exit 1; }
    else
        lib_ver_id="$(printf '%s' "$json_data" | jq -er '.libtorrent_1_2 | strings | select(length > 0)')" || { echo_err "${MSG_WR}Metadata is missing libtorrent_1_2. Aborting before stopping the service.${NC}"; exit 1; }
    fi
    if [[ ! "$lib_ver_id" =~ ^[0-9A-Za-z._+-]+$ ]]; then echo_err "${MSG_WR}Unexpected libtorrent version identifier: '$lib_ver_id'. Aborting.${NC}"; exit 1; fi
    local final_url="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${latest_ver}_v${lib_ver_id}/${arch}-qbittorrent-nox"

    print_update_warning "$current_ver" "$latest_ver" "$arch" "$lib_ver"
    if ! confirm_action "Download and install this build now?"; then
        echo_err "\n${MSG_WY}Update cancelled. The updater did not stop the service or replace the executable.${NC}\n"
        return 2
    fi

    echo_err
    echo_err "${MSG_IG}Proceeding with the selected build. The service will remain running"
    echo_err "  during download and validation; it is stopped only for replacement."
    echo_err

    perform_update "$final_url" "$latest_ver" "$arch"
}

dietpi_marker_present() {
    [[ -f "$DIETPI_SERVICES" ]]
}

main() {
    print_logo

    echo_err
    echo_err
    status_info "Executing preflight checks..."
    if command -v sleep >/dev/null 2>&1; then sleep 1; fi

    check_root

    status_info "Checking for a DietPi installation..."
    if dietpi_marker_present; then
        status_ok "DietPi installation detected."
    else
        status_fail "This script is intended for DietPi; aborting."
        exit 1
    fi

    local action operation_status
    while true; do
        action="$(get_main_menu_choice)"
        case "$action" in
            exit)
                echo_err "\n${MSG_IG}Exited without making changes.${NC}"
                return 0
                ;;
            install)
                if install_qbittorrent_via_dietpi; then
                    # Installation is a separate step. Show the menu again and
                    # require a separate user choice before beginning an update.
                    continue
                else
                    operation_status=$?
                    if (( operation_status == 2 )); then
                        echo_err "${MSG_IG}Installation/repair cancelled; returning to main menu.${NC}"
                        continue
                    fi
                    return "$operation_status"
                fi
                ;;
            restore)
                # Restore is local; it does not need GitHub access.
                if ensure_dependencies restore; then
                    restore_backup
                    echo_err "${MSG_IG}Returning to main menu.${NC}"
                    continue
                else
                    operation_status=$?
                    if (( operation_status == 2 )); then
                        echo_err "${MSG_IG}Restore setup cancelled; returning to main menu.${NC}"
                        continue
                    fi
                    return "$operation_status"
                fi
                ;;
            uninstall)
                if ensure_dependencies uninstall; then
                    uninstall_qbittorrent
                    echo_err "${MSG_IG}Returning to main menu.${NC}"
                    continue
                else
                    operation_status=$?
                    if (( operation_status == 2 )); then
                        echo_err "${MSG_IG}Uninstall setup cancelled; returning to main menu.${NC}"
                        continue
                    fi
                    return "$operation_status"
                fi
                ;;
            update)
                if run_update_workflow; then
                    echo_err "${MSG_IG}Update workflow finished; returning to main menu.${NC}"
                    continue
                else
                    operation_status=$?
                    if (( operation_status == 2 )); then
                        echo_err "${MSG_IG}Operation cancelled; returning to main menu.${NC}"
                        continue
                    fi
                    return "$operation_status"
                fi
                ;;
            *)
                echo_err "${MSG_WR}Unknown main-menu action. Aborting safely.${NC}"
                return 1
                ;;
        esac
    done
}


# When executed from a file, run normally. When Bash reads this script from stdin
# (for example, curl ... | sudo bash), BASH_SOURCE[0] is empty. Keep the
# non-empty/different case sourced so tests and callers can load our functions.
if [[ "${BASH_SOURCE[0]:-}" == "$0" || -z "${BASH_SOURCE[0]:-}" ]]; then
    main "$@"
fi
