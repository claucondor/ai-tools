# State Recovery (v0.8)

v0.8 replaces event-scan recovery with two on-chain contracts:
`ShieldedCheckpoint` (sender balance store) and `ShieldedInbox` (incoming notes).
The v0.7 `@claucondor/sdk/recovery` subpath is removed.

---

## Why recovery?

The chain stores only opaque Pedersen commitment points. Per-account `(balance, blinding)`
lives in the `ShieldedCheckpoint` contract as an ECIES-encrypted snapshot. If the user
switches devices, they read the checkpoint with their MemoKey privkey and reconstruct
state without any event scanning.

---

## Recovery flow (normal path)

```typescript
import {
  ShieldedCheckpointClient,
  ShieldedInboxClient,
  getPortfolioView,
  TOKEN_REGISTRY,
  SHIELDED_CHECKPOINT_ADDRESS,
  SHIELDED_INBOX_ADDRESS,
} from "@claucondor/sdk";
import { MemoKeySession } from "@claucondor/sdk/session";

// 1. Re-derive MemoKey privkey (prompts wallet signature once per session)
const privkey = MemoKeySession.get() ?? (await rederiveFromWallet());

// 2. Read ShieldedCheckpoint for each token
const cp = new ShieldedCheckpointClient();
const flowSnap = await cp.readAndDecrypt(wallet, privkey, TOKEN_REGISTRY.flow.proxy);
// flowSnap.balance, flowSnap.blinding, flowSnap.lastConsumedNoteIndex
// null → no checkpoint yet (fresh slot)

// 3. Drain pending inbox notes (notes after lastConsumedNoteIndex)
const inbox = new ShieldedInboxClient();
const { decrypted } = await inbox.drainAndDecrypt(wallet, privkey);
const pendingNotes = decrypted.filter(
  (n) => n.absoluteIndex >= (flowSnap?.lastConsumedNoteIndex ?? 0n)
);

// 4. Total balance = checkpoint balance + sum of pending notes
const totalBalance = (flowSnap?.balance ?? 0n) + pendingNotes.reduce((s, n) => s + n.content.amount, 0n);
```

Or use `getPortfolioView` which does all of the above in one call:

```typescript
const portfolio = await getPortfolioView(myCoaEvmAddr, {
  rpc: "https://testnet.evm.nodes.onflow.org",
  checkpointAddr: SHIELDED_CHECKPOINT_ADDRESS,
  inboxAddr: SHIELDED_INBOX_ADDRESS,
  tokens: [
    { id: 'flow', address: TOKEN_REGISTRY.flow.proxy, janusTokenAddr: TOKEN_REGISTRY.flow.proxy },
  ],
  memoPrivkey: privkey,
  cadenceAddress: myFlowCadenceAddr,
});

const flowView = portfolio.tokens.flow;
console.log("Shielded balance:", flowView.shielded);
console.log("Pending notes:", flowView.pendingCount);
console.log("Total:", flowView.total);
```

---

## Fresh slot detection (3-layer defense)

A slot is "fresh" when it has never been initialized OR was reset by an admin
(`adminResetSlot` / `adminBatchResetSlots`). Using stale local state against a
fresh on-chain slot produces a `C_old` mismatch and the verifier will reject the tx.

### Layer 1 — UI (getPortfolioView)

```typescript
const flowView = portfolio.tokens.flow;

if (flowView.freshSlot) {
  // Slot is uninitialized or was admin-reset.
  // ALWAYS reset local state to zero — never use stale cached values.
  localState.prevBalance  = 0n;
  localState.prevBlinding = 0n;
  localState.prevCursor   = 0n;
  // User can safely wrap (creates the slot) or claim (also initializes).
  // send/unwrap must be blocked until slot is populated.
  uiState.showFreshSlotBanner = true;
}
```

`freshSlot` is true when `checkpointVersion === 0n` (no checkpoint ever written
or slot was reset to zero by an admin call).

### Layer 2 — SDK (isFreshSlotCommit)

```typescript
import { isFreshSlotCommit } from "@claucondor/sdk";

// Check the on-chain Pedersen commitment directly (for EVM tokens)
const commit = await getOnChainCommitment(janusTokenAddr, coaAddr, provider);
if (isFreshSlotCommit(commit)) {
  // commit is identity: (0,0) — never-written storage
  // or  (0,1) — explicit identity point (JanusToken._effectiveCommitment converts 0,0 → 0,1)
  // Either way: prevBalance = 0n, prevBlinding = 0n
}
```

