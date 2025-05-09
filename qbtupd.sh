#!/bin/bash

################################################################
###                                                          ###
#     DietPi qBitTorrent Updater script by Teraflops v.1.2     #
###                                                          ###
################################################################

# Feel free to use and/or modify this script, as per your needs.
# Author doesn't hold any accountability nor responsibility for
# any mishap and/or damage this script causes.

################################################################
## BASIC SCRIPT VARIABLES ######################################

## Text Formatting variables ########################## START ##
# 
# Standard Colors      # Light Colors          # Dark Colors
RED='\033[0;91m'       LRED='\033[1;31m'       DRED='\033[0;31m'
GREEN='\033[0;92m'     LGREEN='\033[1;32m'     DGREEN='\033[0;32m'
BLUE='\033[0;94m'      LBLUE='\033[1;34m'      DBLUE='\033[0;34m'

CYAN='\033[0;96m'      LCYAN='\033[1;36m'      DCYAN='\033[0;36m'
MAGENTA='\033[0;95m'   LMAGENTA='\033[1;35m'   DMAGENTA='\033[0;35m'
YELLOW='\033[0;93m'    LYELLOW='\033[1;33m'    DYELLOW='\033[0;33m'

WHITE='\033[1;37m'     LGRAY='\033[0;37m'      DGRAY='\033[0;90m'

# White text with background color (light and dark variants)
B_RED='\033[41;37m'     B_GREEN='\033[42;37m'      B_BLUE='\033[44;37m'
DB_RED='\033[41;1;37m'   DB_GREEN='\033[42;1;37m'   DB_BLUE='\033[44;1;37m'

B_CYAN='\033[46;37m'      B_MAGENTA='\033[45;37m'      B_YELLOW='\033[43;37m'
DB_CYAN='\033[46;1;37m'   DB_MAGENTA='\033[45;1;37m'   DB_YELLOW='\033[43;1;37m'

# No Color / Reset
NC='\033[0m'

# Text underlining & bolding
ULINE='\033[4m'
BOLD='\033[1m'

# Drawing helpers

MSG_WG=" ${B_RED} WARN ${NC} - ${LGREEN}"
MSG_WR=" ${B_RED} WARN ${NC} - ${LRED}"
MSG_WY=" ${B_RED} WARN ${NC} - ${LYELLOW}"

MSG_IG=" ${B_CYAN} INFO ${NC} - ${LGREEN}"
MSG_IR=" ${B_CYAN} INFO ${NC} - ${LRED}"
MSG_IY=" ${B_CYAN} INFO ${NC} - ${LYELLOW}"
#
## Text Formatting variables ############################ END ##

clear

## ASCII logo ######################################### START ##
#
cat << "EOF"

       ___  _ __ ______                      __      _  __
 ___ _/ _ )(_) //_  __/__  ___________ ___  / /_  NO| |/_/
/ _ `/ _  / / __// / / _ \/ __/ __/ -_) _ \/ __/   _>  <  
\_, /____/_/\__//_/__\___/_/ /_/  \__/_//_/\__/ _ /_/|_|_ 
 /_// / / /__  ___/ /__ _/ /____   / __/_______(_)__  / /_
   / /_/ / _ \/ _  / _ `/ __/ -_) _\ \/ __/ __/ / _ \/ __/
   \____/ .__/\_,_/\_,_/\__/\__/ /___/\__/_/ /_/ .__/\__/ 
       /_/                                    /_/Teraflops

EOF
#
## ASCII logo ########################################### END ##

