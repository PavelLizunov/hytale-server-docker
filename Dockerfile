FROM eclipse-temurin:25-jre

ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates bash unzip coreutils findutils curl jq \
 && rm -rf /var/lib/apt/lists/*

# Download hytale-downloader
RUN set -ex; \
    DOWNLOAD_URL="https://downloader.hytale.com/hytale-downloader.zip"; \
    mkdir -p /tmp/dl; \
    curl -fsSL "$DOWNLOAD_URL" -o /tmp/dl/hytale-downloader.zip; \
    unzip -q /tmp/dl/hytale-downloader.zip -d /tmp/dl; \
    case "${TARGETARCH}" in \
        amd64) BINARY="hytale-downloader-linux" ;; \
        arm64) BINARY="hytale-downloader-linux-arm64" ;; \
        *) BINARY="hytale-downloader-linux" ;; \
    esac; \
    find /tmp/dl -name "$BINARY" -exec cp {} /usr/local/bin/hytale-downloader \;; \
    chmod +x /usr/local/bin/hytale-downloader; \
    rm -rf /tmp/dl; \
    /usr/local/bin/hytale-downloader -version || true

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

WORKDIR /data

ENTRYPOINT ["/scripts/entrypoint.sh"]
