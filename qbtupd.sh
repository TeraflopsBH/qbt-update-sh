#!/bin/bash

#DietPi qBitTorrent Updater script by Teraflops

# Color variables
# Standard Colors      # Light Colors          # Dark Colors
RED='\033[0;91m'       LRED='\033[1;31m'       DRED='\033[0;31m'
GREEN='\033[0;92m'     LGREEN='\033[1;32m'     DGREEN='\033[0;32m'
BLUE='\033[0;94m'      LBLUE='\033[1;34m'      DBLUE='\033[0;34m'

CYAN='\033[0;96m'      LCYAN='\033[1;36m'      DCYAN='\033[0;36m'
MAGENTA='\033[0;95m'   LMAGENTA='\033[1;35m'   DMAGENTA='\033[0;35m'
YELLOW='\033[0;93m'    LYELLOW='\033[1;33m'    DYELLOW='\033[0;33m'

WHITE='\033[1;37m'     LGRAY='\033[0;37m'      DGRAY='\033[0;90m'

# Colored background with white text (light and dark variants)
B_RED='\033[41m;37m'     B_GREEN='\033[42;37m'      B_BLUE='\033[44;37m'
DB_RED='\033[41;1;37m'   DB_GREEN='\033[42;1;37m'   DB_BLUE='\033[44;1;37m'

B_CYAN='\033[46;37m'      B_MAGENTA='\033[45;37m'      B_YELLOW='\033[43;37m'
DB_CYAN='\033[46;1;37m'   DB_MAGENTA='\033[45;1;37m'   DB_YELLOW='\033[43;1;37m'

#No Color
NC='\033[0m'

#  Text formatting variables
ULINE='\033[4m'
BOLD='\033[1m'

clear
echo
echo -e " ${YELLOW}Teraflops${NC} ${LCYAN}DietPi qBitTorrent-nox-static${NC} ${YELLOW}Update Script${NC}";
echo

# Detect the system architecture
detected_arch="$(uname -m)"

# Check if the detected architecture is one of the supported architectures
if [[ "$detected_arch" =~ ^(armhf|armv7|aarch64|x86_64)$ ]]; then
  echo -e " ${GREEN}Detected system architecture: ${DB_MAGENTA} $detected_arch ${NC}"
  echo -e "\n ${GREEN}Type${NC} "${LCYAN}0${NC}" ${GREEN}then press${NC} ${DB_BLUE} ENTER ${NC} ${GREEN}to install the autodetected:  ${DB_MAGENTA} $detected_arch ${NC}"
  echo -e " ${GREEN}version, or press${NC} ${DB_BLUE} ENTER ${NC} ${LYELLOW}${BOLD}${ULINE}without entering any number${NC} ${GREEN}to${NC} ${DB_RED} ABORT ${NC}"
else
  echo -e "${LMAGENTA}$detected_arch${NC} ${LRED}detected. Currently, it is not supported."
  echo -e "You should choose option${NC} "${LCYAN}3${NC}" ${LRED} or just press ${LCYAN}ENTER${NC} ${LRED}to abort...${NC}"
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
  echo -e "\n${GREEN}You've chosen option:${NC} ${LMAGENTA}$selection${NC}"
  echo
  
  case $selection in
    0)
      arch="$detected_arch"
      echo -e "${GREEN}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
      echo
      break
      ;;
    1)
      arch="aarch64"
      echo -e "${GREEN}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
      echo
      break
      ;;
    2)
      arch="x86_64"
      echo -e "${GREEN}Setting${NC} ${LMAGENTA}$arch${NC} ${GREEN}as system architecture...${NC}"
      echo
      break
      ;;
    3)
      echo -e "${LRED}Aborting${NC} ${RED}the update script${NC}\n"
      exit 1
      ;;
    *)
      echo -e "${LRED}Invalid selection${NC}\n${RED}Please choose one of menu options\n${NC}"
      ;;
  esac
done

# Variables:
# Set service name
service_to_kill="qbittorrent"

# Making temporary download directory
echo -e "\n${LGREEN}Setting temporary download directory${NC}";
tmp_dir=$(mktemp -d)

# Check if the qBitTorrent service is active/running
if systemctl is-active --quiet "$service_to_kill"; then
  # Service is running, so stop it
  echo -e "\n${LGREEN}Stopping${NC} ${LCYAN}$service_to_kill${NC} ${LGREEN}service...${NC}"
  sudo systemctl stop "$service_to_kill"
  if [ $? -ne 0 ]; then
    echo -e "\n${LRED}Failed to stop${NC} ${LCYAN}$service_to_kill${NC} ${LRED}service${NC}"
    exit 1
  fi
else
  # Service is not running, so skip stopping it
  echo -e "\n${LCYAN}$service_to_kill${NC} ${LGREEN}service is not running, proceeding further...${NC}"
fi

# Backing up existing qbittorrent-nox file
if [ -e "/usr/bin/qbittorrent-nox" ]; then
  echo -e "\n${LGREEN}Backing up existing qbittorrent-nox file...${NC}";
  cp /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox.bak || { echo -e "\n${LRED}Failed to backup qbittorrent-nox file${NC}"; exit 1; }
fi

# Downloading the latest qbittorrent-nox-static file to temporary directory
echo -e "\n${LGREEN}Downloading the latest qbittorrent-nox-static file to temporary directory...${NC}";
/usr/bin/curl -# -L "https://github.com/userdocs/qbittorrent-nox-static/releases/latest/download/$arch-qbittorrent-nox" -o "$tmp_dir/qbittorrent-nox" -w "\nDownloaded file: %{filename_effective}\nDownloaded: %{size_download} bytes\nAverage download speed: %{speed_download} bytes/s\nTotal time: %{time_total}s\n\n" || { echo -e "\n${LRED}Failed to download qbittorrent-nox file${NC}"; rm -rf "$tmp_dir"; exit 1; }

# Moving downloaded file to /usr/bin/ location and replacing the previous one
echo -e "\n${LGREEN}Moving downloaded file to /usr/bin/ location and replacing the previous one...${NC}";
/bin/mv "$tmp_dir/qbittorrent-nox" /usr/bin/qbittorrent-nox || { echo -e "\n${LRED}Failed to move qbittorrent-nox file${NC}"; rm -rf "$tmp_dir"; exit 1; }

# Setting qbittorrent-nox chmod to 755
echo -e "\n${LGREEN}Setting qbittorrent-nox chmod to 755...${NC}";
/bin/chmod 755 /usr/bin/qbittorrent-nox || { echo -e "\n${LRED}Failed to set qbittorrent-nox file permissions${NC}"; rm -rf "$tmp_dir"; exit 1; }

# Starting qbittorrent-nox service
echo -e "\n${LGREEN}Starting qbittorrent-nox service...${NC}";
/usr/sbin/service qbittorrent start || { echo -e "\n${LRED}Failed to start qbittorrent service${NC}"; rm -rf "$tmp_dir"; exit 1; }

# Cleaning up temporary download directory
echo -e "\n${LGREEN}Cleaning up temporary download directory${NC}";
rm -rf "$tmp_dir"

echo -e "\n${LGREEN}Done :)${NC}\n";
