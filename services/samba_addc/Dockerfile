FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive

COPY run.sh /run.sh

RUN echo 'krb5-config krb5-config/default_realm string HOME.ARPA' | debconf-set-selections \
 && echo 'krb5-config krb5-config/kerberos_servers string 127.0.0.1' | debconf-set-selections \
 && echo 'krb5-config krb5-config/admin_server string 127.0.0.1' | debconf-set-selections \
 && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -yy tzdata \
    && apt-get install -y samba samba-ad-provision \
    && apt-get install -y krb5-user \
    && apt-get install -y dnsutils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 53 88 135 389 464 636 3268 3269 49152

CMD ["bash","/run.sh"]
