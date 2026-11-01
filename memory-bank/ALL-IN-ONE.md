# Memory Bank: Home Server — полная выгрузка (для веб-чатов Claude / ChatGPT)

> Авто-сгенерированный конкатенат всех файлов memory-bank. Прикрепи этот ОДИН файл в чат (claude.ai / chatgpt.com), если работаешь без агента с доступом к репозиторию. Актуальная версия — всегда в папке memory-bank/.

---

# ===== ФАЙЛ: projectbrief.md =====

# Project Brief: Home Server (домашний сервер)

## Overview
Персональный домашний сервер, разворачиваемый через Docker Compose на отдельной машине/хосте. Центральное звено — домен **Active Directory (Samba AD DC)** для единой аутентификации Linux/Windows/macOS; поверх — файловое хранилище (Samba member домена), торрент-качалка (Transmission) и медиасервер (Plex). Конфигурация декларативная, всё хранится в одном git-репозитории.

## Core Requirements
- **Active Directory (Samba AD DC)**: домен HOME.ARPA (DNS+Kerberos+LDAP), единые учётки для Linux/Windows/macOS
- Файловый сервер Samba (member домена): общая шара `home_share` (гостевой доступ) + персональные домашние каталоги доменных пользователей
- Управление пользователями через shell-скрипты (`bash/add_user.sh` = samba-tool, и др.)
- торрент-клиент Transmission с веб-интерфейсом (порт 9091) и watcher-каталогом для .torrent файлов
- Медиасервер Plex (порт 32400) с библиотекой, фильмами и сериалами
- Все данные (загрузки, медиа, конфиги) вынесены в `folders/` на хосте и переживают пересоздание контейнеров
- Автозапуск всех сервисов (`restart: always`)

## Goals
- Простой переносимый стек: `.env` + `docker compose up -d` поднимает весь сервер с доменом
- Данные и база домена отделены от контейнеров (volumes из `folders/`), переживают down/up
- Минимальное обслуживание, конфиги версонируются в git, секреты — только в `.env`

## Project Scope
**Входит:** AD DC + Samba member, Transmission, Plex; вспомогательные скрипты; заготовки (закомментированные) FTP (vsftpd) и Ace Stream.
**Не входит:** GPO/групповые политики (нет 445 у DC), reverse-proxy, HTTPS, мониторинг, бэкапы, интеграция AD с Plex/Transmission.

---

# ===== ФАЙЛ: productContext.md =====

# Product Context: Home Server

## Problem Statement
Нужен единый домашний сервер для семьи: общее файловое хранилище с разных устройств (ПК, ТВ, телефоны), автоматическая загрузка торрентов и удобный просмотр медиа (фильмы/сериалы) на любых клиентах. Ручная установка и настройка каждого сервиса на хосте неудобна и непереносима.

## Как это работает (пользовательский сценарий)
- Пользователь подключается к `\\<server>\home_share` без пароля для обмена файлами; у каждого пользователя есть личный каталог `\\<server>\<username>` с паролем (создаётся через `add_user.sh`)
- .torrent-файлы, положенные в watch-каталог Transmission, автоматически скачиваются в `folders/transmission/downloads`
- Загруженные фильмы/сериалы перемещаются в `folders/plex_media_server/movies` и `tvseries`, после чего появляются в библиотеке Plex и доступны на ТВ/телефоне/браузере

## User Experience Goals
- Нулевая настройка со стороны клиентов: SMB-протокол из коробки на всех ОС, веб-UI Transmission, нативные клиенты Plex
- Надёжность: сервисы перезапускаются сами, данные не теряются при пересоздании контейнеров
- Простое администрирование: один git-репозиторий, два скрипта для пользователей

## Success Metrics
- Семья регулярно пользуется шарой и Plex
- Torrent'ы качаются автоматически через watch-папку
- Восстановление сервера с нуля = clone репо + `docker compose up -d` + создание пользователей

## Дополнительный контекст
- README.md содержит ссылку на статью https://itmemo.su/page/ne-avtorizovan-u-vas-net-dostupa-k-etomu-serveru — решение проблемы авторизации Plex («не авторизован, нет доступа к серверу»)

---

