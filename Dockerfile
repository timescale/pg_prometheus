FROM postgres:10.4-alpine

MAINTAINER erik@timescale.com

ENV PG_MAJOR 10.4
ENV TIMESCALEDB_VERSION 0.11.0
ENV PG_PROMETHEUS_VERSION 0.2

COPY pg_prometheus.control Makefile /build/pg_prometheus/
COPY src/*.c src/*.h /build/pg_prometheus/src/
COPY sql/prometheus.sql /build/pg_prometheus/sql/

RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                openssl \
                tar \
                git \
    && git clone https://github.com/timescale/timescaledb -b ${TIMESCALEDB_VERSION} /build/timescaledb-${TIMESCALEDB_VERSION} \
    \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                dpkg-dev dpkg \
                gcc \
                libc-dev \
                make \
                util-linux-dev \
                cmake \
    \
    && cd /build/timescaledb-${TIMESCALEDB_VERSION} && ./bootstrap && cd build && make install \
    \
    && sed -i "s/default_version = '[0-9.]\+'/default_version = '${PG_PROMETHEUS_VERSION}'/" /build/pg_prometheus/pg_prometheus.control \
    && make -C /build/pg_prometheus install \
    \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build \
    && sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" /usr/local/share/postgresql/postgresql.conf.sample
