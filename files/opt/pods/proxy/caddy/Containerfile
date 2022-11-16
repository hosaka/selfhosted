ARG CADDY_VERSION=2.6.2

FROM docker.io/caddy:${CADDY_VERSION}-builder-alpine as builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM docker.io/caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy