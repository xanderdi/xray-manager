# xray-manager

[![Release](https://img.shields.io/github/v/release/xanderdi/xray-manager)](https://github.com/xanderdi/xray-manager/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Debian 13](https://img.shields.io/badge/Debian-13-blue)](https://www.debian.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-green)](https://www.gnu.org/software/bash/)

**English** | [Русский](README.ru.md)

`xray-manager` is a CLI toolkit for managing Xray Core on Debian with multiple routing modes:

* `OFF` — Xray is completely disabled
* `SOCKS` — local SOCKS5 proxy on `127.0.0.1:10808`
* `SPLIT` — system traffic through TUN while keeping direct access to DNS and the Xray server
* `FULL` — system traffic through TUN with only the required bypass to the Xray server

## Features

* VLESS + Reality support
* import from `vless://...` URIs
* automatic runtime configuration generation
* configuration validation before installation
* backup before configuration replacement
* restoration of the last active mode after boot
* route recovery after network changes via NetworkManager
* health-check and status commands

## Requirements

Supported system:

* Debian 13
* NetworkManager
* systemd
* Xray Core installed at `/usr/local/bin/xray`

Required packages:

```bash
sudo apt install \
  iproute2 \
  network-manager \
  python3 \
  curl \
  sudo
```

Check Xray Core:

```bash
/usr/local/bin/xray version
```

## Installation

Clone the repository:

```bash
git clone https://github.com/xanderdi/xray-manager.git ~/xray-manager
cd ~/xray-manager
```

Install xray-manager:

```bash
sudo ./install.sh
```

The installer:

* checks required dependencies
* checks for Xray Core
* creates required directories
* backs up existing files
* installs CLI tools
* installs the systemd restore unit
* installs the NetworkManager dispatcher
* disables direct autostart of `xray.service`
* enables `xray-manager-restore.service`
* initializes new installations in the safe `OFF` mode

Check status:

```bash
xray-status
```

Check connectivity:

```bash
xray-check
```

## Import configuration

`xray-manager` supports importing configuration from a `connection.conf` file or directly from a `vless://` URI.

### Import from VLESS URI

Validate and install a runtime configuration:

```bash
sudo xray-import --install 'vless://...'
```

Before installation, `xray-import`:

* generates `socks.json`, `split.json`, and `full.json`
* validates all three configurations
* backs up the current runtime files
* updates `/etc/xray-manager/xray-manager.conf`
* atomically replaces the runtime configurations
* restores the currently selected mode

### Import from connection.conf

Example configuration:

```text
configs/connection.conf.example
```

Install configuration:

```bash
sudo xray-import --install /path/to/connection.conf
```

Generate configurations without installing them:

```bash
xray-import /path/to/connection.conf /tmp/xray-test
```

## Modes

Switch modes with:

```bash
sudo xray-mode off
sudo xray-mode socks
sudo xray-mode split
sudo xray-mode full
```

The current mode is stored in:

```text
/var/lib/xray-manager/mode
```

After boot, the last selected mode is restored by:

```text
xray-manager-restore.service
```

### OFF

Stops Xray completely and removes TUN and service routes.

### SOCKS

Starts a local SOCKS5 proxy on:

```text
127.0.0.1:10808
```

System routing remains direct.

### SPLIT

Creates the `xray0` interface and routes IPv4 traffic through TUN.

The manager preserves direct access to:

* the Xray server
* DNS servers that require bypass
* local networks through more specific routes

### FULL

Creates `xray0` and routes system IPv4 traffic through TUN.

A direct bypass is retained only for the Xray server to prevent a routing loop.

## Status and health check

Passive status:

```bash
xray-status
```

Displays:

* current mode
* `xray.service` state
* SOCKS listener state
* `xray0` state
* current IPv4 routes
* route to the Xray server

Active connectivity check:

```bash
xray-check
```

Checks:

* direct internet connectivity
* connectivity through SOCKS
* DNS resolution of the Xray server
* TCP/443 connectivity to the Xray server

## Backups

The installer stores previous file versions in:

```text
/var/backups/xray-manager/
```

Importing a new VLESS configuration creates a separate backup in:

```text
/var/backups/xray-manager/import-YYYYMMDD-HHMMSS/
```

## Uninstall

Remove `xray-manager` while preserving its configuration and state:

```bash
sudo ./uninstall.sh
```

Also remove `/etc/xray-manager` and `/var/lib/xray-manager`:

```bash
sudo ./uninstall.sh --purge
```

The uninstall script does **not** remove Xray Core, `/usr/local/etc/xray`, or `/etc/systemd/system/xray.service`.

## License

Licensed under the [MIT License](LICENSE).
