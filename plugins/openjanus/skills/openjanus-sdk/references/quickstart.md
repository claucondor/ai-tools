# Quick Start — JanusFlow v0.5.4 (Fully Shielded Native FLOW + Fees + Recovery)

This guide covers the complete v0.5.4 workflow using `@openjanus/sdk@^0.5.4`.

> **What v0.5.x adds over v0.3:**
> - Inline snapshot events: `wrap`, `shieldedTransfer`, and `unwrap` now emit
>   `*WithSnapshot` EVM events that carry an encrypted `(balance, blinding)` blob.
>   These events are the primary source for cross-device state recovery.
> - Generic `MemoKey` primitive: `JanusFlow.MemoKey` resource type replaces the
>   app-specific `PrivateTip.MemoKey`. Same storage path `/storage/openjanusMemoKey`,
>   now protocol-level and usable by any app.
> - `recovery` module: `@openjanus/sdk/recovery` provides `encryptSnapshotToSelf`,
>   `scanJanusFlowSnapshots`, `reconstructFromSnapshots`, and `readJanusFlowCommitment`.

**SDK version:** `@openjanus/sdk@^0.5.4`
**JanusFlow EVM proxy:** `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078`
**JanusFlow EVM impl (v0.5.4-fees):** `0x4F0914911C2f2beb7bFf6d060F3136bbd8c57943`
**JanusFlow Cadence router:** `0x5dcbeb41055ec57e`
**AmountDiscloseVerifier:** `0x9c83b2b1EFFD3bd375b9Bee93Cb618005D6A2Dc4`
**ConfidentialTransferVerifier:** `0x48f791D2a4992F448Cc36F12e5500b6553e969b3`
**Fee recipient (admin COA):** `0x0000000000000000000000022f6b30Af48A94787`

## Install

```bash
npm install @openjanus/sdk@^0.5.4
```

Circuit artifacts (WASM + zkeys + verification keys + ceremony record) are bundled
at `node_modules/@openjanus/sdk/circuits/v0.3/`.

## Import

```typescript
import {
  JanusFlow,
  JanusFlowCadence,
  JANUS_FLOW_TESTNET,
  buildWrapCalldata,
  buildShieldedTransferCalldata,
  buildUnwrapCalldata,
} from "@openjanus/sdk/tokens";
import {
  buildAmountDiscloseProof,
  buildShieldedTransferProof,
  computeCommitment,
  generateBlinding,
  flowToWei,
  weiToFlow,
} from "@openjanus/sdk/crypto";

// recovery module for cross-device state reconstruction
import {
  encryptSnapshotToSelf,
  decryptSnapshot,
  scanJanusFlowSnapshots,
  reconstructFromSnapshots,
  readJanusFlowCommitment,
  RecoveryDesyncError,
  type Snapshot,
  type RecoveredShieldedState,
} from "@openjanus/sdk/recovery";

// Or via the recovery namespace on the main barrel:
import { recovery } from "@openjanus/sdk";
// recovery.encryptSnapshotToSelf(...)
// recovery.scanJanusFlowSnapshots(...)
```

## App responsibilities

The chain stores only opaque commitments. Every app MUST persist the cleartext
side of every commitment it produces:

- Each `wrap` produces a fresh `blinding`. Store `(amount, blinding)` in
  localStorage paired with the resulting commitment.
- Each `shieldedTransfer` produces a `newBlinding` for the sender's residual
  balance. Store `(newBalance, newBlinding)` and discard the old pair.
- Recipients of a `shieldedTransfer` MUST be told `(transferAmount, transferBlinding)`
  out-of-band — they cannot reconstruct them from on-chain state alone.

**Inline snapshot recovery:** `wrap`, `shieldedTransfer`, and
`unwrap` accept optional `encryptedSnapshot + ephPubkeyX/Y` params. Pass the
output of `encryptSnapshotToSelf()` here so the EVM emits `*WithSnapshot` events.
The `recovery` module can later scan those events to reconstruct state on any device
without any off-band messaging.

## Step 1 — Connect with an ethers v6 signer (EVM direct)

```typescript
const flow = new JanusFlow();                     // canonical testnet defaults
await flow.connectWithSigner(senderSigner);       // ethers v6 wallet / signer
```

`JanusFlow` (concrete class) extends `JanusToken` (abstract base) and adds the
native-FLOW-only `wrap` / `unwrap` methods. The `shieldedTransfer` method is
inherited from the abstract base.

## Step 2 — Wrap FLOW

