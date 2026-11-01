FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive

COPY run.sh /run.sh
COPY home_sync.sh /home_sync.sh

RUN echo "samba" && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -yy tzdata \
    && apt-get install -y wget \
    && apt-get install -y apt-utils \
    && apt-get install -y curl \
    && apt-get install -y alien \
    && apt-get install -y software-properties-common \
    && apt-get install -y ca-certificates \
    && apt-get install -y ubuntu-keyring \
    && apt-get install -y zip

# krb5-user задаёт вопрос про realm через debconf — глушим пресидом
# (значение неважно: /etc/krb5.conf полностью генерируется в run.sh при старте контейнера)
RUN echo 'krb5-config krb5-config/default_realm string HOME.ARPA' | debconf-set-selections \
 && echo 'krb5-config krb5-config/kerberos_servers string service_samba_addc' | debconf-set-selections \
 && echo 'krb5-config krb5-config/admin_server string service_samba_addc' | debconf-set-selections \
 && apt-get install -y samba winbind krb5-user dnsutils ldb-tools

CMD ["bash","/run.sh"]
