# v0.8.x Architecture — Adapters, Orchestration, Checkpoint, Inbox, Safety

> This document was previously titled "v0.3 Architecture". It is rewritten in-place
> to describe the current v0.8.x production stack. For historical v0.3 context, see
> `migration-to-v08.md` which preserves the v0.3 → v0.8 transition story.

---

## The pattern in one sentence

`sdk.token(id)` returns a `JanusTokenAdapter` — a thin token-specific shell that
delegates all proof building and state management to `src/orchestration/`. Apps
interact with adapters; adapters never build proofs directly.

## Module layout (v0.8)

```
src/
  adapters/       — JanusTokenAdapter interface + 3 generic variant implementations
  orchestration/  — ALL crypto + ordering logic (wrap/shieldedTransfer/unwrap)
  crypto/         — ECIES, note-helpers, checkpoint-schema, memokey derivation, proof builders
  proof/          — Groth16 wrappers + pi_b swap
  network/        — EVM/Cadence clients + TOKEN_REGISTRY
  inbox/          — ShieldedInboxClient (state recovery — drains EVM and Cadence inboxes)
  checkpoint/     — ShieldedCheckpointClient (sender-side encrypted state store)
  cadence/        — Cadence transaction templates (atomic wrap+checkpoint, install, etc.)
  batchClaim/     — BatchClaimClient (batch note consolidation)
  portfolio/      — getPortfolioView (multi-token drift detector)
  safety/         — safeBuild* guards (pre-flight commitment coherence checks)
  session/        — MemoKeySession + SentMemoStore (browser-side caching)
  identity/       — resolveRecipient (Cadence ↔ EVM address resolution)
  utils/          — helpers: pi_b swap, ufix64, evm-helpers, fresh-slot detection
  primitives/     — computeCommitment, addCommitmentsLocal
  types/          — shared TypeScript interfaces
```

## Adapter hierarchy (TypeScript)

```
JanusTokenAdapter (interface — src/adapters/JanusTokenAdapter.ts)
│
├── wrap(params, signer): Promise<WrapResult>
├── shieldedTransfer(params, signer): Promise<SendResult>
├── unwrap(params, signer): Promise<UnwrapResult>
└── publishMemoKey(keypair, signer): Promise<TxResult>

JanusFlowAdapter   — native FLOW (EVM payable, COA-mediated)
JanusERC20Adapter  — ERC20 tokens (MockUSDC; approve-then-wrap)
JanusFTAdapter     — Cadence FT tokens (JanusFT registry; FCL-signed)
```

All adapters are instantiated lazily through `sdk.token(id)`:

```typescript
import { sdk } from "@claucondor/sdk";
const flow    = sdk.token('flow');     // JanusFlowAdapter
const usdc    = sdk.token('mockusdc'); // JanusERC20Adapter
const ft      = sdk.token('mockft');   // JanusFTAdapter
```

## State model (v0.8)

### Sender state — ShieldedCheckpoint

The `ShieldedCheckpoint` contract stores one encrypted slot per `(owner, token)` pair.
The slot contains:
- `encryptedSnapshot`: ECIES ciphertext of `{ balance: bigint, blinding: bigint }`
- `ephPubkeyX`, `ephPubkeyY`: ephemeral BabyJub pubkey for ECIES decryption
- `lastConsumedNoteIndex`: cursor into the ShieldedInbox (notes before this index are already absorbed)
- `lastUpdatedBlock`, `version`: metadata

Only the slot owner (`msg.sender = COA`) can call `read(token)`. Public `metadata(user, token)` exposes non-sensitive fields.

```
ShieldedCheckpoint (EVM): 0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26
```

### Recipient state — ShieldedInbox

`shieldedTransfer` deposits an ECIES-encrypted note into the recipient's EVM `ShieldedInbox`.
The note contains `{ amount, blinding, memo }`. The depositor field identifies the token.

Cadence FT notes (`mockft`) go to the Cadence `ShieldedInbox` resource — a separate
on-chain data store under the recipient's Cadence account.

```
ShieldedInbox (EVM): 0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6
```

### On-chain commitment

