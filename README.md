# Home Server

Домашний сервер на Docker Compose: **Active Directory (Samba AD DC)** + файловый сервер (Samba) + media-стек: **qBittorrent → Radarr/Sonarr/Lidarr → Jellyfin** + медиасервер **Plex**.

Единая аутентификация для **Linux, Windows, macOS** через собственный домен `HOME.ARPA`.

## Сервисы

| Сервис | Назначение | Порты |
|---|---|---|
| `service_samba_addc` | Samba AD DC: DNS, Kerberos, LDAP, пользователи | 53, 88, 135, 389, 464, 636, 3268, 3269, 49152 |
| `service_samba_folder` | Файлы: шара `home_share` + домашние каталоги `[homes]` | 445 |
| `service_qbittorrent` | Торрент-клиент (BitTorrent), web-UI | 8080, 6881 |
| `service_radarr` | Автозагрузка фильмов | 7878 |
| `service_sonarr` | Автозагрузка сериалов | 8989 |
| `service_lidarr` | Автозагрузка музыки | 8686 |
| `service_jellyfin` | Медиасервер | 8096 |
| `service_plex` | Медиасервер | 32400 |
| `service_tg_ws_proxy` | Telegram MTProto-прокси (WebSocket) | 1443 |
| ~~service_ace_stream, service_ftp~~ | Отключены (закомментированы) | — |

### Как связаны media-сервисы

Все сидят в общей сети compose и видят друг друга по именам; пути томов совпадают, поэтому Remote Path Mapping не нужен:

```
qBittorrent (/downloads) ──качает──▶ Radarr/Sonarr/Lidarr ──импортируют──▶ /media/{movies,tv,music} ──▶ Jellyfin (+Plex вручную)
```

Разовая настройка — в разделе «Настройка media-стека» ниже.

## Настройка media-стека (разовая, после первого `make up`)

Все адреса: `http://<IP-сервера>:<порт>` — qBittorrent `8080`, Radarr `7878`, Sonarr `8989`, Lidarr `8686`, Jellyfin `8096`.

### Шаг 1. qBittorrent — задать свой пароль

1. Пока постоянный пароль не задан, контейнер при каждом старте печатает в лог новый временный пароль:
   ```bash
   docker compose logs service_qbittorrent | grep -i password
   ```
2. Войди в web-UI `:8080` — логин `admin`, пароль из лога.
3. Меню ⚙ → Web UI → Authentication: укажи свои логин/пароль → Save. После этого временные пароли больше не генерируются.
4. Больше ничего настраивать не нужно: путь сохранения уже `/downloads`, peer-порт `6881` уже проброшен.

⚠️ Пароль из шага 1.3 понадобится в шаге 2 — его указывают в каждом *arr.

### Шаг 2. Radarr / Sonarr / Lidarr — одинаковая настройка (повторить в каждом)

**2.1. Защита входа (первый экран после установки):**
Settings → General → Authentication Method:
- `Forms (Login Page)` + свой пароль — если в LAN есть посторонние;
- `No Authentication` — упрощение для доверенной домашней сети.

**2.2. Клиент загрузок — qBittorrent:**
Settings → Download Clients → `+` → qBittorrent:

| Поле | Значение |
|---|---|
| Name | qBittorrent |
| Host | `service_qbittorrent` (имя сервиса в compose — контейнеры видят друг друга по нему) |
| Port | `8080` |
| Username / Password | логин/пароль из шага 1.3 |
| Category | необязательно: `radarr` / `sonarr` / `lidarr` — чтобы загрузки не перемешивались в `/downloads` |

→ `Test` (должно быть зелёное) → `Save`.

**2.3. Корневая папка (куда импортируется медиа):**
Settings → Media Management → Root Folders → `+`:
- Radarr: `/media/movies`
- Sonarr: `/media/tv`
- Lidarr: `/media/music`

**2.4. Индексеры (торрент-поиск) — без них *arr не находит релизы:**
Settings → Indexers → `+` → выбери доступные торрент-трекеры из списка (для приватных нужны логин/API-ключ, публичные добавляются сразу).

**2.5. Проверка:** Movie/Series/Artist → Search → добавь что-нибудь → *arr сам поставит задачу в qBittorrent (`:8080` → Transfers), после скачивания импортирует файл в корневую папку и удалит торрент.

