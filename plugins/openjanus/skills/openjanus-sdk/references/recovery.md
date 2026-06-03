# Recovery Module — `@claucondor/sdk/recovery`

SDK version: `@claucondor/sdk@0.6.5`

Cross-device shielded-state reconstruction from on-chain `*WithSnapshot` events.

---

## Why recovery?

The chain stores only opaque Pedersen commitment points. Per-account `(balance,
blinding)` lives locally. If the user clears `localStorage` or switches devices,
that state is lost.

**Inline snapshot solution (current in v0.6.5):** every `wrap`, `shieldedTransfer`, and `unwrap` embeds an
encrypted `(balance, blinding)` snapshot in the EVM transaction via three new
events:

| Event | Who can decrypt |
|-------|----------------|
| `WrapWithSnapshot(user, amount, ciphertext, ephX, ephY)` | user (self-encrypted) |
| `ShieldedTransferWithSnapshot(sender, recipient, ciphertext, ephX, ephY)` | sender (self-encrypted residual) |
| `UnwrapWithSnapshot(user, amount, ciphertext, ephX, ephY)` | user (self-encrypted residual) |

The snapshot ciphertext is ECIES-encrypted (BabyJubJub + AES-GCM) to the
user's own `MemoKey` pubkey. Only the holder of the matching privkey can decrypt.

---

## Import

```typescript
// Named imports from subpath (recommended):
import {
  encryptSnapshotToSelf,
  decryptSnapshot,
  scanJanusFlowSnapshots,
  reconstructFromSnapshots,
  readJanusFlowCommitment,
  validatePedersenCommit,
  RecoveryDesyncError,
  type Snapshot,
  type RawSnapshot,
  type RecoveredShieldedState,
  type IncomingDelta,
  JANUS_FLOW_DEFAULT,
} from "@claucondor/sdk/recovery";

// Or via the recovery namespace on the main barrel:
import { recovery } from "@claucondor/sdk";
// recovery.encryptSnapshotToSelf(...)
// recovery.scanJanusFlowSnapshots(...)
// etc.
```

---

## API surface

### `encryptSnapshotToSelf(snapshot, myPubkey)`

Encrypt a post-action `(balance, blinding)` pair to the user's own MemoKey
pubkey. Returns the ciphertext blob + ephemeral pubkey for the EVM event.

```typescript
const snap = await encryptSnapshotToSelf(
  { balance: newBalanceWei, blinding: newBlinding },
  { x: myPubkeyX, y: myPubkeyY }
);
// snap.ciphertext: Uint8Array
// snap.ephPubkey.x: bigint
// snap.ephPubkey.y: bigint

// Pass to calldata builders:
const calldataHex = await buildWrapCalldata(
  txCommit, amountProof,
  snap.ciphertext, snap.ephPubkey.x, snap.ephPubkey.y
);
```

### `decryptSnapshot(ciphertext, ephPubkey, myPrivkey)`

Decrypt a single snapshot blob. Returns `null` on failure (wrong key,
corrupt ciphertext, or snapshot for a different user — all silent).

```typescript
const decoded = await decryptSnapshot(
  raw.ciphertext,
  raw.ephPubkey,
  myMemoPrivkey
);
if (decoded) {
  console.log(decoded.balance, decoded.blinding);
}
```

### `scanJanusFlowSnapshots(userEvmAddr, provider, opts?)`

Scan the JanusFlow EVM proxy for all `*WithSnapshot` events involving
`userEvmAddr` as `user` or `sender`. Returns raw encrypted blobs.

```typescript
const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const raws: RawSnapshot[] = await scanJanusFlowSnapshots(
  myCoaEvmAddr,
  provider,
  { janusFlowAddr: "0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156" }
  // fromBlock?: number  (default: 0 — full history)
);
// Each RawSnapshot: { ciphertext, ephPubkey, timestamp, txHash, blockNumber }
```

### `readJanusFlowCommitment(userEvmAddr, provider, janusFlowAddr?)`

Read the user's on-chain Pedersen commitment from `commitments(address)`.
Returns `{ x: bigint, y: bigint }`. Identity point is `{ x: 0n, y: 1n }`.

```typescript
const commit = await readJanusFlowCommitment(myCoaEvmAddr, provider);
const isEmpty = commit.x === 0n && commit.y === 1n;
```

