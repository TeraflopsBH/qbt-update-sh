# qbt-update-sh

## Intro
Linux BASH script to automatically download and update qbittorrent-nox to the latest version available.
Currently, it is mainly intended for updating already installed qBitTorrent-nox on DietPi linux.
It is strongly suggested to install qbittorrent-nox using 'dietpi-software' script because it performs all config needed.

This script replaces the apt package version of qBitTorrent-nox with a 3rd party executable, because Debian apt package versions are not always up to date.


### The way it works
 
The `qbt-update-sh` project is a `bash` script that updates `qbittorrent-nox` installation on `DietPi` using a static `qbittorrent-nox` binary from [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static) GitHub repository.

Script tries to detect the system platform first, then tries to download and install matching binary file.
If detection fails, it allows user to manually choose system architecture and/or abort the execution of the script.

### How to use

1. If qbittorrent-nox is not installed on your system, istall it by executing the command: `dietpi-software install 46`
2. Upon finishing the installation, download `qbtupd.sh` bash script, `chmod u+x` it and, finally, execute it by typing `./qbtupd.sh` or `sudo ./qbtupd.sh` if executing it as `non-root` user.
3. Script will try to autodetect host system architecture. If detected architecture is one of supported architectures, it will state so and offer it as a first menu option, while offering three most used architectures too.
4. Enter menu item number as desired and press `ENTER` to proceed with updating the binary.


### Notice

This `bash` script is in a `work-in-progress` state.
It was tested on `aarch64` and `x86_64` architectures using `DietPi` optimized `Debian Bullseye` distro and everything worked as intended.

I have a plan to improve end expand it further to autodetect if system running is non-dietpi (vanilla) linux installation and make it properly install `qbittorrent-nox` binaries, as per system architecture detected.
