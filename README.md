# Home Server

Домашний сервер на Docker Compose: **Active Directory (Samba AD DC)** + файловый сервер (Samba) + media-стек: **qBittorrent → Radarr/Sonarr/Lidarr (+Bazarr) → Jellyfin** + медиасервер **Plex**, Ace Stream, MeTube (видео с YouTube), Telegram-прокси, Docker Registry, Vaultwarden (пароли) и SearXNG (поиск).

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
| `service_bazarr` | Субтитры для фильмов и сериалов | 6767 |
| `service_jellyfin` | Медиасервер | 8096 |
| `service_plex` | Медиасервер | 32400 |
| `service_tg_ws_proxy` | Telegram MTProto-прокси (WebSocket) | 1443 |
| `service_registry` | Docker Registry — хранилище собственных образов | 5000 |
| `service_vaultwarden` | Vaultwarden — пароли (Bitwarden-совместимый сервер) | 8222 |
| `service_acestream` | Ace Stream Engine 3.2.11 — p2p-стриминг | 6878 |
| `service_metube` | MeTube — загрузка видео с YouTube и 100+ сайтов (yt-dlp) → /media/youtube | 8081 |
| `service_searxng` | SearXNG — приватный метапоисковик | 8888 |
| `service_portainer` | Portainer — web-UI управления Docker | 9443 |
| ~~service_ftp~~ | Отключён (закомментирован) | — |

### Как связаны media-сервисы

Все сидят в общей сети compose и видят друг друга по именам; пути томов совпадают, поэтому Remote Path Mapping не нужен:

```
qBittorrent (/downloads) ──качает──▶ Radarr/Sonarr/Lidarr ──импортируют──▶ /media/{movies,tv,music} ──▶ Jellyfin (авто) + Plex (после п.4)
                                        └─ Bazarr: субтитры к /media/{movies,tv}
MeTube (:8081, yt-dlp) ──────────────────────────────────▶ /media/youtube ──▶ Jellyfin/Plex (после п.5)
```

Разовая настройка — в разделе «Настройка media-стека» ниже.

## Первый запуск

```bash
make env    # создаст .env из шаблона — пропиши пароли (3 класса символов, от 7)
make up     # сборка + запуск
make logs   # ждать "provisioned" у service_samba_addc и статуса healthy
```

Первый старт DC создаёт домен и пишет базу в `folders/samba_addc/` (персистентна). Файловый сервер сам вводится в домен при каждом старте — это штатно.

В `.env` есть и опциональные переменные (см. соответствующие разделы): `TG_WS_PROXY_SECRET` (Telegram-прокси), `SIGNUPS_ALLOWED` / `ADMIN_TOKEN` (Vaultwarden), `SEARXNG_BASE_URL` (SearXNG) — их можно заполнить позже.

## Управление и пользователи (make help — полная справка)

```bash
# запуск / остановка / сборка: весь стек или по группе
# (up-dc, up-nas, up-plex, up-media, up-tg, up-registry, up-vaultwarden, up-acestream, up-metube, up-searxng, up-portainer)
make up / down / build            # весь стек (down = только остановка, данные живы)
make up-nas / down-nas / build-dc # конкретный сервис

# ПОЛНОЕ удаление: контейнер + образ + volume + ВСЕ данные сервиса (prune не нужен)
make remove                        # весь стек (образы, volume, сеть, все folders/)
make remove-dc                     # + база домена (все юзеры AD!)
make remove-nas                    # + все домашние каталоги и общая шара
make remove-media                  # + все загрузки и медиатека media-стека
make remove-tg                     # + Telegram-прокси (данных нет)
make remove-registry              # + ВСЕ образы в registry
make remove-vaultwarden           # + база паролей ВСЕХ пользователей!
make remove-acestream             # + кэш стримов
make remove-metube                # + все загруженные видео
make remove-searxng               # + настройки поиска
make remove-portainer             # + настройки и учётки Portainer
make remove-plex                   # + медиатека

# пользователи домена
make user-add U=ivan P='Str0ng_Pass!'
make user-del U=ivan
make user-pass U=ivan P='New_Pass!'
make users

make ps / logs
```

⚠️ `remove-*` запрашивает подтверждение (обойти: `make remove-<x> CONFIRM=yes`) и удаляет данные БЕЗВОЗВРАТНО — образ, контейнер, анонимные volume и соответствующие каталоги в `folders/`.

⚠️ После `make remove-plex` сервер придётся заново привязать к plex.tv (Настройки → Удалённый доступ; при необходимости раскомментировать `PLEX_CLAIM` в docker-compose.yml с новым кодом с plex.tv/claim) и пересобрать библиотеки. Удалённый доступ извне LAN требует проброса порта 32400 на роутере.

