FROM ubuntu:22.04

COPY run.sh /run.sh

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -yy tzdata \
    && apt-get install -y samba \
    && apt-get install -y krb5-user \
    && apt-get install -y dnsutils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 53 88 135 389 464 636 3268 3269 49152

CMD ["bash","/run.sh"]
