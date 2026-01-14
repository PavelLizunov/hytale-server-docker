FROM eclipse-temurin:25-jre

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates bash unzip coreutils findutils curl jq \
 && rm -rf /var/lib/apt/lists/*

# Copy hytale-downloader (for updater service)
COPY bin/hytale-downloader /usr/local/bin/hytale-downloader
RUN chmod +x /usr/local/bin/hytale-downloader

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

WORKDIR /data

ENTRYPOINT ["/scripts/entrypoint.sh"]