Each JanusToken contract stores a Pedersen commitment per user:
```
commitments[user] = amount * G + blinding * H   (BabyJubJub point)
```
Updated homomorphically on every `wrap`, `shieldedTransfer`, and `claimBatch`.
`totalLocked` (visible aggregate) is the only cleartext per-pool aggregate.

## Protocol flow per operation

### wrap (JanusFlow)

```
1. Caller builds AmountDisclose proof: Pedersen(grossAmount, blinding)
2. Cadence tx (FCL) or EVM tx (ethers):
     a. Transfer FLOW to JanusFlow EVM contract
     b. JanusFlow.wrap(txCommit, amountProof) — updates commitments[COA]
3. SDK returns checkpointPayload (encrypted new balance snapshot)
4. Caller submits ShieldedCheckpoint.update(token, payload, cursor) — OR
   Uses cadenceTx.wrapFlowAtomic — atomic: wrap + checkpoint in one Cadence tx
```

### shieldedTransfer (v0.8 — 6-arg)

```
1. Caller reads ShieldedCheckpoint → { balance, blinding }
2. Caller builds ConfidentialTransfer proof:
     C_old = Pedersen(oldBalance, oldBlinding)
     C_new = Pedersen(newBalance, newBlinding)    ← sender residual
     C_sent = Pedersen(amount, sentBlinding)      ← recipient receives
3. Caller builds ShieldedNote: ECIES(amount, sentBlinding, memo) → recipient MemoKey
4. JanusToken.shieldedTransfer(recipient, ciphertext, ephX, ephY, publicInputs, proof)
   → token contract verifies proof, updates sender/recipient commitments
   → deposits ECIES note in ShieldedInbox
5. SDK returns { txHash, checkpointPayload, newBalance, newBlinding }
6. Caller submits ShieldedCheckpoint.update(token, checkpointPayload, lastConsumedNoteIndex)
```

The sender snapshot is no longer embedded in calldata (v0.7 had it). The checkpoint
is a separate write — or use `combinedShieldedTransferWithCheckpoint` Cadence template.

### claimBatch

```
1. Caller reads ShieldedInbox.peek(owner, 0, count) → list of notes
2. Caller decrypts notes with MemoKey privkey
3. Caller builds ConfidentialClaimBatch proof (N=50 padded):
     C_old = current commitment
     C_consumed = Pedersen(Σ amounts, Σ blindings)
     C_new = C_old + C_consumed
4. JanusToken.claimBatch(publicInputs[6], proof[8])
   → adds consumed sum to caller's commitment
5. Caller updates ShieldedCheckpoint with new balance + cursor = lastNoteIndex+1
```

## ShieldedCheckpoint — per-token (v0.8.2 breaking change)

Before v0.8.2, the checkpoint was a singleton shared across tokens.
v0.8.2 added `address token` as a first argument to `read()` and `update()`.
FLOW and mUSDC checkpoints are now isolated.

```typescript
import { ShieldedCheckpointClient, TOKEN_REGISTRY } from "@claucondor/sdk";

const cp = new ShieldedCheckpointClient();

// Read sender's FLOW checkpoint
const flowSnap = await cp.readAndDecrypt(wallet, memoPrivkey, TOKEN_REGISTRY.flow.proxy);
// flowSnap.balance, flowSnap.blinding, flowSnap.lastConsumedNoteIndex

// Update after a transfer
await cp.update(TOKEN_REGISTRY.flow.proxy, checkpointPayload, lastConsumedNoteIndex, wallet);
```

## BatchClaimClient

Aggregates up to 50 inbox notes into the caller's shielded balance via one Groth16 proof.

```typescript
import { BatchClaimClient, TOKEN_REGISTRY } from "@claucondor/sdk";

const client = new BatchClaimClient(signer, TOKEN_REGISTRY.flow.proxy);

// If you already have a proof (off-chain generation):
await client.claimBatch(publicInputs, proof);

// Or generate + submit in one call:
const { tx, newCommit, newBalance } = await client.buildAndClaim({
  oldBalance, oldBlinding, newBlinding,
  notesToConsume: [...],   // up to 50 notes
});
```

