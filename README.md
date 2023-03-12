# qbt-update-sh

### Intro
Linux BASH script to automatically download and update qbittorrent-nox to the latest version available.
Currently, it is mainly intended for updating already installed qBitTorrent-nox on DietPi linux.
It is strongly suggested to install qbittorrent-nox using 'dietpi-software' script because it performs all config needed.



### The way it works
Script tries to detect the platform then download and install matching binary file.
If detection fails, it allows user to manually choose system architecture and/or abort the script.
