FROM ubuntu:22.04

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

RUN mkdir /tmp/acestream \
    && wget -P /tmp https://downloads.plex.tv/plex-media-server-new/1.32.8.7639-fb6452ebf/debian/plexmediaserver_1.32.8.7639-fb6452ebf_amd64.deb \
    && dpkg -i /tmp/plexmediaserver_1.32.8.7639-fb6452ebf_amd64.deb

CMD ["bash","/run.sh"]