Доступ к персональной шаре: `\\<IP-сервера>\ivan`, логин `HOME\ivan`.
Смена пароля Administrator: `docker exec -it service_samba_addc samba-tool user setpassword Administrator`.

## Настройка media-стека (разовая, после первого `make up`)

Все адреса: `http://<IP-сервера>:<порт>` — qBittorrent `8080`, Radarr `7878`, Sonarr `8989`, Lidarr `8686`, Bazarr `6767`, Jellyfin `8096`.

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

**2.6. Bazarr — субтитры (порт 6767):**
Settings → Providers настроить язык (Russian) и провайдеров субтитров, затем подключить библиотеки:
- Settings → Radarr → Enabled, Host `service_radarr`, Port `7878`, API Key (Radarr: Settings → General → API Key)
- Settings → Sonarr → Enabled, Host `service_sonarr`, Port `8989`, API Key (Sonarr: Settings → General → API Key)

Пути совпадают (`/media` в обоих) — Bazarr сам подпишет сериалы/фильмы субтитрами и будет держать их актуальными при апгрейдах качества.

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

### Шаг 4. Plex — те же библиотеки media-стека (опционально)

Plex подключён к той же медиатеке (`/media` = `folders/media`). После старта Plex (`:32400`):
1. Настройки → Медиатеки → Добавить библиотеку:
   - Фильмы → папка `/media/movies`
   - Сериалы → папка `/media/tv`
   - Музыка → папка `/media/music`
2. Включи «Сканировать медиатеку периодически» — новые файлы *arr будут подхватываться сами.

(Старые каталоги `/movies`, `/tv` из `folders/plex_media_server/` остаются подключёнными как есть.)

### Шаг 5. MeTube — видео с YouTube в той же медиатеке

MeTube уже пишет в `/media/youtube`. Добавь библиотеку в Jellyfin (и при желании в Plex): тип контента **Home Videos**, папка `/media/youtube` — случайные названия с YouTube не будут портиться метаданными.

## Docker Registry (хранилище собственных образов)

