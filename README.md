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

## Управление и пользователи (make)

```bash
make user-add U=ivan P='Str0ng_Pass!'   # создать доменного юзера + домашний каталог
make user-del U=ivan                    # удалить юзера и каталог
make user-pass U=ivan P='New_Pass!'     # сменить пароль
make users                              # список юзеров домена
make ps / logs / down                   # жизненный цикл стека
```

Доступ к персональной шаре: `\\<IP-сервера>\ivan`, логин `HOME\ivan`.
Смена пароля Administrator: `docker exec -it service_samba_addc samba-tool user setpassword Administrator`.

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
