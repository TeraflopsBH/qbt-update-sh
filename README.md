# qBitTorrent Updater (`qbt-update-sh`)

## Intro
Linux BASH script which provides an option to automatically download and update qbittorrent-nox to the latest version available.
Currently, it is mainly intended for installing and updating already installed qBitTorrent-nox on `DietPi` linux.

This script replaces the apt package version of qBitTorrent-nox with a 3rd party executable, main reason being Debian apt package versions are not always up to date.


### The way it works
 
The `qbt-update-sh` project is a `bash` script which updates `qbittorrent-nox` installation on `DietPi` using a static `qbittorrent-nox` binary from [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static) GitHub repository.

As it requires `ROOT / SUDO` privilege to work as intended, if run as `non-root` user, it would prompt user if he wants script ro rerun with as root and do so if user agrees to. Otherwise script would abort.

Script would then try to detect the if system platform is `DietPi` by checking for existence of specific files.
If `DietPi` has been detected, script would proceed further. Otherwise, it would abort.

Script then checks if `DietPi` version of `qBitTorrent` has been already installed and offers to install if not, by executing the command: `dietpi-software install 46`.
If `DietPi` `qBitTorrent` installation was not detected and user refuses to allow script to install it, script would abort.
Otherwise, it would proceed with installing `qBitTorrent` as described above.

If `DietPi` `qBitTorrent` installation is present, it would be checked if it is running and stopped if so.

Updating procedure would start only if all three requirements were met:

1. System detected as `DietPi`
2. `DietPi` `qBitTorrent` version found or installed.
3. `qBitTorrent` service marked as inactive.

Script would then try to detect host system achitecture and offer user to accept detected architecture by typing `0` and pressing `Enter`, along with choice to manually chose system architecture by offering two most used architectures if he disagrees with one that was detected.

`This part will be expanded further to broaden the menu options to cover all architectures qbittorrent-nox-static supports`

Pressing `Enter` without entering any of options listed, or chosing option to `Abort` would abort the script.


### How to use

1. Download `qbtupd.sh`
2. CHMOD it to enable execution: `chmod u+x qbtupd.sh`
3. Execute it: `./qbtupd.sh`


### Notice

This `bash` script is in a `work-in-progress` state.
It was tested on `aarch64` and `x86_64` architectures using `DietPi` optimized `Debian Bullseye` distro and everything worked as intended.

I have a plan to improve end expand it further to autodetect if system running is non-dietpi (vanilla) linux installation and make it properly install `qbittorrent-nox` binaries, as per system architecture detected.
