#!/bin/sh
# Смена пароля доменного пользователя
# Использование: ./ad_set_password.sh -u <username> -p <new_password>
while getopts u:p: flag
do
  case "$flag" in
    u) username=${OPTARG};;
    p) password=${OPTARG};;
  esac
done

if [ -z "$username" ] || [ -z "$password" ]; then
  echo "Usage: $0 -u <username> -p <new_password>"
  exit 1
fi

docker exec service_samba_addc samba-tool user setpassword "$username" --newpassword="$password"
echo "OK: password for $username changed"
