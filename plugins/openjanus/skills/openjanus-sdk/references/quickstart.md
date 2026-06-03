# Quick Start — v0.6.5 SDK / v0.6.4 contracts (4 tokens, generic adapter API)

This guide covers the complete v0.6.5 workflow using `@claucondor/sdk@^0.6.5`.

> **What v0.6.x adds over v0.5.x:**
> - Generic adapter API: one interface across all 4 tokens via `sdk.token(id)`.
> - JanusWFLOW (Wrapped FLOW ERC20) — new token adapter.
> - MemoKeyRegistry — single immutable contract; one `publishMemoKey` covers all tokens.
> - JanusFT Cadence now at `0x7599043aea001283` (new address).
> - New JanusFlow proxy at `0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156`.
> - Updated verifier addresses.

**SDK version:** `@claucondor/sdk@^0.6.5`
**Contracts tag:** `claucondor/contracts@v0.6.4`

Canonical addresses — see
[../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md)
for the full address table.

---

## Install

```bash
npm install @claucondor/sdk@^0.6.5
```

Circuit artifacts (WASM + zkeys + verification keys + ceremony record) are bundled
at `node_modules/@claucondor/sdk/circuits/v0.3/`.

---

## Architecture: one interface, 4 adapters

The v0.6.5 SDK ships a generic adapter model. A single `sdk.token(id)` call returns
the appropriate concrete adapter for each token:

| `id` | Token | Underlying | Notes |
|------|-------|-----------|-------|
| `'flow'` | JanusFlow | Native FLOW | Cadence-first; COA-based wrap |
| `'wflow'` | JanusWFLOW | WFLOW9 ERC20 | ERC20 wrap; approve required |
| `'mockusdc'` | JanusMockUSDC | MockUSDC ERC20 | ERC20 wrap; approve required |
| `'mockft'` | JanusFT | MockFT Cadence FT | Pure Cadence |

All adapters share the same `wrap` / `shieldedTransfer` / `unwrap` method signatures
and the same `publishMemoKey` call.

```typescript
import { OpenJanusSDK } from "@claucondor/sdk";

const sdk = new OpenJanusSDK({ network: "testnet" });

const flow    = sdk.token('flow');     // native FLOW
const wflow   = sdk.token('wflow');    // wrapped FLOW (ERC20)
const usdc    = sdk.token('mockusdc'); // mock USDC (ERC20)
const ft      = sdk.token('mockft');   // mock Cadence FT
```

---

## Step 0 — Publish MemoKey (once, covers all tokens)

The `MemoKeyRegistry` at `0x05D104962ff087441f26BA11A1E1C3b9E091D663` is immutable.
A single `publishMemoKey` call registers a BabyJub pubkey for ALL 4 tokens.

```typescript
import { deriveMemoKeyFromSignature } from "@claucondor/sdk";
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// Derive keypair deterministically from wallet signature (sign-derive pattern)
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
// memoKeypair.privkey — keep in sessionStorage only; never on-chain
// memoKeypair.pubkey  — safe to publish

// One publish covers all 4 tokens
await sdk.token('flow').publishMemoKey(memoKeypair, wallet);
```

---

## Step 1 — Connect with an ethers v6 signer

```typescript
// All three EVM tokens connect the same way:
const flow  = sdk.token('flow');
const wflow = sdk.token('wflow');
const usdc  = sdk.token('mockusdc');

await flow.connectWithSigner(wallet);
await wflow.connectWithSigner(wallet);
await usdc.connectWithSigner(wallet);

// JanusFT (Cadence) uses FCL — no ethers signer
const ft = sdk.token('mockft');
await ft.configure(); // configures FCL internally
```

---

## Step 2 — Wrap tokens into shielded commitments

### JanusFlow (native FLOW)

`wrap` is payable — value is gross amount; fee deducted automatically.

```typescript
await flow.wrap({ grossAmount: 5n * 10n**18n }, wallet);
```

### JanusWFLOW (ERC20 — approve first)

```typescript
import { ethers } from "ethers";
const WFLOW9 = "0xe7BbEAcC04A589e4B70922b2796Bb4F8e6e4873C";
const wflow9 = new ethers.Contract(WFLOW9, ["function approve(address,uint256) returns(bool)"], wallet);
await (await wflow9.approve(wflow.address, 5n * 10n**18n)).wait();
await wflow.wrap({ grossAmount: 5n * 10n**18n }, wallet);
```

