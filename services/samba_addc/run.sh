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

if [ ! -f /var/lib/samba/private/sam.ldb ]; then
    echo ">>> [samba_addc] First start: provisioning domain ${DOMAIN} (${REALM}), DNS forwarder: ${DNS_FORWARDER}"
    samba-tool domain provision \
        --use-rfc2307 \
        --realm="${REALM}" \
        --domain="${DOMAIN}" \
        --host-name="${HOSTNAME}" \
        --server-role=active-directory-domain-controller \
        --dns-backend=SAMBA_INTERNAL \
        --adminpass="${ADMIN_PASS}" \
        --option="dns forwarder = ${DNS_FORWARDER}" \
        --option="rpc server port = 49152"
    echo ">>> [samba_addc] Domain ${REALM} provisioned. Administrator password from .env"
else
    echo ">>> [samba_addc] Existing domain database found, starting AD DC"
fi

# samba -i = запуск AD DC одним процессом в foreground (включая smbt_internal DNS)
exec /usr/sbin/samba -i
