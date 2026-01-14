#!/bin/bash
# =============================================================================
# updater.sh - Download and extract Hytale server files
# =============================================================================
# Скачивание и распаковка файлов сервера Hytale
# =============================================================================

set -euo pipefail

DATA_DIR="/data"
TMP_DIR="${DATA_DIR}/tmp"
CURRENT_DIR="${DATA_DIR}/current"
PATCHLINE="${PATCHLINE:-release}"

# Minimum free space required (in MB) - game.zip ~4GB + extraction ~4GB
MIN_FREE_SPACE_MB=10000

log() { echo "[updater] $1"; }
log_error() { echo "[updater] ERROR: $1" >&2; }

check_disk_space() {
    log "Checking disk space..."

    # Get free space in MB
    FREE_SPACE_MB=$(df -m "$DATA_DIR" | awk 'NR==2 {print $4}')

    log "Free space: ${FREE_SPACE_MB}MB (need ${MIN_FREE_SPACE_MB}MB)"

    if [[ "$FREE_SPACE_MB" -lt "$MIN_FREE_SPACE_MB" ]]; then
        log_error "Not enough disk space!"
        log_error "Need at least ${MIN_FREE_SPACE_MB}MB, have ${FREE_SPACE_MB}MB"
        exit 1
    fi
}

cleanup() {
    log "Cleaning up temp files..."
    rm -rf "$TMP_DIR"
}

# Trap to cleanup on error
trap cleanup EXIT

download_game() {
    log "Downloading game files (patchline: $PATCHLINE)..."

    mkdir -p "$TMP_DIR"

    # Download with hytale-downloader
    /usr/local/bin/hytale-downloader \
        -patchline "$PATCHLINE" \
        -download-path "$TMP_DIR/game.zip"

    if [[ ! -f "$TMP_DIR/game.zip" ]]; then
        log_error "Download failed - game.zip not found"
        exit 1
    fi

    local size=$(du -h "$TMP_DIR/game.zip" | cut -f1)
    log "Downloaded: $size"
}

extract_game() {
    log "Extracting game files..."

    mkdir -p "$TMP_DIR/extract"

    # Extract with low I/O priority to prevent system overload
    # ionice -c3 = idle priority (only when disk is idle)
    if command -v ionice &> /dev/null; then
        ionice -c3 unzip -o "$TMP_DIR/game.zip" -d "$TMP_DIR/extract"
    else
        unzip -o "$TMP_DIR/game.zip" -d "$TMP_DIR/extract"
    fi

    # Remove zip immediately to free space
    rm -f "$TMP_DIR/game.zip"
    log "Removed game.zip to free space"
}

install_files() {
    log "Installing server files..."

    # Find extracted files
    ASSETS=$(find "$TMP_DIR/extract" -type f -name "Assets.zip" | head -n1)
    SERVER_DIR=$(find "$TMP_DIR/extract" -type d -name "Server" | head -n1)

    if [[ -z "$ASSETS" ]]; then
        log_error "Assets.zip not found in archive"
        exit 1
    fi

    if [[ -z "$SERVER_DIR" ]]; then
        log_error "Server directory not found in archive"
        exit 1
    fi

    # Create current directory
    mkdir -p "$CURRENT_DIR"

    # Remove old server files
    rm -rf "$CURRENT_DIR/Server"

    # Move instead of copy (faster, less I/O)
    log "Moving Server files..."
    mv "$SERVER_DIR" "$CURRENT_DIR/Server"

    log "Moving Assets.zip..."
    mv "$ASSETS" "$CURRENT_DIR/Assets.zip"

    # Show installed files
    log "Installed files:"
    ls -lh "$CURRENT_DIR/"
    ls -lh "$CURRENT_DIR/Server/"
}

main() {
    log "=== Hytale Server Updater ==="
    log "Patchline: $PATCHLINE"
    log "Data dir: $DATA_DIR"

    check_disk_space
    download_game
    extract_game
    install_files

    log "=== Update complete! ==="
    log "Server files at: $CURRENT_DIR"
}

main "$@"