# ===== ФАЙЛ: systemPatterns.md =====

# System Patterns: Home Server

## System Architecture
Монолитный Docker Compose-стек на одном хосте. Ядро — домен Active Directory (Samba AD DC); файловый сервер — member домена; остальные сервисы независимы, связаны только через тома (volumes) в `folders/`.

```
docker-compose.yml
├── service_samba_addc      ← AD DC: DNS 53, Kerberos 88, RPC 135/49152, LDAP 389/636, GC 3268/3269
│     сеть: network_service (фикс. IP 172.28.0.53 — он же DNS для member'а и LAN)
│     состояние: folders/samba_addc/{etc,lib} (персистентно; при первом старте — provisioning домена)
├── service_samba_folder    ← member домена (security=ads, winbind, idmap rid), порт 445
│     join при каждом старте (net ads join --no-dns-updates)
│   ├── folders/users   -> /var/home-service/users   ([homes] доменных юзеров)
│   ├── folders/share   -> /var/home-service/share   (общая шара home_share)
│   └── services/samba_folder/config -> /etc/samba/smb.conf.d (секции шар)
├── service_transmission   (linuxserver/transmission, порты 9091, 51413/tcp+udp)
├── service_plex           (linuxserver/plex, порт 32400)
├── #service_ace_stream    (ЗАКОММЕНТИРОВАН)
└── #service_ftp           (ЗАКОММЕНТИРОВАН)
```

Сеть: `network_service` (subnet 172.28.0.0/24, DC — 172.28.0.53). Transmission/Plex вне этой сети.

## Key Technical Decisions
- **Active Directory на Samba AD DC** в отдельном контейнере + файловый сервер как member (security=ads + winbind + idmap rid 10000-999999). Домен HOME.ARPA (RFC 8375), NetBIOS HOME, DC dc1 — всё переопределяется в `.env`
- **Порт 445 опубликован только у файлового сервера** — DC без 445: работает join/логин/аутентификация, НЕ работают GPO/SYSVOL для Windows (осознанный компромисс домашней среды)
- **RPC dynamic ports зафиксирован на 49152** (`rpc server port`) + 135 — вместо публикации диапазона 49152-65535
- **Provisioning домена при первом старте** run.sh DC (проверка sam.ldb), база в volume → юзеры и машина переживают down/up
- **Member делает net ads join при каждом старте** (машинный секрет не персистентится) — штатно; DNS-обновления отключены (--no-dns-updates, чтобы не писать docker-IP в DNS)
- **Member использует DNS от DC** (`dns: 172.28.0.53`) — docker embedded DNS не умеет SRV; DC сам форвардит внешние запросы к AD_DNS_FORWARDER
- **Секреты в `.env`** (gitignore): AD_ADMIN_PASSWORD, AD_JOIN_PASSWORD; шаблон — `.env.example`
- **Готовые образы linuxserver.io** для Transmission и Plex; Samba-сервисы собираются кастомно из ubuntu:22.04
- **Конфиги шар Samba** — файлы в smb.conf.d, при старте run.sh генерирует [global] (домен) и приклеивает шары через cat (построчный while-read убран — манглил бэкслэши/пробелы)
- **Автосинк ФС ↔ AD (home_sync.sh)** — фоновый цикл в member-контейнере (SYNC_INTERVAL, по умолч. 60с): доменный юзер без каталога → создаётся users/<u> (chown u:domain users, 0700); каталог без юзера в AD → архивируется в users/.deleted/<u>_<ts> (не rm — защита от ложного срабатывания при недоступном DC; гарды wbinfo -P/-u). Работает независимо от способа создания юзера (add_user.sh / RSAT / samba-tool напрямую)
- **[homes] защищён** invalid users = root Administrator krbtgt Guest; встроенные учётки не получают шары
- **Данные отделены от контейнеров** — всё в `folders/`, каталог в `.gitignore`

## Design Patterns in Use
- Declarative infrastructure-as-code (docker-compose)
- Volume-mounted configuration (конфиги подключаются с хоста)
- Admin-скрипты как «API поверх docker exec» (управление пользователями)

