# Chain specs

Raw chain specs for the public AETRON networks. A node that follows mainnet or
testnet runs from one of these files, not from `--chain mainnet` / `--chain testnet`.

| Network | File | Genesis hash |
| --- | --- | --- |
| Mainnet | `aetron-mainnet-raw.json` | `0xed62243b8824023257fe3d2887c2379dfcae9d55ec9727b9f56a6fde8283125d` |
| Testnet | `aetron-testnet-raw.json` | `0x2e45803a320dbf6c0d3fc8bdc6059107aca00e6f285961a394d103c0391e1074` |

## Why the built-in names are not enough

`--chain mainnet` and `--chain testnet` build a genesis from whatever the current
code says it should be. The live chains were started from earlier code, so the
genesis that comes out does not match theirs. A node built that way is not
"slightly out of date" — it is on a different chain, and it will sit at zero
peers indefinitely because no peer agrees with its genesis.

The hashes above are what the live networks actually report. Confirm them
yourself against a public endpoint:

```bash
curl -s https://entrypoint-mainnet.aetron.ai \
  -H 'Content-Type: application/json' \
  -d '{"id":1,"jsonrpc":"2.0","method":"chain_getBlockHash","params":[0]}'
```

## Checking a spec before you trust it

A raw spec is a genesis state, so it either hashes to the right value or it does
not. Start a throwaway node against the file and read the block-zero hash out of
the log:

```bash
aetron-node --chain ./aetron-mainnet-raw.json --tmp 2>&1 | grep -i genesis
```

If the hash in that line is not the one in the table above, the spec is for a
different chain. Stop there rather than debugging peering.

## Where these files came from

Not from `build-spec`. `aetron-node build-spec --chain mainnet --raw` builds a
genesis out of the current code and produces a spec for a chain that does not
exist — it is the trap described above, not the cure.

These two were reconstructed from the live networks. A raw spec's
`genesis.raw.top` is exactly the storage map at block zero, and that is readable
over the public RPC without any privileged method:

```bash
# page the keys at block 0
state_getKeysPaged ["0x", 1000, null, "<genesis hash>"]
# then one value per key
state_getStorage  ["<key>", "<genesis hash>"]
```

Mainnet genesis holds 106 keys, testnet 107, so this is a handful of requests.
Everything outside `genesis` — `id`, `protocolId`, `properties`, `bootNodes`,
`forkBlocks`, `badBlocks` — is carried over from the built-in spec of the same
code tree that launched the chain.

Both files were verified the only way that means anything: fed to a node, and
the resulting genesis hash compared against the live one. Both matched, and a
node started from each found peers and began syncing.

## Updating a spec

The genesis of a live chain never changes, so these files only need touching
when something outside genesis does — bootnodes, telemetry endpoints, the
protocol id. Editing anything under `genesis` changes the hash and breaks the
file for its network.
