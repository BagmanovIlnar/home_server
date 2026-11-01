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
- **Автосинк ФС ↔ AD (home_sync.sh)** — фоновый цикл в member-контейнере (SYNC_INTERVAL, по умолч. 60с): доменный юзер без каталога → создаётся users/<u> (chown u:domain users, 0700); каталог без юзера в AD → архивируется в users/.deleted/<u>_<ts> (не rm — защита от ложного срабатывания при недоступном DC; гарды wbinfo -P/-u). Работает независимо от способа создания юзера (make user-add / RSAT / samba-tool напрямую)
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
- `bash/add_user.sh` / `del_user.sh` → ЗАМЕНЕНЫ на Makefile: цели user-add/user-del/user-pass/users + env/up/down/logs/ps
- `services/samba_folder/run.sh` — генерация krb5.conf/smb.conf (member), авто-join, winbind+smbd
- `.env` — секреты и параметры домена (НЕ коммитить)

## Известные проблемы / подводные камни
- DC без порта 445 → Windows-клиенты: вход в домен и логин работают, GPO/SYSVOL — нет
- Порт 53 на хосте должен быть свободен (DC DNS); конфликт с dnsmasq/AdGuard/Pi-hole
- LAN-клиенты должны использовать сервер как DNS (настройка DHCP роутера), иначе SRV-записи домена не найдутся
- Kerberos чувствителен к времени: NTP на хосте обязателен
- `services/ace-stream/Dockerfile` ссылается на отсутствующие файлы (`search.py`, `setup.cfg`, `default.conf`, `nginx.conf`) — образ не собирается
- Transmission: авторизация веб-UI отключена — порт 9091 только из локальной сети
