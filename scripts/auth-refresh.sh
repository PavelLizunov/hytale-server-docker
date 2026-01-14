#!/bin/bash
# =============================================================================
# auth-refresh.sh - Refresh Hytale OAuth refresh_token
# Add to cron to run every ~25 days to keep token alive
# =============================================================================
# Обновление refresh_token для поддержания авторизации
# Добавьте в cron для запуска каждые ~25 дней
# =============================================================================
# Cron example / Пример cron:
#   0 3 */25 * * /opt/hytale-server/scripts/auth-refresh.sh >> /var/log/hytale-auth.log 2>&1
# =============================================================================

set -euo pipefail

TOKENS_DIR="${TOKENS_DIR:-/opt/hytale-data/.tokens}"
OAUTH_URL="https://oauth.accounts.hytale.com"
CLIENT_ID="hytale-server"

log() { echo "[$(date -Iseconds)] $1"; }

main() {
    if [[ ! -f "${TOKENS_DIR}/refresh_token" ]]; then
        log "ERROR: No refresh_token found at ${TOKENS_DIR}/refresh_token"
        exit 1
    fi

    REFRESH_TOKEN=$(cat "${TOKENS_DIR}/refresh_token")

    log "Refreshing token..."

    RESPONSE=$(curl -s -X POST "${OAUTH_URL}/oauth2/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=${CLIENT_ID}" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=${REFRESH_TOKEN}")

    NEW_REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.refresh_token // empty')
    ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token // empty')

    if [[ -z "$ACCESS_TOKEN" ]]; then
        log "ERROR: Failed to refresh token"
        log "Response: $RESPONSE"
        exit 1
    fi

    if [[ -n "$NEW_REFRESH_TOKEN" ]]; then
        echo "$NEW_REFRESH_TOKEN" > "${TOKENS_DIR}/refresh_token"
        chmod 600 "${TOKENS_DIR}/refresh_token"
        echo "$(date -Iseconds)" > "${TOKENS_DIR}/last_refresh"
        log "OK: Token refreshed successfully"
    else
        log "OK: Token valid (no new refresh_token issued)"
    fi
}

main
