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

for cmd in bash ip ss systemctl install getent awk grep dpkg-query sudo; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd"
        exit 1
    fi
done


echo
echo "Checking required packages..."

required_packages=(
    iproute2
    network-manager
    python3
    curl
    sudo
)

missing_packages=()

for pkg in "${required_packages[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | \
        grep -q '^install ok installed$'
    then
        missing_packages+=("$pkg")
    fi
done

if (( ${#missing_packages[@]} > 0 )); then
    echo "ERROR: missing required packages:"
    printf '  %s\n' "${missing_packages[@]}"
    echo
    echo "Install them with:"
    echo "  apt install ${missing_packages[*]}"
    exit 1
fi

if ! systemctl is-active --quiet NetworkManager; then
    echo "ERROR: NetworkManager is not active"
    exit 1
fi

echo "Required packages: OK"
echo "NetworkManager: active"

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


if [[ ! -e /var/lib/xray-manager/mode ]]; then
    printf 'OFF\n' > /var/lib/xray-manager/mode
    chmod 644 /var/lib/xray-manager/mode
    echo "Initial mode: OFF"
else
    echo "Existing mode preserved: $(cat /var/lib/xray-manager/mode)"
fi


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


echo
echo "Configuring boot restore..."

systemctl disable xray.service 2>/dev/null || true
systemctl enable xray-manager-restore.service

echo "xray.service: disabled"
echo "xray-manager-restore.service: enabled"

echo
echo "Installation complete"
echo "Current mode: $(cat /var/lib/xray-manager/mode)"
