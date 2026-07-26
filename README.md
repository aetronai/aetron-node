# aetron-node

The blockchain client for [AETRON](https://aetron.io). It is a Substrate node with a Frontier layer, so one process serves both the Substrate JSON-RPC and the Ethereum JSON-RPC on the same port.

The node does not run AI work. Inference and training happen on [miners](https://github.com/aetronai/aetron-miner); the node carries the accounting and the proofs around them.

This repository distributes prebuilt binaries, chain specs and a Docker image. The source tree is not public.

## Download

[![Linux x86_64](https://img.shields.io/badge/Download-Linux%20x86__64-1a1a1a?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/aetronai/aetron-node/releases/latest/download/aetron-node-linux-x86_64.tar.gz)
[![macOS Apple Silicon](https://img.shields.io/badge/Download-macOS%20arm64-1a1a1a?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/aetronai/aetron-node/releases/latest/download/aetron-node-macos-arm64.tar.gz)
[![Docker](https://img.shields.io/badge/Docker-ghcr.io-2496ed?style=for-the-badge&logo=docker&logoColor=white)](#docker)

Every link points at the newest release. [All releases and changelogs →](https://github.com/aetronai/aetron-node/releases)

Each archive holds the `aetron-node` binary and both chain specs. Verify what you downloaded before you run it:

```bash
curl -fLO https://github.com/aetronai/aetron-node/releases/latest/download/aetron-node-linux-x86_64.tar.gz
curl -fLO https://github.com/aetronai/aetron-node/releases/latest/download/SHA256SUMS
sha256sum --check --ignore-missing SHA256SUMS

tar -xzf aetron-node-linux-x86_64.tar.gz
./aetron-node --help
```

There is no `--version` flag. The node prints its version and the commit it was
built from in the startup banner:

```
AETRON Node
✌️  version 0.0.1-48c5ec134ec
```

On macOS use `shasum -a 256 -c` instead, and see [macOS Gatekeeper](#macos-gatekeeper) below before the first run.

## Chain Specs: Read This First

The node accepts `--chain dev`, `--chain mainnet`, `--chain testnet`, or a path to a JSON spec file.

**The built-in `mainnet` and `testnet` names do not connect you to the live networks.** They build a genesis from the current code, and the live chains were started from earlier ones, so the genesis hash comes out different and your node never finds a peer that agrees with it. The symptom is a healthy process sitting at zero peers forever.

A node that follows a public network runs from a raw spec file. Both ship in every release archive, under `chainspecs/`, and are published as standalone assets:

| Network | Spec file | Genesis hash |
| --- | --- | --- |
| Mainnet | `aetron-mainnet-raw.json` | `0xed62243b8824023257fe3d2887c2379dfcae9d55ec9727b9f56a6fde8283125d` |
| Testnet | `aetron-testnet-raw.json` | `0x2e45803a320dbf6c0d3fc8bdc6059107aca00e6f285961a394d103c0391e1074` |

Those hashes are the ones to check against, and you can confirm them against the live chain yourself:

```bash
curl -s https://entrypoint-mainnet.aetron.ai \
  -H 'Content-Type: application/json' \
  -d '{"id":1,"jsonrpc":"2.0","method":"chain_getBlockHash","params":[0]}'
```

`--chain dev` is the exception and is exactly right for a throwaway local chain.

## Running

Testnet:

```bash
./aetron-node \
  --base-path /data/aetron-testnet \
  --chain ./chainspecs/aetron-testnet-raw.json \
  --name my-node
```

Mainnet — same thing with the other spec:

```bash
./aetron-node \
  --base-path /data/aetron-mainnet \
  --chain ./chainspecs/aetron-mainnet-raw.json \
  --name my-node
```

Each spec carries its network's bootnode, so there is no `--bootnodes` to pass.
Add the flag only to point at extra peers of your own.

A local chain that owes nothing to the public networks, no spec file needed:

```bash
./aetron-node --dev --base-path /tmp/aetron-dev
```

`--dev` produces blocks on its own with Alice as the sole authority and sudo. Every key on a dev chain is a well-known public one, so never reuse those seeds anywhere real.

To expose the RPC beyond localhost, add `--rpc-external --rpc-cors all --rpc-methods safe`. Keep `safe` on anything reachable from outside: the unsafe set includes key insertion and peer management.

Check that it worked:

```bash
curl -s http://127.0.0.1:9944 \
  -H 'Content-Type: application/json' \
  -d '{"id":1,"jsonrpc":"2.0","method":"system_health","params":[]}'
```

`isSyncing: false` with a non-zero `peers` count means you are caught up and connected. Zero peers with a healthy process almost always means the genesis does not match, which takes you back to the spec section above.

## Docker

The image carries the binary and both chain specs. Nothing is compiled at build time — it unpacks the same release archive you would download by hand.

```bash
docker run -d --name aetron-node \
  -p 30333:30333 -p 127.0.0.1:9944:9944 \
  -v aetron-mainnet:/data \
  ghcr.io/aetronai/aetron-node:latest \
  --base-path /data \
  --chain /etc/aetron/chainspecs/aetron-mainnet-raw.json \
  --name my-node \
  --rpc-external --rpc-cors all --rpc-methods safe
```

`--rpc-external` is required inside a container because the RPC has to listen on the container's own interface rather than its loopback. Binding the host side to `127.0.0.1:9944` is what keeps it off the public internet — publish it on `0.0.0.0` only behind a reverse proxy you control.

### Compose

[`docker-compose.yml`](./docker-compose.yml) defines a mainnet service and a testnet one, each with its own volume and ports:

```bash
curl -fLO https://raw.githubusercontent.com/aetronai/aetron-node/main/docker-compose.yml
docker compose up -d mainnet
docker compose logs -f mainnet
```

Both networks side by side, on separate ports:

```bash
docker compose up -d mainnet testnet
```

Add `--profile archive` for an archive node that keeps full state and block history.

### Building the image yourself

[`Dockerfile`](./Dockerfile) takes the release tag as a build argument:

```bash
docker build -t aetron-node:local --build-arg VERSION=latest .
docker build -t aetron-node:v0.1.0 --build-arg VERSION=v0.1.0 .
```

The published image is `linux/amd64`. On Apple Silicon it runs under emulation,
and there the node starts and answers RPC but does not reliably complete peer
handshakes — the emulated crypto is slow enough to hit libp2p's timeout, so the
node sits at zero peers. Use the native macOS binary on a Mac; the image is for
Linux hosts.

## Requirements

A node that keeps up with the head wants 4 cores, 8 GB of RAM and fast NVMe. An archive node needs considerably more disk and keeps growing, so size it for where the chain will be rather than where it is.

The binary carries the runtime with it; there is nothing to install alongside it. On Linux it is dynamically linked against glibc 2.34 or newer, which covers Debian 12, Ubuntu 22.04 and anything more recent. On older distributions use the Docker image.

## Ports

| Port | What | Flag |
| --- | --- | --- |
| 30333 | libp2p, peer to peer | `--port` |
| 9944 | JSON-RPC, both Substrate and Ethereum | `--rpc-port` |
| 9615 | Prometheus metrics | `--prometheus-port` |

30333 needs to be reachable for good peering. Running a second node on the same host means moving all three.

## Pruning and Archive Mode

There is no `--pruning` flag; it is split in two:

```bash
  --state-pruning archive --blocks-pruning archive
```

Without those the node keeps a recent window of state and discards the rest, which is right for following the head and useless for indexing history. An indexer or a block explorer needs both set to `archive`.

## The Ethereum Layer

The Ethereum JSON-RPC is served from the same port as the Substrate one, so `eth_*` calls work with nothing extra enabled. Chain id is 3355 on mainnet and 3356 on testnet.

One thing to keep in mind: the native chain counts AET in 9 decimals and the EVM layer in 18. Frontier scales between them, so the same balance looks different depending on which side you ask.

`--enable-dev-signer` hands transaction signing to the node itself. Leave it off on anything public.

## Subcommands

| Subcommand | What it does |
| --- | --- |
| `key` | Generate and inspect keys, insert them into the keystore |
| `build-spec` | Produce a chain spec, with `--raw` for the deployable form |
| `export-blocks`, `import-blocks` | Move block data in and out of a node |
| `export-state` | Dump state at a block into a spec |
| `check-block` | Re-validate a single block |
| `revert` | Roll the chain back by N blocks |
| `purge-chain` | Delete the database for a base path |
| `chain-info` | Print database metadata |

## macOS Gatekeeper

macOS quarantines anything downloaded from the internet, and an unsigned binary is refused on the first run. Clear the flag on the extracted file:

```bash
xattr -d com.apple.quarantine ./aetron-node
```

## Validators

Block production uses Aura, with GRANDPA for finality. The validator set is not open at the moment: the base chain runs in a permissioned mode while the verification protocol is rolled out. Running a full node is open to anyone, producing blocks is not.

## Do You Even Need a Node

Most people do not. The public endpoints answer the same RPC, and a miner or a gateway is perfectly happy pointed at them:

| | Mainnet | Testnet |
| --- | --- | --- |
| WebSocket | `wss://entrypoint-mainnet.aetron.ai` | `wss://entrypoint-test.aetron.ai` |
| HTTPS | `https://entrypoint-mainnet.aetron.ai` | `https://entrypoint-test.aetron.ai` |

Run your own when you want no rate limits and no dependency on someone else's uptime, when you need archive state that public endpoints prune away, when you are indexing the chain, or when you are operating a validator.

## Documentation

- [Running a Node](https://docs.aetron.io/docs/network/running-a-node) — the long version of this page
- [Networks and Endpoints](https://docs.aetron.io/docs/network/endpoints)
- [EVM Compatibility](https://docs.aetron.io/docs/blockchain/evm)
- [Explorer](https://explorer.aetron.io) · [Console](https://app.aetron.io)

Problems with a release or the image go in [Issues](https://github.com/aetronai/aetron-node/issues).
