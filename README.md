# qBitTorrent Updater (`qbt-update-sh`)

## Overview

A Bash updater for `qbittorrent-nox` on DietPi. It downloads the static executable published by [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static), allowing users to install a newer upstream build than may be available from the distribution package.

**This script replaces the executable installed at `/usr/bin/qbittorrent-nox`. Review the source before running it, and keep a separate backup of important system configuration.** This project is a work in progress.

## What the updater does

On launch, the script verifies root privileges and checks for the DietPi marker. It then opens a main menu showing the installed qBittorrent version, service status, and the number of local backups:

- **Update qBittorrent** — follows the interactive update workflow described below.
- **Restore a previous backup** — appears when backup files using this updater's naming pattern are found. Restoration is local and does not perform a GitHub release check.
- **Exit** — leaves the system unchanged.

### Update workflow

1. Shows the update safety notice and waits for explicit confirmation.
2. Checks the helper commands required for updating. If commands are missing, it lists the commands and APT packages, explains the operations, and asks permission before running `apt-get update` and installing packages with `--no-install-recommends --no-upgrade`. APT and `systemctl` must already be available.
3. Checks for `/usr/bin/qbittorrent-nox` and `qbittorrent.service` independently. If both are absent, it asks permission before installing qBittorrent through DietPi (software ID 46). If only one exists, it aborts and asks you to repair the inconsistent installation.
4. Verifies that the service's `ExecStart` references the target executable, checks HTTPS access to GitHub, and fetches and validates the release metadata.
5. Displays installed and latest qBittorrent versions, then asks you to select the architecture and libtorrent 2.0 or 1.2.
6. Shows a final confirmation screen. It waits for approval before downloading or changing the executable.
7. Downloads the selected asset and validates that it is non-empty, an ELF executable for the selected architecture, runnable for its `--version` self-test, and reports the expected qBittorrent version.
8. Stages the candidate in `/usr/bin`, creates a timestamped backup of the current executable, then stops the service and atomically replaces the executable.
9. Starts the service and checks that it becomes active. If replacement or startup fails, it attempts to restore the previous executable and service state.
10. After a successful update, offers cleanup choices for older backups. The backup created for the current update is always retained.

### Restore workflow

1. Scans the timestamped backup filename pattern `/usr/bin/qbittorrent-nox.*.bak` and presents compatible backups newest first.
2. Skips files that are not regular, non-empty ELF executables, do not match the detected host architecture, or fail their `--version` self-test.
3. Shows each candidate's qBittorrent version, filename and size, then asks the user to select one and confirm the restore.
4. Stages the selected executable before stopping the service. If an executable is currently installed, it first saves that version as a new timestamped safety backup. If the target is missing, failed restoration attempts return it to the missing state.
5. Replaces the executable and preserves the service's prior active/inactive state. If a previously active service fails to start, the script attempts to restore the pre-restore executable and restart the service.
6. Retains both the selected source backup and any newly created safety backup; restore does not run the older-backup cleanup menu.

Restoration covers the executable only. It does not roll back qBittorrent configuration, torrent state, or other application data. Automatic rollback is best-effort, so keep separate backups of important system configuration.

The updater does not publish releases or change release assets. The update workflow does not intentionally modify existing qBittorrent settings. If qBittorrent was absent, the separately approved DietPi installation may create its initial configuration.

## Requirements

- DietPi Linux, APT (`apt-get`), and the expected `qbittorrent.service` systemd unit. The `systemctl` command must already be available.
- Root privileges. When run as a non-root user, the script explains the requirement and exits; it does not automatically re-run itself through `sudo`.
- The updater checks for every external helper command it uses. If commands are missing, it lists the required packages and asks for consent before running `apt-get update` and installing only those packages, with `--no-install-recommends --no-upgrade`. It verifies the commands again after installation. No package installation happens without an explicit yes.
- An interactive terminal (the script reads confirmations and menu choices from `/dev/tty`). The update workflow requires HTTPS access to GitHub; restoring a local backup does not require GitHub access. If helper packages are missing, installing them through APT may require network access.

## Usage

### Option 1: download and run

Inspect the script first if you do not already trust its source. The following commands download the latest published script and then run it interactively with root privileges. The updater waits for explicit consent before proceeding, installing missing helper packages, optionally installing qBittorrent through DietPi, and performing the final binary replacement:

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

- The main menu offers local restore when backup files matching `/usr/bin/qbittorrent-nox.*.bak` exist. Only compatible backups that pass the executable checks are selectable.
- When an executable is present, restore first creates a safety backup of it. If the executable is missing, a failed restore attempts to return the target to that absent state.
- Restore retains the chosen source backup and any safety backup. It does not run the backup-cleanup menu.
- After a successful update, the current update's backup is never removed by the cleanup menu. The options only manage older backups.
- If the service does not start after an update, inspect logs with `journalctl -u qbittorrent.service`.
- Automatic rollback is best-effort. If the service was active before the update, the script attempts to restart it after rollback; if it was inactive, the script leaves it stopped.
- Keep a separate backup of important system configuration; executable rollback does not reverse unrelated system or configuration changes.

## Testing status

The script changes should be checked with `bash -n qbtupd.sh` and ShellCheck, then tested in a disposable DietPi environment before using them on a live installation. In particular, test HTTP failures, malformed metadata, wrong-architecture downloads, and service-start failure. Do not assume a successful shell syntax check proves the updater works on every DietPi version.

## Upstream project

- [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static)
- [This repository](https://github.com/TeraflopsBH/qbt-update-sh)
