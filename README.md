# qBitTorrent Updater (`qbt-update-sh`)

## Overview

A Bash updater for `qbittorrent-nox` on DietPi. It downloads the static executable published by [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static), allowing users to install a newer upstream build than may be available from the distribution package.

**This script replaces the executable installed at `/usr/bin/qbittorrent-nox`. Review the source before running it, and keep a separate backup of important system configuration.** This project is a work in progress.

## What the updater does

1. Requires root privileges and checks that DietPi is present.
2. Checks that both `/usr/bin/qbittorrent-nox` and `qbittorrent.service` exist. It verifies that the service's `ExecStart` references the expected executable. If only one component exists, it stops and asks you to repair the installation instead of guessing.
3. Checks required commands and automatically installs `jq` through APT if it is missing (after confirming this is DietPi). It then fetches release metadata over HTTPS and validates it as JSON.
4. Shows the installed and latest qBittorrent versions, displays an explicit warning explaining the third-party binary replacement, service restart, backup, and best-effort rollback, then asks whether to continue.
5. Normalizes common architecture names (including `armv7l` to `armv7`). It only offers the detected architecture or abort; it will not let you choose a binary for a different architecture.
6. Asks whether to use libtorrent 2.0 or 1.2.
7. Downloads the selected asset with HTTP error checking and retries. Before touching the installed binary, it checks that the download is non-empty, is an ELF executable for the requested architecture, and can run its `--version` self-test with the expected qBittorrent version.
8. Stages the candidate on the target filesystem and creates a timestamped backup of the current executable. Only then does it stop the service and atomically replace the executable.
9. Starts the service and checks that it becomes active. If replacement or startup fails, the script attempts to restore the previous executable and restart the service. If automatic recovery fails, the backup is left in place and its path is reported.
10. Offers backup cleanup only after the updated service has started successfully.

The updater does not publish releases, change release assets, or modify the qBittorrent configuration.

## Requirements

- DietPi Linux and the expected `qbittorrent.service` systemd unit.
- Root privileges. When run as a non-root user, the script reports the requirement and exits; it does not automatically re-run itself through `sudo`.
- Commands: `curl`, `file`, `grep`, `head`, `systemctl`, plus standard system utilities available on DietPi. If `jq` is missing, the script attempts to install it with `apt-get update` and `apt-get install -y jq`.
- HTTPS access to GitHub.

## Usage

### Option 1: download and run

Inspect the script first if you do not already trust its source. The following command streams the latest published release directly into Bash and should only be used if you are comfortable executing the remote script as root:

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
- Keep at least one known-good backup until you have verified qBittorrent is working normally.
- If the service does not start after an update, inspect logs with `journalctl -u qbittorrent.service`.
- Automatic rollback is best-effort; it cannot guarantee that a service starts if the underlying configuration or system has another problem.

## Testing status

The script changes should be checked with `bash -n qbtupd.sh` and ShellCheck, then tested in a disposable DietPi environment before using them on a live installation. In particular, test HTTP failures, malformed metadata, wrong-architecture downloads, and service-start failure. Do not assume a successful shell syntax check proves the updater works on every DietPi version.

## Upstream project

- [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static)
- [This repository](https://github.com/TeraflopsBH/qbt-update-sh)