## Intro ############################################## START ##
#
echo
echo -e " ${DB_RED}  INTRODUCTION                                          ${NC}"
echo -e " ${DB_RED} ${NC}                                                      ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${YELLOW}This script${NC} ${LMAGENTA}converts${NC} ${YELLOW}the${NC} ${LGREEN}DietPi${NC} ${YELLOW}version of the${NC}       ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${LBLUE}qBitTorrent-NOX${NC} ${YELLOW}service to the ${LRED}3rd party${NC} ${YELLOW}version,${NC}    ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${YELLOW}using the latest${NC} ${LBLUE}qbittorrent-nox-static${NC} ${YELLOW}binary from${NC}  ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${DGRAY}github.com/userdocs/qbittorrent-nox-static${NC} ${YELLOW}repo.${NC}     ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC}                                                      ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${YELLOW}If you choose to proceed, the script will try to${NC}     ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${YELLOW}detect the current ${LGREEN}DietPi${NC} installation and update${NC}    ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${YELLOW}it, as explained. If there is no ${LGREEN}DietPi${NC} ${LBLUE}qBitTorrent${NC}  ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${YELLOW}installation present, script would offer to install${NC}  ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC} ${YELLOW}it first, before proceeding with updating procedure.${NC} ${DB_RED} ${NC}"
echo -e " ${DB_RED} ${NC}                                                      ${DB_RED} ${NC}"
echo -e " ${DB_RED}                                                        ${NC}"
echo
echo
#
## Intro ################################################ END ##

## Prompt user to continue ############################ START ##
#
while true; do
    echo -ne "${MSG_WG}Do you want proceed with this script (y/n): ${NC}"
    read -r continuerun
    if [[ $continuerun == "y" || $continuerun == "Y" ]]; then
        break
    elif [[ $continuerun == "n" || $continuerun == "N" ]]; then
        echo -e "\n${MSG_WR}You've chosen not to proceed.${NC}    ${DB_RED} Aborting! ${NC}\n"
        sleep 1
        clear
        exit 1
    else
        echo -e "\n${MSG_WY}Invalid input!${NC} ${LGREEN}Please enter ${BOLD}${LYELLOW}'y/Y'${NC} ${LGREEN}or ${BOLD}${LRED}'n/N'${NC}\n"
    fi
done
#
## Prompt user to continue ############################## END ##

################################################################
## FUNCTIONS ###################################################

## Check Internet availability ######################## START ##
#
function check_internet() {
    local host="cloudflare.com"

    if ping -c 1 -W 3 "$host" > /dev/null 2>&1; then
        return 0  # online
    else
        return 1  # offline
    fi
}
#
## Check Internet availability ########################## END ##

## Detect host system architecture #################### START ##
#
function setsysarch() {
    sleep 1
    # Detect the system architecture
    detected_arch="$(uname -m)"

    # Check if the detected architecture is one of the supported architectures
    if [[ "$detected_arch" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
      echo -e "${MSG_IG}Detected system architecture: ${DB_MAGENTA} $detected_arch ${NC}"
      sleep 1
      echo -e "\n${MSG_IG}Type${NC} "${LCYAN}0${NC}" ${GREEN}then press${NC} ${DB_BLUE} ENTER ${NC} ${GREEN}to install the autodetected:  ${DB_MAGENTA} $detected_arch ${NC}"
      echo -e "\n${MSG_IG}version, or press${NC} ${DB_BLUE} ENTER ${NC} ${LYELLOW}${BOLD}${ULINE}without entering any number${NC} ${GREEN}to${NC} ${DB_RED} ABORT ${NC}"
    else
      echo -e "${MSG_WY}${LMAGENTA}$detected_arch detected. Currently, it is not supported."
      echo -e "${MSG_WG}You should choose option${NC} "${LCYAN}3${NC}" ${LRED} or just press ${LCYAN}ENTER${NC} ${LRED}to abort...${NC}"
    fi

    # Menu to select the system architecture
    while true; do
      echo

    # Add detected architecture as a menu option only if it is one of the supported architectures
      if [[ "$detected_arch" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
        echo -e "   0. ${LMAGENTA}${detected_arch}${NC} ${LGREEN}(${LCYAN}supported${NC}${LGREEN})${NC}"
      else
        echo -e "${LGREEN}...or select your system architecture manually:${NC}\n"
      fi

    # Rest of menu items (for manual selection)
      echo -e "   1. ${LBLUE}aarch64${NC}"
      echo -e "   2. ${LYELLOW}x86_64${NC}"
      echo -e "   3. ${LRED}Abort${NC}"
      echo
      echo -ne " ${LGREEN}Choice: ${NC}"
      read -r selection
      selection=${selection:-3}
      echo -e "\n${MSG_IG}You've chosen option:${NC} ${LMAGENTA}$selection${NC}"
      echo
  
      case $selection in
        0)
          arch="$detected_arch"
          echo -e "${MSG_IG}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
          echo
          break
          ;;
        1)
          arch="aarch64"
          echo -e "${MSG_IG}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
          echo
          break
          ;;
        2)
          arch="x86_64"
          echo -e "${MSG_IG}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
          echo
          break
          ;;
        3)
          echo -e "${MSG_WR}Aborting${NC} the script${NC}\n"
          exit 1
          ;;
        *)
          echo -e "${MSG_WY}Invalid selection${NC}\n          Please choose one of menu options\n${NC}"
          ;;
      esac
    done
                
}
#
## Detect host system architecture ###################### END ##

