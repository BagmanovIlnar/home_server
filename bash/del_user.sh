#!/bin/sh
# Удаление пользователя Active Directory и его домашнего каталога
# Использование: ./del_user.sh -u <username>
# set -e: если удаление из AD не удалось — ФС-каталог НЕ трогаем
set -e

while getopts u: flag
do
  case "$flag" in
    u) username=${OPTARG};;
  esac
done

if [ -z "$username" ]; then
  echo "Usage: $0 -u <username>"
  exit 1
fi

docker exec service_samba_addc samba-tool user delete "$username"
docker exec service_samba_folder rm -rf "/var/home-service/users/$username"
echo "OK: user $username deleted (AD + home dir)"
