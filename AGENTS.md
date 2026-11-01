# AGENTS.md — правила для ИИ-ассистентов

Перед началом ЛЮБОЙ задачи в этом репозитории прочитай все файлы Memory Bank в `memory-bank/`:
`projectbrief.md` → `productContext.md` → `systemPatterns.md` → `techContext.md` → `activeContext.md` → `progress.md`

## Кратко о проекте
Домашний сервер на Docker Compose: домен Active Directory (Samba AD DC) + файловый сервер Samba (member домена), Transmission (торренты), Plex (медиа). Подробности — только в memory-bank, не полагайся на память.

## Правила
- Перед началом ЛЮБОЙ задачи прочитай все файлы Memory Bank в `memory-bank/`
- После значимых изменений обновляй `memory-bank/activeContext.md` и `memory-bank/progress.md`
- Ничего из `folders/` и `.env` не коммитить (там данные и секреты)
- Пользователи домена — только через `bash/add_user.sh` / `bash/del_user.sh` (samba-tool)
- Сервисы ace-stream и ftp в docker-compose.yml закомментированы — они НЕ активны
- Ответы и документация — на русском
