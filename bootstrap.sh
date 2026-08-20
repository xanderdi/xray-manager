#!/bin/bash
set -euo pipefail

XRAY_PREFIX="${XRAY_PREFIX:-/usr/local}"

XRAY_BIN="$XRAY_PREFIX/bin/xray"
XRAY_SHARE="$XRAY_PREFIX/share/xray"

echo "=== xray-manager bootstrap ==="

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run with sudo"
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: /etc/os-release not found"
    exit 1
fi

. /etc/os-release

if [[ "${ID:-}" != "debian" ]]; then
    echo "ERROR: unsupported distribution: ${ID:-unknown}"
    echo "Supported: Debian"
    exit 1
fi

echo "Distribution: ${PRETTY_NAME:-Debian}"

DEB_ARCH="$(dpkg --print-architecture)"

case "$DEB_ARCH" in
    amd64)
        XRAY_ARCH="64"
        ;;
    arm64)
        XRAY_ARCH="arm64-v8a"
        ;;
    *)
        echo "ERROR: unsupported architecture: $DEB_ARCH"
        exit 1
        ;;
esac

echo "Architecture: $DEB_ARCH"
echo "Xray asset architecture: $XRAY_ARCH"

REQUIRED_PACKAGES=(
    iproute2
    network-manager
    python3
    curl
    sudo
    unzip
    ca-certificates
)

MISSING_PACKAGES=()

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if (( ${#MISSING_PACKAGES[@]} > 0 )); then
    echo "Installing missing packages:"
    printf '  %s\n' "${MISSING_PACKAGES[@]}"

    apt-get update
    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y "${MISSING_PACKAGES[@]}"
else
    echo "Required packages: OK"
fi

for cmd in apt-get dpkg curl unzip sha256sum install; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd"
        exit 1
    fi
done

if [[ -x $XRAY_BIN ]]; then
    echo "Xray Core: already installed"
    $XRAY_BIN version | head -1
else
    echo "Xray Core: not installed"

    XRAY_ZIP="Xray-linux-${XRAY_ARCH}.zip"
    TMP_DIR="$(mktemp -d)"

    cleanup() {
        rm -rf "$TMP_DIR"
    }
    trap cleanup EXIT

    echo "Downloading latest Xray Core..."

    curl -fL \
        "https://github.com/XTLS/Xray-core/releases/latest/download/${XRAY_ZIP}" \
        -o "$TMP_DIR/$XRAY_ZIP"

    unzip -q "$TMP_DIR/$XRAY_ZIP" -d "$TMP_DIR/xray"

    if [[ ! -x "$TMP_DIR/xray/xray" ]]; then
        echo "ERROR: xray binary not found in downloaded archive"
        exit 1
    fi

    for file in xray geoip.dat geosite.dat; do
    if [[ ! -f "$TMP_DIR/xray/$file" ]]; then
        echo "ERROR: required file not found in downloaded archive: $file"
        exit 1
    fi
done

    install -d -m 755 "$XRAY_PREFIX/bin"
    
    install -d -m 755 "$XRAY_SHARE"


    install -m 755 "$TMP_DIR/xray/xray" \
        $XRAY_BIN

    install -m 644 "$TMP_DIR/xray/geoip.dat" \
        $XRAY_SHARE/geoip.dat

    install -m 644 "$TMP_DIR/xray/geosite.dat" \
        $XRAY_SHARE/geosite.dat

    echo "Xray Core installed:"
    $XRAY_BIN version | head -1
fi

echo "Bootstrap preflight: OK"