## qBitTorrent stopper ################################ START ##
#
function qbtstopper() {
    sleep 1
    while systemctl is-active qbittorrent.service >/dev/null 2>&1; do
        systemctl stop qbittorrent.service >/dev/null 2>&1
        sleep 3
        if systemctl is-active qbittorrent.service >/dev/null 2>&1; then
            echo -e "${DB_GREEN} FAILED   ${NC}\n"
            echo -ne "\n${MSG_WY}Do you want to try again? (y/n):${NC} "
            read -r choice
            case "$choice" in
                y|Y ) continue;;
                n|N ) echo -e "\n${MSG_WR}Exiting script...${NC}"; exit 0;;
                * ) echo -e "\n${MSG_WR}Invalid choice. Please enter${NC} ${LCYAN}Y/y or ${LRED}N/n.${NC}"; true;;
            esac
        else
            echo -e "${DB_GREEN}  DONE   ${NC}\n"
            qbtactive=false
        fi
        sleep 1
    done
}
#
## qBitTorrent stopper ################################## END ##

## Query the latest version info & links ############## START ##
#
function fetchqbtlinks() {
    
    # Fetch JSON and extract values
    eval "$(
        curl -sL https://github.com/userdocs/qbittorrent-nox-static/releases/latest/download/dependency-version.json \
        | grep -E '"(qbittorrent|libtorrent_1_2|libtorrent_2_0)"' \
        | sed -n \
            -e 's/.*"qbittorrent": *"\([^"]*\)".*/latestver_qbt="\1"/p' \
            -e 's/.*"libtorrent_1_2": *"\([^"]*\)".*/latestver_libt_1_2="\1"/p' \
            -e 's/.*"libtorrent_2_0": *"\([^"]*\)".*/latestver_libt_2_0="\1"/p'
    )"

    # Construct download links
    latestdlink_libt_1_2="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${latestver_qbt}_v${latestver_libt_1_2}/${arch}-qbittorrent-nox"
    latestdlink_libt_2_0="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${latestver_qbt}_v${latestver_libt_2_0}/${arch}-qbittorrent-nox"
}
#
## Query the latest version info & links ################ END ##

## Prompt user for libtorrent version choice ########## START ##
#
function libtorchoice() {
    while true; do
        echo -e "\n${MSG_IG}Please choose the desired libtorrent${NC}"
        echo -e "${GREEN}          version to be installed"
        echo -e "${GREEN}          (if not sure, choose libtorrent 2.0):${NC}\n"
        echo -e "   1. ${LMAGENTA}libtorrent 2.0${NC} ${GREEN}(default)${NC}"
        echo
        echo -e "   2. ${LBLUE}libtorrent 2.0${NC}"
        echo
        echo -ne "\n${GREEN}Enter choice ${LYELLOW}${BOLD}${ULINE}[1]${NC}${GREEN} or ${LYELLOW}${BOLD}${ULINE}[2]${NC}: "
        read -r choice

        case "$choice" in
            1)
                userlibtor="2.0"
                break
                ;;
            2)
                userlibtor="1.2"
                break
                ;;
            *)
                echo -e "\n${MSG_WY}Invalid choice. Please enter ${LGREEN}${BOLD}${ULINE}[1]${NC}${YELLOW} or ${LGREEN}${BOLD}${ULINE}[2]${NC}\n"
                ;;
        esac
        echo -e "${MSG_IG}Chosen libtorrent version: ${LYELLOW} $userlibtor$ {NC}\n"
    done
}
#
## Prompt user for libtorrent version choice ############ END ##

