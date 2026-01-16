# Known Issues / Известные проблемы

## Active Issues / Активные проблемы

### 1. Mount Crash Bug / Баг с маунтами
**Status:** Active
**Severity:** Critical - crashes server
**Date:** 2026-01-15

**Description:**
Server crashes when player dismounts from a mount (horse, etc.)

**Error:**
```
java.lang.IllegalArgumentException: ComponentType is not in archetype: MountedComponent
java.lang.RuntimeException: Unable to process DismountNPC packet. Player ref is invalid!
```

**Affected:** All players using mounts
**Workaround:** Do not use mounts. If mounted, disconnect instead of dismounting.

---

**Описание:**
Сервер крашится когда игрок слезает с маунта (лошадь и т.д.)

**Затронуты:** Все игроки использующие маунтов
**Обход:** Не использовать маунтов. Если сели - выйти из игры вместо слезания.

---

### 2. Player Data Not Saving / Данные игроков не сохраняются
**Status:** Under investigation
**Severity:** High
**Date:** 2026-01-14

**Description:**
Player inventory files are 0 bytes or contain empty inventory (`"Items": {}`).
Items collected in-game are not persisted after server restart.

**Affected files:**
- `/opt/hytale-data/universe/players/*.json`

---

**Описание:**
Файлы инвентаря игроков 0 байт или содержат пустой инвентарь.
Предметы собранные в игре не сохраняются после перезапуска сервера.

---

### 3. Death Loot Despawn / Деспавн лута после смерти
**Status:** Likely intended behavior
**Severity:** Low (not a bug)
**Date:** 2026-01-15

**Description:**
Items dropped on death despawn after ~5-10 minutes.
Player returned after 10-15 minutes - items were gone.

This is likely standard game behavior, not a bug.

**Possible solutions:**
- Return to death point faster (<5 min)
- Check if server has `/gamerule` or similar to adjust despawn time

**Note:** Player deaths are NOT logged by the server, making debugging difficult.

---

**Описание:**
Предметы выпавшие при смерти исчезают через ~5-10 минут.
Игрок вернулся через 10-15 минут - предметов уже не было.

Скорее всего это стандартное поведение игры, не баг.

**Возможные решения:**
- Возвращаться к точке смерти быстрее (<5 мин)
- Проверить есть ли команды для изменения времени деспавна

**Примечание:** Смерти игроков НЕ записываются в логи сервера.

---

### 4. Day Counter Reset After Update / Сброс счётчика дней после обновления
**Status:** Active - under investigation
**Severity:** Low
**Date:** 2026-01-15

**Description:**
GameTime resets after running `docker compose run --rm updater`.

**Finding:**
- GameTime stored in `universe/worlds/default/config.json`
- Updater script does NOT touch `universe/` folder
- Possible cause: Hytale server itself resets GameTime on version change

**Finding from logs:**
- `Hytale:MigrationModule` plugin loads on startup
- May be responsible for GameTime reset during version migration
- This is likely Hytale's intended behavior during Early Access (data migrations between versions)

---

**Описание:**
GameTime сбрасывается после запуска `docker compose run --rm updater`.

**Находки:**
- GameTime хранится в `universe/worlds/default/config.json`
- Скрипт updater НЕ трогает папку `universe/`
- Возможная причина: сам Hytale сервер сбрасывает GameTime при смене версии

---

## Resolved Issues / Решённые проблемы

*(none yet)*

---

## How to Report / Как сообщить

Official Hytale bug report channels:
- Discord: https://discord.gg/hytale
- Support: https://support.hytale.com
