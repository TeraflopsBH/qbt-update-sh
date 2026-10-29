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
readonly VERSION_JSON_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/latest/download/dependency-version.json"

################################################################
# VISUAL STYLING
################################################################

# Standard Colors
readonly RED='\033[0;91m'
readonly LRED='\033[1;31m'
readonly DRED='\033[0;31m'
readonly GREEN='\033[0;92m'
readonly LGREEN='\033[1;32m'
readonly DGREEN='\033[0;32m'
readonly BLUE='\033[0;94m'
readonly LBLUE='\033[1;34m'
readonly DBLUE='\033[0;34m'
readonly CYAN='\033[0;96m'
readonly LCYAN='\033[1;36m'
readonly DCYAN='\033[0;36m'
readonly MAGENTA='\033[0;95m'
readonly LMAGENTA='\033[1;35m'
readonly DMAGENTA='\033[0;35m'
readonly YELLOW='\033[0;93m'
readonly LYELLOW='\033[1;33m'
readonly DYELLOW='\033[0;33m'
readonly WHITE='\033[1;37m'
readonly LGRAY='\033[0;37m'
readonly DGRAY='\033[0;90m'

# Background Colors
readonly B_RED='\033[41;37m'
readonly DB_RED='\033[41;1;37m'
readonly B_GREEN='\033[42;37m'
readonly DB_GREEN='\033[42;1;37m'
readonly B_BLUE='\033[44;37m'
readonly DB_BLUE='\033[44;1;37m'
readonly B_CYAN='\033[46;37m'
readonly DB_CYAN='\033[46;1;37m'
readonly DB_MAGENTA='\033[45;1;37m'
readonly DB_YELLOW='\033[43;1;37m'

# Formatting
readonly NC='\033[0m'
readonly ULINE='\033[4m'
readonly BOLD='\033[1m'

# Helpers
readonly MSG_WG=" ${B_RED} WARN ${NC} - ${LGREEN}"
readonly MSG_WR=" ${B_RED} WARN ${NC} - ${LRED}"
readonly MSG_WY=" ${B_RED} WARN ${NC} - ${LYELLOW}"
readonly MSG_IG=" ${B_CYAN} INFO ${NC} - ${LGREEN}"
readonly MSG_IR=" ${B_CYAN} INFO ${NC} - ${LRED}"

################################################################
# SYSTEM FUNCTIONS
################################################################

TMP_DIR=""
BACKUP_FILE=""
STAGED_PATH=""
UPDATE_IN_PROGRESS=0
SERVICE_WAS_ACTIVE=0

