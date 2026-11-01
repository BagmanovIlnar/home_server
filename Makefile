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

.DEFAULT_GOAL := help
.PHONY: help env up down logs ps users user-add user-del user-pass

help: ## показать эту справку
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

env: ## создать .env из шаблона (если ещё нет)
	@test -f .env && echo ".env уже существует" || (cp .env.example .env && echo "Создан .env — пропиши пароли и запусти make up")

up: ## собрать и запустить всё (detached)
	docker compose up -d --build

down: ## остановить стек
	docker compose down

logs: ## живые логи всех сервисов
	docker compose logs -f

ps: ## статус сервисов
	docker compose ps

users: ## список пользователей домена
	docker exec service_samba_addc samba-tool user list

user-add: ## создать юзера AD + домашний каталог: make user-add U=ivan P='Str0ng_Pass!'
	@test -n "$(U)" && test -n "$(P)" || { echo "Usage: make user-add U=<user> P=<password>"; exit 2; }
	docker exec service_samba_addc samba-tool user create "$(U)" "$(P)"
	i=0; while :; do \
		docker exec service_samba_folder wbinfo -n "$(U)" >/dev/null 2>&1 && break; \
		i=$$((i+1)); if [ $$i -ge 10 ]; then echo "Юзер создан в AD, каталог доделает автосинк (~60 сек)"; exit 0; fi; \
		sleep 3; \
	done
	docker exec service_samba_folder mkdir -p /var/home-service/users/$(U)
	docker exec service_samba_folder chown "$(DOMAIN)\\$(U):domain users" /var/home-service/users/$(U)
	docker exec service_samba_folder chmod 700 /var/home-service/users/$(U)
	@echo "OK: $(DOMAIN)\\$(U) создан, домашний каталог готов"

user-del: ## удалить юзера AD и его каталог: make user-del U=ivan
	@test -n "$(U)" || { echo "Usage: make user-del U=<user>"; exit 2; }
	docker exec service_samba_addc samba-tool user delete "$(U)"
	docker exec service_samba_folder rm -rf /var/home-service/users/$(U)
	@echo "OK: $(U) удалён (AD + домашний каталог)"

user-pass: ## сменить пароль юзера: make user-pass U=ivan P='New_Pass!'
	@test -n "$(U)" && test -n "$(P)" || { echo "Usage: make user-pass U=<user> P=<password>"; exit 2; }
	docker exec service_samba_addc samba-tool user setpassword "$(U)" --newpassword="$(P)"
	@echo "OK: пароль $(U) изменён"
