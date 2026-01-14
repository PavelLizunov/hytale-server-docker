#!/bin/bash
# =============================================================================
# auth-session.sh - Create Hytale game session from saved refresh_token
# Called at server startup to get session_token and identity_token
# =============================================================================
# Создание игровой сессии из сохранённого refresh_token
# Вызывается при запуске сервера
# =============================================================================

set -euo pipefail

TOKENS_DIR="${TOKENS_DIR:-/opt/hytale-data/.tokens}"
OAUTH_URL="https://oauth.accounts.hytale.com"
SESSIONS_URL="https://sessions.hytale.com"
CLIENT_ID="hytale-server"

# Output mode: "env" (default) or "export" or "file"
OUTPUT_MODE="${1:-env}"

log_error() { echo "[ERROR] $1" >&2; }
log_info()  { echo "[INFO] $1" >&2; }

# Read saved tokens
read_tokens() {
    if [[ ! -f "${TOKENS_DIR}/refresh_token" ]]; then
        log_error "No refresh_token found. Run auth-init.sh first."
        log_error "refresh_token не найден. Сначала запустите auth-init.sh"
        exit 1
    fi

    if [[ ! -f "${TOKENS_DIR}/profile_uuid" ]]; then
        log_error "No profile_uuid found. Run auth-init.sh first."
        exit 1
    fi

    REFRESH_TOKEN=$(cat "${TOKENS_DIR}/refresh_token")
    PROFILE_UUID=$(cat "${TOKENS_DIR}/profile_uuid")
}

# Get new access_token using refresh_token
refresh_access_token() {
    log_info "Refreshing access token..."

    TOKEN_RESPONSE=$(curl -s -X POST "${OAUTH_URL}/oauth2/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=${CLIENT_ID}" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=${REFRESH_TOKEN}")

    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
    NEW_REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')

    if [[ -z "$ACCESS_TOKEN" ]]; then
        log_error "Failed to refresh access token"
        log_error "Response: $TOKEN_RESPONSE"
        exit 1
    fi

    # Update refresh_token if a new one was issued
    if [[ -n "$NEW_REFRESH_TOKEN" && "$NEW_REFRESH_TOKEN" != "$REFRESH_TOKEN" ]]; then
        echo "$NEW_REFRESH_TOKEN" > "${TOKENS_DIR}/refresh_token"
        chmod 600 "${TOKENS_DIR}/refresh_token"
        log_info "Refresh token updated"
    fi

    log_info "Access token obtained"
}

# Create game session
create_game_session() {
    log_info "Creating game session for profile ${PROFILE_UUID}..."

    SESSION_RESPONSE=$(curl -s -X POST "${SESSIONS_URL}/game-session/new" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"uuid\": \"${PROFILE_UUID}\"}")

    SESSION_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.sessionToken // empty')
    IDENTITY_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.identityToken // empty')
    EXPIRES_AT=$(echo "$SESSION_RESPONSE" | jq -r '.expiresAt // empty')

    if [[ -z "$SESSION_TOKEN" || -z "$IDENTITY_TOKEN" ]]; then
        log_error "Failed to create game session"
        log_error "Response: $SESSION_RESPONSE"
        exit 1
    fi

    log_info "Game session created (expires: ${EXPIRES_AT})"
}

# Output tokens
output_tokens() {
    case "$OUTPUT_MODE" in
        "env")
            # Output as environment variable assignments (for eval)
            echo "HYTALE_SERVER_SESSION_TOKEN=${SESSION_TOKEN}"
            echo "HYTALE_SERVER_IDENTITY_TOKEN=${IDENTITY_TOKEN}"
            ;;
        "export")
            # Output as export statements (for sourcing)
            echo "export HYTALE_SERVER_SESSION_TOKEN=\"${SESSION_TOKEN}\""
            echo "export HYTALE_SERVER_IDENTITY_TOKEN=\"${IDENTITY_TOKEN}\""
            ;;
        "file")
            # Save to files
            echo "$SESSION_TOKEN" > "${TOKENS_DIR}/session_token"
            echo "$IDENTITY_TOKEN" > "${TOKENS_DIR}/identity_token"
            chmod 600 "${TOKENS_DIR}/session_token" "${TOKENS_DIR}/identity_token"
            log_info "Session tokens saved to ${TOKENS_DIR}/"
            ;;
        "json")
            # Output as JSON
            jq -n \
                --arg st "$SESSION_TOKEN" \
                --arg it "$IDENTITY_TOKEN" \
                --arg exp "$EXPIRES_AT" \
                '{sessionToken: $st, identityToken: $it, expiresAt: $exp}'
            ;;
        *)
            log_error "Unknown output mode: $OUTPUT_MODE"
            exit 1
            ;;
    esac
}

main() {
    read_tokens
    refresh_access_token
    create_game_session
    output_tokens
}

main
