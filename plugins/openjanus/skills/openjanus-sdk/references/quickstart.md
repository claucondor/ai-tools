# Quick Start — JanusFlow v0.3 (Fully Shielded Native FLOW)

This guide covers the complete v0.3 workflow using `@openjanus/sdk@^0.3.0`.

> **What v0.3 provides:** native FLOW custody with fully shielded internal transfers.
> `wrap` and `unwrap` are visible at the boundary by design (audit-friendly pool aggregate).
> `shieldedTransfer` hides the amount on calldata, storage, events, and the
> commitment is computationally hiding (128-bit blinding).

**SDK version:** `@openjanus/sdk@^0.3.0`
**JanusFlow EVM proxy:** `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078`
**JanusFlow Cadence router:** `0x5dcbeb41055ec57e`

## Install

```bash
npm install @openjanus/sdk@^0.3.0
```

Circuit artifacts (WASM + zkeys + verification keys + ceremony record) are bundled
at `node_modules/@openjanus/sdk/circuits/v0.3/`.

## Import

```typescript
import {
  JanusFlow,
  JanusFlowCadence,
  JANUS_FLOW_TESTNET,
} from "@openjanus/sdk/tokens";
import {
  buildAmountDiscloseProof,
  buildShieldedTransferProof,
  computeCommitment,
  generateBlinding,
  flowToWei,
  weiToFlow,
} from "@openjanus/sdk/crypto";
```

## App responsibilities (new in v0.3)

The chain stores only opaque commitments. There is no on-chain decryption key.
Every app MUST persist (locally on the user's device) the cleartext side of every
commitment it produces:

- Each `wrap` produces a fresh `blinding`. Store `(amount, blinding)` paired
  with the resulting commitment.
- Each `shieldedTransfer` produces a `newBlinding` for the sender's residual
  balance. Store `(newBalance, newBlinding)` and discard the old pair.
- Recipients of a `shieldedTransfer` MUST be told `(transferAmount, transferBlinding)`
  out-of-band — they cannot reconstruct them from on-chain state alone. Common
  patterns: encrypted messaging channel, push notification, off-chain receipt.

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
  // wasmPath / zkeyPath / vkPath default to the bundled v0.3 artifacts
});

const tx = await flow.wrap({
  amountWei,
  txCommit:    wrapProof.txCommit,
  amountProof: wrapProof.proof,
});
console.log("Wrap tx:", tx.hash);
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

- [migration-v02-to-v03.md](migration-v02-to-v03.md) — v0.2 ElGamal API rewrite recipes
- [v03-architecture.md](v03-architecture.md) — Abstract base / concrete pattern + privacy properties
- [decrypt-flow.md](decrypt-flow.md) — Recover a balance from `(commit, blinding, range)`
- [../../../openjanus-tokens/references/janus-flow.md](../../../openjanus-tokens/references/janus-flow.md) — Cadence templates reference
- [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md) — All addresses
