#!/bin/bash
set -euo pipefail

DESTDIR="${DESTDIR:-}"
TEST_MODE="${TEST_MODE:-0}"

root_path() {
    printf '%s%s\n' "$DESTDIR" "$1"
}

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run with sudo"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XRAY_BIN="$(root_path /usr/local/bin/xray)"
LOCAL_BIN_DIR="$(root_path /usr/local/bin)"
LOCAL_LIB_DIR="$(root_path /usr/local/lib/xray-manager)"
MANAGER_ETC_DIR="$(root_path /etc/xray-manager)"
STATE_DIR="$(root_path /var/lib/xray-manager)"
BACKUP_BASE="$(root_path /var/backups/xray-manager)"
SYSTEMD_DIR="$(root_path /etc/systemd/system)"
NM_DISPATCHER_DIR="$(root_path /etc/NetworkManager/dispatcher.d)"
XRAY_ETC_DIR="$(root_path /usr/local/etc/xray)"

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

if [[ "$TEST_MODE" == "1" ]]; then
    echo "TEST_MODE: NetworkManager check skipped"
else
    if ! systemctl is-active --quiet NetworkManager; then
        echo "ERROR: NetworkManager is not active"
        exit 1
    fi

    echo "NetworkManager: active"
fi

if [[ ! -x "$XRAY_BIN" ]]; then
    echo "ERROR: Xray Core not found at $XRAY_BIN"
    exit 1
fi

echo "Xray: $("$XRAY_BIN" version | head -1)"

echo
echo "Preparing directories..."

install -d -m 755 "$LOCAL_LIB_DIR"
install -d -m 755 "$MANAGER_ETC_DIR"
install -d -m 755 "$STATE_DIR"
install -d -m 755 "$NM_DISPATCHER_DIR"
install -d -m 755 "$XRAY_ETC_DIR"
install -d -m 755 "$LOCAL_BIN_DIR"
install -d -m 755 "$SYSTEMD_DIR"
install -d -m 755 "$BACKUP_BASE"

echo
echo "Preflight OK"


if [[ ! -e "$STATE_DIR/mode" ]]; then
    printf 'OFF\n' > "$STATE_DIR/mode"
    chmod 644 "$STATE_DIR/mode"
else
    echo "Existing mode preserved: $(cat "$STATE_DIR/mode")"
fi


BACKUP_DIR="$BACKUP_BASE/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

for file in \
    "$LOCAL_BIN_DIR/xray-mode" \
    "$LOCAL_BIN_DIR/xray-import" \
    "$LOCAL_BIN_DIR/xray-check" \
    "$LOCAL_BIN_DIR/xray-status" \
    "$LOCAL_LIB_DIR/config.sh" \
    "$LOCAL_LIB_DIR/routes.sh" \
    "$SYSTEMD_DIR/xray.service" \
    "$SYSTEMD_DIR/xray-manager-restore.service" \
    "$NM_DISPATCHER_DIR/90-xray-manager"
do
    if [[ -e "$file" ]]; then
        cp -a --parents "$file" "$BACKUP_DIR/"
    fi
done

echo "Backup: $BACKUP_DIR"

echo
echo "Installing xray-manager files..."

install -m 755 "$PROJECT_DIR/bin/xray-mode" "$LOCAL_BIN_DIR/xray-mode"
install -m 755 "$PROJECT_DIR/bin/xray-import" "$LOCAL_BIN_DIR/xray-import"
install -m 755 "$PROJECT_DIR/bin/xray-check" "$LOCAL_BIN_DIR/xray-check"
install -m 755 "$PROJECT_DIR/bin/xray-status" "$LOCAL_BIN_DIR/xray-status"

install -m 644 "$PROJECT_DIR/lib/config.sh" \
    "$LOCAL_LIB_DIR/config.sh"

install -m 644 "$PROJECT_DIR/lib/routes.sh" \
    "$LOCAL_LIB_DIR/routes.sh"

install -m 644 "$PROJECT_DIR/systemd/xray.service" \
    "$SYSTEMD_DIR/xray.service"

install -m 644 "$PROJECT_DIR/systemd/xray-manager-restore.service" \
    "$SYSTEMD_DIR/xray-manager-restore.service"

install -m 755 "$PROJECT_DIR/networkmanager/90-xray-manager" \
    "$NM_DISPATCHER_DIR/90-xray-manager"

if [[ "$TEST_MODE" == "1" ]]; then
    echo "TEST_MODE: systemctl daemon-reload skipped"
else
    systemctl daemon-reload
fi

echo
echo "Manager files installed"


echo
echo "Configuring boot restore..."

if [[ "$TEST_MODE" == "1" ]]; then
    echo "TEST_MODE: systemctl disable/enable skipped"
else
    systemctl disable xray.service 2>/dev/null || true
    systemctl enable xray-manager-restore.service

    echo "xray.service: disabled"
    echo "xray-manager-restore.service: enabled"
fi

echo
echo "Installation complete"
echo "Current mode: $(cat "$STATE_DIR/mode")"
