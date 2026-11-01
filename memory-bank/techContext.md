# Tech Context: Home Server

## Technologies Used
- **Docker Compose** (version "3.9") — оркестрация всех сервисов
- **Samba AD DC** (custom build ubuntu:22.04) — Active Directory: DNS (SAMBA_INTERNAL), Kerberos KDC, LDAP/LDAPS, Global Catalog; домен HOME.ARPA
- **Samba member + winbind** (custom build) — файловый сервер в домене, idmap rid, порт 445
- **Kerberos/krb5** — аутентификация (порты 88, 464)
- **Transmission** — образ `lscr.io/linuxserver/transmission:latest`, порты 9091 (web UI без пароля), 51413 tcp/udp
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
- Transmission без пароля — доступ только из доверенной LAN
- Windows Home не входит в домен; Plex/Transmission не поддерживают AD/LDAP

## Dependencies
- linuxserver/transmission:latest (docker hub lscr.io)
- linuxserver/plex:latest (docker hub lscr.io)
- ubuntu:22.04 (база для custom-сборок samba/ftp)
- vstavrinov/acestream-engine (для отключённого ace-stream; образ сейчас не собирается — отсутствуют файлы контекста)

## Tool Usage Patterns
- `make help` — справка; `make user-add U=<user> P=<pass>` — доменный юзер + домашний каталог (chown DOMAIN\user, 0700, с ожиданием видимости в winbind)
- `make user-del U=<user>` / `make user-pass U= P=` / `make users` — удаление/пароль/список
- `make env` / `up[-dc|nas|plex|transmission]` / `down[-...]` — запуск/остановка (всего стека или по сервису; down = только stop, данные живы)
- `make build[-dc|nas]` — сборка кастомных образов
- `make remove[-dc|nas|plex|transmission]` — ПОЛНОЕ удаление: контейнер + образ + анонимные volume + данные в folders/ (rm -rf с восстановлением git-заглушек .gitignore); подтверждение через read, обход — CONFIRM=yes; цель — чтобы docker prune был не нужен
- Управление руками: `docker compose ...`; при down/up member сам переjoin'ится — штатно
- Диагностика домена: `docker exec service_samba_addc samba-tool dns query localhost HOME.ARPA @ ALL -U administrator`