### JanusMockUSDC (ERC20 — approve first)

```typescript
const MOCK_USDC = "0x8405E8831737aE72204c271581b7d4fAD9f622bE";
const mockUsdc = new ethers.Contract(MOCK_USDC, ["function approve(address,uint256) returns(bool)"], wallet);
const amount = 1_000_000n; // 1 mUSDC at 6 decimals
await (await mockUsdc.approve(usdc.address, amount)).wait();
await usdc.wrap({ grossAmount: amount }, wallet);
```

### JanusFT (Cadence FT — FCL path)

```typescript
await ft.wrap({ grossAmount: 2_00000000n /* 2.0 in UFix64 raw */ });
// Submits a Cadence transaction via FCL (requires wallet authorization)
```

---

## Step 3 — Shielded transfer (amount hidden end-to-end)

Same API for all 4 tokens:

```typescript
const recipient = "0xRecipientEvmAddress"; // or Cadence address for ft

await flow.shieldedTransfer({
  recipient,
  amount,
  memo,            // optional encrypted memo string
  currentBalance,  // sender's current cleartext balance (local)
  currentBlinding, // sender's current blinding (local)
}, wallet);
```

**What leaks:** sender + recipient addresses (visible by EVM/Cadence design).
**What stays hidden:** `amount` — never in calldata, events, or storage.

---

## Step 4 — Unwrap (release tokens from shielded pool)

```typescript
await flow.unwrap({
  claimedAmount,
  recipient,       // EVM address for FLOW/ERC20; Cadence address for ft
  currentBalance,
  currentBlinding,
}, wallet);
```

**What leaks at unwrap (by design):**
- `claimedAmount` cleartext (necessary so the contract knows how much to release)
- `recipient` address
- `Unwrapped(user, recipient, amount)` event

---

## Recovery: rebuild state from on-chain snapshots

```typescript
import { scanJanusFlowSnapshots, reconstructFromSnapshots } from "@claucondor/sdk/recovery";
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const raws = await scanJanusFlowSnapshots(myCoaEvmAddr, provider);

// Decrypt with MemoKey privkey
const snapshots = [];
for (const raw of raws) {
  const decoded = await decryptSnapshot(raw.ciphertext, raw.ephPubkey, memoKeypair.privkey);
  if (decoded) snapshots.push({ ...decoded, timestamp: raw.timestamp, txHash: raw.txHash });
}

const onChainCommit = await readJanusFlowCommitment(myCoaEvmAddr, provider);
const state = await reconstructFromSnapshots({ snapshots, onChainCommit });
// state.balanceWei, state.blinding
```

---

## Cadence router path (FCL, cross-VM)

If your UX flows through Cadence (FCL wallet, native-FLOW vault as input):

```typescript
import { TX_WRAP, TX_SHIELDED_TRANSFER, TX_UNWRAP } from "@claucondor/sdk/tokens";
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

---

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `wrap reverts "amount cap"` | Wrap amount exceeds per-wrap cap | Lower the wrap amount |
| `shieldedTransfer reverts` | Public inputs / proof shape wrong | Use `sdk.token(id).shieldedTransfer(...)` — do not hand-build inputs |
| `unwrap reverts` | Amount-disclose blinding does not match transfer blinding | Always reuse the same `currentBlinding` through the flow |
| Proof verify returns false | pi_b Fp2 swap missing (manual proof) | Call `applyPiBSwap` from `@claucondor/sdk/utils` before submit |
| Wrong addresses | Hardcoded old proxy addresses (0x09A3... or 0xf2C0...) | Import from SDK constants; never hardcode |
| Any write reverts with "paused" | Admin emergency stop active | Check `isPaused()` first |
| MemoKey not found | `publishMemoKey` never called | Call once, any token — registry is shared |

---

## Next steps

- [install.md](install.md) — Package installation, exports map, Node version
- [v03-architecture.md](v03-architecture.md) — Abstract base / concrete pattern + privacy properties
- [recovery.md](recovery.md) — Recovery module: scan + decrypt + reconstruct
- [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md) — All addresses
- [../../../openjanus-tokens/references/janus-flow.md](../../../openjanus-tokens/references/janus-flow.md) — Cadence templates reference
