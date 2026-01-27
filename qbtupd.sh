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
readonly RED='\033[0;91m'       readonly LRED='\033[1;31m'       readonly DRED='\033[0;31m'
readonly GREEN='\033[0;92m'     readonly LGREEN='\033[1;32m'     readonly DGREEN='\033[0;32m'
readonly BLUE='\033[0;94m'      readonly LBLUE='\033[1;34m'      readonly DBLUE='\033[0;34m'
readonly CYAN='\033[0;96m'      readonly LCYAN='\033[1;36m'      readonly DCYAN='\033[0;36m'
readonly MAGENTA='\033[0;95m'   readonly LMAGENTA='\033[1;35m'   readonly DMAGENTA='\033[0;35m'
readonly YELLOW='\033[0;93m'    readonly LYELLOW='\033[1;33m'    readonly DYELLOW='\033[0;33m'
readonly WHITE='\033[1;37m'     readonly LGRAY='\033[0;37m'      readonly DGRAY='\033[0;90m'

# Background Colors
readonly B_RED='\033[41;37m'    readonly DB_RED='\033[41;1;37m'
readonly B_GREEN='\033[42;37m'  readonly DB_GREEN='\033[42;1;37m'
readonly B_BLUE='\033[44;37m'   readonly DB_BLUE='\033[44;1;37m'
readonly B_CYAN='\033[46;37m'   readonly DB_CYAN='\033[46;1;37m'
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

