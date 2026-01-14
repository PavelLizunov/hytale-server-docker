# Doc Fetcher

Tool for downloading Hytale documentation from support.hytale.com.

Used by AI agents (Claude, etc.) to access official documentation,
as the site is protected by Cloudflare and requires JavaScript to render.

---

Инструмент для скачивания документации Hytale с сайта support.hytale.com.

Используется AI-агентами (Claude, etc.) для доступа к официальной документации,
так как сайт защищён Cloudflare и требует JavaScript для рендеринга.

## Installation / Установка

```bash
cd ai-tools/doc-fetcher
npm install
```

## Usage / Использование

```bash
node fetch-docs.js "<url>" "<output_name>"
```

### Example / Пример

```bash
node fetch-docs.js "https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual" "server-manual"
```

Results are saved to the `docs/` folder:
- `docs/<output_name>.html` — full HTML
- `docs/<output_name>.txt` — text content (for agent reading)

---

Результат сохраняется в папку `docs/`:
- `docs/<output_name>.html` — полный HTML
- `docs/<output_name>.txt` — текстовое содержимое (для чтения агентом)

## What to commit / Что коммитить

| File / Файл | Git |
|-------------|-----|
| `fetch-docs.js` | Yes / Да |
| `package.json` | Yes / Да |
| `package-lock.json` | Yes / Да |
| `node_modules/` | No / Нет (.gitignore) |
| `docs/` | No / Нет (.gitignore) |
