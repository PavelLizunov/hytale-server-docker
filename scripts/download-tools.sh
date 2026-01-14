#!/bin/bash
# =============================================================================
# download-tools.sh - Download hytale-downloader binary
# =============================================================================
# Скачивание hytale-downloader
# =============================================================================

set -euo pipefail

DOWNLOAD_URL="https://downloader.hytale.com/hytale-downloader.zip"
BIN_DIR="${BIN_DIR:-./bin}"
TMP_DIR="/tmp/hytale-downloader-$$"

log() { echo "[download-tools] $1"; }

detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$os" in
        linux)
            case "$arch" in
                x86_64|amd64) echo "hytale-downloader-linux-amd64" ;;
                aarch64|arm64) echo "hytale-downloader-linux-arm64" ;;
                *) echo "hytale-downloader-linux-amd64" ;;
            esac
            ;;
        darwin)
            # macOS not available in official release, use linux binary with Rosetta or native
            case "$arch" in
                arm64) echo "hytale-downloader-linux-arm64" ;;
                *) echo "hytale-downloader-linux-amd64" ;;
            esac
            ;;
        *)
            log "ERROR: Unsupported OS: $os"
            exit 1
            ;;
    esac
}

main() {
    log "Downloading hytale-downloader..."

    mkdir -p "$BIN_DIR" "$TMP_DIR"

    # Download zip
    log "Fetching $DOWNLOAD_URL"
    curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/hytale-downloader.zip"

    # Extract
    log "Extracting..."
    unzip -q -o "$TMP_DIR/hytale-downloader.zip" -d "$TMP_DIR"

    # Find correct binary for platform
    BINARY_NAME=$(detect_platform)
    log "Platform binary: $BINARY_NAME"

    # Look for the binary
    BINARY_PATH=$(find "$TMP_DIR" -name "$BINARY_NAME" -type f 2>/dev/null | head -1)

    if [[ -z "$BINARY_PATH" ]]; then
        log "Available files:"
        find "$TMP_DIR" -type f -name "hytale-downloader*"
        log "ERROR: Binary $BINARY_NAME not found"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Copy to bin directory
    cp "$BINARY_PATH" "$BIN_DIR/hytale-downloader"
    chmod +x "$BIN_DIR/hytale-downloader"

    # Cleanup
    rm -rf "$TMP_DIR"

    log "Done! Binary at: $BIN_DIR/hytale-downloader"
    "$BIN_DIR/hytale-downloader" -version 2>/dev/null || true
}

main "$@"