```typescript
const amountWei = flowToWei(10n);              // 10 FLOW → 10 * 10^18 wei
const blinding  = generateBlinding();          // 128-bit random

const wrapProof = await buildAmountDiscloseProof({
  amount:   amountWei,
  blinding,
  // wasmPath / zkeyPath / vkPath default to the bundled artifacts
});

// encrypt post-wrap snapshot for WrapWithSnapshot event.
// This enables cross-device recovery without a second tx.
const newBalance = existingBalance + amountWei;       // cumulative
const newBlinding = existingBlinding + blinding;      // cumulative sum
const myPubkey = { x: myMemoKeyPubX, y: myMemoKeyPubY };
const snap = await encryptSnapshotToSelf(
  { balance: newBalance, blinding: newBlinding },
  myPubkey
);

const tx = await flow.wrap({
  amountWei,
  txCommit:          wrapProof.txCommit,
  amountProof:       wrapProof.proof,
  encryptedSnapshot: snap.ciphertext,      // optional, default "0x"
  ephPubkeyX:        snap.ephPubkey.x,
  ephPubkeyY:        snap.ephPubkey.y,
});
console.log("Wrap tx:", tx.hash);
```

Or via the Cadence/FCL path using `buildWrapCalldata`:

```typescript
const calldataHex = await buildWrapCalldata(
  wrapProof.txCommit,
  wrapProof.proof,
  snap.ciphertext,   // encryptedSnapshot (optional)
  snap.ephPubkey.x,  // ephPubkeyX
  snap.ephPubkey.y   // ephPubkeyY
);
// pass calldataHex to TX_WRAP / TX_WRAP_FROM_COA via FCL
```

**What leaks at wrap (by design):**

- `msg.value` (the wrap amount in attoFLOW) — observable in the transaction
- `Wrapped(user, amount)` event — observable in logs
- `totalLocked()` delta — observable via public view

**What stays hidden:**

- Per-account `commitments[user]` is updated to a new opaque Point. No observer can
  derive the user's balance from `commitments[user]` alone.

Persist `(amountWei, blinding)` for this commitment.

## Step 3 — Read the shielded balance

```typescript
const commit       = await flow.balanceOfCommitment(userEvmAddr);   // Point
const totalCommit  = await flow.totalSupplyCommitment();            // Point (sum)
const totalLocked  = await flow.totalLocked();                      // bigint (intentional aggregate)
```

To recover the cleartext balance from the commitment, you need the
`(amount, blinding)` you persisted locally. The SDK provides
`decryptBalance(commit, blinding, maxValue)` for an exhaustive search across a
known small range (e.g. after losing the cleartext but still holding the blinding).

## Step 4 — Shielded transfer (amount hidden end-to-end)

```typescript
// Sender side: convert the old commitment into (residual, transferred) pair.
// All five values below come from the sender's local persistent state.
const tProof = await buildShieldedTransferProof({
  oldBalance,        // sender's plaintext residual before the transfer
  oldBlinding,       // sender's blinding before the transfer
  transferAmount,    // amount to send
  transferBlinding,  // fresh blinding for the transfer-commitment (share with recipient)
  newBlinding,       // fresh blinding for sender's residual commitment
});

const tx = await flow.shieldedTransfer({
  to: recipientEvmAddr,
  publicInputs: tProof.publicInputs,   // uint256[6] — six commitment coordinates
  proof:        tProof.proof,           // uint256[8] (pi_b Fp2-swapped, ready for EVM)
});
console.log("Shielded transfer tx:", tx.hash);
```

**What leaks (none on the amount):**

- Sender + recipient addresses (visible by EVM design)
- `ConfidentialTransfer(from, to)` event — no amount field

**What stays hidden:**

- `transferAmount` — never in calldata, never in events, never in storage
- New sender commitment and new recipient commitment are both opaque Points
- The transferred-commitment publicInputs are just curve coordinates — they reveal
  nothing about the underlying value because of the 128-bit blinding

After the transfer, the sender's local store should now hold:

- `(oldBalance - transferAmount, newBlinding)` for the residual
- (and forward `(transferAmount, transferBlinding)` to the recipient out-of-band)

## Step 5 — Unwrap (release FLOW from the pool)

`unwrap` requires BOTH an amount-disclose proof AND a transfer proof — the user
proves the claimed amount matches a commitment they hold, and that commitment is
correctly converted into a residual.

