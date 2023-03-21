#!/bin/bash

# DietPi qBitTorrent Updater script by Teraflops
# Feel free to use and/or modify this script, as per your requirements.
# Author doesn't hold any responsibility for any mishap and/or damage it causes.

# Text Formatting variables START #
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

#  Text underlining & bolding
ULINE='\033[4m'
BOLD='\033[1m'

#
# Text Formatting variables END #

clear

# ASCII Logo START #
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
# ASCII Logo END #

# Intro START #
#

echo
echo -e " ${DB_RED}  READ ME                                               ${NC}"
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

#
# Intro END #

# Prompt user to continue... START #
#

while true; do
    echo -ne " ${B_RED} WARN ${NC} - ${LGREEN}Do you want proceed with this script (y/n): ${NC}"
    read -r continuerun
    if [[ $continuerun == "y" || $continuerun == "Y" ]]; then
        break
    elif [[ $continuerun == "n" || $continuerun == "N" ]]; then
        echo -e "\n ${B_RED} WARN ${NC} - ${LRED}You've chosen not to proceed.${NC} ${DB_RED} Aborting! ${NC}\n"
        sleep 1
        exit 1
    else
        echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Invalid input!${NC} ${RED}Please enter ${BOLD}'y/Y'${NC} ${RED}or ${BOLD}'n/N'${NC}\n"
    fi
done

#
# Prompt user to continue... END #

# Functions Block START #
#

# Host system architecture detection/selection function
function setsysarch() {
    sleep 1
    # Detect the system architecture
    detected_arch="$(uname -m)"

    # Check if the detected architecture is one of the supported architectures
    if [[ "$detected_arch" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
      echo -e " ${B_CYAN} INFO ${NC} - ${GREEN}Detected system architecture: ${DB_MAGENTA} $detected_arch ${NC}"
      sleep 1
      echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Type${NC} "${LCYAN}0${NC}" ${GREEN}then press${NC} ${DB_BLUE} ENTER ${NC} ${GREEN}to install the autodetected:  ${DB_MAGENTA} $detected_arch ${NC}"
      echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}version, or press${NC} ${DB_BLUE} ENTER ${NC} ${LYELLOW}${BOLD}${ULINE}without entering any number${NC} ${GREEN}to${NC} ${DB_RED} ABORT ${NC}"
    else
      echo -e " ${B_RED} WARN ${NC} - ${LMAGENTA}$detected_arch${NC} ${LRED}detected. Currently, it is not supported."
      echo -e " ${B_RED} WARN ${NC} - ${GREEN}You should choose option${NC} "${LCYAN}3${NC}" ${LRED} or just press ${LCYAN}ENTER${NC} ${LRED}to abort...${NC}"
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
      echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}You've chosen option:${NC} ${LMAGENTA}$selection${NC}"
      echo
  
      case $selection in
        0)
          arch="$detected_arch"
          echo -e " ${B_CYAN} INFO ${NC} - ${GREEN}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
          echo
          break
          ;;
        1)
          arch="aarch64"
          echo -e " ${B_CYAN} INFO ${NC} - ${GREEN}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
          echo
          break
          ;;
        2)
          arch="x86_64"
          echo -e " ${B_CYAN} INFO ${NC} - ${GREEN}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
          echo
          break
          ;;
        3)
          echo -e " ${B_RED} WARN ${NC} - ${LRED}Aborting${NC} ${RED}the update script${NC}\n"
          exit 1
          ;;
        *)
          echo -e " ${B_RED} WARN ${NC} - ${LRED}Invalid selection${NC}\n          ${RED}Please choose one of menu options\n${NC}"
          ;;
      esac
    done
                
}

# qBt stopper function
#
function qbtstopper() {
    sleep 1
    while systemctl is-active qbittorrent.service >/dev/null 2>&1; do
        systemctl stop qbittorrent.service >/dev/null 2>&1
        sleep 3
        if systemctl is-active qbittorrent.service >/dev/null 2>&1; then
            echo -ne "\n ${B_RED} WARN ${NC} - ${LRED}Couldn't stop qbittorrent service. Do you want to try again? (y/n):${NC} "
            read -r choice
            case "$choice" in
                y|Y ) continue;;
                n|N ) echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Exiting script...${NC}"; exit 0;;
                * ) echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Invalid choice. Please enter${NC} ${LCYAN}Y/y or ${LRED}N/n.${NC}"; true;;
            esac
        else
            echo -e " ${B_CYAN} INFO ${NC} - ${LBLUE}qBitTorrent${NC} ${GREEN}service stopped successfully.${NC}\n"
            qbtactive=false
        fi
        sleep 1
    done
}

