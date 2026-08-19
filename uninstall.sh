#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run with sudo"
    exit 1
fi

PURGE=false

case "${1:-}" in
    "")
        ;;
    --purge)
        PURGE=true
        ;;
    *)
        echo "Usage: $0 [--purge]"
        exit 1
        ;;
esac

echo "=== xray-manager uninstall ==="

echo
echo "Switching to OFF..."

if [[ -x /usr/local/bin/xray-mode ]]; then
    /usr/local/bin/xray-mode off || true
else
    systemctl stop xray.service 2>/dev/null || true
fi

echo
echo "Disabling boot restore..."

systemctl disable --now xray-manager-restore.service 2>/dev/null || true

echo
echo "Removing xray-manager files..."

rm -f /usr/local/bin/xray-mode
rm -f /usr/local/bin/xray-import
rm -f /usr/local/bin/xray-check
rm -f /usr/local/bin/xray-status

rm -rf /usr/local/lib/xray-manager

rm -f /etc/systemd/system/xray-manager-restore.service
rm -f /etc/NetworkManager/dispatcher.d/90-xray-manager

systemctl daemon-reload

if [[ "$PURGE" == true ]]; then
    echo
    echo "Purging xray-manager state..."

    rm -rf /etc/xray-manager
    rm -rf /var/lib/xray-manager
else
    echo
    echo "Preserving:"
    echo "  /etc/xray-manager"
    echo "  /var/lib/xray-manager"
fi

echo "  /usr/local/etc/xray"
echo "  /usr/local/bin/xray"

echo
echo "xray-manager removed"
