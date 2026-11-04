# Active Context: Home Server

## Current Work Focus
**Media-стек: Transmission заменён на qBittorrent, добавлены Radarr/Sonarr/Lidarr/Jellyfin** (ожидает развёртывания на сервере). AD (Samba AD DC) реализован ранее, тоже ждёт развёртывания.

## Recent Changes (по git-истории)
- 2024+: MEDIA-СТЕК: Transmission удалён (сервис из compose, legacy-каталог services/transmission), добавлены service_qbittorrent (8080/6881, BitTorrent-клиент), service_radarr (7878), service_sonarr (8989), service_lidarr (8686), service_jellyfin (8096). Связь: общие тома — folders/qbittorrent/downloads монтируется как /downloads в qBittorrent+все *arr, folders/media как /media в *arr+Jellyfin (одинаковые пути => Remote Path Mapping не нужен); все в default-сети compose, друг друга видят по именам (клиент загрузок в *arr: service_qbittorrent:8080). Plex остался рядом (свои каталоги folders/plex_media_server). Makefile: transmission-цели заменены на group-цели up/down/build/remove-media. Старые загрузки Transmission остались в folders/transmission на сервере (не удалялись, перенести вручную при желании)
- 2024+: README: подробная пошаговая настройка media-стека (пароль qBittorrent из лога → аутентификация+download client+root folder+индексеры в каждом *arr → библиотеки Jellyfin /media/*)
- 2024+: TELEGRAM-ПРОКСИ: добавлен service_tg_ws_proxy (FlowSeal/tg-ws-proxy, MTProto over WebSocket, порт 1443). Образ собирается из GitHub с пином тега v1.11.4 (context: https://github.com/FlowSeal/tg-ws-proxy.git#v1.11.4). Секрет TG_WS_PROXY_SECRET в .env (пусто = random при каждом пересоздании, ссылка tg://proxy в логах). Makefile: up/down/build/remove-tg. README: раздел «Telegram-прокси»
- 2024+: sh-скрипты bash/ заменены на Makefile: user-add/user-del/user-pass/users (samba-tool) + env/up/down/logs/ps; README и память обновлены
- 2024+: krb5-user в ubuntu:26.04 интерактивно спрашивает realm при apt install (debconf-диалог) — глушится ARG DEBIAN_FRONTEND=noninteractive + debconf-set-selections пресидами в обоих Dockerfile (значения неважны: krb5.conf генерится в run.sh)
- 2024+: БАЗА ОБРАЗОВ: ubuntu 22.04 → 26.04 LTS (addc/folder/ftp + мёртвые plex/transmission Dockerfile); в DC добавлен samba-ad-provision; проверено: init.d smbd/winbind в resolute, rpc server port актуален, пакет в resolute-updates есть
- 2024+: АУДИТ service_plex: compose-конфиг корректен; TZ параметризован через \${TZ} (plex+transmission); добавлены build-plex/build-transmission (pull готовых образов), build теперь и pull'ит; задокументировано: после remove-plex — повторная привязка plex.tv (PLEX_CLAIM) и пересборка библиотек
- 2024+: Makefile расширен группами целей: up-*/down-*/build-*/remove-* (по каждому сервису dc/nas/plex/transmission); remove-* — полное удаление (контейнер+образ+volume+данные folders/, с подтверждением и CONFIRM=yes для обхода), чтобы prune не требовался
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
- ⚠️ РЕАЛЬНЫЙ ДЕПЛОЙ: порт 53 на Ubuntu-хосте занят systemd-resolved (127.0.0.53+.54) — wildcard-бинг docker 0.0.0.0:53 конфликтует даже с loopback-слушателем. Лечение (задокументировано в README «Решение проблем»): DNSStubListener=no через drop-in + ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf + restart. Прошло на сервере
- ⚠️ npm-пакет `ponytail` — НЕ официальный (чужой сквоттер); официальный — `@dietrichgebert/ponytail` / GitHub DietrichGebert/ponytail. У официала есть режимы lite/full/ultra/off + команды review/audit/debt/gain; у нас стоит сторонний lite-порт без режимов — при желании заменить на `pi install --local npm:@dietrichgebert/ponytail`
- Порт 445 на хосте один — его держит файловый сервер; AD DC без 445 = работает всё кроме GPO/SYSVOL для Windows
- Samba RPC dynamic ports зафиксирован на 49152 (smb.conf `rpc server port`), чтобы не публиковать диапазон 49152-65535
- Member-сервер вводится в домен при каждом старте контейнера (`net ads join` idempotent, `--no-dns-updates` чтобы не плодить A-записи с docker-IP)
- Docker embedded DNS не отдаёт SRV-записи — поэтому member'у прописан `dns: 172.28.0.53` (фиксированный IP DC в сети network_service)
- Проблема «не авторизован / нет доступа» в Plex — см. README
- Samba-пользователи не переживают пересоздание контейнера — это главное, что надо помнить при миграции/восстановлении
