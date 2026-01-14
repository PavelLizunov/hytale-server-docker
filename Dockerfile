FROM eclipse-temurin:25-jre

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates bash unzip coreutils findutils \
 && rm -rf /var/lib/apt/lists/*

COPY bin/hytale-downloader /usr/local/bin/hytale-downloader
RUN chmod +x /usr/local/bin/hytale-downloader

WORKDIR /data