cleanup() {
    local status=$?
    if [[ $status -ne 0 && "${UPDATE_IN_PROGRESS:-0}" -eq 1 && -n "${BACKUP_FILE:-}" && -f "$BACKUP_FILE" ]]; then
        echo_err "\n${MSG_WR}Update failed; attempting to restore the previous executable... ${NC}"
        local restore_path="/usr/bin/.qbittorrent-nox.rollback.${BASHPID}"

        # Stop any partially-started candidate before restoring the old file.
        systemctl stop "$QBT_SERVICE" >/dev/null 2>&1 || true
        if cp -p "$BACKUP_FILE" "$restore_path" && chmod 755 "$restore_path" && mv -f "$restore_path" "$BIN_PATH"; then
            if [[ "$SERVICE_WAS_ACTIVE" -eq 1 ]]; then
                systemctl reset-failed "$QBT_SERVICE" >/dev/null 2>&1 || true
                if systemctl start "$QBT_SERVICE"; then
                    local retries=10
                    while (( retries > 0 )); do
                        systemctl is-active --quiet "$QBT_SERVICE" && break
                        sleep 1
                        retries=$((retries - 1))
                    done
                    if systemctl is-active --quiet "$QBT_SERVICE"; then
                        echo_err "${MSG_IG}Previous executable restored and service is active again.${NC}"
                    else
                        echo_err "${MSG_WR}Previous executable restored, but service did not become active. Check journalctl -u $QBT_SERVICE.${NC}"
                    fi
                else
                    echo_err "${MSG_WR}Previous executable restored, but service restart failed. Check journalctl -u $QBT_SERVICE.${NC}"
                fi
            else
                echo_err "${MSG_IG}Previous executable restored. The service was inactive before the update and has been left stopped.${NC}"
            fi
        else
            rm -f "$restore_path"
            echo_err "${MSG_WR}AUTOMATIC ROLLBACK FAILED. Backup remains at: $BACKUP_FILE${NC}"
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

check_root() {
    echo_n_err "\n        ${GREEN}- Checking for ${LBLUE}SUDO${GREEN}...                                     "
    if [[ $EUID -ne 0 ]]; then
        echo_err "${DB_RED} ABSENT  ${NC}"
        echo_err "\n${MSG_WY}This script must be run ${ULINE}with ROOT privileges${NC}\n"
        exit 1
    fi
    echo_err "${DB_GREEN} PRESENT ${NC}"
}

check_internet() {
    echo_n_err "\n        ${GREEN}- Checking HTTPS access to GitHub...                      ${NC}"
    if ! curl -fsSL --connect-timeout 10 --max-time 30 "$VERSION_JSON_URL" -o /dev/null; then
        echo_err "${DB_RED} FAILED  ${NC}"
        echo_err "\n${MSG_WR}Cannot fetch release metadata from GitHub. Check DNS, HTTPS access, and system time.${NC}\n"
        exit 1
    fi
    echo_err "${DB_GREEN} PRESENT ${NC}"
}

ensure_dependencies() {
    # The script is intended for DietPi/Debian and runs as root. Install only
    # packages that provide commands actually missing from this system.
    local required_command package
    local -a required_commands=(
        curl jq file grep head sort du cut basename sleep mktemp
        cp chmod mv rm cat date uname
    )
    local -a missing_packages=()

    if ! command -v apt-get >/dev/null 2>&1; then
        echo_err "${MSG_WR}Cannot install missing dependencies automatically: apt-get is unavailable.${NC}"
        echo_err "          This updater requires a DietPi/Debian system with APT available.${NC}"
        exit 1
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        echo_err "${MSG_WR}systemctl is unavailable. This system does not appear to have the expected systemd service manager.${NC}"
        exit 1
    fi

    for required_command in "${required_commands[@]}"; do
        if ! command -v "$required_command" >/dev/null 2>&1; then
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
        echo_err "${MSG_IG}All required external commands are available.${NC}"
        return 0
    fi

    echo_err
    echo_err "${DB_YELLOW}              MISSING DEPENDENCIES WARNING              ${NC}"
    echo_err "${YELLOW}-----------------------------------------------------------${NC}"
    echo_err "The following package(s) are missing: ${LYELLOW}${missing_packages[*]}${NC}"
    echo_err "The updater will install them using APT before continuing."
    echo_err "No qBittorrent executable will be replaced during this step."
    echo_err "${YELLOW}-----------------------------------------------------------${NC}"

    echo_n_err "${MSG_IG}Refreshing APT package lists... ${NC}"
    if ! apt-get update; then
        echo_err "${DB_RED} FAILED ${NC}"
        echo_err "${MSG_WR}APT update failed. Check network/repository configuration, then rerun the updater.${NC}"
        exit 1
    fi
    echo_err "${DB_GREEN} DONE ${NC}"

    echo_n_err "${MSG_IG}Installing missing package(s): ${LYELLOW}${missing_packages[*]}${NC}... "
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing_packages[@]}"; then
        echo_err "${DB_RED} FAILED ${NC}"
        echo_err "${MSG_WR}Dependency installation failed. Fix APT and rerun the updater.${NC}"
        exit 1
    fi
    echo_err "${DB_GREEN} DONE ${NC}"

    for required_command in "${required_commands[@]}"; do
        if ! command -v "$required_command" >/dev/null 2>&1; then
            echo_err "${MSG_WR}The command '$required_command' is still unavailable after installing dependencies. Aborting.${NC}"
            exit 1
        fi
    done
    echo_err "${MSG_IG}Dependency verification completed.${NC}"
}

