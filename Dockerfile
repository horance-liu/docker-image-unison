FROM alpine:edge

ARG OCAML_VERSION=4.08.1

COPY ocaml-${OCAML_VERSION}.tar.gz /ocaml-${OCAML_VERSION}.tar.gz

RUN apk update \
    && apk add --no-cache --virtual .build-deps build-base coreutils \
	&& tar xvf /ocaml-${OCAML_VERSION}.tar.gz -C /tmp \
	&& cd /tmp/ocaml-${OCAML_VERSION} \
    && ./configure \
    && make world \
    && make opt \
    && umask 022 \
    && make install \
    && make clean \
    && apk del .build-deps  \
	&& rm -rf /tmp/ocaml-${OCAML_VERSION} \
	&& rm /ocaml-${OCAML_VERSION}.tar.gz

ARG UNISON_VERSION=2.51.2

COPY v${UNISON_VERSION}.tar.gz /v${UNISON_VERSION}.tar.gz
COPY patch.diff /patch.diff

RUN apk update \
    && apk add --no-cache --virtual .build-deps \
        build-base curl git \
    && apk add --no-cache \
        bash inotify-tools monit supervisor rsync ruby \
    && tar zxvf /v${UNISON_VERSION}.tar.gz -C /tmp \
    && cd /tmp/unison-${UNISON_VERSION} \
    && git apply /patch.diff \
    && rm /patch.diff \
    && sed -i -e 's/GLIBC_SUPPORT_INOTIFY 0/GLIBC_SUPPORT_INOTIFY 1/' src/fsmonitor/linux/inotify_stubs.c \
    && make UISTYLE=text NATIVE=true STATIC=true \
    && cp src/unison src/unison-fsmonitor /usr/local/bin \
    && apk del binutils .build-deps  \
    && apk add --no-cache libgcc libstdc++ \
    && rm -rf /tmp/unison-${UNISON_VERSION} \
    && apk add --no-cache --repository http://dl-4.alpinelinux.org/alpine/edge/testing/ shadow \
    && apk add --no-cache tzdata

# These can be overridden later
ENV TZ="Europe/Helsinki" \
    LANG="C.UTF-8" \
    UNISON_DIR="/data" \
    HOME="/root"

COPY entrypoint.sh /entrypoint.sh
COPY precopy_appsync.sh /usr/local/bin/precopy_appsync
COPY monitrc /etc/monitrc

RUN mkdir -p /docker-entrypoint.d \
 && chmod +x /entrypoint.sh \
 && mkdir -p /etc/supervisor.conf.d \
 && mkdir /unison \
 && chmod +x /usr/local/bin/precopy_appsync \
 && chmod u=rw,g=,o= /etc/monitrc

COPY supervisord.conf /etc/supervisord.conf
COPY supervisor.daemon.conf /etc/supervisor.conf.d/supervisor.daemon.conf

ENTRYPOINT ["/entrypoint.sh"]
CMD ["supervisord"]
############# ############# #############
############# /SHARED     / #############
############# ############# #############

VOLUME /unison
EXPOSE 5000
