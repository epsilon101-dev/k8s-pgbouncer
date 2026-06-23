# syntax=docker/dockerfile:1.6
# Builder stage
FROM debian:bookworm-slim@sha256:96e378d7e6531ac9a15ad505478fcc2e69f371b10f5cdf87857c4b8188404716 AS builder

ARG PGBOUNCER_VERSION=1.25.2
ARG PGBOUNCER_SHA256=924ad35113fd0a71c8e2dbe85b5d03445532e2b7b37a9f8a48983beea238b332

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
    -o pgbouncer.tar.gz \
    && echo "${PGBOUNCER_SHA256}  pgbouncer.tar.gz" | sha256sum -c - \
    && tar -xz --strip-components=1 -f pgbouncer.tar.gz \
    && rm pgbouncer.tar.gz \
    && ./configure \
    --prefix=/usr/local \
    --with-openssl \
    --disable-debug \
    && make pgbouncer \
    && cp pgbouncer /usr/local/bin/pgbouncer

# Runtime stage
FROM debian:bookworm-slim@sha256:96e378d7e6531ac9a15ad505478fcc2e69f371b10f5cdf87857c4b8188404716

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libevent-2.1-7 \
    libssl3 \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r -g 70 pgbouncer \
    # rejects shell access, using -s /sbin/nologin
    && useradd -r -u 70 -g pgbouncer -d /var/lib/pgbouncer -s /sbin/nologin pgbouncer \
    && mkdir -p /etc/pgbouncer /var/log/pgbouncer \
    && chown -R pgbouncer:pgbouncer /etc/pgbouncer /var/log/pgbouncer \
    && chmod 750 /etc/pgbouncer /var/log/pgbouncer
# ^ no /var/run here — let emptyDir handle it

COPY --from=builder /usr/local/bin/pgbouncer /usr/local/bin/pgbouncer

USER 70:70
EXPOSE 5432
ENTRYPOINT ["pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