print_startup_warning() {
    echo_err
    echo_err "${DB_YELLOW}                 IMPORTANT SAFETY NOTICE                 ${NC}"
    echo_err "${YELLOW}-----------------------------------------------------------${NC}"
    echo_err "This updater is intended for DietPi and is a work in progress."
    echo_err "It downloads a third-party static qBittorrent executable from"
    echo_err "userdocs/qbittorrent-nox-static on GitHub."
    echo_err
    echo_err "${LYELLOW}During this run, it may:${NC}"
    echo_err "  - Install missing helper packages using APT."
    echo_err "  - Offer to install qBittorrent through DietPi if it is absent."
    echo_err "  - Replace ${LBLUE}$BIN_PATH${NC} and start ${LBLUE}$QBT_SERVICE${NC}."
    echo_err "  - Create a timestamped backup and attempt rollback on failure."
    echo_err
    echo_err "${LYELLOW}Important:${NC}"
    echo_err "  - The executable is not the standard Debian/DietPi package build."
    echo_err "  - Rollback is best-effort; keep a known-good backup."
    echo_err "  - The script does not intentionally modify qBittorrent settings."
    echo_err "${YELLOW}-----------------------------------------------------------${NC}"
}

print_update_warning() {
    echo_err
    echo_err "${DB_YELLOW}                 BEFORE YOU CONTINUE                 ${NC}"
    echo_err "${YELLOW}-----------------------------------------------------------${NC}"
    echo_err "You are about to replace the qBittorrent executable at:"
    echo_err "  ${LBLUE}$BIN_PATH${NC}"
    echo_err "The selected third-party binary will be downloaded and validated"
    echo_err "before the installed executable is touched."
    echo_err "The script will back up the existing binary, stop the service,"
    echo_err "replace the executable, and attempt to start the service."
    echo_err "If replacement or startup fails, automatic rollback is attempted."
    echo_err
    echo_err "${LYELLOW}Do not proceed on a production system without a separate backup.${NC}"
    echo_err "Rollback is best-effort and cannot repair unrelated service/config errors."
    echo_err "${YELLOW}-----------------------------------------------------------${NC}"
}

print_logo() {
    if command -v clear >/dev/null 2>&1; then
        clear >&2 || true
    else
        printf '\\033[2J\\033[H' >&2
    fi
    cat << "EOF" >&2

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
        echo_err "${MSG_WR}Choose Abort. No binary will be replaced.${NC}"
    fi

    while true; do
        echo_err
        echo_err "${YELLOW}          -----------------------${NC}"
        if [[ "$detected" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
            echo_err "           0. ${LMAGENTA}$detected${NC} ${LGREEN}(${LCYAN}detected${NC}${LGREEN})${NC}"
        fi
        echo_err "           1. ${LBLUE}aarch64${NC}"
        echo_err "           2. ${LYELLOW}x86_64${NC}"
        echo_err "           3. ${LRED}Abort${NC}"
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
            3) echo_err "${MSG_WR}Aborting the script.${NC}\n"; exit 1 ;;
            *) echo_err "${MSG_WY}Invalid selection.${NC}\n" ;;
        esac
    done

    echo_err "\n${MSG_IG}Selected artifact architecture: ${DB_MAGENTA}$selected_arch${NC}"
    echo_err "${MSG_WY}A non-native selection will fail validation unless the host can execute that architecture.${NC}\n"
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
        echo_err "${YELLOW}          -----------------------------${NC}"
        echo_err
        echo_n_err "\n ${GREEN}Enter choice ${LYELLOW}${BOLD}${ULINE}[1]${NC}${GREEN} or ${LYELLOW}${BOLD}${ULINE}[2]${NC}: "
        
        read -r choice < /dev/tty || choice="1"

        case "$choice" in
            1|"") ver="2.0"; break ;;
            2)    ver="1.2"; break ;;
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
        local size
        size=$(du -h "$b" | cut -f1)
        echo_err "          ${LGRAY}$(basename "$b") ${LYELLOW}($size)"
    done

    echo_err "\n          ${GREEN}How would you like to manage them?${NC}\n"
    echo_err "          ${YELLOW}-----------------------------------------${NC}"
    echo_err "           1. ${LGREEN}Keep all${NC}"
    echo_err "           2. ${LYELLOW}Keep only the newest (delete others)${NC}"
    echo_err "           3. ${LRED}Delete all previous backups${NC}"
    echo_err "          ${YELLOW}-----------------------------------------${NC}"
    echo_n_err "\n${GREEN}Enter choice ${LYELLOW}${BOLD}${ULINE}[1]${NC}: "
    
    local choice
    read -r choice < /dev/tty || choice="1"
    choice=${choice:-1}

    case "$choice" in
        1) echo_err "\n${MSG_IG}Keeping all previous backups.${NC}" ;;
        2) 
            echo_n_err "\n${MSG_IG}Cleaning up old backups.............                        ${NC}"
            for ((i=1; i<${#backups[@]}; i++)); do
                rm -f "${backups[$i]}"
            done
            echo_err "${DB_GREEN}  DONE  ${NC}"
            ;;
        3)
            echo_n_err "\n${MSG_IG}Deleting all previous backups.............                  ${NC}"
            for b in "${backups[@]}"; do
                rm -f "$b"
            done
            echo_err "${DB_GREEN}  DONE  ${NC}"
            ;;
        *) echo_err "${MSG_WY}Invalid choice. Keeping all.${NC}" ;;
    esac
}

