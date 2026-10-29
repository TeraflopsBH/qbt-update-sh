# qBitTorrent Updater (`qbt-update-sh`)

## Overview

A Bash updater for `qbittorrent-nox` on DietPi. It downloads the static executable published by [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static), allowing users to install a newer upstream build than may be available from the distribution package.

**This script replaces the executable installed at `/usr/bin/qbittorrent-nox`. Review the source before running it, and keep a separate backup of important system configuration.** This project is a work in progress.

## What the updater does

On launch, the script verifies root privileges and checks for the DietPi marker. It then reads DietPi's machine-readable software list to determine whether qBittorrent software ID 46 is installed. The main menu shows the installed qBittorrent version, service status, DietPi software state, and number of local executable backups:

- **Update qBittorrent** — follows the interactive update workflow described below.
- **Restore a previous backup** — offered only when DietPi confirms software ID 46 is installed and updater backup files exist.
- **Uninstall qBittorrent through DietPi** — offered only when DietPi confirms software ID 46 is installed.
- **Exit** — leaves the system unchanged.

If DietPi cannot verify the software state, restore and uninstall are disabled rather than guessing from leftover files.

### Update workflow

1. Shows the update safety notice and waits for explicit confirmation.
2. Checks the helper commands required for updating. If commands are missing, it lists the commands and APT packages, explains the operations, and asks permission before running `apt-get update` and installing packages with `--no-install-recommends --no-upgrade`. APT and `systemctl` must already be available.
3. Checks for `/usr/bin/qbittorrent-nox` and `qbittorrent.service` independently. If both are absent, it asks permission before installing qBittorrent through DietPi (software ID 46). If only one exists, it aborts and asks you to repair the inconsistent installation.
4. Verifies that the service's `ExecStart` references the target executable, checks HTTPS access to GitHub, and fetches and validates the release metadata.
5. Displays installed and latest qBittorrent versions, then asks you to select the architecture and libtorrent 2.0 or 1.2.
6. Shows a final confirmation screen. It waits for approval before downloading or changing the executable.
7. Downloads the selected asset and validates that it is non-empty, an ELF executable for the selected architecture, runnable for its `--version` self-test, and reports the expected qBittorrent version.
8. Stages the candidate in `/usr/bin` and creates a timestamped backup of the current executable. It then stops qBittorrent and saves the current `qBittorrent.conf` under `/var/backups/qbt-update-sh/` using the same backup identifier, pairing the config snapshot with that executable version.
9. Atomically replaces the executable and starts the service. If replacement or startup fails, it attempts to restore the previous executable, pre-update configuration, and service state. The paired configuration snapshot is retained for a later restore.
10. After a successful update, offers cleanup choices for older backups. The backup created for the current update is always retained.

### Restore workflow

1. Requires DietPi to report qBittorrent software ID 46 as installed. A leftover service file or executable backup alone is not treated as proof that the complete installation exists.
2. Verifies that `qbittorrent.service` points to `/usr/bin/qbittorrent-nox` and locates the non-empty qBittorrent configuration file associated with that service's user/profile. If the existing configuration cannot be located, restore is refused rather than risking startup with a new profile and default WebUI credentials or port.
3. Scans `/usr/bin/qbittorrent-nox.*.bak` and presents compatible backups newest first. Files must be regular, non-empty ELF executables, match the detected host architecture, and pass their `--version` self-test.
4. Shows each candidate's qBittorrent version, filename and size, then asks the user to select one and confirm the restore.
5. Stages the selected executable before stopping the service. If an executable is currently installed, it saves that version as a new timestamped safety backup and saves a private pre-restore copy of the current `qBittorrent.conf` for rollback.
6. If the selected executable has a matching pre-update config snapshot from an updater-managed update, the script applies that version-matched configuration before starting the restored executable. This matters because a newer qBittorrent version may migrate settings that an older version cannot use correctly.
7. If the restored binary changes its paired configuration on startup, the script offers to reapply the configuration snapshot that belongs to that executable and restart qBittorrent. If recovery fails, it attempts to restore the previous executable and the pre-restore configuration.
8. Older executable backups created before config snapshots were paired will be labelled as legacy backups. For those, the script offers any existing saved config snapshots for manual selection; these are not guaranteed to match the chosen executable, so choose carefully. If no suitable snapshot exists, unsaved pre-upgrade settings cannot be reconstructed.
9. Retains the selected source executable backup, any new executable safety backup, and the configuration snapshots. Removing an older executable backup through the cleanup menu also removes its paired config snapshot; restore itself does not run that cleanup menu.

