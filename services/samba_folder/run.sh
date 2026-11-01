#!/usr/bin/env bash
# Файловый сервер Samba — член домена Active Directory
# При старте: генерация krb5.conf/smb.conf, ввод в домен (если ещё не введён), запуск winbind+smbd

set -e

: "${REALM:=HOME.ARPA}"
: "${DOMAIN:=HOME}"
: "${DC:=service_samba_addc}"
: "${JOIN_USER:=administrator}"
: "${JOIN_PASS:?JOIN_PASS is required (set AD_JOIN_PASSWORD in .env)}"

# --- Kerberos ---
cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = true
    rdns = false
    dns_canonicalize_hostname = false

[realms]
    ${REALM} = {
        kdc = ${DC}
        admin_server = ${DC}
    }
EOF

# --- NSS: winbind (для chown DOMAIN\\user и владельцев файлов) ---
sed -i '/^passwd:/ { /winbind/! s/$/ winbind/ }' /etc/nsswitch.conf
sed -i '/^group:/  { /winbind/! s/$/ winbind/ }' /etc/nsswitch.conf

# --- smb.conf: [global] как member домена + шары из smb.conf.d ---
cat > /etc/samba/smb.conf <<EOF
[global]
    security = ads
    realm = ${REALM}
    workgroup = ${DOMAIN}
    password server = ${DC}
    kerberos method = secrets and keytab

    winbind use default domain = yes
    winbind enum users = yes
    winbind enum groups = yes
    winbind refresh tickets = yes

    idmap config * : backend = tdb
    idmap config * : range = 3000-7999
    idmap config ${DOMAIN} : backend = rid
    idmap config ${DOMAIN} : range = 10000-999999

    template shell = /bin/bash
    template homedir = /var/home-service/users/%U
EOF

for fileName in /etc/samba/smb.conf.d/*; do
    if [ -f "$fileName" ]; then
        cat "$fileName" >> /etc/samba/smb.conf
    fi
done

# --- Ввод в домен (при пересоздании контейнера выполняется заново, это штатно) ---
if net ads testjoin >/dev/null 2>&1; then
    echo ">>> [samba_folder] Already joined to ${REALM}"
else
    echo ">>> [samba_folder] Joining domain ${REALM} as $(hostname)..."
    net ads join --no-dns-updates -U "${JOIN_USER}%${JOIN_PASS}"
    echo ">>> [samba_folder] Joined to ${REALM}"
fi

# --- Запуск сервисов ---
/etc/init.d/winbind start
/etc/init.d/smbd start

# --- Автосинк домашних каталогов с AD (создание/архивация) ---
bash /home_sync.sh &

echo ">>> [samba_folder] UP. Press [CTRL+C] to exit this loop..."
while :
do
    sleep 2
done
