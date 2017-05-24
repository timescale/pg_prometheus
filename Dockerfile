FROM postgres:9.6.2-alpine

MAINTAINER erik@timescale.com

ENV PG_MAJOR 9.6
ENV TIMESCALEDB_VERSION 0.0.10-beta
ENV PG_PROMETHEUS_VERSION 0.0.1

COPY pg_prometheus.control Makefile /build/pg_prometheus/
COPY src/*.c src/*.h /build/pg_prometheus/src/
COPY sql/prometheus.sql /build/pg_prometheus/sql/

RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                openssl \
                tar \
    && wget -O /build/${TIMESCALEDB_VERSION}.tar.gz "https://github.com/timescale/timescaledb/archive/${TIMESCALEDB_VERSION}.tar.gz" \
    \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                dpkg-dev dpkg \
                gcc \
                libc-dev \
                make \
                util-linux-dev \
    \
    && tar zxf /build/${TIMESCALEDB_VERSION}.tar.gz -C /build \
    && make -C /build/timescaledb-${TIMESCALEDB_VERSION} install \
    \
    && make -C /build/pg_prometheus install \
    \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build \
    && sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" /usr/local/share/postgresql/postgresql.conf.sample