################################################################
# CORE LOGIC
################################################################

stop_service() {
    if systemctl is-active --quiet "$QBT_SERVICE"; then
        echo_n_err "${MSG_IG}Stopping ${LBLUE}qbittorrent-nox${NC} ${GREEN}service.....                     ${NC}"
        systemctl stop "$QBT_SERVICE"
        
        local retries=10
        while systemctl is-active --quiet "$QBT_SERVICE" && ((retries > 0)); do
            sleep 1
            ((retries--))
        done

        if systemctl is-active --quiet "$QBT_SERVICE"; then
            echo_err "${DB_RED} FAILED  ${NC}"
            exit 1
        else
             echo_err "${DB_GREEN}  DONE  ${NC}"
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
    local download_path candidate_version file_description timestamp staged_path retries
    echo_n_err "${MSG_IG}Making temporary download directory....................     ${NC}"
    TMP_DIR="$(mktemp -d)"; download_path="$TMP_DIR/qbittorrent-nox"
    echo_err "${DB_GREEN}  DONE  ${NC}"
    echo_err "\n${MSG_IG}Downloading and validating the candidate binary... ${NC}"
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
    if ! candidate_version="$("$download_path" --version 2>&1)"; then echo_err "${MSG_WR}Downloaded executable failed its --version self-test. Existing executable was not changed.${NC}"; exit 1; fi
    if ! printf '%s\n' "$candidate_version" | grep -Fq "$expected_version"; then
        echo_err "${MSG_WR}Downloaded executable version does not match metadata version $expected_version. Existing executable was not changed.${NC}"
        echo_err "          Reported version: $candidate_version"; exit 1
    fi
    chmod 755 "$download_path"
    STAGED_PATH="/usr/bin/.qbittorrent-nox.new.$BASHPID"
    if ! cp "$download_path" "$STAGED_PATH" || ! chmod 755 "$STAGED_PATH"; then
        rm -f "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Could not stage executable in /usr/bin. Existing executable was not changed.${NC}"
        exit 1
    fi
    if [[ ! -x "$BIN_PATH" ]]; then
        rm -f "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Existing qBittorrent executable is missing; refusing an unbacked replacement. Repair/install it with DietPi first.${NC}"
        exit 1
    fi
    timestamp="$(date +'%Y%m%d_%H%M%S')_${BASHPID}"; BACKUP_FILE="${BIN_PATH}.${timestamp}.bak"
    if ! cp -p "$BIN_PATH" "$BACKUP_FILE"; then rm -f "$staged_path"; echo_err "${MSG_WR}Cannot create backup. Update aborted for safety.${NC}"; exit 1; fi
    echo_err "${MSG_IG}Created rollback backup: ${LYELLOW}$BACKUP_FILE${NC}"
    if systemctl is-active --quiet "$QBT_SERVICE"; then
        SERVICE_WAS_ACTIVE=1
    else
        SERVICE_WAS_ACTIVE=0
    fi
    UPDATE_IN_PROGRESS=1
    stop_service
    echo_err "\n${MSG_IG}Atomically replacing the executable... ${NC}"
    if ! mv -f "$STAGED_PATH" "$BIN_PATH"; then
        rm -f "$STAGED_PATH"
        STAGED_PATH=""
        echo_err "${MSG_WR}Replacement failed; rollback will be attempted.${NC}"
        exit 1
    fi
    STAGED_PATH=""
    echo_n_err "${MSG_IG}Starting ${LBLUE}qbittorrent-nox${NC} ${GREEN}service... ${NC}"
    systemctl reset-failed "$QBT_SERVICE" >/dev/null 2>&1 || true
    if ! systemctl start "$QBT_SERVICE"; then echo_err "${DB_RED} FAILED ${NC}"; echo_err "${MSG_WR}Service start failed; rollback will be attempted.${NC}"; exit 1; fi
    retries=10
    while (( retries > 0 )); do systemctl is-active --quiet "$QBT_SERVICE" && break; sleep 1; retries=$((retries - 1)); done
    if ! systemctl is-active --quiet "$QBT_SERVICE"; then echo_err "${DB_RED} FAILED ${NC}"; echo_err "${MSG_WR}Service did not become active; rollback will be attempted. Inspect journalctl -u $QBT_SERVICE.${NC}"; exit 1; fi
    UPDATE_IN_PROGRESS=0
    echo_err "${DB_GREEN}  DONE  ${NC}"
    echo_err "\n${MSG_IG}Update successful: qBittorrent $expected_version is active.${NC}"
    echo_err "${MSG_IG}Rollback backup retained at: ${LYELLOW}$BACKUP_FILE${NC}"
    manage_backups "$BACKUP_FILE"
}

