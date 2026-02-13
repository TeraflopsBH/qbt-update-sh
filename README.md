# qBitTorrent Updater (`qbt-update-sh`)

## NOTE - `Updated with new functions and option to choose which libtorrent version to use`

## Intro
Linux BASH script which provides an option to automatically download and update qbittorrent-nox to the latest version available.
Currently, it is mainly intended for installing and updating already installed qBitTorrent-nox on `DietPi` Linux.

This script replaces the apt package version of qBitTorrent-nox with a 3rd party executable binary from [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static) GitHub repository, the main reason being that Debian apt package versions are not always up to date.
 

### The way it works
 
The `qbt-update-sh` project is a `bash` script which updates `qbittorrent-nox` installation on `DietPi` using a static `qbittorrent-nox` binary from [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static) GitHub repository.

As it requires `ROOT / SUDO` privilege to work as intended, if run as a `non-root` user, it would prompt the user if he wants script to rerun as root and do so if the user agrees. Otherwise, the script would abort.

The script would then try to detect if the system platform is `DietPi` by checking for the existence of specific files.
If `DietPi` has been detected, the script will proceed further. Otherwise, it would abort.

Script then checks if `DietPi` version of `qBitTorrent` has already been installed and offers to install it if not, by executing the command: `dietpi-software install 46`.
If `DietPi` `qBitTorrent` installation was not detected and the user refuses to allow the script to install it, the script would abort.
Otherwise, it would proceed with installing `qBitTorrent` as described above.

If `dietpi-software` installation of `qBitTorrent` is present, it would be checked if it is running and stopped if so.

The updating procedure would start only if all three requirements were met:

  1. System detected as `DietPi`.
  2. `DietPi` `qBitTorrent` version found or installed.
  3. `qBitTorrent` service marked as inactive.

Script would then try to detect the host system architecture and offer the user to accept the detected architecture by typing `0` and pressing `Enter`, along with a choice to manually choose system architecture by offering the two most used architectures if the user disagrees with the one that is detected.

Pressing `Enter` without entering any of the options listed, or choosing the option to `Abort` would abort the script.

As of v1.2, the user is prompted to choose which libtorrent version is desired to be used during installation (current options being `libtorrent 2.0` and `libtorrent 1.2`).

For security purposes, the old executable binary is backed up (renamed) with a `.bak` extension.
Keep in mind that each script rerun will rewrite the backup file. This is about to change in future releases.

 
### How to use
Option 1 (convenient one-liner):
  Copy/Paste it to the console and execute (Enter)
  ```
  curl -fsSL https://github.com/TeraflopsBH/qbt-update-sh/releases/latest/download/qbtupd.sh | bash
  ```

Option 2 (manual download):
  1. Download the script file: `qbtupd.sh`
  2. CHMOD it to enable execution: `chmod u+x qbtupd.sh`
  3. Execute it: `./qbtupd.sh`


### Notice

This `bash` script is in a `work-in-progress` state.
It was tested on `aarch64` and `x86_64` architectures using `DietPi` optimized `Debian Bullseye` distro, and everything worked as intended.

I have a plan to improve and expand it further to autodetect if the system running is a non-dietpi (vanilla) Linux installation and make it properly install `qbittorrent-nox` binaries, as per the system architecture detected.
