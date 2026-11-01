# Home Server

Домашний сервер на Docker Compose: **Active Directory (Samba AD DC)** + файловый сервер (Samba) + торрент-клиент (Transmission) + медиасервер (Plex).

Единая аутентификация для **Linux, Windows, macOS** через собственный домен `HOME.ARPA`.

## Сервисы

| Сервис | Назначение | Порты |
|---|---|---|
| `service_samba_addc` | Samba AD DC: DNS, Kerberos, LDAP, пользователи | 53, 88, 135, 389, 464, 636, 3268, 3269, 49152 |
| `service_samba_folder` | Файлы: шара `home_share` + домашние каталоги `[homes]` | 445 |
| `service_transmission` | Торренты (web-UI без пароля — только LAN!) | 9091, 51413 |
| `service_plex` | Медиасервер | 32400 |
| ~~service_ace_stream, service_ftp~~ | Отключены (закомментированы) | — |

## Первый запуск

```bash
make env    # создаст .env из шаблона — пропиши пароли (3 класса символов, от 7)
make up     # сборка + запуск
make logs   # ждать "provisioned" у service_samba_addc и статуса healthy
```

Первый старт DC создаёт домен и пишет базу в `folders/samba_addc/` (персистентна). Файловый сервер сам вводится в домен при каждом старте — это штатно.

## Управление и пользователи (make help — полная справка)

```bash
# запуск / остановка / сборка (как всего стека, так и по одному сервису: up-dc, up-nas, up-plex, up-transmission)
make up / down / build            # весь стек (down = только остановка, данные живы)
make up-nas / down-nas / build-dc # конкретный сервис

# ПОЛНОЕ удаление: контейнер + образ + volume + ВСЕ данные сервиса (prune не нужен)
make remove                        # весь стек (образы, volume, сеть, все folders/)
make remove-dc                     # + база домена (все юзеры AD!)
make remove-nas                    # + все домашние каталоги и общая шара
make remove-transmission           # + все загрузки
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
- Plex и Transmission **не поддерживают AD** — у них свои локальные аккаунты.
- Машина-аккаунт файлового сервера пересоздаётся при `docker compose down/up` (автоматически, штатно).
- Данные домена: `folders/samba_addc/` — бэкапить.

## Помощь ИИ-агентам

Контекст проекта для ИИ (Cursor, Claude, Codex, Kilo): `memory-bank/`, вход — `AGENTS.md`.

Полезное: [Plex: «не авторизован, нет доступа к серверу»](https://itmemo.su/page/ne-avtorizovan-u-vas-net-dostupa-k-etomu-serveru)