ABI: `claimBatch(uint256[6] publicInputs, uint256[8] proof)` — same selector for JanusFlow and JanusERC20.

## Safety guards

```typescript
import { safeBuildSendProof, isOpSafeNow, OpType } from "@claucondor/sdk";

// Soft check (never throws)
const result = await isOpSafeNow({
  op: 'send' as OpType,
  janusTokenAddr: TOKEN_REGISTRY.flow.proxy,
  owner: myCoaEvmAddr,
  checkpointAddr: SHIELDED_CHECKPOINT_ADDRESS,
  memoPrivkey,
  rpc: "https://testnet.evm.nodes.onflow.org",
  // inputs for op:
  oldBalance, oldBlinding,
});
// result.safe — boolean
// result.reason — why unsafe (if false)
// result.suggestedAction — "claim" | "reset" | "wait" | none

// Hard check (throws CheckpointDivergenceError if unsafe)
const proof = await safeBuildSendProof({ janusTokenAddr, owner, ..., oldBalance, oldBlinding, ... });
```

## Deployed contracts (v0.8.1 testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| JanusFlow proxy | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` | UUPS proxy |
| JanusERC20 proxy | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` | UUPS proxy |
| JanusFT | `0x4b6bc58bc8bf5dcc` (Cadence) | JanusFT Cadence contract |
| MockFT | `0x4b6bc58bc8bf5dcc` (Cadence) | MockFT underlying |
| ShieldedCheckpoint | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` | EVM, per-token |
| ShieldedInbox | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` | EVM |
| MemoKeyRegistry | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` | Immutable |
| AmountDiscloseVerifier | `0xf7B634D41259D0613345633eE1CD193A030A6329` | Aggregate |
| ConfidentialTransferVerifier | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` | Aggregate |
| ConfidentialClaimBatchVerifier | `0x2FBf6baef1D70f5A9aFF2602c934Bd62dcf6Df80` | N=50 |
| Cadence deployer | `0x4b6bc58bc8bf5dcc` | Cadence + COA owner |

## Privacy properties

| Operation | Amount visibility | Verdict |
|-----------|------------------|---------|
| `wrap` | **LEAK** (boundary: `msg.value` for FLOW, `Wrapped(user, amount)` event) | MIXED — pass for boundary |
| `shieldedTransfer` | **HIDE** (calldata = commitment coords only; no amount; events = `from`, `to` only) | PASS — fully shielded |
| `unwrap` | **LEAK** (boundary: `claimedAmount` in calldata, `Unwrapped(user, recipient, amount)` event) | MIXED — pass for boundary |
| `claimBatch` | **HIDE** (accumulator absorbs notes; only commitment points in calldata) | PASS — fully shielded |

## Versioning policy

Class names do NOT carry version suffixes. Versioning via:
- npm semver (`@claucondor/sdk@^0.8`)
- UUPS proxy addresses (stable; impl swappable)
- `VERSION()` constant on each contract

## Building a new adapter

To add a new `Janus<X>` concrete token:

1. Deploy a Solidity contract extending the on-chain `JanusToken` abstract base.
2. Add a `CadenceFTTokenEntry | ERC20TokenEntry | NativeTokenEntry` to `TOKEN_REGISTRY`.
3. Create `src/adapters/janus-<x>.ts` implementing `JanusTokenAdapter`.
4. Build on `src/orchestration/` (reuse `orchestrateWrap`, `orchestrateShieldedTransfer`, etc.).
5. Wire into `buildAdapter()` in `src/index.ts`.

The proof builders (`buildAmountDiscloseProof`, `buildShieldedTransferProof`, `buildBatchClaimProof`)
are asset-agnostic — reuse unchanged.

## See also

- [quickstart.md](quickstart.md) — Full v0.8 workflow
- [migration-to-v08.md](migration-to-v08.md) — v0.7 → v0.8 breaking changes
- [recovery.md](recovery.md) — ShieldedCheckpoint reads + fresh slot detection
- [extending-the-sdk.md](extending-the-sdk.md) — New adapters and modules
- [cross-vm-coa-pattern.md](cross-vm-coa-pattern.md) — COA + MemoKey resource details
