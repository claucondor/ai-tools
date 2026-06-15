# Quick Start — @claucondor/sdk v0.8.x (3 tokens, ShieldedCheckpoint + BatchClaim)

This guide covers the complete v0.8 workflow using `@claucondor/sdk@^0.8`.

**SDK version:** `@claucondor/sdk@^0.8.1-alpha.7`  
**Contracts:** v0.8.1 testnet (Flow EVM chainId 545)

---

## Install

```bash
# npm (canonical)
npm install @claucondor/sdk

# tarball ref (apps with tarball committed to repo)
# package.json entry:
#   "@claucondor/sdk": "file:claucondor-sdk-0.8.1-alpha.7.tgz"
npm install
```

---

## Architecture: one interface, 3 adapters

| `id` | Token | Variant | Proxy / Cadence addr |
|------|-------|---------|----------------------|
| `'flow'` | JanusFlow | native FLOW | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` |
| `'mockusdc'` | JanusERC20 | MockUSDC ERC20 | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` |
| `'mockft'` | JanusFT | Cadence FT | `0x4b6bc58bc8bf5dcc` (JanusFT) |

All adapters share `.wrap()`, `.shieldedTransfer()`, `.unwrap()`, `.publishMemoKey()`.

```typescript
import { sdk } from "@claucondor/sdk";

const flow    = sdk.token('flow');
const usdc    = sdk.token('mockusdc');
const ft      = sdk.token('mockft');
```

---

## Step 0 — Connect provider + wallet

```typescript
import { ethers } from "ethers";
import { configureFCL } from "@claucondor/sdk/network";

const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// For Cadence operations (mockft / FCL wallet):
configureFCL("testnet"); // sets accessNode.api + discovery.wallet
```

---

## Step 1 — Derive and publish MemoKey (once per account)

The `MemoKeyRegistry` at `0x361bD4d037838A3a9c5408AE465d36077800ee6c` is immutable.
A single `publishMemoKey` call registers a BabyJub pubkey for ALL tokens.

```typescript
import { sdk, deriveMemoKeyFromSignature, MemoKeySession } from "@claucondor/sdk";
import { ethers } from "ethers";

// Derive keypair deterministically from wallet signature (sign-derive pattern)
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
// memoKeypair.privkey — BabyJub scalar, store in sessionStorage only
// memoKeypair.pubkey  — safe to publish

// Cache privkey in sessionStorage for this session
MemoKeySession.set(memoKeypair.privkey);

// Publish pubkey on-chain (one call covers all 3 tokens)
await sdk.token('flow').publishMemoKey(memoKeypair, wallet);
```

On subsequent sessions, restore from session cache:

```typescript
const cachedPrivkey = MemoKeySession.get();
// null if session expired — re-derive from wallet signature
```

---

## Step 2 — Read portfolio before acting

Always read current state before building any proof. `getPortfolioView` reads
`ShieldedCheckpoint` + `ShieldedInbox` for all tokens in one call.

```typescript
import {
  getPortfolioView,
  TOKEN_REGISTRY,
  SHIELDED_CHECKPOINT_ADDRESS,
  SHIELDED_INBOX_ADDRESS,
} from "@claucondor/sdk";

const MY_COA_EVM = "0x..."; // COA EVM address of the user
const MY_CADENCE = "0x4b6bc58bc8bf5dcc"; // Cadence address (for mockft)

const portfolio = await getPortfolioView(MY_COA_EVM, {
  rpc: "https://testnet.evm.nodes.onflow.org",
  checkpointAddr: SHIELDED_CHECKPOINT_ADDRESS,
  inboxAddr: SHIELDED_INBOX_ADDRESS,
  tokens: [
    { id: 'flow',     address: TOKEN_REGISTRY.flow.proxy,     janusTokenAddr: TOKEN_REGISTRY.flow.proxy },
    { id: 'mockusdc', address: TOKEN_REGISTRY.mockusdc.proxy, janusTokenAddr: TOKEN_REGISTRY.mockusdc.proxy },
    { id: 'mockft',   address: TOKEN_REGISTRY.mockft.cadenceAddress },
  ],
  memoPrivkey: memoKeypair.privkey,
  cadenceAddress: MY_CADENCE,
});

const flowView = portfolio.tokens.flow;
// flowView.shielded         — decrypted checkpoint balance (attoFLOW)
// flowView.pending          — sum of pending inbox notes not yet claimed
// flowView.total            — shielded + pending
// flowView.pendingNotes     — Array<{ amount, blinding, memo, inboxIndex }>
// flowView.freshSlot        — true if slot was never initialized or admin-reset
// flowView.checkpointHealth — "coherent" | "stale" | "corrupted" | "not_initialized"
// flowView.safeOpsAvailable — { wrap, send, claim, unwrap } — gate UI on these
```

