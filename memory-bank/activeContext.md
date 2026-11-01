# Active Context: Home Server

## Current Work Focus
**Внедрение Active Directory (реализовано, ожидает развёртывания на сервере).** Добавлен Samba AD DC (`service_samba_addc`) + файловый сервер переведён из standalone в member домена. Единая аутентификация для Linux/Windows/macOS через домен HOME.ARPA (настраивается в .env).

## Recent Changes (по git-истории)
- 2024+: sh-скрипты bash/ заменены на Makefile: user-add/user-del/user-pass/users (samba-tool) + env/up/down/logs/ps; README и память обновлены
- 2024+: АУДИТ samba_folder + автосинк ФС↔AD: новый home_sync.sh (авто-создание/архивация домашних каталогов по состоянию AD), исправлены баги: while-read-манглилг в run.sh → cat; add_user.sh — set -e + ожидание видимости юзера в winbind (гонка кэша) + парсинг .env от каталога скрипта; del_user.sh — set -e (ФС не трогаем при ошибке AD); [homes] — invalid users для встроенных учёток
- 2024+: добавлен проектный скил `.agents/skills/ponytail-lite/` (Lazy Senior Dev — «лестница лени» против over-engineering, порт MIT-скила ilindaniel/ponytail-lite с доп. правилами под home_server). Работает только для этого проекта: pi сканирует `.agents/skills/` автоматически; принудительно — команда `/skill:ponytail-lite`
- 2024+: РЕАЛИЗОВАН Active Directory: новый сервис `service_samba_addc` (Dockerfile + run.sh с provisioning домена), `service_samba_folder` переведён на security=ads + winbind + rid-idmap, сеть network_service получила subnet 172.28.0.0/24, добавлены `.env.example`/`.env` (секреты), скрипты `bash/add_user.sh`/`del_user.sh` переписаны под samba-tool, новые `ad_set_password.sh`/`ad_list_users.sh`, README переписан
- `b931dac` add info — добавлена ссылка в README (статья о проблеме авторизации Plex)
- `9a67e6e` remove login in transmission — отключена авторизация веб-UI Transmission
- `232f7e6..f1053ce` — правки .gitignore (не коммитить `folders/`)
- `7247437/af78fa6` init home server — начальная инициализация

## Next Steps (потенциальные)
- [ ] РАЗВЕРНУТЬ AD на живом сервере: `make env` (пароли!), `make up`; убедиться что порт 53 хоста свободен (dnsmasq/AdGuard конфликт)
- [ ] Настроить DHCP роутера: DNS = IP сервера (иначе клиенты не найдут домен по SRV)
- [ ] Пересоздать пользователей через `make user-add` (локальные юзеры старого samba в AD не переехали)
- [ ] Проверить вход в домен с Windows Pro / macOS / Linux (sssd), доступ к шарам `HOME\\user`
- Решить судьбу отключённых сервисов: ace_stream (образ сейчас не собирается — в Dockerfile упоминаются отсутствующие файлы `search.py`, `default.conf`, `nginx.conf`, `setup.cfg`) и ftp (vsftpd)
- Придумать безопасный способ передачи паролей в make user-add (сейчас пароль в аргументе командной строки; в паролях нельзя символ $)
- Рассмотреть бэкап `folders/plex_media_server/library` и конфигов Transmission
- Вернуть авторизацию или ограничить доступ к Transmission, если сеть перестанет быть доверенной

## Active Decisions and Considerations
- **Transmission без логина/пароля**: осознанное упрощение для домашней сети (коммит 9a67e6e), закомментированные переменные USER/PASS остались в docker-compose.yml на будущее
- **PLEX_CLAIM** закомментирован — сервер уже активирован
- **Собственные Dockerfile для Plex/Transmission не используются** — compose берёт готовые образы linuxserver; файлы в `services/plex_media_server/` и `services/transmission/` остались как наследие раннего подхода

## Important Patterns and Preferences
- Изменения конфигурации → правка docker-compose.yml / config-файлов + `docker compose up -d`
- Новые пользователи → только через скрипты `bash/` (теперь это доменные учётки через samba-tool)
- Ничего из `folders/` не коммитить (gitignore); секреты — только в `.env` (тоже gitignore)

## Learnings and Project Insights
- ⚠️ npm-пакет `ponytail` — НЕ официальный (чужой сквоттер); официальный — `@dietrichgebert/ponytail` / GitHub DietrichGebert/ponytail. У официала есть режимы lite/full/ultra/off + команды review/audit/debt/gain; у нас стоит сторонний lite-порт без режимов — при желании заменить на `pi install --local npm:@dietrichgebert/ponytail`
- Порт 445 на хосте один — его держит файловый сервер; AD DC без 445 = работает всё кроме GPO/SYSVOL для Windows
- Samba RPC dynamic ports зафиксирован на 49152 (smb.conf `rpc server port`), чтобы не публиковать диапазон 49152-65535
- Member-сервер вводится в домен при каждом старте контейнера (`net ads join` idempotent, `--no-dns-updates` чтобы не плодить A-записи с docker-IP)
- Docker embedded DNS не отдаёт SRV-записи — поэтому member'у прописан `dns: 172.28.0.53` (фиксированный IP DC в сети network_service)
- Проблема «не авторизован / нет доступа» в Plex — см. README
- Samba-пользователи не переживают пересоздание контейнера — это главное, что надо помнить при миграции/восстановлении