## Component Relationships
- AD DC ←join— Файловый сервер (аутентификация доменных юзеров на шарах через winbind)
- LAN-клиенты (Win/Mac/Linux) → DNS 53 сервера → SRV-записи → Kerberos/LDAP DC → вход в домен; шары → 445 файлового сервера (логин HOME\user)
- Transmission (downloads) -> [ручное перемещение] -> Plex (movies/tvseries). Автоматизации связи нет.
- Plex/Transmission с AD НЕ интегрируются (свои локальные аккаунты)

## Critical Implementation Paths
- `docker-compose.yml` — сервисы, порты, subnet 172.28.0.0/24, .env-переменные
- `services/samba_addc/run.sh` — provisioning домена при первом старте, `exec samba -i`
- `services/samba_folder/run.sh` — генерация krb5.conf/smb.conf (member), авто-join, winbind+smbd
- `bash/add_user.sh` / `del_user.sh` / `ad_set_password.sh` / `ad_list_users.sh` — жизненный цикл доменных юзеров
- `.env` — секреты и параметры домена (НЕ коммитить)

## Известные проблемы / подводные камни
- DC без порта 445 → Windows-клиенты: вход в домен и логин работают, GPO/SYSVOL — нет
- Порт 53 на хосте должен быть свободен (DC DNS); конфликт с dnsmasq/AdGuard/Pi-hole
- LAN-клиенты должны использовать сервер как DNS (настройка DHCP роутера), иначе SRV-записи домена не найдутся
- Kerberos чувствителен к времени: NTP на хосте обязателен
- `services/ace-stream/Dockerfile` ссылается на отсутствующие файлы (`search.py`, `setup.cfg`, `default.conf`, `nginx.conf`) — образ не собирается
- Transmission: авторизация веб-UI отключена — порт 9091 только из локальной сети

---

# ===== ФАЙЛ: techContext.md =====

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
- `bash/add_user.sh -u <user> -p <pass>` — доменный юзер (samba-tool) + домашний каталог с chown HOME\user
- `bash/del_user.sh -u <user>` — удалить юзера и каталог
- `bash/ad_set_password.sh -u <user> -p <pass>` / `bash/ad_list_users.sh` — пароли/список
- Управление сервисами — `docker compose` (up/down/logs/build); при `down/up` member сам переjoin'ится — это штатно
- Диагностика домена: `docker exec service_samba_addc samba-tool dns query localhost HOME.ARPA @ ALL -U administrator`

---

# ===== ФАЙЛ: activeContext.md =====

# Active Context: Home Server

## Current Work Focus
**Внедрение Active Directory (реализовано, ожидает развёртывания на сервере).** Добавлен Samba AD DC (`service_samba_addc`) + файловый сервер переведён из standalone в member домена. Единая аутентификация для Linux/Windows/macOS через домен HOME.ARPA (настраивается в .env).

## Recent Changes (по git-истории)
- 2024+: АУДИТ samba_folder + автосинк ФС↔AD: новый home_sync.sh (авто-создание/архивация домашних каталогов по состоянию AD), исправлены баги: while-read-манглилг в run.sh → cat; add_user.sh — set -e + ожидание видимости юзера в winbind (гонка кэша) + парсинг .env от каталога скрипта; del_user.sh — set -e (ФС не трогаем при ошибке AD); [homes] — invalid users для встроенных учёток
- 2024+: добавлен проектный скил `.agents/skills/ponytail-lite/` (Lazy Senior Dev — «лестница лени» против over-engineering, порт MIT-скила ilindaniel/ponytail-lite с доп. правилами под home_server). Работает только для этого проекта: pi сканирует `.agents/skills/` автоматически; принудительно — команда `/skill:ponytail-lite`
- 2024+: РЕАЛИЗОВАН Active Directory: новый сервис `service_samba_addc` (Dockerfile + run.sh с provisioning домена), `service_samba_folder` переведён на security=ads + winbind + rid-idmap, сеть network_service получила subnet 172.28.0.0/24, добавлены `.env.example`/`.env` (секреты), скрипты `bash/add_user.sh`/`del_user.sh` переписаны под samba-tool, новые `ad_set_password.sh`/`ad_list_users.sh`, README переписан
- `b931dac` add info — добавлена ссылка в README (статья о проблеме авторизации Plex)
- `9a67e6e` remove login in transmission — отключена авторизация веб-UI Transmission
- `232f7e6..f1053ce` — правки .gitignore (не коммитить `folders/`)
- `7247437/af78fa6` init home server — начальная инициализация

