#FROM ubuntu:18.04

#WORKDIR /var/home-service

#COPY run.sh /run.sh

#RUN apt-get update \
#    && apt-get upgrade -y \
#    && apt-get install -yy tzdata \
#    && apt-get install -y wget \
#    && apt-get install -y apt-utils \
#    && apt-get install -y curl \
#    && apt-get install -y alien \
#    && apt-get install -y software-properties-common \
#    && apt-get install -y ca-certificates \
#    && apt-get install -y ubuntu-keyring \
#    && apt-get install -y zip \
#    && apt-get install -y git

#RUN add-apt-repository ppa:deadsnakes/ppa \
#    && apt-get update \
#    && apt-get upgrade -y \
#    && apt-get install build-essential \
#    && apt-get install -y zlib1g-dev \
#    && apt-get install -y libncurses5-dev \
#    && apt-get install -y libgdbm-dev \
#    && apt-get install -y libnss3-dev \
#    && apt-get install -y libssl-dev \
#    && apt-get install -y libsqlite3-dev \
#    && apt-get install -y libreadline-dev \
#    && apt-get install -y libffi-dev \
#    && apt-get install -y libbz2-dev \
#    && apt-get install -y python2.7 \
#    && apt-get install -y python-apsw \
#    && apt-get install -y python-lxml \
#    && apt-get install -y python-m2crypto \
#    && apt-get install -y python-psutil \
#    && apt-get install -y python-gevent \
#    && apt-get install -y python-pkg-resources \
#    && apt-get install -y libpython2.7 \
#    && apt-get install -y python-requests \
#    && apt-get install -y python-pip \
#    && mkdir /tmp/acestream \
#    && wget -P /tmp https://download.acestream.media/linux/acestream_3.1.74_ubuntu_18.04_x86_64.tar.gz \
#    && tar -xf /tmp/acestream_3.1.74_ubuntu_18.04_x86_64.tar.gz -C /tmp/acestream \
#    && mv /tmp/acestream /opt/acestream \
#    && rm /tmp/acestream_3.1.74_ubuntu_18.04_x86_64.tar.gz \
#    && pip install greenlet gevent psutil \
#    && ln -s /opt/acestream/start-engine /usr/bin/acestreamengine

#RUN git clone https://github.com/pepsik-kiev/HTTPAceProxy.git /opt/HTTPAceProxy

#COPY config/aceconfig.py /opt/HTTPAceProxy/aceconfig.py    

#ENTRYPOINT ["/opt/acestream/start-engine"]
#CMD ["--client-console"]
#CMD ["/run.sh"]


FROM vstavrinov/acestream-engine
WORKDIR /srv/ace
ENV COLUMNS=116
ENV PYTHONDONTWRITEBYTECODE=0
ENV TMP=/dev/shm/tmp
ENV PORT=80
ENV ENTRY=8000
ENV SCHEME=http
ADD search.py setup.cfg .
USER root
RUN apt-get update; apt-get --yes install nginx; apt-get clean;  \
    ln --symbolic --force /dev/stderr /var/log/nginx/error.log;  \
    ln --symbolic --force /dev/stdout /var/log/nginx/access.log; \
    ln --symbolic --force  /dev/shm/.ACEStream .ACEStream;       \
    rmdir --verbose /var/lib/nginx;                              \
    ln --symbolic --force /dev/shm/nginx/lib  /var/lib/nginx;    \
    pip install --no-cache-dir gunicorn flask                    \
        git+https://github.com/vstavrinov/acestream_search.git
COPY default.conf /etc/nginx/sites-available/default
COPY nginx.conf /etc/nginx/
USER ace
CMD mkdir --verbose /dev/shm/.ACEStream;                    \
    mkdir --verbose /dev/shm/tmp;                           \
    cp --verbose --archive /etc/nginx /dev/shm;             \
    mkdir --verbose /dev/shm/nginx/lib;                     \
    cd /dev/shm/nginx/sites-enabled;                        \
    ln --symbolic --force ../sites-available/default .; cd; \
    sed --expression="s/PORT/${PORT:=80}/"                  \
        --expression="s/ENTRY/${ENTRY:+:$ENTRY}/"           \
        --expression="s/SCHEME/${SCHEME:=https}/"           \
        --in-place /dev/shm/nginx/sites-available/default;  \
    gunicorn --bind 0.0.0.0:3031 search:app &               \
    /usr/sbin/nginx -c /dev/shm/nginx/nginx.conf &          \
    ./start-engine                                          \
        --client-console                                    \
        --live-cache-type memory