For JanusFT, also check the Cadence commitment:

```typescript
const ftCommit = await ftAdapter.getCommitment(cadenceAddr);
if (isFreshSlotCommit(ftCommit)) {
  // JanusFT commitment is identity — slot reset or never initialized
}
```

### Layer 3 — Contract (on-chain)

The JanusToken contract verifies that `C_old` matches `commitments[msg.sender]`.
If an app submits a proof with wrong `(oldBalance, oldBlinding)` because it used
stale local state after an admin reset, the verifier will revert with a commitment
mismatch. This is the last safety net — but you want to catch it in layer 1 or 2.

---

## computeActualCOld — absorb pending notes into stale checkpoint

When the checkpoint is stale (pending notes exist that aren't absorbed), use
`computeActualCOld` to compute the correct C_old for the next proof:

```typescript
import { computeActualCOld } from "@claucondor/sdk";

// Stale checkpoint: balance=10n, blinding=B0
// Pending notes: [{ amount: 3n, blinding: B1 }, { amount: 2n, blinding: B2 }]
const { actualBalance, actualBlinding } = await computeActualCOld(
  { balance: cpBalance, blinding: cpBlinding },
  pendingNotes, // array of { amount, blinding }
);
// actualBalance = 10n + 3n + 2n = 15n
// actualBlinding = (B0 + B1 + B2) mod subOrder
// Use actualBalance/actualBlinding as C_old in send/unwrap proofs
```

This is automatically handled by `shieldedTransfer` and `unwrap` adapter methods
when you pass `currentBalance` and `currentBlinding` from the portfolio view.

---

## Checkpoint health states

`getPortfolioView` returns `checkpointHealth` for each token:

| State | Meaning | Safe ops |
|-------|---------|----------|
| `"coherent"` | Pedersen(checkpoint + pending) == on-chain commitment | All ops safe |
| `"stale"` | Pending notes exist not yet absorbed into checkpoint | wrap, claim safe; send/unwrap auto-absorb |
| `"corrupted"` | pendingCount=0 but commitment still mismatches | wrap only; admin reset required |
| `"not_initialized"` | `NoCheckpoint` revert from contract (slot never written) | wrap, claim safe |
| `"unknown"` | RPC failure or check unavailable | Treat as stale |

```typescript
if (flowView.checkpointHealth === "corrupted") {
  // This indicates a blinding storage bug from a previous SDK version.
  // On testnet: admin can reset the slot (adminResetSlot).
  // User must re-wrap after reset.
  showError("Checkpoint corrupted — admin reset required");
}
```

---

## Cross-device recovery

On a new device:

1. The user authenticates with their wallet (FCL or ethers).
2. App calls `wallet.signMessage('OpenJanus MemoKey v1')` → `deriveMemoKeyFromSignature` → same privkey as before.
3. App reads `ShieldedCheckpointClient.readAndDecrypt(wallet, privkey, tokenAddr)` → recovers sender balance.
4. App reads `ShieldedInboxClient.drainAndDecrypt(wallet, privkey)` → recovers any pending notes.
5. Total state is restored. No seed phrase, no backup phrases — the wallet signature is the root.

---

## Known scenarios

| Scenario | Recovery outcome |
|----------|-----------------|
| Fresh account (no wraps) | `freshSlot=true`, balance=0n, no pending notes |
| Checkpoint exists, no pending | Normal read — coherent |
| Checkpoint exists, pending notes | Read checkpoint + drain inbox — stale, safe |
| Slot admin-reset | `freshSlot=true`, local state MUST be zeroed |
| MemoKey rotated | Cannot decrypt old snapshots — re-wrap after rotation |
| Cadence FT (mockft) | Cadence ShieldedInbox read + JanusFT.commitments check |

---

## See also

- [decrypt-flow.md](decrypt-flow.md) — Note and snapshot decryption detail
- [quickstart.md](quickstart.md) — Full v0.8 workflow
- [v03-architecture.md](v03-architecture.md) — ShieldedCheckpoint + ShieldedInbox protocol design