---

## Step 3 — Wrap tokens into shielded commitments

### JanusFlow (native FLOW)

```typescript
const wrapResult = await sdk.token('flow').wrap({ grossAmount: 5n * 10n**18n }, wallet);
// wrapResult.netAmount       — attoFLOW credited to shielded slot (gross - 0.1% fee)
// wrapResult.checkpointPayload — encrypted state to persist (pass to checkpoint.update)
```

### JanusERC20 (MockUSDC — approve first)

```typescript
import { ethers } from "ethers";
const MOCK_USDC_UNDERLYING = "0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524";
const mockUsdc = new ethers.Contract(
  MOCK_USDC_UNDERLYING,
  ["function approve(address,uint256) returns(bool)"],
  wallet
);
const grossAmount = 1_000_000n; // 1 mUSDC at 6 decimals
await (await mockUsdc.approve(TOKEN_REGISTRY.mockusdc.proxy, grossAmount)).wait();

const wrapResult = await sdk.token('mockusdc').wrap({ grossAmount }, wallet);
```

### JanusFT (Cadence FT — FCL path)

```typescript
// JanusFT.wrapWithProof is called via Cadence transaction through the SDK.
// The adapter builds the proof and submits via FCL internally.
const wrapResult = await sdk.token('mockft').wrap({
  grossAmount: 2_00000000n, // 2.0 MockFT in UFix64 raw (8 decimals)
});
// No ethers signer needed — FCL wallet signs
```

### Persisting the checkpoint after wrap (EVM tokens)

```typescript
import { ShieldedCheckpointClient, TOKEN_REGISTRY } from "@claucondor/sdk";

const cp = new ShieldedCheckpointClient();
if (wrapResult.checkpointPayload) {
  await cp.update(TOKEN_REGISTRY.flow.proxy, wrapResult.checkpointPayload, 0n, wallet);
}
```

Or use the atomic Cadence template (wrap + checkpoint in one tx, one wallet popup):

```typescript
import { cadenceTx, TOKEN_REGISTRY } from "@claucondor/sdk";
import * as fcl from "@onflow/fcl";

const txTemplate = cadenceTx.wrapFlowAtomic(TOKEN_REGISTRY.flow.proxy);
await fcl.mutate({
  cadence: txTemplate,
  args: (arg, t) => [
    arg(amountUFix64, t.UFix64),
    arg(txCommit.x.toString(), t.UInt256),
    arg(txCommit.y.toString(), t.UInt256),
    arg(proof.map(String), t.Array(t.UInt256)),
    arg(encryptedSnapshotHex, t.String),
    arg(ephPubkeyX.toString(), t.UInt256),
    arg(ephPubkeyY.toString(), t.UInt256),
    arg("0", t.UInt64),
  ],
  limit: 9999,
});
```

---

## Step 4 — Shielded transfer (amount hidden end-to-end)

Same API for all tokens. Read current state from portfolio first.

