#!/usr/bin/env bash
# Samba AD Domain Controller
# Первый запуск: provisioning домена (данные в /var/lib/samba — volume, персистентны)
# Последующие запуски: старт существующего домена

set -e

: "${REALM:=HOME.ARPA}"
: "${DOMAIN:=HOME}"
: "${HOSTNAME:=dc1}"
: "${DNS_FORWARDER:=1.1.1.1}"
: "${ADMIN_PASS:?ADMIN_PASS is required (set AD_ADMIN_PASSWORD in .env)}"
: "${TZ:=Europe/Moscow}"

# DNS = сам себя (samba_dnsupdate и доменные запросы должны попадать в SAMBA_INTERNAL, а не в embedded-DNS docker'а)
echo 'nameserver 127.0.0.1' > /etc/resolv.conf 2>/dev/null || true

# Проверка включена в docker-compose: cap_add SYS_ADMIN (нужен для записи xattr security.NTACL при provisioning)
if [ ! -f /var/lib/samba/private/sam.ldb ]; then
    echo ">>> [samba_addc] First start: provisioning domain ${DOMAIN} (${REALM}), DNS forwarder: ${DNS_FORWARDER}"
    rm -f /etc/samba/smb.conf   # пакетный conf (standalone server) ломает provision — сгенерим свой
    samba-tool domain provision \
        --use-rfc2307 \
        --realm="${REALM}" \
        --domain="${DOMAIN}" \
        --host-name="${HOSTNAME}" \
        --server-role=dc \
        --dns-backend=SAMBA_INTERNAL \
        --adminpass="${ADMIN_PASS}" \
        --option="dns forwarder = ${DNS_FORWARDER}" \
        --option="rpc server port = 49152"
    echo ">>> [samba_addc] Domain ${REALM} provisioned. Administrator password from .env"
else
    echo ">>> [samba_addc] Existing domain database found, starting AD DC"
fi

# samba -i = запуск AD DC одним процессом в foreground (включая smbt_internal DNS)
# [global]: разрешить LDAP simple-bind без TLS по 389 — ldap_manager/hls_dl биндятся
# plaintext. Идемпотентно: применяется и после provision, и к существующему домену
# при каждом старте контейнера (docker compose restart тоже перезапускает run.sh).
# ponytail: правильный путь — ldaps://:636, но у DC самоподписанный сертификат
# dc1.<realm>, приложениям нужна поддержка доверия к нему; переключиться, когда появится.
grep -q '^ldap server require strong auth' /etc/samba/smb.conf \
    || sed -i '/^\[global\]/a ldap server require strong auth = No' /etc/samba/smb.conf

exec /usr/sbin/samba -i