## qBitTorrent Update function ######################## START ##
#
function qbtupdater() {
    sleep 1

    # Making temporary download directory
    echo -ne "${MSG_IG}Making temp download directory...     ${NC}";
    tmp_dir=$(mktemp -d)
    echo -e "${DB_GREEN}  DONE   ${NC}\n"
    sleep 1

    # Backing up existing qbittorrent-nox file
    if [ -e "/usr/bin/qbittorrent-nox" ]; then
        echo -e "\n${MSG_IG}Making backup of the existing${NC}";
        echo -ne "          ${LBLUE}qbittorrent-nox${NC} ${GREEN}executable...         ${NC}"
        cp /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox.bak || { echo -e "${DB_RED} FAILED  ${NC}\n"; exit 1; }
    fi
    echo -e "${DB_GREEN}  DONE   ${NC}"
    sleep 1

    # Downloading the latest qbittorrent-nox-static file to temporary directory
    echo -e "\n${MSG_IG}Downloading the latest${NC}"
    echo -e "          ${LBLUE}qbittorrent-nox-static${NC} ${GREEN}file\n"
    echo -e "          to the temporary directory...${NC}"

    for i in {1..3}; do
        [[ "$userlibtor" == "2.0" ]] && /usr/bin/curl -# -L "$latestdlink_libt_2_0" -o "$tmp_dir/qbittorrent-nox" \
            -w "\n\nDownloaded file: %{filename_effective}\nDownloaded: %{size_download} bytes\nAverage download speed: %{speed_download} bytes/s\nTotal time: %{time_total}s\n\n" \
            && { echo -e "\n${GREEN}............................................... ${DB_GREEN}  DONE   ${NC}"; break; }

        [[ "$userlibtor" == "1.2" ]] && /usr/bin/curl -# -L "$latestdlink_libt_1_2" -o "$tmp_dir/qbittorrent-nox" \
            -w "\n\nDownloaded file: %{filename_effective}\nDownloaded: %{size_download} bytes\nAverage download speed: %{speed_download} bytes/s\nTotal time: %{time_total}s\n\n" \
            && { echo -e "\n${GREEN}............................................... ${DB_GREEN}  DONE   ${NC}"; break; }

        echo -e "\n${MSG_WR}Download attempt $i failed.${NC}\n"
        sleep 1
    done

    [[ ! -s "$tmp_dir/qbittorrent-nox" ]] && { echo -e "\n${MSG_WR}All 3 download attempts failed. Aborting.${NC}"; rm -rf "$tmp_dir"; exit 1; }


    # Moving downloaded file to /usr/bin/ location and replacing the previous one
    echo -e "\n${MSG_IG}Overwriting existing ${LYELLOW}DietPi${NC} ${GREEN}version at${NC}";
    echo -ne "          ${LYELLOW}/usr/bin/ ${GREEN}with the downloaded one...  ";
    /bin/mv "$tmp_dir/qbittorrent-nox" /usr/bin/qbittorrent-nox || { echo -e "\n${MSG_WR}Failed to move qbittorrent-nox file${NC}"; rm -rf "$tmp_dir"; exit 1; }
    echo -e "${DB_GREEN}  DONE   ${NC}"
    sleep 1

    #Setting qbittorrent-nox chmod to 755
    echo -ne "\n${MSG_IG}Chmod ${LBLUE}qbittorrent-nox${NC} ${GREEN} to ${LYELLOW}755${GREEN}...      ${NC}";
    /bin/chmod 755 /usr/bin/qbittorrent-nox || { echo -e "${DB_RED} FAILED  ${NC}\n"; rm -rf "$tmp_dir"; exit 1; }
    echo -e "${DB_GREEN}  DONE   ${NC}"
    sleep 1

    #Starting qbittorrent-nox service
    echo -ne "\n${MSG_IG}Starting${NC} ${LBLUE}qbittorrent-nox${NC} ${GREEN}service...   ${NC}";
    /usr/sbin/service qbittorrent start || { echo -e "${DB_RED} FAILED  ${NC}\n"Q; rm -rf "$tmp_dir"; exit 1; }
    echo -e "${DB_GREEN}  DONE   ${NC}"
    sleep 1

    #Cleaning up temporary download directory
    echo -ne "\n${MSG_IG}Cleaning up temp download directory...${NC}";
    rm -rf "$tmp_dir"
    sleep 1
    echo -e "${DB_GREEN}  DONE   ${NC}"
    sleep 1
}
#
## qBitTorrent Update function ########################## END ##