```typescript
const amtProof = await buildAmountDiscloseProof({
  amount:   claimedAmountWei,
  blinding: transferBlinding,         // blinding of the commit being unwrapped
});

const tProof = await buildShieldedTransferProof({
  oldBalance, oldBlinding,
  transferAmount: claimedAmountWei,
  transferBlinding,
  newBlinding,
});

const tx = await flow.unwrap({
  claimedAmountWei,
  recipient,                          // FLOW recipient (EVM address)
  txCommit:             amtProof.txCommit,
  amountProof:          amtProof.proof,
  transferPublicInputs: tProof.publicInputs,
  transferProof:        tProof.proof,
});
console.log("Unwrap tx:", tx.hash);
```

**What leaks at unwrap (by design):**

- `claimedAmount` cleartext (first arg) — necessary so the contract knows how much
  FLOW to release
- `recipient` EVM address
- `Unwrapped(user, recipient, amount)` event
- `totalLocked()` delta

## Cadence router path (cross-VM)

If your UX flows through Cadence (FCL wallet, native-FLOW vault as input),
use the exported templates. The Cadence router at `0x5dcbeb41055ec57e` funds the
user's COA and forwards ABI calldata to the EVM proxy atomically.

```typescript
import { TX_WRAP, TX_SHIELDED_TRANSFER, TX_UNWRAP } from "@openjanus/sdk/tokens";
import * as fcl from "@onflow/fcl";

const txId = await fcl.mutate({
  cadence: TX_WRAP,
  args: (arg, t) => [
    arg(amountUFix64, t.UFix64),
    arg(wrapProof.txCommit.x.toString(), t.UInt256),
    arg(wrapProof.txCommit.y.toString(), t.UInt256),
    arg(wrapProof.proof.map(String), t.Array(t.UInt256)),
  ],
  proposer: fcl.authz,
  payer: fcl.authz,
  authorizations: [fcl.authz],
  limit: 9999,
});
```

Read-only Cadence scripts (admin / introspection):

```typescript
import {
  JanusFlowCadence,
  SCRIPT_IS_PAUSED,
  SCRIPT_GET_TOTAL_LOCKED,
  SCRIPT_GET_ACTIVE_IMPL_VERSION,
  SCRIPT_GET_EVM_TARGET,
} from "@openjanus/sdk/tokens";

const cadence = new JanusFlowCadence();
await cadence.configure();

const paused = await cadence.isPaused();
const lockedUFix = await cadence.getTotalLocked();
const impl = await cadence.getActiveImplVersion();
const evmTarget = await cadence.getEvmTarget();
```

## Admin operations

The UUPS owner (`0x0000000000000000000000022f6b30af48a94787` — the openjanus-flow COA)
controls upgrades on the EVM side. The Cadence router exposes `TX_ADMIN_PAUSE` /
`TX_ADMIN_UNPAUSE` for emergency stop.

```typescript
import { TX_ADMIN_PAUSE, TX_ADMIN_UNPAUSE } from "@openjanus/sdk/tokens";

await fcl.mutate({ cadence: TX_ADMIN_PAUSE,   args: () => [], limit: 9999, ... });
await fcl.mutate({ cadence: TX_ADMIN_UNPAUSE, args: () => [], limit: 9999, ... });
```

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `wrap reverts "amount cap"` | `amountWei > JANUS_FLOW_MAX_WRAP_ATTOFLOW` | Lower the wrap amount; cap is 18 FLOW on v0.3 testnet |
| `shieldedTransfer reverts` | Public inputs / proof shape wrong | Use `buildShieldedTransferProof` — do not hand-build inputs |
| `unwrap reverts` | Amount-disclose blinding does not match the transfer blinding | Always reuse the same `transferBlinding` between the two proof builders for unwrap |
| Proof verify returns false | pi_b Fp2 swap missing (manual proof) | Call `applyPiBSwap` from `@openjanus/sdk/utils` before submit |
| Wrong addresses | Hardcoded v0.2 `0x025efe7e...` | Import from SDK constants (`JANUS_FLOW_EVM_ADDRESS`) |
| Any write reverts with "paused" | Admin emergency stop active | Call `cadence.isPaused()` first; surface error to user |

## Next steps

- [migration-v02-to-v03.md](migration-v02-to-v03.md) — v0.2 ElGamal API rewrite recipes (historical)
- [v03-architecture.md](v03-architecture.md) — Abstract base / concrete pattern + privacy properties
- [decrypt-flow.md](decrypt-flow.md) — Recover a balance from `(commit, blinding, range)`
- [../../../openjanus-tokens/references/janus-flow.md](../../../openjanus-tokens/references/janus-flow.md) — Cadence templates reference
- [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md) — All addresses