```typescript
const flowView = portfolio.tokens.flow;

// Gate on safety before building proof
if (!flowView.safeOpsAvailable.send) {
  throw new Error(`Send not safe: checkpointHealth=${flowView.checkpointHealth}`);
}

const { txHash, checkpointPayload, newBalance, newBlinding } =
  await sdk.token('flow').shieldedTransfer({
    recipient: BOB_COA_EVM_ADDR,   // EVM address for flow/mockusdc; Cadence addr for mockft
    amount: 2n * 10n**18n,
    memo: 'payment',
    currentBalance: flowView.shielded,
    currentBlinding: cpBlinding,   // from checkpoint read or local state
  }, wallet);

// Persist updated checkpoint after transfer
const cp = new ShieldedCheckpointClient();
await cp.update(TOKEN_REGISTRY.flow.proxy, checkpointPayload!, 0n, wallet);
```

**What leaks:** sender + recipient EVM addresses.
**What stays hidden:** `amount` — never in calldata, events, or storage.

---

## Step 5 — Batch claim pending notes

When `portfolio.tokens.flow.pendingNotes.length >= 10` (or anytime you want to
consolidate inbox notes), use `BatchClaimClient`:

```typescript
import { BatchClaimClient, TOKEN_REGISTRY, generateBlinding } from "@claucondor/sdk";

const client = new BatchClaimClient(wallet, TOKEN_REGISTRY.flow.proxy);
const newBlinding = await generateBlinding();

const { tx, newCommit, newBalance } = await client.buildAndClaim({
  oldBalance: flowView.shielded,
  oldBlinding: cpBlinding,
  newBlinding,
  notesToConsume: flowView.pendingNotes, // up to 50
});

console.log("New balance after claim:", newBalance);
```

After `claimBatch`, update the checkpoint with the new balance, blinding, and cursor:

```typescript
const { encryptedSnapshot, ephPubkeyX, ephPubkeyY } = await encryptSnapshot(
  { balance: newBalance, blinding: newBlinding },
  { x: memoKeypair.pubkey.x, y: memoKeypair.pubkey.y }
);
const cp = new ShieldedCheckpointClient();
await cp.update(
  TOKEN_REGISTRY.flow.proxy,
  { encryptedSnapshot, ephPubkeyX, ephPubkeyY },
  BigInt(flowView.pendingNotes[flowView.pendingNotes.length - 1].inboxIndex + 1),
  wallet
);
```

---

## Step 6 — Unwrap (release tokens from shielded pool)

```typescript
await sdk.token('flow').unwrap({
  claimedAmount: 1n * 10n**18n,
  recipient: MY_COA_EVM_ADDR,
  currentBalance: flowView.shielded,
  currentBlinding: cpBlinding,
}, wallet);
```

**What leaks at unwrap (by design):**
- `claimedAmount` cleartext (contract must know how much to release)
- `recipient` address
- `Unwrapped(user, recipient, amount)` event

---

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `CheckpointDivergenceError` | Local state doesn't match on-chain commitment | Re-read portfolio; use `safeBuild*` guards |
| `NoCheckpoint(user, token)` | Slot never initialized or admin-reset | `freshSlot=true`: reset prevBalance/prevBlinding to 0 |
| `claimBatch reverts` | publicInputs / proof shape wrong | Use `BatchClaimClient.buildAndClaim` — do not hand-build |
| Proof verify returns false | pi_b Fp2 swap missing (manual proof) | Call `applyPiBSwap` before submit |
| Wrong addresses | Hardcoded proxy addresses | Import from `TOKEN_REGISTRY` / SDK constants |
| `paused()` revert | Admin emergency stop | Check `isPaused()` on the contract first |
| MemoKey not found | `publishMemoKey` never called | Call once (any token — registry is shared) |
| `decryptErrors` in portfolio | Wrong MemoKey or corrupted note | Re-derive keypair; note may belong to a different account |

---

## Next steps

- [install.md](install.md) — Package installation, exports map, Node version
- [v03-architecture.md](v03-architecture.md) — v0.8.x architecture: adapters, orchestration, safety
- [recovery.md](recovery.md) — State recovery: ShieldedCheckpoint, isFreshSlot, 3-layer defense
- [migration-to-v08.md](migration-to-v08.md) — v0.7 → v0.8 migration recipes