Restoring an executable does not roll back downloaded files or the full torrent session state. Configuration recovery is best-effort; retain the displayed configuration snapshot path if WebUI credentials or ports need to be recovered manually.

### Uninstall workflow

1. Offered only when DietPi confirms qBittorrent software ID 46 is installed.
2. Shows a confirmation screen and asks permission before running `/boot/dietpi/dietpi-software uninstall 46`.
3. Stops the service when it is active and saves a private copy of `qBittorrent.conf` first if the service profile can be identified.
4. Leaves the updater's timestamped executable backups untouched and checks DietPi's reported software state after uninstall.

The uninstall action deliberately delegates software removal to DietPi rather than manually deleting package files or service definitions. The configuration snapshot protects settings such as the WebUI username, password hash and port, but it does not include downloaded payloads or the complete torrent session state. DietPi may remove qBittorrent's user/profile data as part of its own uninstall process.

The updater does not publish releases or change release assets. The binary-update workflow does not intentionally modify existing qBittorrent settings. If qBittorrent was absent, the separately approved DietPi installation may create its initial configuration.

## Requirements

- DietPi Linux, APT (`apt-get`), and the expected `qbittorrent.service` systemd unit. The `systemctl` command must already be available.
- Root privileges. When run as a non-root user, the script explains the requirement and exits; it does not automatically re-run itself through `sudo`.
- The updater checks for every external helper command it uses. If commands are missing, it lists the required packages and asks for consent before running `apt-get update` and installing only those packages, with `--no-install-recommends --no-upgrade`. It verifies the commands again after installation. No package installation happens without an explicit yes.
- An interactive terminal (the script reads confirmations and menu choices from `/dev/tty`), the DietPi software manager, and `systemctl`. The update workflow requires HTTPS access to GitHub; restoring a local backup does not require GitHub access. If helper packages are missing, installing them through APT may require network access.

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

- The main menu offers restore only when DietPi confirms software ID 46 is installed and backup files matching `/usr/bin/qbittorrent-nox.*.bak` exist. Only compatible backups that pass the executable checks are selectable.
- Each new updater-created executable backup is paired with the pre-update `qBittorrent.conf` snapshot sharing its timestamp/PID identifier in `/var/backups/qbt-update-sh/`. Restore applies that version-matched config and retains a separate safety copy of the currently installed config.
- Older executable backups created before this pairing feature have no linked config snapshot. The restore menu explicitly warns about this and offers existing config snapshots for manual selection. If no suitable snapshot exists, settings that were never backed up cannot be reconstructed.
- When an executable is present, restore creates a safety backup of it. If the executable is missing, a failed restore attempts to return the target to that absent state.
- Restore retains the chosen source backup and any safety backups. It does not run the executable-backup cleanup menu.
- The uninstall menu action runs `dietpi-software uninstall 46` only after explicit confirmation, preserves a private qBittorrent configuration copy when one can be identified, and leaves updater executable backups untouched.
- After a successful update, the current update's backup is never removed by the cleanup menu. The options only manage older backups.
- If the service does not start after an update, inspect logs with `journalctl -u qbittorrent.service`.
- Automatic rollback is best-effort. If the service was active before the update, the script attempts to restart it after rollback; if it was inactive, the script leaves it stopped.
- Keep a separate backup of important system configuration; executable rollback does not reverse unrelated system or configuration changes.

## Testing status

The script changes should be checked with `bash -n qbtupd.sh`, ShellCheck, and the software-state/config-snapshot unit tests, then tested in a disposable DietPi environment before using them on a live installation. In particular, test HTTP failures, malformed metadata, wrong-architecture downloads, paired-config restore, legacy backups without paired configs, configuration changes after restore, config-recovery fallback, the DietPi uninstall command, and service-start failure. Do not assume a successful shell syntax check proves the updater works on every DietPi version.

## Upstream project

- [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static)
- [This repository](https://github.com/TeraflopsBH/qbt-update-sh)
