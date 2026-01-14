#!/bin/bash
# =============================================================================
# auth-init.sh - Initial Hytale OAuth2 Device Code Flow Authentication
# Run this ONCE to authorize and save refresh_token
# =============================================================================
# Первоначальная авторизация через Device Code Flow
# Запустите ОДИН РАЗ для получения refresh_token
# =============================================================================

set -euo pipefail

TOKENS_DIR="${TOKENS_DIR:-/opt/hytale-data/.tokens}"
OAUTH_URL="https://oauth.accounts.hytale.com"
ACCOUNT_URL="https://account-data.hytale.com"
CLIENT_ID="hytale-server"
SCOPE="openid offline auth:server"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_deps() {
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd is required but not installed"
            exit 1
        fi
    done
}

# Step 1: Request device code
request_device_code() {
    log_info "Requesting device code..."

    DEVICE_RESPONSE=$(curl -s -X POST "${OAUTH_URL}/oauth2/device/auth" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=${CLIENT_ID}" \
        -d "scope=${SCOPE}")

    DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.device_code // empty')
    USER_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.user_code // empty')
    VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | jq -r '.verification_uri // empty')
    VERIFICATION_URI_COMPLETE=$(echo "$DEVICE_RESPONSE" | jq -r '.verification_uri_complete // empty')
    EXPIRES_IN=$(echo "$DEVICE_RESPONSE" | jq -r '.expires_in // 900')
    INTERVAL=$(echo "$DEVICE_RESPONSE" | jq -r '.interval // 5')

    if [[ -z "$DEVICE_CODE" || -z "$USER_CODE" ]]; then
        log_error "Failed to get device code"
        echo "$DEVICE_RESPONSE"
        exit 1
    fi
}

# Step 2: Display auth instructions
show_auth_instructions() {
    echo ""
    echo "==================================================================="
    echo -e "${YELLOW}DEVICE AUTHORIZATION / АВТОРИЗАЦИЯ УСТРОЙСТВА${NC}"
    echo "==================================================================="
    echo ""
    echo -e "Visit / Перейдите:  ${CYAN}${VERIFICATION_URI}${NC}"
    echo -e "Enter code / Код:   ${GREEN}${USER_CODE}${NC}"
    echo ""
    echo -e "Or open / Или откройте:"
    echo -e "${CYAN}${VERIFICATION_URI_COMPLETE}${NC}"
    echo ""
    echo "==================================================================="
    echo "Waiting for authorization (expires in ${EXPIRES_IN}s)..."
    echo "Ожидание авторизации (истекает через ${EXPIRES_IN}с)..."
    echo ""
}

# Step 3: Poll for token
poll_for_token() {
    local start_time=$(date +%s)
    local end_time=$((start_time + EXPIRES_IN))

    while true; do
        sleep "$INTERVAL"

        local now=$(date +%s)
        if [[ $now -ge $end_time ]]; then
            log_error "Authorization timed out / Время авторизации истекло"
            exit 1
        fi

        TOKEN_RESPONSE=$(curl -s -X POST "${OAUTH_URL}/oauth2/token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "client_id=${CLIENT_ID}" \
            -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
            -d "device_code=${DEVICE_CODE}")

        ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // empty')

        case "$ERROR" in
            "authorization_pending")
                echo -n "."
                ;;
            "slow_down")
                INTERVAL=$((INTERVAL + 1))
                ;;
            "")
                # Success!
                echo ""
                ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
                REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token')

                if [[ -n "$ACCESS_TOKEN" && -n "$REFRESH_TOKEN" ]]; then
                    log_ok "Authorization successful! / Авторизация успешна!"
                    return 0
                else
                    log_error "Invalid token response"
                    echo "$TOKEN_RESPONSE"
                    exit 1
                fi
                ;;
            *)
                echo ""
                log_error "Authorization failed: $ERROR"
                echo "$TOKEN_RESPONSE" | jq .
                exit 1
                ;;
        esac
    done
}

# Step 4: Get profile
get_profile() {
    log_info "Fetching profile..."

    PROFILE_RESPONSE=$(curl -s -X GET "${ACCOUNT_URL}/my-account/get-profiles" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}")

    PROFILE_UUID=$(echo "$PROFILE_RESPONSE" | jq -r '.profiles[0].uuid // empty')
    PROFILE_NAME=$(echo "$PROFILE_RESPONSE" | jq -r '.profiles[0].username // empty')

    if [[ -z "$PROFILE_UUID" ]]; then
        log_error "Failed to get profile"
        echo "$PROFILE_RESPONSE"
        exit 1
    fi

    log_ok "Profile: ${PROFILE_NAME} (${PROFILE_UUID})"
}

# Step 5: Save tokens
save_tokens() {
    log_info "Saving tokens to ${TOKENS_DIR}..."

    mkdir -p "$TOKENS_DIR"
    chmod 700 "$TOKENS_DIR"

    echo "$REFRESH_TOKEN" > "${TOKENS_DIR}/refresh_token"
    echo "$PROFILE_UUID" > "${TOKENS_DIR}/profile_uuid"
    echo "$PROFILE_NAME" > "${TOKENS_DIR}/profile_name"
    echo "$(date -Iseconds)" > "${TOKENS_DIR}/auth_date"

    chmod 600 "${TOKENS_DIR}"/*

    log_ok "Tokens saved! / Токены сохранены!"
}

# Main
main() {
    echo ""
    echo "Hytale Server Authentication / Авторизация сервера Hytale"
    echo ""

    check_deps

    if [[ -f "${TOKENS_DIR}/refresh_token" ]]; then
        log_warn "Tokens already exist at ${TOKENS_DIR}"
        log_warn "Токены уже существуют"
        read -p "Overwrite? / Перезаписать? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "Aborted / Отменено"
            exit 0
        fi
    fi

    request_device_code
    show_auth_instructions
    poll_for_token
    get_profile
    save_tokens

    echo ""
    echo "==================================================================="
    echo -e "${GREEN}Setup complete! / Настройка завершена!${NC}"
    echo ""
    echo "Saved files / Сохранённые файлы:"
    echo "  - ${TOKENS_DIR}/refresh_token"
    echo "  - ${TOKENS_DIR}/profile_uuid"
    echo ""
    echo "Next step / Следующий шаг:"
    echo "  docker compose up -d"
    echo "==================================================================="
}

main "$@"
