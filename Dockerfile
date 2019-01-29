ARG PG_VERSION_TAG
FROM timescale/timescaledb:1.2.0-${PG_VERSION_TAG}

MAINTAINER Timescale https://www.timescale.com

COPY pg_prometheus.control Makefile /build/pg_prometheus/
COPY src/*.c src/*.h /build/pg_prometheus/src/
COPY sql/prometheus.sql /build/pg_prometheus/sql/

RUN set -ex \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                dpkg-dev dpkg \
                gcc \
                libc-dev \
                make \
                util-linux-dev \
    \
    && make -C /build/pg_prometheus install \
    \
    && apk del .build-deps \
    && rm -rf /build
