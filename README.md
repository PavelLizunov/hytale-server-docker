# Hytale Server Docker

Docker setup for running a dedicated Hytale server with automated OAuth2 authentication.

---

Docker-конфигурация для запуска выделенного сервера Hytale с автоматической OAuth2 авторизацией.

## Requirements / Требования

- Docker & Docker Compose
- Linux x64 or arm64
- 4GB+ RAM (8GB+ recommended)
- 15GB+ free disk space
- Swap recommended (4GB+)
- Hytale account with game license

## Quick Start / Быстрый старт

### 1. Clone / Клонирование

```bash
git clone https://github.com/PavelLizunov/hytale-server-docker.git
cd hytale-server-docker
```

### 2. Create data directory / Создать папку данных

```bash
sudo mkdir -p /opt/hytale-data
sudo chown $USER:$USER /opt/hytale-data
```

### 3. Build / Сборка

`hytale-downloader` is downloaded automatically during build.

`hytale-downloader` скачивается автоматически при сборке.

```bash
docker compose build
```

### 4. Download server files / Скачать файлы сервера

Downloads ~4GB, requires ~10GB free space during extraction.

Скачивает ~4GB, требует ~10GB свободного места при распаковке.

```bash
docker compose run --rm updater
```

### 5. Authentication (ONE TIME) / Авторизация (ОДИН РАЗ)

```bash
docker compose run --rm auth-init
```

Follow the instructions:
1. Open the URL shown in terminal
2. Enter the code
3. Authorize with your Hytale account

Следуйте инструкциям:
1. Откройте URL из терминала
2. Введите код
3. Авторизуйтесь через аккаунт Hytale

### 6. Start server / Запуск сервера

```bash
docker compose up -d
docker compose logs -f hytale
```

You should see: `Hytale Server Booted! [Multiplayer]`

### 7. Setup token refresh (cron) / Настройка обновления токена

The refresh token expires in 30 days. Add a cron job to renew it:

Refresh token истекает через 30 дней. Добавьте cron для обновления:

```bash
crontab -e

# Add this line (runs every 25 days at 3 AM)
0 3 */25 * * docker exec hytale /scripts/auth-refresh.sh >> /var/log/hytale-auth.log 2>&1
```

## Commands / Команды

```bash
# Start server / Запуск
docker compose up -d

# Stop server / Остановка
docker compose down

# View logs / Просмотр логов
docker compose logs -f hytale

# Console access / Доступ к консоли
docker attach hytale
# (Ctrl+P, Ctrl+Q to detach / для выхода)

# Update server / Обновление сервера
docker compose down
docker compose run --rm updater
docker compose up -d

# Rebuild after git pull / Пересборка после обновления
docker compose build --no-cache
```

## Configuration / Конфигурация

Environment variables in `docker-compose.yml` or `.env` file:

Переменные окружения в `docker-compose.yml` или `.env` файле:

| Variable | Default | Description |
|----------|---------|-------------|
| `HYTALE_DATA_DIR` | `/opt/hytale-data` | Data directory path |
| `HYTALE_PORT` | `5520` | UDP port for server |
| `JAVA_OPTS` | `-Xms2G -Xmx6G` | JVM memory settings |
| `BACKUP_ENABLED` | `true` | Enable automatic backups |
| `BACKUP_FREQUENCY` | `30` | Backup interval (minutes) |
| `PATCHLINE` | `release` | Game version channel |

## File Structure / Структура файлов

```
/opt/hytale-data/
├── .tokens/           # OAuth tokens (chmod 700)
│   ├── refresh_token
│   └── profile_uuid
├── current/           # Server files
│   ├── Server/
│   │   ├── HytaleServer.jar
│   │   └── HytaleServer.aot  # AOT cache for fast startup
│   └── Assets.zip
└── runtime/           # Runtime data
    ├── universe/      # World saves
    ├── logs/
    ├── mods/
    └── backups/
```

## Network / Сеть

Hytale uses **QUIC over UDP** (not TCP).

Hytale использует **QUIC поверх UDP** (не TCP).

- Default port: `5520/udp`
- Firewall: Allow UDP inbound on port 5520
- Port forwarding: UDP only

```bash
# UFW
sudo ufw allow 5520/udp

# iptables
sudo iptables -A INPUT -p udp --dport 5520 -j ACCEPT
```

## Troubleshooting / Устранение неполадок

### Scripts not found after update / Скрипты не найдены после обновления

Docker caches old layers. Rebuild with `--no-cache`:

Docker кэширует старые слои. Пересоберите с `--no-cache`:

```bash
docker rmi hytale-server-docker-hytale:latest --force
docker rmi hytale-server-docker-updater:latest --force 2>/dev/null || true
docker compose build --no-cache
```

### Server won't start / Сервер не запускается

```bash
# Check logs
docker compose logs hytale

# Verify files exist
ls -la /opt/hytale-data/current/
```

### Auth token expired / Токен истёк

```bash
docker compose run --rm auth-init
```

### VM crashes during extraction / VM падает при распаковке

Add swap if not present:

Добавьте swap если его нет:

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Players can't connect / Игроки не могут подключиться

- Check firewall allows UDP 5520
- Verify port forwarding is UDP (not TCP)
- Check server is authenticated (`/auth status` in console)

## License

ISC
