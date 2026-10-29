# qBitTorrent Updater (`qbt-update-sh`)

## Overview

A Bash updater for `qbittorrent-nox` on DietPi. It downloads the static executable published by [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static), allowing users to install a newer upstream build than may be available from the distribution package.

**This script replaces the executable installed at `/usr/bin/qbittorrent-nox`. Review the source before running it, and keep a separate backup of important system configuration.** This project is a work in progress.

## What the updater does

1. Requires root privileges and checks that the DietPi marker file exists. It exits on non-DietPi systems.
2. Displays an initial safety notice. It then checks for helper commands and installs missing packages through APT before using them. This includes `curl`, `jq`, `file`, `grep`, and `coreutils` when their commands are missing. APT (`apt-get`) and `systemctl` must already be available.
3. Checks for `/usr/bin/qbittorrent-nox` and the `qbittorrent.service` unit independently. If both are absent, it offers to install qBittorrent with DietPi. If only one exists, it aborts and asks you to repair the inconsistent installation.
4. Verifies that the service's `ExecStart` references `/usr/bin/qbittorrent-nox`, then checks HTTPS access to GitHub and validates the release metadata JSON.
5. Shows the installed and latest qBittorrent versions, displays an explicit replacement warning, and asks whether to continue.
6. Normalizes common architecture names (including `armv7l` to `armv7`). The interactive menu retains the detected choice and the original `aarch64` / `x86_64` alternatives. The selected artifact must pass both architecture and executable self-tests before the installed binary is touched.
7. Asks whether to use libtorrent 2.0 or 1.2.
8. Downloads the selected asset with HTTP error checking and retries. It verifies that the download is non-empty, is an ELF executable for the selected architecture, and that its `--version` output matches the expected qBittorrent release.
9. Stages the candidate on the target filesystem and creates a timestamped backup of the current executable. Only then does it stop the service and atomically replace the executable.
10. Starts the service and checks that it becomes active. If replacement or startup fails, it attempts to restore the previous executable and restore the service's prior active/inactive state. If automatic recovery fails, the backup is left in place and its path is reported.
11. Offers cleanup of older backups only after the updated service has started successfully. The backup from the current update is retained regardless of the cleanup selection.

The updater does not publish releases, change release assets, or modify the qBittorrent configuration.

## Requirements

- DietPi Linux, APT (`apt-get`), and the expected `qbittorrent.service` systemd unit. The `systemctl` command must already be available.
- Root privileges. When run as a non-root user, the script explains the requirement and exits; it does not automatically re-run itself through `sudo`.
- The updater checks for every external helper command it uses and installs missing packages through APT. It runs `apt-get update` and installs only the packages needed for commands that are missing. It verifies the commands again after installation.
- HTTPS access to GitHub and an interactive terminal (the script reads confirmations and menu choices from `/dev/tty`).

## Usage

### Option 1: download and run

Inspect the script first if you do not already trust its source. The following commands download the latest published script and then run it interactively with root privileges. The updater shows a safety notice before dependency installation and another confirmation before replacing the executable:

```bash
curl -fsSL https://github.com/TeraflopsBH/qbt-update-sh/releases/latest/download/qbtupd.sh -o qbtupd.sh
less qbtupd.sh
sudo bash qbtupd.sh
```

### Option 2: manual download

1. Download `qbtupd.sh` from the repository.
2. Review the contents.
3. Run it with root privileges:

```bash
sudo bash qbtupd.sh
```

## Recovery notes

- The existing executable is backed up to a timestamped file matching `/usr/bin/qbittorrent-nox.*.bak`.
- The current update's backup is never removed by the backup-cleanup menu. The options only manage older backups.
- If the service does not start after an update, inspect logs with `journalctl -u qbittorrent.service`.
- Automatic rollback is best-effort. If the service was active before the update, the script attempts to restart it after rollback; if it was inactive, the script leaves it stopped.
- Keep a separate backup of important system configuration; executable rollback does not reverse unrelated system or configuration changes.

## Testing status

The script changes should be checked with `bash -n qbtupd.sh` and ShellCheck, then tested in a disposable DietPi environment before using them on a live installation. In particular, test HTTP failures, malformed metadata, wrong-architecture downloads, and service-start failure. Do not assume a successful shell syntax check proves the updater works on every DietPi version.

## Upstream project

- [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static)
- [This repository](https://github.com/TeraflopsBH/qbt-update-sh)
