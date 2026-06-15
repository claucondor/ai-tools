# Migration to @claucondor/sdk v0.8.x

v0.8 was a **breaking** release. `shieldedTransfer` ABI changed, the recovery module was
rewritten, `OpenJanusSDK` class was removed, and addresses changed.

> For the earlier v0.2 → v0.3 migration history see
> [migration-v02-to-v03.md](migration-v02-to-v03.md) (archived).

---

## Why v0.8 broke v0.7

1. **6-arg `shieldedTransfer`** — v0.7 embedded the sender snapshot in calldata (7 args total).
   v0.8 removes the snapshot from the contract call; it goes to a separate
   `ShieldedCheckpoint.update()` call. This change reduced contract gas and removed the
   single-tx coupling between the transfer and the state snapshot.

2. **`scan/` → `ShieldedCheckpoint` + `ShieldedInbox`** — v0.7 used event scanning
   (`scanJanusFlowSnapshots`) to recover state. v0.8 gives each token a dedicated on-chain
   checkpoint slot and a shared inbox contract. No RPC log-scan needed.

3. **`claimBatch` added to JanusToken** — v0.7 had no batch claim. v0.8.1 ships
   `claimBatch(uint256[6], uint256[8])` on all JanusToken contracts.

4. **New addresses** — All contracts redeployed for v0.8 (clean deploy 2026-06-09).

5. **`OpenJanusSDK` class removed** — Replaced by `sdk` singleton (`import { sdk } from "@claucondor/sdk"`).

---

## Address changes

| Component | v0.7 | v0.8.1 |
|-----------|------|--------|
| JanusFlow proxy | `0x9A83732417947Ef9b7AEa64bF807a345267c2FdA` (legacy) | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` |
| JanusERC20 proxy | — | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` |
| JanusFT (Cadence) | `0x7599043aea001283` | `0x4b6bc58bc8bf5dcc` |
| ShieldedCheckpoint | — (v0.7 used singleton, now archived) | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` |
| ShieldedInbox | — | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` |
| MemoKeyRegistry | `0x05D104962ff087441f26BA11A1E1C3b9E091D663` | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` |
| AmountDiscloseVerifier | `0xD0ED3936530258C278f5357C1dB709ad34768352` | `0xf7B634D41259D0613345633eE1CD193A030A6329` |
| ConfidentialTransferVerifier | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` |
| ConfidentialClaimBatchVerifier | — | `0x2FBf6baef1D70f5A9aFF2602c934Bd62dcf6Df80` |
| Cadence deployer | `0xbef3c77681c15397` / `0x5dcbeb41055ec57e` | `0x4b6bc58bc8bf5dcc` |

---

## API changes — removed in v0.8

```typescript
// v0.7 exports — REMOVED in v0.8
OpenJanusSDK                 // removed — use sdk singleton
new OpenJanusSDK({ network })

scanJanusFlowSnapshots()     // removed — use ShieldedCheckpointClient
reconstructFromSnapshots()
readJanusFlowCommitment()
validatePedersenCommit()
RecoveryDesyncError
"@claucondor/sdk/recovery"   // subpath removed entirely

// v0.7 shieldedTransfer (7-arg with embedded snapshot)
flow.shieldedTransfer({
  recipient, amount, memo, currentBalance, currentBlinding,
  ephPubkeyX, ephPubkeyY, encryptedSnapshot,  // ← REMOVED from calldata
}, wallet);
```

---

## API changes — v0.8 replacements

### Adapter entry point

```typescript
// v0.7
import { OpenJanusSDK } from "@claucondor/sdk";
const sdk = new OpenJanusSDK({ network: "testnet" });
const flow = sdk.token('flow');

// v0.8
import { sdk } from "@claucondor/sdk";
const flow = sdk.token('flow');
```

### shieldedTransfer (6-arg, returns checkpointPayload)

```typescript
// v0.7 (7 args — snapshot in calldata)
const tx = await flow.shieldedTransfer({
  recipient, amount, memo, currentBalance, currentBlinding,
  ephPubkeyX: myEphX, ephPubkeyY: myEphY,
  encryptedSnapshot: myCiphertext,
}, wallet);

// v0.8 (6 args — snapshot separated)
const { txHash, checkpointPayload, newBalance, newBlinding } =
  await flow.shieldedTransfer({
    recipient, amount, memo, currentBalance, currentBlinding,
  }, wallet);

// Then persist checkpoint separately:
import { ShieldedCheckpointClient, TOKEN_REGISTRY } from "@claucondor/sdk";
const cp = new ShieldedCheckpointClient();
await cp.update(TOKEN_REGISTRY.flow.proxy, checkpointPayload!, lastConsumedNoteIndex, wallet);

// OR use atomic Cadence template (wrap+checkpoint in one tx):
import { cadenceTx } from "@claucondor/sdk";
const txTemplate = cadenceTx.combinedShieldedTransferWithCheckpoint(TOKEN_REGISTRY.flow.proxy);
```