### `validatePedersenCommit(balance, blinding, expectedCommit)`

Verify that `Pedersen(balance, blinding)` equals `expectedCommit`.
Returns `true` on match, `false` on desync.

```typescript
const ok = await validatePedersenCommit(recoveredBalance, recoveredBlinding, onChainCommit);
```

### `reconstructFromSnapshots(opts)`

Pure reconstruction algorithm. Takes decrypted snapshots + incoming deltas +
on-chain commitment. Throws `RecoveryDesyncError` if the reconstructed state
doesn't match the chain.

```typescript
const state: RecoveredShieldedState = await reconstructFromSnapshots({
  snapshots,      // Snapshot[] — decrypted own snapshots (absolute states)
  incomingDeltas, // IncomingDelta[] — incoming tips since last snapshot (optional)
  onChainCommit,  // { x, y } — from readJanusFlowCommitment
});
// state.balanceWei: bigint
// state.blinding: bigint
```

### `RecoveryDesyncError`

Thrown when the reconstructed `(balance, blinding)` doesn't match the
on-chain Pedersen commitment. This means either:
- Activity occurred before snapshot events were added to the contract.
- MemoKey was rotated — existing snapshots encrypted to the old key.
- Chain data is corrupt (extremely unlikely).

```typescript
try {
  const state = await reconstructFromSnapshots(...);
} catch (err) {
  if (err instanceof RecoveryDesyncError) {
    // Do NOT write to localStorage — the state is wrong.
    // Show the user an error and offer "Restore from backup" UX.
  }
}
```

---

## Full recovery flow

```typescript
import { ethers } from "ethers";
import {
  scanJanusFlowSnapshots,
  decryptSnapshot,
  readJanusFlowCommitment,
  reconstructFromSnapshots,
  RecoveryDesyncError,
  type Snapshot,
} from "@claucondor/sdk/recovery";

async function recoverFromChain(
  myCoaEvmAddr: string,
  myMemoPrivkey: bigint
) {
  const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");

  // 1. Scan events.
  const raws = await scanJanusFlowSnapshots(myCoaEvmAddr, provider);

  // 2. Decrypt.
  const snapshots: Snapshot[] = [];
  for (const raw of raws) {
    const decoded = await decryptSnapshot(raw.ciphertext, raw.ephPubkey, myMemoPrivkey);
    if (decoded) {
      snapshots.push({
        balance: decoded.balance,
        blinding: decoded.blinding,
        timestamp: raw.timestamp,
        txHash: raw.txHash,
      });
    }
  }

  // 3. On-chain commitment for validation.
  const onChainCommit = await readJanusFlowCommitment(myCoaEvmAddr, provider);

  // 4. Reconstruct + validate.
  try {
    return await reconstructFromSnapshots({ snapshots, onChainCommit });
  } catch (err) {
    if (err instanceof RecoveryDesyncError) {
      // Slot reset required — see admin ops.
      throw err;
    }
    throw err;
  }
}
```

---

## Types

```typescript
interface RawSnapshot {
  ciphertext: Uint8Array;
  ephPubkey: { x: bigint; y: bigint };
  timestamp: number;   // Unix seconds (estimated from block)
  txHash: string;
  blockNumber: number;
}

interface Snapshot {
  balance: bigint;
  blinding: bigint;
  timestamp: number;
  txHash: string;
}

interface IncomingDelta {
  amount: bigint;
  blinding: bigint;
  timestamp: number;
}

interface RecoveredShieldedState {
  balanceWei: bigint;
  blinding: bigint;
}
```

---

## Known limitations

| Scenario | Recovery outcome |
|----------|-----------------|
| Fresh account (no wraps) | Returns `null` — identity slot |
| Wraps before snapshot events were added | Throws `RecoveryDesyncError` — admin slot reset required |
| MemoKey rotated | Cannot decrypt old snapshots — rotate back or reset slot |
| Activity from another device after recovery | Next wrap/send/unwrap emits new snapshot — recovery works again |

---

## See also

- [quickstart.md](quickstart.md) — Wrap / shieldedTransfer / unwrap with snapshot params
- [../openjanus-tokens/references/janus-flow.md](../openjanus-tokens/references/janus-flow.md) — MemoKey Cadence API
- [../openjanus-elgamal/references/sign-derive.md](../../openjanus-elgamal/references/sign-derive.md) — MemoKey privkey derivation
