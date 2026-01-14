#!/bin/bash
# =============================================================================
# entrypoint.sh - Docker container entrypoint for Hytale server
# =============================================================================

set -euo pipefail

# Paths
DATA_DIR="/data"
CURRENT_DIR="${DATA_DIR}/current"
RUNTIME_DIR="${DATA_DIR}/runtime"
TOKENS_DIR="${DATA_DIR}/.tokens"
SCRIPTS_DIR="/scripts"

SERVER_JAR="${CURRENT_DIR}/Server/HytaleServer.jar"
ASSETS_ZIP="${CURRENT_DIR}/Assets.zip"
AOT_CACHE="${CURRENT_DIR}/Server/HytaleServer.aot"

# Defaults
JAVA_OPTS="${JAVA_OPTS:--Xms2G -Xmx6G}"
HYTALE_BIND="${HYTALE_BIND:-0.0.0.0:5520}"
BACKUP_ENABLED="${BACKUP_ENABLED:-true}"
BACKUP_DIR="${BACKUP_DIR:-${RUNTIME_DIR}/backups}"
BACKUP_FREQUENCY="${BACKUP_FREQUENCY:-30}"

log() { echo "[entrypoint] $1"; }

# Check required files
check_files() {
    if [[ ! -f "$SERVER_JAR" ]]; then
        log "ERROR: Server JAR not found at $SERVER_JAR"
        log "Run the updater first: docker compose run updater"
        exit 1
    fi

    if [[ ! -f "$ASSETS_ZIP" ]]; then
        log "ERROR: Assets not found at $ASSETS_ZIP"
        log "Run the updater first: docker compose run updater"
        exit 1
    fi

    log "Server files OK"
}

# Get authentication tokens
get_auth_tokens() {
    if [[ ! -f "${TOKENS_DIR}/refresh_token" ]]; then
        log "WARNING: No auth tokens found at ${TOKENS_DIR}"
        log "Server will start unauthenticated. Use /auth login device in console."
        return 0
    fi

    log "Getting session tokens..."

    # Run auth-session.sh and capture output
    if AUTH_OUTPUT=$("${SCRIPTS_DIR}/auth-session.sh" "env" 2>&1); then
        # Parse the output for token assignments
        while IFS='=' read -r key value; do
            case "$key" in
                HYTALE_SERVER_SESSION_TOKEN)
                    export HYTALE_SERVER_SESSION_TOKEN="$value"
                    ;;
                HYTALE_SERVER_IDENTITY_TOKEN)
                    export HYTALE_SERVER_IDENTITY_TOKEN="$value"
                    ;;
            esac
        done <<< "$AUTH_OUTPUT"

        if [[ -n "${HYTALE_SERVER_SESSION_TOKEN:-}" ]]; then
            log "Authentication tokens obtained"
        else
            log "WARNING: Failed to parse auth tokens, starting unauthenticated"
        fi
    else
        log "WARNING: Auth failed, starting unauthenticated"
        log "$AUTH_OUTPUT"
    fi
}

# Build Java command
build_java_cmd() {
    mkdir -p "$RUNTIME_DIR" "$BACKUP_DIR"
    cd "$RUNTIME_DIR"

    JAVA_CMD="java"

    # Add AOT cache if available
    if [[ -f "$AOT_CACHE" ]]; then
        JAVA_CMD="$JAVA_CMD -XX:AOTCache=$AOT_CACHE"
        log "Using AOT cache for faster startup"
    fi

    JAVA_CMD="$JAVA_CMD $JAVA_OPTS -jar $SERVER_JAR"
    JAVA_CMD="$JAVA_CMD --assets $ASSETS_ZIP"
    JAVA_CMD="$JAVA_CMD --bind $HYTALE_BIND"

    # Backup options
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        JAVA_CMD="$JAVA_CMD --backup --backup-dir $BACKUP_DIR --backup-frequency $BACKUP_FREQUENCY"
    fi

    echo "$JAVA_CMD"
}

main() {
    log "Starting Hytale server..."
    log "Data dir: $DATA_DIR"
    log "Bind: $HYTALE_BIND"

    check_files
    get_auth_tokens

    JAVA_CMD=$(build_java_cmd)
    log "Command: $JAVA_CMD"

    # Execute server
    exec $JAVA_CMD
}

main "$@"