################################################################
# MAIN
################################################################

main() {
    print_logo
    
    echo_n_err "\n\n${MSG_IG}Executing some preflight checks...${NC} \n"
    sleep 1
    
    check_root
    print_startup_warning

    # Check for DietPi
    echo_n_err "\n        ${GREEN}- Detecting ${LYELLOW}DietPi${NC} ${GREEN}installation...                         ${NC}"
    if [ -f "$DIETPI_SERVICES" ]; then
        echo_err "${DB_GREEN} PRESENT ${NC}"
    else
        echo_err "${DB_RED} ABSENT  ${NC}\n\n       ${LYELLOW}This script is intended for DietPi system.${NC}\n       ${LRED}Script will now abort.${NC}\n"
        exit 1
    fi

    # Install all missing helper tools before using curl, jq, or file.
    ensure_dependencies
    check_internet

    # Check the executable and service unit independently.
    echo_n_err "\n        ${GREEN}- Detecting qBitTorrent installation...                    ${NC}"
    local binary_exists=0 unit_exists=0
    [[ -x "$BIN_PATH" ]] && binary_exists=1
    systemctl cat "$QBT_SERVICE" >/dev/null 2>&1 && unit_exists=1
    if (( binary_exists == 1 && unit_exists == 1 )); then
        echo_err "${DB_GREEN} PRESENT ${NC}"
    elif (( binary_exists == 0 && unit_exists == 0 )); then
        echo_err "${DB_RED} ABSENT  ${NC}\n"
        echo_n_err "${MSG_IG}Would you like to install it: (y/n):${NC} "
        local install_qbt
        read -r install_qbt < /dev/tty || install_qbt="n"
        if [[ $install_qbt =~ ^[Yy]$ ]]; then
            echo_err "${MSG_IG}Installing ${LBLUE}qBitTorrent${NC} ${GREEN}software via DietPi...${NC}"
            if ! /boot/dietpi/dietpi-software install 46; then
                echo_err "\n${MSG_WR}DietPi qBittorrent installation command failed. No updater changes have been made to the binary.${NC}"
                exit 1
            fi
            if ! [[ -x "$BIN_PATH" ]] || ! systemctl cat "$QBT_SERVICE" >/dev/null 2>&1; then
                echo_err "\n${MSG_WR}Installation returned, but the expected executable or service unit is missing.${NC}"
                exit 1
            fi
        else echo_err "\n${MSG_WY}OK. Script will now abort.${NC}\n"; exit 1; fi
    else
        echo_err "${DB_RED} INCONSISTENT ${NC}\n"
        echo_err "${MSG_WR}Only one expected component (binary or systemd unit) exists. Repair the DietPi installation before updating.${NC}"
        exit 1
    fi
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

    echo_err "          ${YELLOW}---------------------------------------"
    echo_err "          ${MSG_IG}Installed Version: ${LYELLOW}${current_ver}${NC}"
    echo_err "          ${MSG_IG}Latest Available:  ${LGREEN}${latest_ver}${NC}"
    
    if [[ "$current_ver" == "$latest_ver" ]]; then
        echo_err "          ${MSG_IG}Status: qBittorrent version matches the latest release.${NC}"
        echo_err "          ${MSG_IG}The selected static build may still differ by libtorrent version.${NC}"
    elif [[ "$current_ver" == "UNKNOWN" ]]; then
        echo_err "          ${MSG_WY}Status: installed version unknown; cannot determine update state.${NC}"
    else
        echo_err "          ${MSG_IG}Status: installed and latest qBittorrent versions differ.${NC}"
    fi
    echo_err "          ${YELLOW}---------------------------------------"

    # Explain the replacement and its recovery implications before asking for consent.
    print_update_warning

    # Prompt to proceed
    while true; do
        echo_n_err "\n${MSG_WY}Do you understand the warning and want to continue (${GREEN}y${YELLOW}/${RED}n${YELLOW}): ${NC}"
        local continuerun
        read -r continuerun < /dev/tty || continuerun="n"
        if [[ $continuerun =~ ^[Yy]$ ]]; then
            break
        elif [[ $continuerun =~ ^[Nn]$ ]]; then
             echo_err "\n${MSG_WR}You've chosen not to proceed.${NC}    ${DB_RED} Aborting! ${NC}\n"
             exit 1
        fi
    done

    echo_err "\n${MSG_IG}Preparing update workflow...           ${NC}\n"
    local arch
    arch="$(get_architecture_interactive)"
    local lib_ver
    lib_ver="$(get_libtorrent_version)"
    local lib_ver_id
    if [[ "$lib_ver" == "2.0" ]]; then
        lib_ver_id="$(printf '%s' "$json_data" | jq -er '.libtorrent_2_0 | strings | select(length > 0)')" || { echo_err "${MSG_WR}Metadata is missing libtorrent_2_0. Aborting before stopping the service.${NC}"; exit 1; }
    else
        lib_ver_id="$(printf '%s' "$json_data" | jq -er '.libtorrent_1_2 | strings | select(length > 0)')" || { echo_err "${MSG_WR}Metadata is missing libtorrent_1_2. Aborting before stopping the service.${NC}"; exit 1; }
    fi
    if [[ ! "$lib_ver_id" =~ ^[0-9A-Za-z._+-]+$ ]]; then echo_err "${MSG_WR}Unexpected libtorrent version identifier: '$lib_ver_id'. Aborting.${NC}"; exit 1; fi
    local final_url="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${latest_ver}_v${lib_ver_id}/${arch}-qbittorrent-nox"
    perform_update "$final_url" "$latest_ver" "$arch"
}

main "$@"
