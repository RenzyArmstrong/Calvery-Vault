#!/bin/bash
# CVSM CLI one-liner installer
# Usage: curl -sL https://calvery.xyz/install.sh | bash

set -e

REPO="RenzyArmstrong/Calvery-Vault"
VERSION="${1:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Detect OS
case "$(uname -s)" in
    Linux*)  OS=linux ;;
    Darwin*) OS=darwin ;;
    MINGW*|CYGWIN*|MSYS*) OS=windows ;;
    *) echo "OS tidak didukung: $(uname -s)"; exit 1 ;;
esac

# Detect ARCH
case "$(uname -m)" in
    x86_64|amd64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    armv7l|armv7) ARCH=armv7 ;;
    *) echo "Arch tidak didukung: $(uname -m)"; exit 1 ;;
esac

echo "==> CVSM installer"
echo "    OS:   $OS"
echo "    Arch: $ARCH"
echo "    Install dir: $INSTALL_DIR"

# Resolve latest version kalau perlu
if [ "$VERSION" = "latest" ]; then
    VERSION=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$VERSION" ]; then
        echo "Gagal resolve latest version"
        exit 1
    fi
fi

echo "    Version: $VERSION"

VERSION_NUM="${VERSION#v}"
ARCHIVE_EXT="tar.gz"
[ "$OS" = "windows" ] && ARCHIVE_EXT="zip"

URL="https://github.com/$REPO/releases/download/$VERSION/cvsm_${VERSION_NUM}_${OS}_${ARCH}.${ARCHIVE_EXT}"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

echo "==> Download dari $URL"
curl -fL --progress-bar "$URL" -o "$TMP/cvsm.${ARCHIVE_EXT}"

echo "==> Extract"
cd "$TMP"
if [ "$ARCHIVE_EXT" = "zip" ]; then
    unzip -q cvsm.${ARCHIVE_EXT}
else
    tar xzf cvsm.${ARCHIVE_EXT}
fi

echo "==> Install ke $INSTALL_DIR/cvsm"
BIN=cvsm
[ "$OS" = "windows" ] && BIN=cvsm.exe

if [ -w "$INSTALL_DIR" ]; then
    install -m 755 "$TMP/$BIN" "$INSTALL_DIR/$BIN"
else
    sudo install -m 755 "$TMP/$BIN" "$INSTALL_DIR/$BIN"
fi

echo ""
echo "Selesai. Jalankan: cvsm login"
"$INSTALL_DIR/$BIN" --version 2>/dev/null || true
