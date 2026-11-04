# Home Server — управление (Docker Compose + домен AD)
#
# Первый запуск:   make env && make up   (не забудь пароли в .env)
# Пользователи:    make user-add U=ivan P='Str0ng_Pass!'
# Справка:         make help
#
# Примечание: в паролях избегай символа $ (make подставляет переменные)

DOMAIN := $(shell grep -E '^AD_DOMAIN=' .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"[:space:]')
ifeq ($(strip $(DOMAIN)),)
  DOMAIN := HOME
endif

DC   := service_samba_addc
NAS  := service_samba_folder
PLEX := service_plex
TG   := service_tg_ws_proxy
MEDIA := service_qbittorrent service_radarr service_sonarr service_lidarr service_jellyfin

.DEFAULT_GOAL := help
.PHONY: help env \
  up up-dc up-nas up-plex up-media up-tg \
  down down-dc down-nas down-plex down-media down-tg \
  build build-dc build-nas build-plex build-media build-tg \
  remove remove-dc remove-nas remove-plex remove-media remove-tg \
  logs ps users user-add user-del user-pass

help: ## показать эту справку
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

env: ## создать .env из шаблона (если ещё нет)
	@test -f .env && echo ".env уже существует" || (cp .env.example .env && echo "Создан .env — пропиши пароли и запусти make up")

# ---------- ЗАПУСК ----------

up: ## запустить весь стек (сборка + старт)
	@test -f .env || { echo "ОШИБКА: нет .env — сначала: make env  (затем пропиши пароли в .env)"; exit 1; }
	docker compose up -d --build
up-dc: ## запустить только домен-контроллер
	docker compose up -d $(DC)
up-nas: ## запустить только файловый сервер (потребует DC)
	docker compose up -d $(NAS)
up-tg: ## запустить Telegram-прокси (сборка из github при первом запуске)
	docker compose up -d $(TG)
up-media: ## запустить media-стек (qBittorrent + Radarr/Sonarr/Lidarr + Jellyfin)
	docker compose up -d $(MEDIA)
up-plex: ## запустить только Plex
	docker compose up -d $(PLEX)

# ---------- ОСТАНОВКА (данные и контейнеры остаются) ----------

down: ## остановить весь стек
	docker compose stop
down-dc: ## остановить домен-контроллер
	docker compose stop $(DC)
down-nas: ## остановить файловый сервер
	docker compose stop $(NAS)
down-tg: ## остановить Telegram-прокси
	docker compose stop $(TG)
down-media: ## остановить media-стек
	docker compose stop $(MEDIA)
down-plex: ## остановить Plex
	docker compose stop $(PLEX)

# ---------- СБОРКА ----------

build: ## собрать все кастомные образы (dc + nas) и обновить готовые (pull)
	docker compose build
	docker compose pull $(MEDIA) $(PLEX)
build-dc: ## собрать образ домен-контроллера
	docker compose build $(DC)
build-nas: ## собрать образ файлового сервера
	docker compose build $(NAS)
build-plex: ## скачать/обновить готовый образ Plex (pull)
	docker compose pull $(PLEX)
build-tg: ## пересобрать образ Telegram-прокси из github
	docker compose build $(TG)
build-media: ## скачать/обновить готовые образы media-стека (pull)
	docker compose pull $(MEDIA)

# ---------- ПОЛНОЕ УДАЛЕНИЕ (контейнер + образ + volume + данные) ----------
# Удаляется ВСЁ, что связано с сервисом: контейнер, образ, анонимные volume,
# данные в folders/. Подтверждение обходится: make remove-<x> CONFIRM=yes

remove: ## !!! удалить ВЕСЬ стек: контейнеры, образы, volume, сеть, ВСЕ данные
	@if [ "$(CONFIRM)" != "yes" ]; then printf "Удалить ВЕСЬ стек БЕЗВОЗВРАТНО (контейнеры, образы, volume, данные)? Введите yes: "; read a; [ "$$a" = "yes" ] || { echo "ОТМЕНЕНО"; exit 1; }; fi
	docker compose down --rmi all --volumes --remove-orphans
	rm -rf folders/samba_addc folders/users folders/share folders/transmission folders/plex_media_server \
	  folders/qbittorrent folders/radarr folders/sonarr folders/lidarr folders/jellyfin folders/media
	mkdir -p folders/samba_addc/etc folders/samba_addc/lib folders/users folders/share \
	  folders/plex_media_server/library folders/plex_media_server/movies folders/plex_media_server/tvseries \
	  folders/qbittorrent/config folders/qbittorrent/downloads folders/radarr/config folders/sonarr/config \
	  folders/lidarr/config folders/jellyfin/config folders/media/movies folders/media/tv folders/media/music
	@echo "OK: стек удалён полностью (контейнеры, образы, volume, сеть, данные)"

remove-dc: ## !!! удалить DC полностью: контейнер, образ, volume, БАЗУ ДОМЕНА (folders/samba_addc)
	@if [ "$(CONFIRM)" != "yes" ]; then printf "Удалить $(DC) БЕЗВОЗВРАТНО (контейнер, образ, volume, базу домена — ВСЕ пользователи AD)? Введите yes: "; read a; [ "$$a" = "yes" ] || { echo "ОТМЕНЕНО"; exit 1; }; fi
	@img=$$(docker compose images -q $(DC) 2>/dev/null); \
	docker compose rm -sfv $(DC); \
	if [ -n "$$img" ]; then docker rmi $$img || true; fi; \
	rm -rf folders/samba_addc; \
	mkdir -p folders/samba_addc/etc folders/samba_addc/lib; \
	touch folders/samba_addc/etc/.gitignore folders/samba_addc/lib/.gitignore; \
	echo "OK: $(DC) удалён полностью (контейнер, образ, volume, база домена). NAS без DC неработоспособен!"

remove-nas: ## !!! удалить файловый сервер полностью: контейнер, образ, volume, ВСЕ шары и каталоги юзеров
	@if [ "$(CONFIRM)" != "yes" ]; then printf "Удалить $(NAS) БЕЗВОЗВРАТНО (контейнер, образ, volume, все домашние каталоги и общую шару)? Введите yes: "; read a; [ "$$a" = "yes" ] || { echo "ОТМЕНЕНО"; exit 1; }; fi
	@img=$$(docker compose images -q $(NAS) 2>/dev/null); \
	docker compose rm -sfv $(NAS); \
	if [ -n "$$img" ]; then docker rmi $$img || true; fi; \
	rm -rf folders/users folders/share; \
	mkdir -p folders/users folders/share; \
	touch folders/users/.gitignore folders/share/.gitignore; \
	echo "OK: $(NAS) удалён полностью (контейнер, образ, volume, файлы пользователей)"

remove-media: ## !!! удалить весь media-стек: контейнеры, образы, volume, ВСЕ загрузки и медиатеку
	@if [ "$(CONFIRM)" != "yes" ]; then printf "Удалить media-стек (qBittorrent, Radarr, Sonarr, Lidarr, Jellyfin) БЕЗВОЗВРАТНО (контейнеры, образы, volume, ВСЕ загрузки и медиатеку)? Введите yes: "; read a; [ "$$a" = "yes" ] || { echo "ОТМЕНЕНО"; exit 1; }; fi
	@imgs=$$(docker compose images -q $(MEDIA) 2>/dev/null); \
	docker compose rm -sfv $(MEDIA); \
	for i in $$imgs; do docker rmi $$i || true; done; \
	rm -rf folders/qbittorrent folders/radarr folders/sonarr folders/lidarr folders/jellyfin folders/media; \
	mkdir -p folders/qbittorrent/config folders/qbittorrent/downloads folders/radarr/config folders/sonarr/config \
	  folders/lidarr/config folders/jellyfin/config folders/media/movies folders/media/tv folders/media/music; \
	echo "OK: media-стек удалён полностью (контейнеры, образы, volume, загрузки и медиатека)"

remove-plex: ## !!! удалить Plex полностью: контейнер, образ, volume, библиотеку и медиа
	@if [ "$(CONFIRM)" != "yes" ]; then printf "Удалить $(PLEX) БЕЗВОЗВРАТНО (контейнер, образ, volume, библиотеку и ВСЁ медиа)? Введите yes: "; read a; [ "$$a" = "yes" ] || { echo "ОТМЕНЕНО"; exit 1; }; fi
	@img=$$(docker compose images -q $(PLEX) 2>/dev/null); \
	docker compose rm -sfv $(PLEX); \
	if [ -n "$$img" ]; then docker rmi $$img || true; fi; \
	rm -rf folders/plex_media_server; \
	mkdir -p folders/plex_media_server/library folders/plex_media_server/movies folders/plex_media_server/tvseries; \
	touch folders/plex_media_server/library/.gitignore folders/plex_media_server/movies/.gitignore folders/plex_media_server/tvseries/.gitignore; \
	echo "OK: $(PLEX) удалён полностью (контейнер, образ, volume, медиатека)"

remove-tg: ## !!! удалить Telegram-прокси полностью: контейнер + образ (данных нет)
	@if [ "$(CONFIRM)" != "yes" ]; then printf "Удалить $(TG) (контейнер + образ)? Введите yes: "; read a; [ "$$a" = "yes" ] || { echo "ОТМЕНЕНО"; exit 1; }; fi
	@img=$$(docker compose images -q $(TG) 2>/dev/null); \
	docker compose rm -sfv $(TG); \
	if [ -n "$$img" ]; then docker rmi $$img || true; fi; \
	echo "OK: $(TG) удалён (контейнер, образ)"

# ---------- СТАТУС / ЛОГИ ----------

logs: ## живые логи всех сервисов
	docker compose logs -f
ps: ## статус сервисов
	docker compose ps

# ---------- ПОЛЬЗОВАТЕЛИ ДОМЕНА ----------

users: ## список пользователей домена
	docker exec $(DC) samba-tool user list

user-add: ## создать юзера AD + домашний каталог: make user-add U=ivan P='Str0ng_Pass!'
	@test -n "$(U)" && test -n "$(P)" || { echo "Usage: make user-add U=<user> P=<password>"; exit 2; }
	docker exec $(DC) samba-tool user create "$(U)" "$(P)"
	i=0; while :; do \
		docker exec $(NAS) wbinfo -n "$(U)" >/dev/null 2>&1 && break; \
		i=$$((i+1)); if [ $$i -ge 10 ]; then echo "Юзер создан в AD, каталог доделает автосинк (~60 сек)"; exit 0; fi; \
		sleep 3; \
	done
	docker exec $(NAS) mkdir -p /var/home-service/users/$(U)
	docker exec $(NAS) chown "$(DOMAIN)\\$(U):domain users" /var/home-service/users/$(U)
	docker exec $(NAS) chmod 700 /var/home-service/users/$(U)
	@echo "OK: $(DOMAIN)\\$(U) создан, домашний каталог готов"

user-del: ## удалить юзера AD и его каталог: make user-del U=ivan
	@test -n "$(U)" || { echo "Usage: make user-del U=<user>"; exit 2; }
	docker exec $(DC) samba-tool user delete "$(U)"
	docker exec $(NAS) rm -rf /var/home-service/users/$(U)
	@echo "OK: $(U) удалён (AD + домашний каталог)"

user-pass: ## сменить пароль юзера: make user-pass U=ivan P='New_Pass!'
	@test -n "$(U)" && test -n "$(P)" || { echo "Usage: make user-pass U=<user> P=<password>"; exit 2; }
	docker exec $(DC) samba-tool user setpassword "$(U)" --newpassword="$(P)"
	@echo "OK: пароль $(U) изменён"