### State recovery

```typescript
// v0.7 — event scan (REMOVED)
import { scanJanusFlowSnapshots, decryptSnapshot, reconstructFromSnapshots }
  from "@claucondor/sdk/recovery";
const raws = await scanJanusFlowSnapshots(myCoaAddr, provider);
const state = await reconstructFromSnapshots({ snapshots, onChainCommit });

// v0.8 — one checkpoint read per session
import { ShieldedCheckpointClient, TOKEN_REGISTRY } from "@claucondor/sdk";
const cp = new ShieldedCheckpointClient();
const snapshot = await cp.readAndDecrypt(wallet, memoPrivkey, TOKEN_REGISTRY.flow.proxy);
// snapshot.balance, snapshot.blinding, snapshot.lastConsumedNoteIndex

// Then drain pending inbox notes
import { ShieldedInboxClient } from "@claucondor/sdk";
const inbox = new ShieldedInboxClient();
const { decrypted } = await inbox.drainAndDecrypt(wallet, memoPrivkey);
for (const { content } of decrypted) {
  console.log('Pending note:', content.amount, content.blinding);
}
```

### Batch claim (new in v0.8.1)

```typescript
// No equivalent in v0.7 — claim was per-note

// v0.8.1 — batch up to 50 notes
import { BatchClaimClient, TOKEN_REGISTRY } from "@claucondor/sdk";
const client = new BatchClaimClient(signer, TOKEN_REGISTRY.flow.proxy);
const { tx, newBalance } = await client.buildAndClaim({
  oldBalance, oldBlinding, newBlinding,
  notesToConsume: pendingNotes,  // from ShieldedInboxClient
});
```

### JanusFT `claimBatch` contract change

v0.7 JanusFT had a per-note claim via Cadence. v0.8.1 ships `claimBatch` at the contract level
with the same ABI as JanusFlow:
```
claimBatch(uint256[6] publicInputs, uint256[8] proof) external
```
The SDK `BatchClaimClient` handles both JanusFlow and JanusERC20. JanusFT batch claim
is submitted via `cadenceTx.claimBatchFtAtomic`.

### JanusFT wrapWithProof — pB swap (W8 workaround)

JanusFT.wrapWithProof does an internal Fp2-swap on pB. The SDK exports `buildFtWrapProofArgs`
to un-swap before submission (so the net result is correct):

```typescript
import { buildFtWrapProofArgs } from "@claucondor/sdk";

// Instead of passing the raw proof.proof to JanusFT.wrapWithProof:
const { pA, pB, pC, publicInputs } = buildFtWrapProofArgs(proof);
// Pass pA, pB, pC to the Cadence transaction
```

### Ceremony / circuit artifacts

v0.8 ships new ceremony artifacts (pot22 — larger power of tau):
- AmountDisclose: pot22, Flow VRF beacon block 450,000,000+
- ConfidentialTransfer: pot22
- ConfidentialClaimBatch: new circuit, pot22

Old `circuits/v0.3/` path is removed. The v0.8 builders resolve artifact paths automatically.

---

## Checklist

- [ ] Replace `new OpenJanusSDK(...)` → `import { sdk } from "@claucondor/sdk"`
- [ ] Remove snapshot args from `shieldedTransfer` call (6-arg only)
- [ ] Add `ShieldedCheckpointClient.update()` call after every `shieldedTransfer`
- [ ] Replace `@claucondor/sdk/recovery` imports → `ShieldedCheckpointClient` + `ShieldedInboxClient`
- [ ] Update all hard-coded addresses to v0.8 values (MemoKeyRegistry, verifiers, proxies)
- [ ] Add `BatchClaimClient` flow when `pendingNotes.length >= 10`
- [ ] Gate UI operations on `portfolio.tokens[id].safeOpsAvailable.*`
- [ ] Check `portfolio.tokens[id].freshSlot` and reset local state to zero if true

---

## See also

- [quickstart.md](quickstart.md) — Full v0.8 workflow
- [v03-architecture.md](v03-architecture.md) — v0.8.x full architecture
- [recovery.md](recovery.md) — State recovery + fresh slot detection
- [migration-v02-to-v03.md](migration-v02-to-v03.md) — Historical: v0.2 ElGamal → v0.3