Поднят `registry:2` (порт 5000, данные в `folders/registry/`) — вместо тяжёлого Harbor: тот требует ~10 контейнеров (БД, redis, trivy), свой установщик и HTTPS-сертификаты. Если понадобятся UI/сканирование/репликация — Harbor ставится отдельным проектом по [официальной инструкции](https://goharbor.io/docs/2.12.0/install-config/).

### Использование

Registry работает по HTTP — на каждом docker-хосте-клиенте разреши insecure-registry и перезапусти docker:

```json
// /etc/docker/daemon.json (или Docker Desktop → Settings → Docker Engine)
{ "insecure-registries": ["<IP-сервера>:5000"] }
```

Сборка и хранение своего образа:

```bash
docker build -t myapp .
docker tag myapp <IP-сервера>:5000/myapp:latest
docker push <IP-сервера>:5000/myapp:latest

docker pull <IP-сервера>:5000/myapp:latest
curl http://<IP-сервера>:5000/v2/_catalog    # что лежит в registry
curl http://<IP-сервера>:5000/v2/myapp/tags/list
```

На сервере-хосте это уже настроено не будет автоматически — добавь `"insecure-registries": ["localhost:5000"]` в daemon.json и там, если хочешь push/pull с самого хоста.

⚠️ Без аутентификации — только доверенная LAN. Включается htpasswd-переменными `REGISTRY_AUTH*` при необходимости.

## Vaultwarden (хранение паролей)

Bitwarden-совместимый сервер (`vaultwarden/server`; у linuxserver.io такого образа нет), порт `8222`, база sqlite + вложения в `folders/vaultwarden/config`.

### Подключение клиентов

В каждом клиенте Bitwarden перед входом укажи self-hosted сервер `http://<IP-сервера>:8222`:

- **Desktop / мобильные приложения:** Настройки аккаунта → «Сервер» → Self-hosted → URL сервера `http://<IP-сервера>:8222` → зарегистрируйся (Создать учётную запись).
- **Расширение браузера:** значок шестерёнки → Self-hosted → тот же URL.
- ⚠️ **Web-vault в браузере требует HTTPS** (Web Crypto API работает только в secure context) — по HTTP из LAN пользуйся приложениями/расширением. Понадобится web-vault — ставь reverse-proxy с TLS.

### После регистрации всех членов семьи

Запрети новые регистрации: в `.env` → `SIGNUPS_ALLOWED=false` → `make up-vaultwarden`.

### Админ-панель и бэкап

- `/admin` доступен только если задан `ADMIN_TOKEN` в `.env` (argon2-хэш: `docker run --rm -it vaultwarden/server /vaultwarden hash`).
- ⚠️ **Бэкап обязателен**: потеря `folders/vaultwarden/config` = потеря всех паролей. Клиенты Bitwarden держат зашифрованную копию, пока устройство живо — но полагаться только на это нельзя. Хотя бы раз скопируй `folders/vaultwarden` на другой носитель.

## Ace Stream Engine (p2p-стриминг)

Движок **3.2.11** (последняя версия), собирается из базового `ubuntu:22.04` + официальный тарбл `download.acestream.media` (см. `services/acestream/Dockerfile`; база 22.04 обязательна — движок бинарно привязан к python 3.10). Первый `make up-acestream` собирает ~5 минут.

### Использование

- **Встроенный web-плеер:** `http://<IP-сервера>:6878/webui/player/` — вставляешь `acestream://`-ссылку или content-id, играется прямо в браузере.
- **HTTP API (VLC/mplayers):** `http://<IP-сервера>:6878/ace/getstream?id=<content-id>` — отдает прямой поток (hls: `/ace/getstream/…?format=hls`).
- Проверка живости: `curl 'http://<IP>:6878/webui/api/service?method=get_version'` (он же — healthcheck в compose).
- Кэш и настройки — `folders/acestream/` (переживают рестарт).

Обновление версии: поменять `ACESTREAM_URL` в `services/acestream/Dockerfile` на свежий тарбл с [download.acestream.media/linux](https://download.acestream.media/linux/) → `make build-acestream && make up-acestream`.

## MeTube (загрузка видео)

Web-UI для yt-dlp (`alexta69/metube`), порт `8081`. Вставляешь ссылку с YouTube/[сотен сайтов](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md) — видео качается **сразу в общую медиатеку** `folders/media/youtube`.

Чтобы видео появились в Jellyfin: Dashboard → Libraries → добавить библиотеку `/media/youtube` с типом контента **Home Videos** (заодно в Plex — `/media/youtube`). Дальше новые загрузки подхватываются автоматическим сканом, ничего вручную.

Basic-авторизация (если в LAN есть посторонние): раскомментируй `USER`/`PASS` в docker-compose.yml → `make up-metube`.

## SearXNG (приватный поиск)

Метапоисковик (`searxng/searxng`), порт `8888` — агрегирует Google/Bing/DuckDuckGo и др., без трекинга и рекламы. Просто открой `http://<IP-сервера>:8888` и укажи адрес как поисковую систему в браузере (открой `:8888/preferences` → «Ваш браузер» — там готовые ссылки-подсказки).

- Настройки: `folders/searxng/settings.yml` (создаётся автоматически при первом старте, включая секретный ключ — каталог уже не переноси с чужими ключами между инсталляциями).
- В `.env` можно задать `SEARXNG_BASE_URL=http://<IP-сервера>:8888/` — чтобы ссылки «поделиться» были правильными.

## Portainer (управление Docker через браузер)

`portainer/portainer-ce`, порт `9443` (**https** с самоподписанным сертификатом — браузер предупредит, это нормально). Данные и учётки — `folders/portainer/`.

Первый вход: `https://<IP-сервера>:9443` → создать администратора. ⚠️ У Portainer есть таймаут: если не создать админа в течение ~10 минут после старта, контейнер уходит в protected — перезапусти: `make down-portainer && make up-portainer`.

Дальше: Get Started → локальное окружение (local) — контейнеры/образы/тома/сети/логи/консоли всего стека в браузере. По сути это GUI поверх того же docker compose, стеки в `docker-compose.yml` оно не заменяет.

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
- Все сервисы вне Samba (Plex, Jellyfin, qBittorrent, *arr, Vaultwarden, registry, Telegram-прокси, Ace Stream, MeTube, SearXNG) **не интегрируются с AD** — у них свои локальные аккаунты или их нет.
- Машина-аккаунт файлового сервера пересоздаётся при `docker compose down/up` (автоматически, штатно).
- **Бэкапить**: `folders/samba_addc/` (домен) и `folders/vaultwarden/` (все пароли) — потеря безвозвратна.

## Помощь ИИ-агентам

Контекст проекта для ИИ (Cursor, Claude, Codex, Kilo): `memory-bank/`, вход — `AGENTS.md`.

Полезное: [Plex: «не авторизован, нет доступа к серверу»](https://itmemo.su/page/ne-avtorizovan-u-vas-net-dostupa-k-etomu-serveru)
