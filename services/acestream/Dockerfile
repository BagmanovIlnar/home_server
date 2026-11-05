# Ace Stream Engine 3.2.11 — собираем из базового образа + официальный тарбл движка
# База ubuntu:22.04 (не 26.04): движок несёт бинарные wheels под python 3.10 / glibc 2.35
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential python3-dev python3-pip \
      libsqlite3-dev libxml2-dev libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*
# Нативные модули движка; версии не пиним — проверено на cp310/22.04
RUN pip3 install --no-cache-dir --prefix=/install \
      apsw lxml PyNaCl requests pycryptodome isodate

FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ARG ACESTREAM_URL=https://download.acestream.media/linux/acestream_3.2.11_ubuntu_22.04_x86_64_py3.10.tar.gz
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tini procps \
      python3 libpython3.10 \
      python3-greenlet python3-gevent python3-psutil python3-simplejson \
      libxml2 libxslt1.1 libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/acestream \
    && curl -sSL "$ACESTREAM_URL" | tar -xz -C /opt/acestream
COPY --from=builder /install/local /usr/local
COPY --chmod=755 run.sh /run.sh
EXPOSE 6878
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/run.sh"]
