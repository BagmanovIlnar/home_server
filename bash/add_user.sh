#!/bin/sh
# Создание пользователя Active Directory + его домашнего каталога на файловом сервере
# Использование: ./add_user.sh -u <username> -p <password>
# Пароль должен проходить политику сложности Samba (3 из 4 классов символов, от 7 символов)
set -e

while getopts u:p: flag
do
  case "$flag" in
    u) username=${OPTARG};;
    p) password=${OPTARG};;
  esac
done

if [ -z "$username" ] || [ -z "$password" ]; then
  echo "Usage: $0 -u <username> -p <password>"
  exit 1
fi

# DOMAIN из .env (парсим от каталога скрипта, а не от cwd)
ENV_FILE="$(dirname "$0")/../.env"
DOMAIN=$(grep -E '^AD_DOMAIN=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"' | tr -d '[:space:]')
DOMAIN=${DOMAIN:-HOME}

# 1. Учётка в домене
docker exec service_samba_addc samba-tool user create "$username" "$password"

# 2. Дождаться, пока свежий юзер станет виден winbind'у файлового сервера (кэш до ~15с)
i=0
while :; do
  if docker exec service_samba_folder wbinfo -n "$username" >/dev/null 2>&1; then
    break
  fi
  i=$((i+1))
  if [ "$i" -ge 10 ]; then
    echo "Пользователь создан в AD, но пока не виден winbind. Домашний каталог создаст автосинк (~60 сек)."
    exit 0
  fi
  sleep 3
done

# 3. Домашний каталог: владелец — доменный пользователь, доступ только ему
docker exec service_samba_folder mkdir -p "/var/home-service/users/$username"
docker exec service_samba_folder chown "${DOMAIN}\\${username}:domain users" "/var/home-service/users/$username"
docker exec service_samba_folder chmod 700 "/var/home-service/users/$username"
echo "OK: domain user ${DOMAIN}\\${username} created, home dir ready"
