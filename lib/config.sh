#!/bin/bash

XRAY_SERVICE="xray.service"
XRAY_BIN="/usr/local/bin/xray"

XRAY_CONFIG_DIR="/usr/local/etc/xray"
XRAY_ACTIVE_CONFIG="${XRAY_CONFIG_DIR}/config.json"

XRAY_SOCKS_CONFIG="${XRAY_CONFIG_DIR}/socks.json"
[[ -r "$XRAY_SOCKS_CONFIG" ]] || XRAY_SOCKS_CONFIG="${XRAY_CONFIG_DIR}/config.proxy.json"

XRAY_FULL_CONFIG="${XRAY_CONFIG_DIR}/full.json"
[[ -r "$XRAY_FULL_CONFIG" ]] || XRAY_FULL_CONFIG="${XRAY_CONFIG_DIR}/config.tun.json"

XRAY_SPLIT_CONFIG="${XRAY_CONFIG_DIR}/split.json"
[[ -r "$XRAY_SPLIT_CONFIG" ]] || XRAY_SPLIT_CONFIG="${XRAY_CONFIG_DIR}/config.split.manual.json"

XRAY_STATE_DIR="/var/lib/xray-manager"
XRAY_MODE_FILE="${XRAY_STATE_DIR}/mode"

XRAY_IF="xray0"
XRAY_ADDR="172.19.0.1/30"
XRAY_SERVER="${XRAY_SERVER:-VPN_SERVER}"

XRAY_SOCKS_HOST="127.0.0.1"
XRAY_SOCKS_PORT="10808"

XRAY_MANAGER_CONF="/etc/xray-manager/xray-manager.conf"

if [[ -r "$XRAY_MANAGER_CONF" ]]; then
    source "$XRAY_MANAGER_CONF"
fi
