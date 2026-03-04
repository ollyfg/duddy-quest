#!/usr/bin/env bash
# Downloads the Godot 4.6 Linux binary to tools/godot4.
# Skip if already installed.
#
# Usage:
#   bash tools/install_godot.sh
#
# Override the version:
#   GODOT_VERSION=4.6.1 bash tools/install_godot.sh

set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.6.1}"
GODOT_CHANNEL="${GODOT_CHANNEL:-stable}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="$SCRIPT_DIR/godot4"

if [ -x "$GODOT_BIN" ]; then
    echo "Godot already installed: $("$GODOT_BIN" --version 2>&1 | head -1)"
    exit 0
fi

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  PLATFORM="linux.x86_64" ;;
    aarch64|arm64) PLATFORM="linux.arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

FILENAME="Godot_v${GODOT_VERSION}-${GODOT_CHANNEL}_${PLATFORM}"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_CHANNEL}/${FILENAME}.zip"

echo "Downloading Godot ${GODOT_VERSION} (${GODOT_CHANNEL}) for ${PLATFORM}..."
echo "URL: $URL"

TMP_ZIP="$(mktemp /tmp/godot_XXXXXX.zip)"
TMP_DIR="$(mktemp -d /tmp/godot_extract_XXXXXX)"

cleanup() {
    rm -f "$TMP_ZIP"
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

curl -fsSL -o "$TMP_ZIP" "$URL"

echo "Extracting..."
unzip -q "$TMP_ZIP" -d "$TMP_DIR"

mv "$TMP_DIR/$FILENAME" "$GODOT_BIN"
chmod +x "$GODOT_BIN"

echo "Installed: $("$GODOT_BIN" --version 2>&1 | head -1)"
echo "Binary path: $GODOT_BIN"
