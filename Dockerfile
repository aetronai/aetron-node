# aetron-node
#
# The image unpacks a published release archive rather than compiling anything.
# The node is a large Rust build; fetching the same artifact everyone else
# downloads keeps the image reproducible and the build under a minute.
#
#   docker build -t aetron-node:local --build-arg VERSION=latest .
#   docker build -t aetron-node:v0.1.0 --build-arg VERSION=v0.1.0 .
#
# Chain specs come from this repository, not from the archive: they are the
# source of truth, they change independently of the binary, and keeping them in
# git means a spec can be reviewed in a diff.
#
# Base image note: the Linux binary needs glibc 2.34 or newer. Debian 12
# (bookworm) ships 2.36 and works; Debian 11 (bullseye) ships 2.31 and does not.

ARG DEBIAN_TAG=bookworm-slim

FROM debian:${DEBIAN_TAG} AS fetch

ARG VERSION=latest
ARG ASSET=aetron-node-linux-x86_64.tar.gz
ARG REPO=aetronai/aetron-node

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl tar \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /fetch
RUN set -eux; \
    if [ "$VERSION" = "latest" ]; then \
      url="https://github.com/${REPO}/releases/latest/download/${ASSET}"; \
    else \
      url="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"; \
    fi; \
    echo "fetching ${url}"; \
    curl -fsSL "$url" -o release.tar.gz; \
    tar -xzf release.tar.gz; \
    # The archive may or may not carry a top-level directory, so locate the
    # binary instead of assuming a layout.
    find . -type f -name 'aetron-node' -exec install -D -m 0755 {} /out/aetron-node \; ; \
    test -x /out/aetron-node

FROM debian:${DEBIAN_TAG}

LABEL org.opencontainers.image.title="aetron-node" \
      org.opencontainers.image.description="AETRON blockchain node (Substrate + Frontier)" \
      org.opencontainers.image.source="https://github.com/aetronai/aetron-node" \
      org.opencontainers.image.documentation="https://docs.aetron.io/docs/network/running-a-node"

# ca-certificates for the WebSocket bootnodes and telemetry, libstdc++ for the
# binary itself, curl only so HEALTHCHECK has something to call.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl libstdc++6 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --create-home --home-dir /data --uid 1000 aetron

COPY --from=fetch /out/aetron-node /usr/local/bin/aetron-node
COPY chainspecs/ /etc/aetron/chainspecs/

USER aetron
WORKDIR /data
VOLUME /data

# 30333 libp2p · 9944 JSON-RPC (Substrate + Ethereum) · 9615 Prometheus
EXPOSE 30333 9944 9615

# Reports unhealthy until the node answers RPC. It deliberately does not check
# peer count: a node still finding peers is starting, not broken.
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -fsS -H 'Content-Type: application/json' \
      -d '{"id":1,"jsonrpc":"2.0","method":"system_health","params":[]}' \
      http://127.0.0.1:9944 | grep -q '"peers"'

ENTRYPOINT ["aetron-node"]

# Overridden in practice. Without a raw spec the node builds a genesis that no
# public network agrees with, so there is no useful default to put here.
CMD ["--help"]