## Next Steps (потенциальные)
- [ ] РАЗВЕРНУТЬ AD на живом сервере: `cp .env.example .env` (пароли!), `docker compose up -d --build`; убедиться что порт 53 хоста свободен (dnsmasq/AdGuard конфликт)
- [ ] Настроить DHCP роутера: DNS = IP сервера (иначе клиенты не найдут домен по SRV)
- [ ] Пересоздать пользователей через новый `bash/add_user.sh` (локальные юзеры старого samba в AD не переехали)
- [ ] Проверить вход в домен с Windows Pro / macOS / Linux (sssd), доступ к шарам `HOME\\user`
- Решить судьбу отключённых сервисов: ace_stream (образ сейчас не собирается — в Dockerfile упоминаются отсутствующие файлы `search.py`, `default.conf`, `nginx.conf`, `setup.cfg`) и ftp (vsftpd)
- Автоматизировать восстановление пользователей Samba (сейчас после пересоздания контейнера надо вручную гонять `add_user.sh`)
- Придумать безопасный способ передачи паролей в `add_user.sh` (сейчас пароль в аргументе командной строки)
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

---

# ===== ФАЙЛ: progress.md =====

# Progress: Home Server

## What Works
- ✅ **Samba AD DC** (service_samba_addc): новый сервис — домен-контроллер (DNS+Kerberos+LDAP+GC), provisioning при первом старте, база персистентна в folders/samba_addc/, healthcheck через SRV-запрос; ФИЗИЧЕСКИ НЕ РАЗВЁРНУТ на сервере — код написан, ждёт docker compose up
- ✅ **Файловый сервер в домене** (service_samba_folder): security=ads, winbind, rid-idmap, авто-join при старте; шары home_share + [homes] для доменных юзеров; АВТОСИНК домашних каталогов с AD (home_sync.sh): создание при появлении юзера, архивация в .deleted при удалении
- ✅ **Управление пользователями AD**: add_user.sh / del_user.sh (samba-tool) + ad_set_password.sh + ad_list_users.sh
- ~~✅ Управление пользователями: `bash/add_user.sh` (useradd + smbpasswd + каталог с правами 775), `bash/del_user.sh`~~ → заменено на доменные учётки через samba-tool
- ✅ **Transmission** (linuxserver): web-UI на 9091 без авторизации, peer-порт 51413, watch-папка `folders/transmission/torrents`, загрузки в `folders/transmission/downloads`
- ✅ **Plex** (linuxserver): порт 32400, библиотека/фильмы/сериалы в `folders/plex_media_server/`, активирован (PLEX_CLAIM больше не нужен)
- ✅ Все сервисы с `restart: always`, данные персистятся в `folders/`
- ✅ README со ссылкой на решение проблемы авторизации Plex

## What's Left to Build / потенциальные задачи
- ⬜ Развёртывание AD на сервере (.env, up, DNS роутера на сервер, пересоздание юзеров, join клиентов Win/Mac/Linux)
- ⬜ Проверка ограничений: GPO/SYSVOL с Windows недоступны (нет 445 у DC) — подтвердить, что для семьи это не критично
- ⬜ Решение по ace_stream: образ не собирается (в Dockerfile отсутствуют `search.py`, `setup.cfg`, `default.conf`, `nginx.conf`), сервис закомментирован
- ⬜ Решение по FTP (vsftpd): полностью готов (Dockerfile, run.sh, vsftpd.conf), но закомментирован в compose; помечен как service_ftp1
- ⬜ Бэкапы конфигураций и библиотек Plex
- ⬜ Безопасность: пароль Transmission, firewall-правила

