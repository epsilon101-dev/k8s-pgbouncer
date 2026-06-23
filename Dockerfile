# syntax=docker/dockerfile:1.6
FROM debian:bookworm-slim AS builder

ARG PGBOUNCER_VERSION=1.25.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    libevent-dev \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN curl -fsSL "https://www.pgbouncer.org/downloads/files/${PGBOUNCER_VERSION}/pgbouncer-${PGBOUNCER_VERSION}.tar.gz" \
    | tar -xz --strip-components=1 \
    && ./configure \
    --prefix=/usr/local \
    --with-openssl \
    --disable-debug \
    && make pgbouncer \
    && cp pgbouncer /usr/local/bin/pgbouncer

# ── Runtime stage ──────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libevent-2.1-7 \
    libssl3 \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r -g 70 pgbouncer \
    && useradd -r -u 70 -g pgbouncer -d /var/lib/pgbouncer -s /sbin/nologin pgbouncer \
    && mkdir -p /etc/pgbouncer /var/log/pgbouncer \
    && chown -R pgbouncer:pgbouncer /etc/pgbouncer /var/log/pgbouncer \
    && chmod 750 /etc/pgbouncer /var/log/pgbouncer
#   ^ no /var/run here — let emptyDir handle it

COPY --from=builder /usr/local/bin/pgbouncer /usr/local/bin/pgbouncer

USER 70:70

EXPOSE 5432

ENTRYPOINT ["pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
