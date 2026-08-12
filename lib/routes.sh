source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

#!/bin/bash

get_default_gateway() {
    ip -4 route show default | awk 'NR==1{print $3}'
}

get_default_device() {
    ip -4 route show default | awk 'NR==1{print $5}'
}

get_xray_server_ip() {
    getent ahostsv4 "$XRAY_SERVER" | awk 'NR==1{print $1}'
}

tun_prepare() {
    ip addr replace "$XRAY_ADDR" dev "$XRAY_IF"
    ip link set "$XRAY_IF" up
}

server_bypass_add() {
    local server_ip gateway device

    server_ip="$(get_xray_server_ip)"
    gateway="$(get_default_gateway)"
    device="$(get_default_device)"

    [[ -n "$server_ip" ]] || {
        echo "ERROR: cannot resolve $XRAY_SERVER" >&2
        return 1
    }

    [[ -n "$gateway" && -n "$device" ]] || {
        echo "ERROR: cannot determine default gateway" >&2
        return 1
    }

    ip route replace "$server_ip/32" via "$gateway" dev "$device"
}

full_routes_add() {
    ip route replace 0.0.0.0/1 dev "$XRAY_IF"
    ip route replace 128.0.0.0/1 dev "$XRAY_IF"
}

full_routes_del() {
    ip route del 0.0.0.0/1 dev "$XRAY_IF" 2>/dev/null || true
    ip route del 128.0.0.0/1 dev "$XRAY_IF" 2>/dev/null || true
}

server_bypass_del() {
    local server_ip

    server_ip="$(get_xray_server_ip 2>/dev/null)" || return 0
    [[ -n "$server_ip" ]] || return 0

    ip route del "$server_ip/32" 2>/dev/null || true
}

tun_cleanup() {
    ip link delete "$XRAY_IF" 2>/dev/null || true
}