cleanup() {
    if [[ -n "${TMP_DIR:-}" ]] && [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
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
    echo_n_err "\n        ${GREEN}- Detecting internet connection...                         ${NC}"
    if ! ping -c 1 -W 2 cloudflare.com > /dev/null 2>&1; then
        echo_err "${DB_RED} ABSENT  ${NC}"
        echo_err "\n${MSG_WR}Cannot run without internet connection.${NC}\n"
        exit 1
    fi
    echo_err "${DB_GREEN} PRESENT ${NC}"
}

print_logo() {
    clear >&2
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
    local detected
    detected="$(uname -m)"
    local selected_arch=""

    echo_err
    echo_err "${MSG_IG}Detected system architecture..............................${DB_MAGENTA} $detected ${NC}"
    
    if [[ "$detected" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
        echo_err "\n${MSG_IG}Type${NC} \"${LCYAN}0${NC}\" ${GREEN}then press${NC} ${DB_BLUE} ENTER ${NC} ${GREEN}to install the autodetected:  ${DB_MAGENTA} $detected ${NC}"
        echo_err "          ${GREEN}version... or press${NC} ${DB_BLUE} ENTER ${NC} ${LYELLOW}${BOLD}${ULINE}without entering any number${NC} ${GREEN}to${NC} ${LRED}<ABORT>${NC}"
    else
        echo_err "${MSG_WY}${LMAGENTA}$detected detected. Currently, it is not supported."
        echo_err "${MSG_WG}You should choose option${NC} \"${LCYAN}3${NC}\" ${LRED} or just press ${LCYAN}ENTER${NC} ${LRED}to abort...${NC}"
    fi

    while true; do
        echo_err
        echo_err "${YELLOW}          -----------------------${NC}"
        if [[ "$detected" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
            echo_err "           0. ${LMAGENTA}${detected}${NC} ${LGREEN}(${LCYAN}detected${NC}${LGREEN})${NC}"
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

        case $selection in
            0)
                if [[ "$detected" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
                    selected_arch="$detected"
                    break
                else
                    echo_err "${MSG_WY}Option 0 not available for unsupported architecture.${NC}"
                fi
                ;;
            1) selected_arch="aarch64"; break ;;
            2) selected_arch="x86_64"; break ;;
            3) echo_err "${MSG_WR}Aborting the script${NC}\n"; exit 1 ;;
            *) echo_err "${MSG_WY}Invalid selection${NC}\n";;
        esac
    done

    echo_err "\n${MSG_IG}Setting${NC} ${DB_MAGENTA}$selected_arch${NC} ${GREEN}as system architecture...${NC}\n"
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
    
    # Finding files matching qbittorrent-nox.*.bak in /usr/bin/, excluding the backup created ($current_backup)
    while IFS= read -r line; do
        if [[ "$line" != "$current_backup" ]]; then
            backups+=("$line")
        fi
    done < <(ls -1 ${BIN_PATH}.*.bak 2>/dev/null | sort -r)

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
    if ! json_content=$(curl -sL "$VERSION_JSON_URL"); then
        echo_err "${MSG_WR}Failed to fetch version info from GitHub.${NC}"
        exit 1
    fi
    echo "$json_content"
}

perform_update() {
    local url="$1"
    
    echo_n_err "${MSG_IG}Making temp download directory....................         ${NC}";
    TMP_DIR=$(mktemp -d)
    local download_path="$TMP_DIR/qbittorrent-nox"
    echo_err "${DB_GREEN}  DONE  ${NC}"

    # BACKUP LOGIC
    if [ -e "$BIN_PATH" ]; then
        local timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_file="${BIN_PATH}.${timestamp}.bak"
        
        echo_err "        - ${GREEN}Backing up the existing executable of${NC}"
        echo_n_err "          ${LBLUE}$(basename "$BIN_PATH")${NC} ${GREEN}to${NC} ${LYELLOW}$(basename "$backup_file")${NC}...  "
        
        if cp "$BIN_PATH" "$backup_file"; then
            echo_err "${DB_GREEN}  DONE  ${NC}"
            echo_err "          ${GREEN}Backup location: ${DGRAY}${backup_file}${NC}"
        else
            echo_err "${DB_RED} FAILED  ${NC}"
            echo_err "${MSG_WR}Cannot create backup. Update aborted for safety.${NC}"
            exit 1
        fi
        
        # Checking and managing previous backups (excluding the one just created)
        manage_backups "$backup_file"
    fi

    echo_err "\n${MSG_IG}Downloading the latest${NC} ${LBLUE}qbittorrent-nox-static${NC}"
    echo_err "          ${GREEN}file to the temporary directory...${NC}"
    echo_err "          "

    if curl -# -L "$url" -o "$download_path"; then
         echo_err "${GREEN} .................................................................... ${DB_GREEN}  DONE  ${NC}\n"
    else
         echo_err "\n${MSG_WR}Download failed.${NC}"
         exit 1
    fi

    echo_err "\n${MSG_IG}Overwriting existing ${LYELLOW}DietPi${NC} ${GREEN}version at${NC}";
    echo_n_err "          ${LYELLOW}/usr/bin/ ${GREEN}with the downloaded one...            ";
    mv "$download_path" "$BIN_PATH"
    echo_err "            ${DB_GREEN}  DONE  ${NC}"

    echo_n_err "\n${MSG_IG}Chmod ${LBLUE}qbittorrent-nox${NC}${GREEN} to ${LYELLOW}755${GREEN}........            ${NC}";
    chmod 755 "$BIN_PATH"
    echo_err "            ${DB_GREEN}  DONE  ${NC}"

    echo_n_err "\n${MSG_IG}Starting${NC} ${LBLUE}qbittorrent-nox${NC} ${GREEN}service....            ${NC}";
    systemctl start "$QBT_SERVICE"
    if systemctl is-active --quiet "$QBT_SERVICE"; then
         echo_err "            ${DB_GREEN}  DONE  ${NC}"
         echo_err "\n${MSG_IG}Update successful${NC}\n";
    else
         echo_err "${DB_RED} FAILED  ${NC}\n"
         exit 1
    fi
}

################################################################
# MAIN
################################################################

main() {
    print_logo
    
    echo_n_err "\n\n${MSG_IG}Executing some preflight checks...${NC} \n"
    sleep 1
    
    check_root
    check_internet

    # Check for DietPi
    echo_n_err "\n        ${GREEN}- Detecting ${LYELLOW}DietPi${NC} ${GREEN}installation...                         ${NC}"
    if [ -f "$DIETPI_SERVICES" ]; then
        echo_err "${DB_GREEN} PRESENT ${NC}"
    else
        echo_err "${DB_RED} ABSENT  ${NC}\n\n       ${LYELLOW}This script is intended for DietPi system.${NC}\n       ${LRED}Script will now abort.${NC}\n"
        exit 1
    fi

    # Check for qBitTorrent installation presence
    echo_n_err "\n        ${GREEN}- Detecting qBitTorrent installation...                    ${NC}"
    if [[ -x "$BIN_PATH" ]] || systemctl list-unit-files "$QBT_SERVICE" &>/dev/null; then
        echo_err "${DB_GREEN} PRESENT ${NC}"
    else
        echo_err "${DB_RED} ABSENT  ${NC}\n"
        echo_n_err "${MSG_IG}Would you like to install it: (y/n):${NC} "
        local install_qbt
        read -r install_qbt < /dev/tty || install_qbt="n"
        if [[ $install_qbt =~ ^[Yy]$ ]]; then
            echo_err "${MSG_IG}Installing ${LBLUE}qBitTorrent${NC} ${GREEN}software via DietPi...${NC}"
            /boot/dietpi/dietpi-software install 46
            if ! [[ -x "$BIN_PATH" ]]; then
                echo_err "\n${MSG_WR}Installation failed or binary is missing.${NC}"
                exit 1
            fi
        else
            echo_err "\n${MSG_WY}OK. Script will now abort.${NC}\n"
            exit 1
        fi
    fi

    # VERSION CHECKING LOGIC
    echo_err "\n\n${MSG_IG}Checking for available updates...      ${NC}"
    local json_data
    json_data=$(fetch_release_data)
    local latest_ver
    latest_ver=$(echo "$json_data" | grep -o '"qbittorrent": *"[^"]*"' | cut -d'"' -f4)

    local current_ver="UNKNOWN"
    if [[ -x "$BIN_PATH" ]]; then
        current_ver=$("$BIN_PATH" --version | awk '{print $2}' | sed 's/v//')
    fi

    echo_err "          ${YELLOW}---------------------------------------"
    echo_err "          ${MSG_IG}Installed Version: ${LYELLOW}${current_ver}${NC}"
    echo_err "          ${MSG_IG}Latest Available:  ${LGREEN}${latest_ver}${NC}"
    
    if [[ "$current_ver" == "$latest_ver" ]]; then
        echo_err "          ${MSG_IG}Status:        ${DB_GREEN} UP TO DATE ${NC}"
    else
        echo_err "          ${MSG_IG}Status: ${DB_YELLOW} UPDATE AVAILABLE ${NC}"
    fi
    echo_err "          ${YELLOW}---------------------------------------"

    # Prompt to proceed
    while true; do
        echo_n_err "\n${MSG_WY}Do you want proceed with this script (${GREEN}y${YELLOW}/${RED}n${YELLOW}): ${NC}"
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

    stop_service

    # Selection menus
    local arch
    arch=$(get_architecture_interactive)

    local lib_ver
    lib_ver=$(get_libtorrent_version)

    # Construction of specific download URL based on libtorrent version and architecture
    local lib_ver_id
    if [[ "$lib_ver" == "2.0" ]]; then
        lib_ver_id=$(echo "$json_data" | grep -o '"libtorrent_2_0": *"[^"]*"' | cut -d'"' -f4)
    else
        lib_ver_id=$(echo "$json_data" | grep -o '"libtorrent_1_2": *"[^"]*"' | cut -d'"' -f4)
    fi
    
    local final_url="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${latest_ver}_v${lib_ver_id}/${arch}-qbittorrent-nox"

    perform_update "$final_url"
}

main "$@"