################################################################
## MAIN CODE ###################################################

clear

## ASCII logo ######################################### START ##
#
cat << "EOF"

       ___  _ __ ______                      __      _  __
 ___ _/ _ )(_) //_  __/__  ___________ ___  / /_  NO| |/_/
/ _ `/ _  / / __// / / _ \/ __/ __/ -_) _ \/ __/   _>  <  
\_, /____/_/\__//_/__\___/_/ /_/  \__/_//_/\__/ _ /_/|_|_ 
 /_// / / /__  ___/ /__ _/ /____   / __/_______(_)__  / /_
   / /_/ / _ \/ _  / _ `/ __/ -_) _\ \/ __/ __/ / _ \/ __/
   \____/ .__/\_,_/\_,_/\__/\__/ /___/\__/_/ /_/ .__/\__/ 
       /_/                                    /_/Teraflops

EOF
#
## ASCII logo ########################################### END ##

echo
echo -ne " \n\n${MSG_IG}Executing some preflight checks...${NC} "
sleep 1

## Check for ROOT/SUDO privilege ###################### START ##
#
echo
echo -ne "\n${MSG_IG}Checking for ${NC}${LBLUE}SUDO${GREEN}...                  "
sleep 1

if [[ $EUID -ne 0 ]]; then
    echo -e "${DB_RED} ABSENT  ${NC}"
    echo -e "\n${MSG_WY}This script must be run ${ULINE}with ROOT privileges${NC}\n"
    sleep 1
    # prompt user to run with sudo
    echo -ne "${MSG_WY}Do you want to run this script with SUDO? (y/n): ${NC}"
    read -r runwithsudo
    if [[ $runwithsudo == "y" || $runwithsudo == "Y" ]]; then
        cd "$PWD" && exec sudo -E bash "$0" "$@"
    else
        echo -e "${MSG_WR}Cannot run without elevated privileges.${NC} ${DB_RED} Aborting! ${NC}"
        sleep 1
        exit 1  # exit the script with an error status
    fi
fi

echo -e "${DB_GREEN} PRESENT ${NC}"
sleep 1
#
## Check for ROOT/SUDO privilege ######################## END ##

## Check if internet is available ##################### START ##
#
echo -ne "\n${MSG_IG}Detecting internet connection...      ${NC}"
if check_internet; then
    echo -e "${DB_GREEN} PRESENT ${NC}"
    inet_present=true
    echo
else
    echo -e "${DB_RED} ABSENT  ${NC}"
    echo -e "\n${MSG_WR}Cannot run without elevated privileges.${NC} ${DB_RED} Aborting! ${NC}"
    inet_present=false
    echo
    exit 1
fi
#
## Check if internet is available ####################### END ##

## Check if host system is DietPi ##################### START ##
#
echo -ne "${MSG_IG}Detecting ${LYELLOW}DietPi${NC} ${GREEN}installation...      ${NC}"
if [ -f /boot/dietpi/dietpi-services ]; then
    sysdietpi=true
    echo -e "${DB_GREEN} PRESENT ${NC}"
    sleep 1
else
    sysdietpi=false
    echo -e "${DB_RED} ABSENT  ${NC}\n\n       ${LYELLOW}This script is intended for DietPi system.${NC}\n       ${LRED}Script will now abort.${NC}\n"
    sleep 1
    exit 1
fi
#
## Check if host system is DietPi ####################### END ##

## Check if qBT service has been already installed #### START ##
#
echo -ne "\n${MSG_IG}Detecting qBitTorrent installation... ${NC}"