### Шаг 3. Jellyfin — библиотеки

1. Мастер первого входа `:8096`: язык → создать пользователя с паролем.
2. Добавить библиотеки (Dashboard → Libraries → `+` Add Media Library):

| Путь | Тип контента |
|---|---|
| `/media/movies` | Movies |
| `/media/tv` | Shows |
| `/media/music` | Music |

3. В каждой библиотеке Preferred metadata language: `Russian`.
4. Новые файлы *arr подхватываются автоматически (планровщик сканирует библиотеки; форс — Dashboard → Libraries → Scan All Libraries).
5. Аппаратное транскодирование (Intel QuickSync): раскомментируй `devices: /dev/dri:/dev/dri` в docker-compose.yml → `make up-media` → Dashboard → Playback → Transcoding → Hardware acceleration: Intel QuickSync.

## Telegram-прокси (tg-ws-proxy)

[FlowSeal/tg-ws-proxy](https://github.com/FlowSeal/tg-ws-proxy) — MTProto-прокси (WebSocket), чтобы Telegram работал в домашней сети. Образ собирается из GitHub при первом `make up-tg` (пин тега в docker-compose.yml).

### Настройка (разовая)

1. В `.env` задай фиксированный секрет (иначе при каждом пересоздании контейнера генерируется новый — придётся заново настраивать клиентов):
   ```bash
   openssl rand -hex 16   # результат — в .env: TG_WS_PROXY_SECRET=...
   make up-tg
   ```
2. Получи ссылку подключения:
   ```bash
   docker compose logs service_tg_ws_proxy | grep 'tg://proxy'
   ```
3. Telegram-клиенты (Desktop / мобильные из LAN): Настройки → Продвинутые → Тип подключения → Прокси → добавить вручную:
   - **Тип:** MTProto
   - **Сервер:** `<IP-сервера>`
   - **Порт:** `1443`
   - **Secret:** значение `TG_WS_PROXY_SECRET` из `.env`

   (на мобильных достаточно открыть `tg://proxy?...` из логов по ссылке с сервера). Telegram Desktop также поддерживает импорт такой ссылки через «Импорт по ссылке».

## Первый запуск

```bash
make env    # создаст .env из шаблона — пропиши пароли (3 класса символов, от 7)
make up     # сборка + запуск
make logs   # ждать "provisioned" у service_samba_addc и статуса healthy
```

Первый старт DC создаёт домен и пишет базу в `folders/samba_addc/` (персистентна). Файловый сервер сам вводится в домен при каждом старте — это штатно.

## Управление и пользователи (make help — полная справка)

```bash
# запуск / остановка / сборка (как всего стека, так и по группе: up-dc, up-nas, up-plex, up-media, up-tg)
make up / down / build            # весь стек (down = только остановка, данные живы)
make up-nas / down-nas / build-dc # конкретный сервис

# ПОЛНОЕ удаление: контейнер + образ + volume + ВСЕ данные сервиса (prune не нужен)
make remove                        # весь стек (образы, volume, сеть, все folders/)
make remove-dc                     # + база домена (все юзеры AD!)
make remove-nas                    # + все домашние каталоги и общая шара
make remove-media                  # + все загрузки и медиатека media-стека
make remove-tg                     # + Telegram-прокси (данных нет)
make remove-plex                   # + медиатека

# пользователи домена
make user-add U=ivan P='Str0ng_Pass!'
make user-del U=ivan
make user-pass U=ivan P='New_Pass!'
make users

make ps / logs
```

⚠️ `remove-*` запрашивает подтверждение (обойти: `make remove-<x> CONFIRM=yes`) и удаляет данные БЕЗВОЗВРАТНО — образ, контейнер, анонимные volume и соответствующие каталоги в `folders/`. Остались git-заглушки `.gitignore`, чтобы структура репо не поехала.

⚠️ После `make remove-plex` сервер придётся заново привязать к plex.tv (Настройки → Удалённый доступ; при необходимости раскомментировать `PLEX_CLAIM` в docker-compose.yml с новым кодом с plex.tv/claim) и пересобрать библиотеки. Удалённый доступ извне LAN требует проброса порта 32400 на роутере.

Доступ к персональной шаре: `\\<IP-сервера>\ivan`, логин `HOME\ivan`.
Смена пароля Administrator: `docker exec -it service_samba_addc samba-tool user setpassword Administrator`.

## Решение проблем

### make up падает: «address already in use» на порту 53

Причина: DNS-заглушка systemd-resolved занимает порт 53 (слушает 127.0.0.53 и 127.0.0.54). Docker биндит 0.0.0.0:53, а wildcard-бинд конфликтует с любым занятым адресом на этом порту, даже loopback-адресом. Диагностика:

```bash
sudo ss -tlnp | grep ':53 '    # systemd-resolve = тот самый случай
```

**Лечение (один раз на хосте):**

```bash
# 1. Отключаем DNS-заглушку (падают оба слушателя .53 и .54)
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNSStubListener=no\n' | sudo tee /etc/systemd/resolved.conf.d/no-stub.conf

# 2. Хост должен резолвить мимо заглушки — переключаем resolv.conf на реальные upstream-DNS
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# 3. Перезапуск и проверка
sudo systemctl restart systemd-resolved
ss -tlnp | grep ':53 '    # должно быть пусто
make up
```

Если после этого хост не резолвит имена (в `/run/systemd/resolve/resolv.conf` нет серверов при статической конфигурации):

```bash
sudo rm /etc/resolv.conf
echo "nameserver 192.168.1.1" | sudo tee /etc/resolv.conf    # IP твоего роутера
```

**Другие случаи занятого порта 53:**
- `dnsmasq` — `sudo systemctl disable --now dnsmasq`
- libvirt (если виртуалки не нужны) — `sudo virsh net-destroy default && sudo virsh net-autostart --disable default`
- AdGuard Home / Pi-hole / bind9 — НЕ отключать вслепую: они раздают DNS сети; вместо этого настроить форвард зоны `home.arpa` на IP сервера

### Прочее

| Симптом | Лечение |
|---|---|
| `make up`: «нет .env» | `make env` + пропиши пароли в `.env` (шаблон `.env.example`) |
| provisioning падает: `PASSWORD_POLICIES` | пароль сложнее: 3 класса символов из 4, от 7 символов |
| «address already in use» на 445 | на хосте другой SMB-сервер (samba/nas) — остановить его |
| Windows: «домен не найден» | в DHCP роутера указать DNS = IP сервера (SRV-записи) |

## Подключение клиентов

**Обязательно:** клиенты должны использовать DNS домена — в роутере (DHCP) укажи DNS = IP этого сервера (порт 53).

- **Windows 10/11 Pro/Enterprise:** Параметры → Учётные записи → Доступ к уч. записи места работы → Подключить → `home.arpa`, логин `HOME\administrator`. *(Windows Home в домен не входит.)*
- **macOS:** Утилита каталогов → Active Directory → домен `HOME.ARPA` → Bind → `administrator`.
- **Linux (SSSD):** `apt install realmd sssd oddjob-mkhomedir adcli && realm join home.arpa -U administrator` (в `/etc/resolv.conf` DNS сервера).

## Ограничения (осознанные решения)

- **Порт 445 занят файловым сервером**, DC его не публикует → Windows-клиенты не получают GPO/SYSVOL (групповые политики). Вход в домен, логин, аутентификация — работают. Если нужны GPO — переноси шары на DC.
- **Порт 53 на хосте** должен быть свободен (конфликт с dnsmasq/AdGuard/Pi-hole, systemd-resolved обычно не мешает).
- Plex, Jellyfin, qBittorrent и *arr **не поддерживают AD** — у них свои локальные аккаунты.
- Машина-аккаунт файлового сервера пересоздаётся при `docker compose down/up` (автоматически, штатно).
- Данные домена: `folders/samba_addc/` — бэкапить.

## Помощь ИИ-агентам

Контекст проекта для ИИ (Cursor, Claude, Codex, Kilo): `memory-bank/`, вход — `AGENTS.md`.

Полезное: [Plex: «не авторизован, нет доступа к серверу»](https://itmemo.su/page/ne-avtorizovan-u-vas-net-dostupa-k-etomu-serveru)
