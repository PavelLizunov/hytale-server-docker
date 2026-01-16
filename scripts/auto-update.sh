#!/bin/bash
# =============================================================================
# auto-update.sh - Automatic Hytale server update script
# =============================================================================
# Автоматическое обновление сервера Hytale
# =============================================================================
# Usage: Run via cron for daily updates
# Использование: Запуск через cron для ежедневных обновлений
# =============================================================================

set -euo pipefail

# Configuration
DATA_DIR="${HYTALE_DATA_DIR:-/opt/hytale-data}"
DOCKER_DIR="${HYTALE_DOCKER_DIR:-/home/mc/hytale-server-docker}"
LOG_FILE="${DATA_DIR}/logs/auto-update.log"
PATCHLINE="${PATCHLINE:-release}"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

validate_environment() {
    # Check required directories exist
    if [[ ! -d "$DATA_DIR" ]]; then
        log_error "Data directory not found: $DATA_DIR"
        exit 1
    fi

    if [[ ! -d "$DOCKER_DIR" ]]; then
        log_error "Docker project directory not found: $DOCKER_DIR"
        exit 1
    fi

    if [[ ! -f "$DOCKER_DIR/docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in: $DOCKER_DIR"
        exit 1
    fi

    log "Environment validated"
}

check_version() {
    log "Checking for updates..."

    # Get current version from server logs (if available)
    CURRENT_VERSION=""
    if [[ -d "${DATA_DIR}/logs" ]]; then
        CURRENT_VERSION=$(grep -h "Booting up HytaleServer - Version:" "${DATA_DIR}/logs/"*.log 2>/dev/null | tail -1 | grep -oP 'Version: \K[^,]+' || echo "unknown")
    fi
    log "Current version: ${CURRENT_VERSION:-unknown}"

    # Check available version using hytale-downloader
    cd "$DOCKER_DIR"
    AVAILABLE_VERSION=$(docker compose run --rm updater hytale-downloader -print-version -patchline "$PATCHLINE" 2>/dev/null | grep -oP '\d{4}\.\d{2}\.\d{2}-[a-f0-9]+' | head -1 || echo "")

    if [[ -z "$AVAILABLE_VERSION" ]]; then
        log_error "Could not determine available version"
        return 1
    fi

    log "Available version: $AVAILABLE_VERSION"

    # Compare versions
    if [[ "$CURRENT_VERSION" == "$AVAILABLE_VERSION" ]]; then
        log "Server is up to date. No update needed."
        return 1
    fi

    log "Update available: $CURRENT_VERSION -> $AVAILABLE_VERSION"
    return 0
}

stop_server() {
    log "Stopping server..."
    cd "$DOCKER_DIR"
    docker compose down --timeout 60 || true
    sleep 5
    log "Server stopped"
}

run_update() {
    log "Running update..."
    cd "$DOCKER_DIR"

    if docker compose run --rm updater; then
        log "Update completed successfully"
        return 0
    else
        log_error "Update failed"
        return 1
    fi
}

start_server() {
    log "Starting server..."
    cd "$DOCKER_DIR"
    docker compose up -d
    sleep 15

    # Check if server started (multiple methods)
    if docker ps --filter "name=hytale" --format "{{.Status}}" | grep -qi "up"; then
        log "Server container is running"

        # Check if server actually booted
        if docker logs hytale 2>&1 | grep -q "Hytale Server Booted"; then
            log "Server started successfully"
            return 0
        else
            log "Server container running but still booting..."
            return 0
        fi
    else
        log_error "Server failed to start"
        return 1
    fi
}

main() {
    log "=========================================="
    log "Hytale Auto-Update Script"
    log "=========================================="
    log "Data dir: $DATA_DIR"
    log "Docker dir: $DOCKER_DIR"

    # Validate environment
    validate_environment

    # Check if update is available
    if ! check_version; then
        log "No update needed. Exiting."
        exit 0
    fi

    # Stop server
    stop_server

    # Run update
    if ! run_update; then
        log_error "Update failed. Attempting to restart server..."
        start_server
        exit 1
    fi

    # Start server
    if ! start_server; then
        log_error "Server failed to start after update!"
        exit 1
    fi

    log "=========================================="
    log "Update completed successfully!"
    log "=========================================="
}

main "$@"
