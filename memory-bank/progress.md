# Progress: Home Server

## What Works
- ✅ **Samba AD DC** (service_samba_addc): новый сервис — домен-контроллер (DNS+Kerberos+LDAP+GC), provisioning при первом старте, база персистентна в folders/samba_addc/, healthcheck через SRV-запрос; ФИЗИЧЕСКИ НЕ РАЗВЁРНУТ на сервере — код написан, ждёт docker compose up
- ✅ **Файловый сервер в домене** (service_samba_folder): security=ads, winbind, rid-idmap, авто-join при старте; шары home_share + [homes] для доменных юзеров; АВТОСИНК домашних каталогов с AD (home_sync.sh): создание при появлении юзера, архивация в .deleted при удалении
- ✅ **Управление (Makefile)**: user-add/user-del/user-pass/users + env/up/down/logs/ps (заменили bash/*.sh)
- ~~✅ Управление пользователями: `bash/add_user.sh` (useradd + smbpasswd + каталог с правами 775), `bash/del_user.sh`~~ → заменено на доменные учётки через samba-tool
- ~~✅ **Transmission** (linuxserver): web-UI на 9091 без авторизации, peer-порт 51413, watch-папка~~ → ЗАМЕНЁН на qBittorrent
- ✅ **Media-стек** (linuxserver): qBittorrent (8080, peer 6881) + Radarr (7878) + Sonarr (8989) + Lidarr (8686) + Jellyfin (8096); связь через общие тома /downloads и /media + default-сеть compose; код написан, ждёт docker compose up
- ✅ **Portainer** service_portainer (9443, web-UI Docker, docker.sock): ждёт docker compose up
- ✅ **MeTube** service_metube (8081, yt-dlp web-UI, загрузки сразу в folders/media/youtube → Jellyfin/Plex) и **SearXNG** service_searxng (8888, метапоисковик): ждут docker compose up
- ✅ **Bazarr** service_bazarr (6767, субтитры): в группе MEDIA, ждёт docker compose up
- ✅ **Ace Stream Engine** service_acestream: 3.2.11, сборка из ubuntu:22.04 + официальный тарбл, порт 6878 (HTTP API/web-плеер); ждёт docker compose up
- ✅ **Ace Stream Proxy + Web UI** service_acestream_proxy (:8085, шаринг сессий движка, HLS/TS, транскод, Swagger) + service_acestream_web (:8086, nginx-интерфейс к прокси, same-origin); сборка из github-репозитвеев автора, управление через make *-acestream (вся связка разом); движок ходим через host.docker.internal (host-gateway) — по имени сервиса из чужой docker-сети прокси не резолвился; ждут docker compose up
- ✅ **Vaultwarden** service_vaultwarden (порт 8222, sqlite в folders/vaultwarden/config): Bitwarden-совместимый сервер паролей; клиенты по HTTP, web-vault требует HTTPS; ждёт docker compose up
- ✅ **Docker Registry** service_registry (registry:2, порт 5000): хранилище собственных образов, без аутентификации (доверенная LAN); вместо Harbor (overkill). Ждёт docker compose up
- ✅ **Telegram-прокси** service_tg_ws_proxy (FlowSeal/tg-ws-proxy v1.11.4, MTProto/WS, порт 1443): сборка из GitHub-контекста, секрет в .env; ждёт docker compose up
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
- ⚠️ Локальные юзеры старого standalone-samba НЕ мигрировали в AD — пересоздать через make user-add
- ⚠️ Windows Home в домен не входит (нужна Pro/Enterprise); Plex/Transmission AD не поддерживают
- ⚠️ Plex: после remove-plex — повторная привязка к plex.tv (PLEX_CLAIM) и пересоздание библиотек; для удалённого доступа нужен проброс 32400 на роутере; образ :latest (непиненный)
- ⚠️ Transmission web-UI без аутентификации — безопасно только в доверенной LAN
- ⚠️ Лишние/мёртвые файлы: Dockerfile+run.sh для plex и transmission не используются (compose берёт linuxserver-образы); старая закомментированная секция в ace-stream Dockerfile
- ⚠️ Общая шара `home_share` с `guest ok = yes` и масками 0777 — любой в LAN может писать/читать
- ⚠️ `.idea/` частично в git (в .gitignore только верхоуровневая запись, история коммитила)

## Evolution of Project Decisions
- 2024+: добавлен Samba AD DC для единой аутентификации Linux/Windows/macOS; файловый сервер стал member домена; локальные юзеры smbpasswd заменены на samba-tool
- Сначала подход «всё собираем сами из ubuntu:22.04» (Dockerfile'ы для samba, ftp, transmission, plex, ace-stream); 2024+: база всех custom-образов поднята до ubuntu:26.04 LTS (в DC добавлен пакет samba-ad-provision), проверено по файллистам/доке samba
- Затем переход на готовые образы linuxserver для Transmission и Plex (собственные Dockerfile'ы остались как артефакты)
- Ace Stream: первая версия (HTTPAceProxy + acestream 3.1.74 на ubuntu:18.04, python2) была заброшена и закомментирована; вторая попытка на базе `vstavrinov/acestream-engine` тоже не доведена до конца
- FTP-сервис был рабочей альтернативой файлового доступа, но вытеснен Samba и отключён
- 2024+: Убрана авторизация Transmission для удобства в домашней сети
- 2025: Vaultwarden переведён на официальный образ vaultwarden/server (lscr.io/linuxserver/vaultwarden не существует — `denied` из registry валил весь make up); атрибут `version` удалён из docker-compose.yml