## Known Issues and Limitations
- ⚠️ AD DC не публикует порт 445 (его занимает файловый сервер): Windows-клиенты не получают GPO/SYSVOL; вход/логин/аутентификация работают
- ⚠️ Порт 53 хоста должен быть свободен для DC DNS (конфликт с dnsmasq/AdGuard/Pi-hole)
- ⚠️ Локальные юзеры старого standalone-samba НЕ мигрировали в AD — пересоздать через add_user.sh
- ⚠️ Windows Home в домен не входит (нужна Pro/Enterprise); Plex/Transmission AD не поддерживают
- ⚠️ Transmission web-UI без аутентификации — безопасно только в доверенной LAN
- ⚠️ Лишние/мёртвые файлы: Dockerfile+run.sh для plex и transmission не используются (compose берёт linuxserver-образы); старая закомментированная секция в ace-stream Dockerfile
- ⚠️ Общая шара `home_share` с `guest ok = yes` и масками 0777 — любой в LAN может писать/читать
- ⚠️ `.idea/` частично в git (в .gitignore только верхоуровневая запись, история коммитила)

## Evolution of Project Decisions
- 2024+: добавлен Samba AD DC для единой аутентификации Linux/Windows/macOS; файловый сервер стал member домена; локальные юзеры smbpasswd заменены на samba-tool
- Сначала подход «всё собираем сами из ubuntu:22.04» (Dockerfile'ы для samba, ftp, transmission, plex, ace-stream)
- Затем переход на готовые образы linuxserver для Transmission и Plex (собственные Dockerfile'ы остались как артефакты)
- Ace Stream: первая версия (HTTPAceProxy + acestream 3.1.74 на ubuntu:18.04, python2) была заброшена и закомментирована; вторая попытка на базе `vstavrinov/acestream-engine` тоже не доведена до конца
- FTP-сервис был рабочей альтернативой файлового доступа, но вытеснен Samba и отключён
- Убрана авторизация Transmission для удобства в домашней сети

---

# ===== ФАЙЛ: memory_bank_instructions.md =====

# Memory Bank Instructions: Home Server

I am coding AI assistant, an expert software engineer with a unique characteristic: my memory resets completely between sessions.
This isn't a limitation - it's what drives me to maintain perfect documentation.
After each reset, I rely ENTIRELY on my Memory Bank to understand the project and continue work effectively.
I MUST read ALL memory bank files at the start of EVERY task - this is not optional.

## Memory Bank Structure

The Memory Bank consists of core files, all in Markdown format. Files build upon each other in a clear hierarchy:

flowchart TD
    PB[projectbrief.md] --> PC[productContext.md]
    PB --> SP[systemPatterns.md]
    PB --> TC[techContext.md]

    PC --> AC[activeContext.md]
    SP --> AC
    TC --> AC

    AC --> P[progress.md]

### Core Files (Required)
1. `projectbrief.md` — Foundation document that shapes all other files; source of truth for scope
2. `productContext.md` — Why this project exists, problems it solves, UX goals
3. `activeContext.md` — Current work focus, recent changes, next steps
4. `systemPatterns.md` — Architecture, technical decisions, design patterns
5. `techContext.md` — Technologies, setup, constraints, dependencies
6. `progress.md` — What works, what's left, known issues

### Additional Files (optional, created when justified)
- `README.md` (root) — user-facing note (сейчас: ссылка на решение проблемы Plex)

## Documentation Standards
- Файлы Memory Bank на русском языке (язык владельца проекта)
- Даты и факты — только из git-истории и содержимого файлов, не выдумывать
- Обновлять `activeContext.md` и `progress.md` после каждой значимой сессии изменений
- Учитывать, что часть сервисов отключена (закомментирована) — не считать их активными

## Workflow
1. **Session start:** прочитать все файлы memory-bank/, начиная с projectbrief.md
2. **Перед изменениями:** свериться с systemPatterns.md (архитектура) и techContext.md (ограничения)
3. **После изменений:** обновить activeContext.md (Recent Changes, Next Steps) и progress.md (What Works / Issues)
4. **При смене решений:** отразить эволюцию в progress.md → Evolution of Project Decisions

## Core Workflows проекта (для быстрого старта)
- Полный перезапуск: `docker compose up -d --build`
- Новый пользователь Samba: `bash/add_user.sh -u <user> -p <pass>`
- Удаление пользователя: `bash/del_user.sh -u <user>`