# Update function
#
function qbtupdater() {
    sleep 1

    # Making temporary download directory
    echo -e " ${B_CYAN} INFO ${NC} - ${GREEN}Setting temporary download directory${NC}";
    tmp_dir=$(mktemp -d)
    sleep 1

    # Backing up existing qbittorrent-nox file
    if [ -e "/usr/bin/qbittorrent-nox" ]; then
        echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Backing up existing${NC} ${LBLUE}qbittorrent-nox${NC} ${GREEN}file...${NC}";
        cp /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox.bak || { echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Failed to backup qbittorrent-nox file${NC}"; exit 1; }
    fi
    sleep 1

    # Downloading the latest qbittorrent-nox-static file to temporary directory
    echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Downloading the latest${NC} ${LBLUE}qbittorrent-nox-static${NC} ${GREEN}file to temporary directory...${NC}";
    /usr/bin/curl -# -L "https://github.com/userdocs/qbittorrent-nox-static/releases/latest/download/$arch-qbittorrent-nox" -o "$tmp_dir/qbittorrent-nox" -w "\nDownloaded file: %{filename_effective}\nDownloaded: %{size_download} bytes\nAverage download speed: %{speed_download} bytes/s\nTotal time: %{time_total}s\n\n" || { echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Failed to download qbittorrent-nox file${NC}"; rm -rf "$tmp_dir"; exit 1; }
    sleep 1

    # Moving downloaded file to /usr/bin/ location and replacing the previous one
    echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Moving downloaded file${NC} ${GREEN}to${NC} ${LYELLOW}/usr/bin/${NC} ${GREEN}location and replacing the previous one...${NC}";
    /bin/mv "$tmp_dir/qbittorrent-nox" /usr/bin/qbittorrent-nox || { echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Failed to move qbittorrent-nox file${NC}"; rm -rf "$tmp_dir"; exit 1; }
    sleep 1

    #Setting qbittorrent-nox chmod to 755
    echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Setting${NC} ${LBLUE}qbittorrent-nox${NC} ${GREEN}CHMOD to 755...${NC}";
    /bin/chmod 755 /usr/bin/qbittorrent-nox || { echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Failed to set qbittorrent-nox file permissions${NC}"; rm -rf "$tmp_dir"; exit 1; }
    sleep 1

    #Starting qbittorrent-nox service
    echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Starting${NC} ${LBLUE}qbittorrent-nox${NC} ${GREEN}service...${NC}";
    /usr/sbin/service qbittorrent start || { echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Failed to start qbittorrent service${NC}"; rm -rf "$tmp_dir"; exit 1; }
    sleep 1

    #Cleaning up temporary download directory
    echo -ne "\n ${B_CYAN} INFO ${NC} - ${GREEN}Cleaning up temporary download directory...${NC}";
    rm -rf "$tmp_dir"
    sleep 1
    echo -e " ${B_CYAN} DONE ${NC}"
    sleep 1
}

#
# Functions Block END #

# Reserved space for further update START #
#

echo -ne " \n\n${GREEN}Initializing the script...${NC} "
sleep 1
echo -e " ${B_CYAN} DONE ${NC}"
sleep 2

#
# Reserved space for further update END #

# Check for ROOT/SUDO privilege START #
#

echo
echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Checking for ${NC}${LBLUE}SUDO${NC}\n"
sleep 1

if [[ $EUID -ne 0 ]]; then
   echo -e " ${B_RED} WARN ${NC} - ${LYELLOW}This script must be run ${ULINE}with ROOT privileges${NC}\n"
   sleep 1
   # prompt user to run with sudo
   echo -ne " ${B_RED} WARN ${NC} - ${LGREEN}Do you want to run this script with SUDO? (y/n): ${NC}"
   read -r runwithsudo
   if [[ $runwithsudo == "y" || $runwithsudo == "Y" ]]; then
       cd "$PWD" && exec sudo -E bash "$0" "$@"
   else
       echo -e " ${B_RED} WARN ${NC} - ${LRED}Cannot run without elevated privileges.${NC} ${DB_RED} Aborting! ${NC}"
       sleep 1
       exit 1  # exit the script with an error status
   fi
fi

echo -e " ${B_CYAN} INFO ${NC} - ${LBLUE}SUDO${NC} ${GREEN}is in da house. Proceeding...\n${NC}"
sleep 1


#
# Check for ROOT/SUDO privilege END #


# Check if host system is DietPi START #
#

if [ -f /boot/dietpi/dietpi-services ]; then
    sysdietpi=true
    echo -e " ${B_CYAN} INFO ${NC} - ${LYELLOW}DietPi${NC} ${GREEN}system detected.${NC}\n"
    sleep 1
else
    sysdietpi=false
    echo -e " ${B_RED} WARN ${NC} - ${LYELLOW}DietPi${NC} ${LRED}system not detected.${NC}\n       ${LRED}This script is intended for DietPi system.${NC}\n       ${LRED}Script will now abort.${NC}\n"
    sleep 1
    exit 1
fi

#
# Check if host system is DietPi END #

# Check if qBitTorrent service has been already installed START #
#

if systemctl show qbittorrent.service | grep -q 'LoadState=loaded'; then
    qbtloaded=true
    echo -e " ${B_CYAN} INFO ${NC} - ${LBLUE}qBitTorrent${NC} ${GREEN}installation detected.${NC}\n"
    sleep 1
    if systemctl show qbittorrent.service | grep -q 'ActiveState=active'; then
        qbtactive=true
        echo -e " ${B_CYAN} INFO ${NC} - ${LBLUE}qBitTorrent${NC} ${GREEN}service is${NC} ${LGREEN}active.${NC}\n"
        sleep 1
    else
        qbtactive=false
        echo -e " ${B_CYAN} INFO ${NC} - ${LBLUE}qBitTorrent${NC} ${GREEN}service is${NC} ${LRED}inactive.${NC}\n"
        sleep 1
    fi
else
    qbtloaded=false
    echo -e " ${B_CYAN} INFO ${NC} - ${GREEN}qBitTorrent installation not detected.${NC}\n"
    echo -ne " ${B_CYAN} INFO ${NC} - ${GREEN}Would you like to install it: (y/n):${NC} "
    read -r install_qbt
    if [[ $install_qbt == "y" || $install_qbt == "Y" ]]; then
        echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Installing ${LBLUE}qBitTorrent${NC} ${GREEN}using dietpi-software...${NC}\n"
        sleep 1
        /boot/dietpi/dietpi-software install 46
        sleep 8
        if systemctl show qbittorrent.service | grep -q 'LoadState=loaded'; then
            qbtloaded=true
            if systemctl show qbittorrent.service | grep -q 'ActiveState=inactive'; then
                qbtactive=false
                echo -e "\n ${B_RED} WARN ${NC} - ${LBLUE}qBitTorrent${NC} ${LRED}installation was not successful. The service is inactive. Script will now abort.${NC}\n"
                exit 1
            else
                qbtactive=true
                echo -e "\n ${B_CYAN} INFO ${NC} - ${LBLUE}qBitTorrent${NC} ${GREEN}installation finished.\n          Proceeding further...${NC}\n"
            fi
            sleep 1
        else
            qbtloaded=false
            qbtactive=false
            echo -e "\n ${B_RED} WARN ${NC} - ${LBLUE}qBitTorrent${NC} ${LRED}installation was not successful. The service is not loaded. Script will now abort.${NC}\n"
            sleep 1
            exit 1
        fi
    else
        echo -e "\n ${B_RED} WARN ${NC} - ${LRED}OK, then. Script will now abort.${NC}"
        sleep 1
        exit 1
    fi
fi

#
# Check if qBitTorrent service has been already installed END #

# Check if qbittorrent is up and running START #
#

echo -e " ${B_CYAN} INFO ${NC} - ${GREEN}Checking if all requirements for update have been met...${NC}\n"
sleep 1
if [ "$qbtloaded" = true ]; then
    echo -e " ${B_CYAN} INFO ${NC} - ${LBLUE}qBitTorrent${NC} ${GREEN}installed.${NC}\n"
else
    echo -e " ${B_RED} WARN ${NC} - ${LBLUE}qBitTorrent${NC} ${LRED}not installed!${NC}\n"
fi
sleep 1

if [ "$qbtactive" = true ]; then
    echo -e " ${B_CYAN} INFO ${NC} - ${LBLUE}qBitTorrent${NC} ${GREEN}service up and running.${NC}\n"
    echo -e " ${B_CYAN} INFO ${NC} - ${GREEN}It will be stopped now.${NC}\n"
    qbtstopper
else
    echo -e " ${B_CYAN} INFO ${NC} - ${LBLUE}qBitTorrent${NC} ${GREEN}service inactive.${NC}\n"
fi
sleep 1

#
# Check if qbittorrent is up and running END #

# Final check if all required parameters have been met START #
#

if [ "$sysdietpi" = true ] && [ "$qbtloaded" = true ] && [ "$qbtactive" = false ]; then
    echo -e " ${B_CYAN} INFO ${NC} - ${LGREEN}Great!${NC} ${GREEN}All requirements have been met.\n          Proceeding with update...${NC}\n"
    sleep 1
    setsysarch
    qbtupdater
    sleep 1
    echo -e "\n ${B_CYAN} INFO ${NC} - ${GREEN}Update successful${NC}";
else
    echo -e "\n ${B_RED} WARN ${NC} - ${LRED}Ouch! Reqirements have not been met to proceed.${NC}\n"
    echo -e " ${B_RED} WARN ${NC} - ${LRED}Script will now abort.${NC}\n"
    exit 0
fi
sleep 1
exit 0

#
# Final check if all required parameters have been met END #
