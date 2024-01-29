FROM ubuntu:22.04

WORKDIR /var/home-service

COPY run.sh /run.sh

RUN apt-get update \
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

RUN apt-get install -y transmission-daemon

CMD ["bash","/run.sh"]