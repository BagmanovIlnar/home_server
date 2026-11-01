#!/bin/sh
# Список пользователей домена
docker exec service_samba_addc samba-tool user list
