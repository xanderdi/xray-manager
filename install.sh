#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run with sudo"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== xray-manager installer ==="

echo
echo "Project directory: $PROJECT_DIR"

echo
echo "Checking dependencies..."

for cmd in bash ip ss systemctl install getent awk grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd"
        exit 1
    fi
done

if [[ ! -x /usr/local/bin/xray ]]; then
    echo "ERROR: Xray Core not found at /usr/local/bin/xray"
    exit 1
fi

echo "Xray: $(/usr/local/bin/xray version | head -1)"

echo
echo "Preparing directories..."

install -d -m 755 /usr/local/lib/xray-manager
install -d -m 755 /etc/xray-manager
install -d -m 755 /var/lib/xray-manager
install -d -m 755 /etc/NetworkManager/dispatcher.d
install -d -m 755 /usr/local/etc/xray

echo
echo "Preflight OK"

BACKUP_DIR="/var/backups/xray-manager/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

for file in \
    /usr/local/bin/xray-mode \
    /usr/local/bin/xray-import \
    /usr/local/bin/xray-status \
    /usr/local/lib/xray-manager/config.sh \
    /usr/local/lib/xray-manager/routes.sh \
    /etc/systemd/system/xray-manager-restore.service \
    /etc/NetworkManager/dispatcher.d/90-xray-manager
do
    if [[ -e "$file" ]]; then
        cp -a --parents "$file" "$BACKUP_DIR/"
    fi
done

echo "Backup: $BACKUP_DIR"

echo
echo "Installing xray-manager files..."

install -m 755 "$PROJECT_DIR/bin/xray-mode" /usr/local/bin/xray-mode
install -m 755 "$PROJECT_DIR/bin/xray-import" /usr/local/bin/xray-import
install -m 755 "$PROJECT_DIR/bin/xray-status" /usr/local/bin/xray-status

install -m 644 "$PROJECT_DIR/lib/config.sh" \
    /usr/local/lib/xray-manager/config.sh

install -m 644 "$PROJECT_DIR/lib/routes.sh" \
    /usr/local/lib/xray-manager/routes.sh

install -m 644 "$PROJECT_DIR/systemd/xray-manager-restore.service" \
    /etc/systemd/system/xray-manager-restore.service

install -m 755 "$PROJECT_DIR/networkmanager/90-xray-manager" \
    /etc/NetworkManager/dispatcher.d/90-xray-manager

systemctl daemon-reload

echo
echo "Manager files installed"

