# Tech Context: Home Server

## Technologies Used
- **Docker Compose** (version "3.9") — оркестрация всех сервисов
- **Samba AD DC** (custom build ubuntu:26.04 LTS) — Active Directory: DNS (SAMBA_INTERNAL), Kerberos KDC, LDAP/LDAPS, Global Catalog; домен HOME.ARPA
- **Samba member + winbind** (custom build ubuntu:26.04 LTS) — файловый сервер в домене, idmap rid, порт 445
- **Kerberos/krb5** — аутентификация (порты 88, 464)
- **Media-стек (linuxserver)** — qBittorrent (8080 web UI, 6881 tcp/udp peer), Radarr 7878, Sonarr 8989, Lidarr 8686, Jellyfin 8096; связаны общими томами /downloads (qBittorrent+*arr) и /media (*arr+Jellyfin) + default-сеть compose
- **Portainer** (portainer/portainer-ce) — web-UI Docker, порт 9443 (https), docker.sock монтируется (root-доступ к хосту — осознанно), данные folders/portainer
- **MeTube** (alexta69/metube, порт 8081) — yt-dlp web-UI, /downloads = folders/metube/downloads; **SearXNG** (searxng/searxng, 8888→8080) — метапоисковик, settings автогенерация при первом старте
- **Bazarr** (lscr.io/linuxserver/bazarr) — субтитры для media-стека, порт 6767, том /media; API Radarr/Sonarr через UI
- **Ace Stream Engine 3.2.11** — кастомная сборка (ubuntu:22.04 base + официальный тарбл download.acestream.media/linux; cp310 => только 22.04), порт 6878, multi-stage (builder: apsw/lxml/PyNaCl/pycryptodome/isodate), healthcheck get_version
- **Vaultwarden** (vaultwarden/server — официального образа у linuxserver.io нет, lscr.io-путь отвечал `denied` и валил весь make up) — пароли (Bitwarden-совместимый), порт 8222, sqlite; HTTP для нативных клиентов/расширения, web-vault требует HTTPS; SIGNUPS_ALLOWED/ADMIN_TOKEN из .env
- **registry:2** — Docker Registry, порт 5000, HTTP (клиентам нужен insecure-registries в daemon.json), данные в folders/registry, без аутентификации (доверенная LAN; Harbor отклонён как overkill)
- **tg-ws-proxy** (FlowSeal/tg-ws-proxy, MTProto over WebSocket) — Telegram-прокси, порт 1443; образ собирается из git-контекста с пином тега v1.11.4; секрет TG_WS_PROXY_SECRET в .env (пусто = random на каждый рестарт)
- **Plex Media Server** — образ `lscr.io/linuxserver/plex:latest`, порт 32400
- **vsftpd** (отключён), **Ace Stream** (отключён, образ не собирается)
- **Shell-скрипты** (POSIX sh) — управление доменными пользователями через samba-tool

## Development Setup
- Хост: Linux-сервер с Docker/Docker Compose (на Mac-рабочей копии docker нет — валидация yaml/скриптов сделана без запуска)
- Обязательно: `cp .env.example .env` и заполнить пароли (AD_ADMIN_PASSWORD, AD_JOIN_PASSWORD — сложные: 3 класса символов, от 7 символов)
- Запуск: `docker compose up -d --build`; логи домена: `docker compose logs -f service_samba_addc`
- Репозиторий: git; данные: `folders/` (gitignore), секреты: `.env` (gitignore)

## Technical Constraints
- Сеть `network_service` = 172.28.0.0/24; DC всегда 172.28.0.53 (на него завязаны dns: и extra_hosts у member'а)
- Порт 53 хоста — только для DC DNS; порт 445 — только для файлового сервера (у DC не публикуется → GPO/SYSVOL недоступны с Windows)
- Клиенты домена (Win/Mac/Linux) должны получать DNS = IP сервера (настройка DHCP роутера) — иначе SRV-записи не резолвятся
- Kerberos требует точного времени: NTP на хосте обязателен (контейнеры наследуют часы хоста)
- Домен HOME.ARPA / NetBIOS HOME — смена через .env (переделать provisioning: удалить folders/samba_addc/lib)
- Контейнеры linuxserver: PUID=1000, PGID=1000, TZ=Europe/Moscow
- qBittorrent: временный пароль в логе контейнера при первом старте (сменить)
- Windows Home не входит в домен; Plex/Jellyfin/qBittorrent/*arr не поддерживают AD/LDAP

## Dependencies
- linuxserver/qbittorrent|radarr|sonarr|lidarr|jellyfin:latest (docker hub lscr.io)
- linuxserver/plex:latest (docker hub lscr.io)
- ubuntu:26.04 LTS (база для custom-сборок; обновлено с 22.04; проверено: samba-ad-provision, init.d smbd/winbind, rpc server port — всё на месте)
- vstavrinov/acestream-engine (для отключённого ace-stream; образ сейчас не собирается — отсутствуют файлы контекста)

## Tool Usage Patterns
- `make help` — справка; `make user-add U=<user> P=<pass>` — доменный юзер + домашний каталог (chown DOMAIN\user, 0700, с ожиданием видимости в winbind)
- `make user-del U=<user>` / `make user-pass U= P=` / `make users` — удаление/пароль/список
- `make env` / `up[-dc|nas|plex|media]` / `down[-...]` — запуск/остановка (всего стека или по сервису; down = только stop, данные живы)
- `make build[-dc|nas]` — сборка кастомных образов
- `make remove[-dc|nas|plex|media]` — ПОЛНОЕ удаление: контейнер + образ + анонимные volume + данные в folders/ (rm -rf с восстановлением git-заглушек .gitignore); подтверждение через read, обход — CONFIRM=yes; цель — чтобы docker prune был не нужен
- Управление руками: `docker compose ...`; при down/up member сам переjoin'ится — штатно
- Диагностика домена: `docker exec service_samba_addc samba-tool dns query localhost HOME.ARPA @ ALL -U administrator`