if systemctl show qbittorrent.service | grep -q 'LoadState=loaded'; then
    qbtloaded=true
    echo -e "${DB_GREEN} PRESENT ${NC}"
    sleep 1
    if systemctl show qbittorrent.service | grep -q 'ActiveState=active'; then
        qbtactive=true
        echo -e "\n${MSG_IG}${LBLUE}qBitTorrent${NC} ${GREEN}service is${NC} ${LGREEN}active.${NC}\n"
        sleep 1
    else
        qbtactive=false
        echo -e "\n${MSG_IG}${LBLUE}qBitTorrent${NC} ${GREEN}service is${NC} ${LRED}inactive.${NC}\n"
        sleep 1
    fi
else
    qbtloaded=false
    echo -e "${DB_RED} ABSENT  ${NC}\n"
    echo -ne "${MSG_IG}Would you like to install it: (y/n):${NC} "
    read -r install_qbt
    if [[ $install_qbt == "y" || $install_qbt == "Y" ]]; then
        echo -ne "${MSG_IG}Installing ${LBLUE}qBitTorrent${NC} ${GREEN}software\n          using dietpi-software utility...      ${NC}\n"
        sleep 1
        /boot/dietpi/dietpi-software install 46
        sleep 8
        if systemctl show qbittorrent.service | grep -q 'LoadState=loaded'; then
            qbtloaded=true
            echo -e "\n${GREEN}............................................... ${DB_GREEN}  DONE   ${NC}"
            if systemctl show qbittorrent.service | grep -q 'ActiveState=inactive'; then
                qbtactive=false
                echo -e "\n${GREEN}...............................................${DB_RED} FAILED  ${NC}"
                echo -e "\n${MSG_WY}${LBLUE}qBitTorrent${NC} ${LRED}installation was not successful.\n           The service is inactive. Script will now abort.${NC}\n"
                exit 1
            else
                qbtactive=true
                echo -e "\n${MSG_IG}${LBLUE}qBitTorrent${NC} ${GREEN}installation finished.\n          Proceeding further...${NC}\n"
            fi
            sleep 1
        else
            qbtloaded=false
            qbtactive=false
            echo -e "${DB_RED} FAILED  ${NC}"
            echo -e "\n${MSG_WY}${LBLUE}qBitTorrent${NC} ${LRED}installation was not successful.\n          The service is not loaded. Script will now abort.${NC}\n"
            sleep 1
            exit 1
        fi
    else
        echo -e "\n${MSG_WY}OK, then. Script will now abort.${NC}\n"
        sleep 1
        exit 1
    fi
fi
#
## Check if qBT service has been already installed ###### END ##

## Check if qBt service is up and running ############# START ##
#
echo -e "\n\n${MSG_IG}Preflight checks before update...     ${NC}\n"
sleep 1
if [ "$qbtloaded" = true ]; then
    echo -ne "${MSG_IG}${LBLUE}qBitTorrent${NC} ${GREEN}installed...              ${NC}"
    echo -e "${DB_GREEN}   YES   ${NC}\n"
else
    echo -e "${DB_RED}   NO    ${NC}\n"
fi
sleep 1

if [ "$qbtactive" = true ]; then
    echo -ne "${MSG_IG}${LBLUE}qBitTorrent${NC} ${GREEN}service active...         ${NC}"
    echo -e "${DB_GREEN}   YES   ${NC}\n"
    echo -ne "${MSG_IG}It will be stopped now...             ${NC}"
    qbtstopper
else
    echo -e "${MSG_IG}${LBLUE}qBitTorrent${NC} ${GREEN}service inactive...       ${NC}\n"
fi
sleep 1
#
## Check if qBt service is up and running ############### END ##

## Update preflight checks ############################ START ##
#
if [ "$sysdietpi" = true ] && [ "$inet_present" = true ] && [ "$qbtloaded" = true ] && [ "$qbtactive" = false ]; then
    echo -e "${MSG_IG}Great! All requirements have been met.\n          Proceeding with update...${NC}\n"
    sleep 1
    setsysarch

    fetchqbtlinks
    libtorchoice
    qbtupdater
    sleep 1
    echo -e "\n${MSG_IG}Update successful${NC}\n\n";
else
    echo -e "\n${MSG_WR}Ouch! ${LYELLOW}Reqirements have not been met to proceed.${NC}\n"
    echo -e "${MSG_WR}Script will now abort.${NC}\n\n"
    exit 0
fi
sleep 1
exit 0
#
## Update preflight checks ############################## END ##
