---
name: openjanus-sdk
description: |
  Guide for installing and using @claucondor/sdk@^0.8 — the multi-token TypeScript SDK for OpenJanus confidential token primitives on Flow. Covers package installation (npm or tarball file: ref), FCL configuration, the generic sdk.token(id) adapter API (3 tokens: flow/mockusdc/mockft), fully-shielded Pedersen-commit wrap/shieldedTransfer/unwrap, ShieldedCheckpoint reads, ShieldedInbox reads, BatchClaimClient, getPortfolioView, MemoKeySession, safeBuild* pre-flight guards, atomic wrap+checkpoint Cadence templates, proof helpers (buildAmountDiscloseProof, buildShieldedTransferProof, buildBatchClaimProof), and state recovery.
  TRIGGER when: installing @claucondor/sdk, "npm install @claucondor/sdk", importing from @claucondor/sdk, sdk.token(), flow.wrap(), flow.shieldedTransfer(), flow.unwrap(), flow.publishMemoKey(), JanusFlowAdapter, JanusERC20Adapter, JanusFTAdapter, ShieldedCheckpointClient, ShieldedInboxClient, BatchClaimClient, buildBatchClaimProof, getPortfolioView, getPortfolioView PortfolioView, safeBuildWrapProof, safeBuildSendProof, safeBuildClaimProof, safeBuildUnwrapProof, isOpSafeNow, assertCheckpointMatchesCommit, isFreshSlotCommit, computeActualCOld, cadenceTx.wrapFlowAtomic, cadenceTx.combinedShieldedTransferWithCheckpoint, MemoKeySession, getCachedMemoPrivkey, cacheMemoPrivkey, SentMemoStore, deriveMemoKeyFromSignature, deriveBabyJubKeypairFromBytes, buildAmountDiscloseProof, buildShieldedTransferProof, computeCommitment, generateBlinding, flowToWei, weiToFlow, createEvmWallet, createEvmProvider, configureFCL, TOKEN_REGISTRY, VERIFIERS, SHIELDED_CHECKPOINT_ADDRESS, SHIELDED_INBOX_ADDRESS, "@claucondor/sdk/adapters", "@claucondor/sdk/batchClaim", "@claucondor/sdk/checkpoint", "@claucondor/sdk/inbox", "@claucondor/sdk/cadence", "@claucondor/sdk/session", "@claucondor/sdk/orchestration", "@claucondor/sdk/primitives", "@claucondor/sdk/crypto", "@claucondor/sdk/network", "@claucondor/sdk/utils", "v0.8 migration", "shielded transfer", "fully shielded", "Pedersen commit token", "MemoKeyRegistry", "publishMemoKey", "sdk.token", "mockft", "mockusdc", "batch claim", "claimBatch", "fresh slot", "adminResetSlot", "checkpoint health", "portfolio view", "atomic transaction".
  DO NOT TRIGGER when: asking about low-level BabyJubJub curve math (use openjanus-primitives), deploying a new JanusFlow instance or custom ERC-20 wrapper (use openjanus-deploy), or implementing the JanusToken Solidity standard from scratch (use openjanus-tokens).
---

# @claucondor/sdk Guide — v0.8.x

`@claucondor/sdk@^0.8` is the generic, app-agnostic TypeScript SDK for OpenJanus
confidential token primitives on Flow. Current release: **v0.8.1-alpha.7**.

- Generic `sdk.token(id)` adapter — one interface for all 3 tokens: `flow`, `mockusdc`, `mockft`.
- `JanusFlowAdapter` (native FLOW), `JanusERC20Adapter` (MockUSDC ERC20), `JanusFTAdapter` (Cadence FT).
- `ShieldedCheckpoint` + `ShieldedInbox` — replaces v0.7 event-scan recovery. State lives in contracts.
- `BatchClaimClient` — batch-consolidate up to 50 inbox notes via a single Groth16 proof.
- `getPortfolioView` — read, decrypt, and health-check all token balances in one call.
- `safeBuild*` — pre-flight guards that block proof builds when state is incoherent.
- Atomic `cadenceTx.*` templates — wrap+checkpoint in one Cadence tx, one wallet popup.
- `MemoKeySession` — sessionStorage-backed BabyJub privkey cache with typed helpers.
- Bundled Groth16 artifacts (ConfidentialTransfer, AmountDisclose, ConfidentialClaimBatch).
- ECIES on BabyJubJub + AES-GCM for note encryption and snapshot encryption.
- Boundary fees: 0.1% on wrap + unwrap, free on shielded transfers.

> v0.8 was a **breaking** release from v0.7. `shieldedTransfer` is now 6-arg (no sender
> snapshot in calldata). `scan/` and the `recovery` subpath are removed — use
> `ShieldedCheckpointClient` + `ShieldedInboxClient` instead. `OpenJanusSDK` class is gone.
> See `references/migration-to-v08.md` for migration recipes.

## Quick Start

```bash
# npm (canonical)
npm install @claucondor/sdk

# tarball (private-tip-v1 pattern — tarball committed in repo)
# package.json: "@claucondor/sdk": "file:claucondor-sdk-0.8.1-alpha.7.tgz"
npm install
```

```typescript
import { sdk, deriveMemoKeyFromSignature, MemoKeySession } from "@claucondor/sdk";
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// Three token adapters — same interface for all
const flow    = sdk.token('flow');     // native FLOW
const usdc    = sdk.token('mockusdc'); // mock USDC (ERC20)
const ft      = sdk.token('mockft');   // mock Cadence FT

// MemoKey — derive, cache in session, publish once (covers all tokens)
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
MemoKeySession.set(memoKeypair.privkey);

await flow.publishMemoKey(memoKeypair, wallet);

// Wrap native FLOW (grossAmount is attoFLOW)
const wrapResult = await flow.wrap({ grossAmount: 5n * 10n**18n }, wallet);
// wrapResult.netAmount = 4_995_000_000_000_000_000n (0.1% fee deducted)
// wrapResult.checkpointPayload — pass to checkpoint.update() to persist

// Shielded transfer — amount never appears in calldata, events, or storage
const { txHash, checkpointPayload, newBalance, newBlinding } = await flow.shieldedTransfer({
  recipient: BOB_COA_EVM_ADDR,
  amount: 2n * 10n**18n,
  memo: 'payment',
  currentBalance: snapshot.balance,
  currentBlinding: snapshot.blinding,
}, wallet);

// Unwrap
await flow.unwrap({
  claimedAmount: 1n * 10n**18n,
  recipient: MY_COA_EVM_ADDR,
  currentBalance,
  currentBlinding,
}, wallet);
```

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/install.md` — npm install + tarball file: ref pattern, exports map, Node.js version
- `references/quickstart.md` — Full v0.8 workflow: 3 tokens, MemoKey, wrap → getPortfolioView → shieldedTransfer → batchClaim
- `references/migration-to-v08.md` — v0.7 → v0.8 migration recipes (shieldedTransfer sig, addresses, recovery rewrite)
- `references/v03-architecture.md` — v0.8.x full architecture: adapters, orchestration, checkpoint, inbox, safety
- `references/decrypt-flow.md` — Note and snapshot decryption: ShieldedCheckpoint reads, ShieldedInbox reads, BabyJubJub ECIES
- `references/extending-the-sdk.md` — Adding a new adapter, new circuit, or new top-level module
- `references/recovery.md` — State recovery: ShieldedCheckpoint read, isFreshSlot detection, 3-layer defense
- `references/ts-sdk-integration.md` — Next.js / React integration: getPortfolioView, BatchClaim, atomic transactions
- `references/cross-vm-coa-pattern.md` — COA pattern internals: MemoKey resource, JanusFT.CommitmentRegistry, ABI encoding

## Cross-skill references (load when context indicates)

- `../openjanus-primitives/references/pi-b-fp2-swap.md` — Why verifyProof silently returns false without the Fp2 swap
- `../openjanus-deploy/references/circuit-artifacts.md` — WASM / zkey / vkey locations
- `../openjanus-deploy/references/canonical-addresses.md` — Canonical addresses
- `../openjanus-tokens/references/janus-token.md` — JanusToken abstract base (Solidity ABI)

## Token registry (v0.8.1 testnet)

| `id` | Token | Variant | Decimals | Proxy / Cadence addr |
|------|-------|---------|----------|----------------------|
| `'flow'` | JanusFlow | native EVM | 18 | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` |
| `'mockusdc'` | JanusERC20 | EVM ERC20 | 6 | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` |
| `'mockft'` | JanusFT | Cadence FT | 8 | `0x4b6bc58bc8bf5dcc` (JanusFT contract) |

### Shared infra addresses

| Component | Address |
|-----------|---------|
| `ShieldedCheckpoint` (EVM) | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` |
| `ShieldedInbox` (EVM) | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` |
| `MemoKeyRegistry` (EVM) | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` |
| `ConfidentialTransferVerifier` | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` |
| `AmountDiscloseVerifier` | `0xf7B634D41259D0613345633eE1CD193A030A6329` |
| `ConfidentialClaimBatchVerifier` | `0x2FBf6baef1D70f5A9aFF2602c934Bd62dcf6Df80` |
| Cadence deployer | `0x4b6bc58bc8bf5dcc` |
| Cadence deployer COA (EVM) | `0x0000000000000000000000020885d7ad3582356a` |

## Key exports (top-level and subpaths)

```typescript
// Top-level barrel (@claucondor/sdk)
import {
  sdk,                        // singleton: sdk.token(id) → JanusTokenAdapter
  TOKEN_REGISTRY, VERIFIERS,  // addresses
  deriveMemoKeyFromSignature,  // BabyJub keypair from wallet sig
  deriveBabyJubKeypairFromBytes,
  MemoKeySession,              // sessionStorage cache for BabyJub privkey
  getCachedMemoPrivkey, cacheMemoPrivkey, clearMemoPrivkeyCache,
  SentMemoStore, saveSentMemo, findSentMemo,
  ShieldedInboxClient,         // drain EVM inbox notes
  ShieldedCheckpointClient,    // read/write encrypted balance checkpoint
  BatchClaimClient,            // batch claim up to 50 notes
  buildBatchClaimProof,        // build ConfidentialClaimBatch proof
  getPortfolioView,            // multi-token portfolio snapshot
  resolveRecipient,            // cross-VM recipient resolution
  // Safety guards
  isOpSafeNow, assertCheckpointMatchesCommit,
  safeBuildWrapProof, safeBuildSendProof, safeBuildClaimProof, safeBuildUnwrapProof,
  // Crypto helpers
  buildAmountDiscloseProof, buildShieldedTransferProof,
  computeCommitment, generateBlinding,
  encryptSnapshot, decryptSnapshot, encryptNote, decryptNote, decryptAnyNote,
  applyPiBSwap, evmProofToUint256Array,
  // Workaround helpers (v0.8-promoted)
  isFreshSlotCommit, computeActualCOld,
  cadenceAddrToEvmToken, rawToUFix64, flowToUFix64,
  // Cadence tx templates
  cadenceTx, installInbox, installCheckpoint, installInboxAndCheckpoint,
  updateCheckpointViaCoa, combinedShieldedTransferWithCheckpoint,
  // COA helpers
  getCoaEvmAddress, hasCOA, getCoaBalanceWei,
} from "@claucondor/sdk";

// Sub-paths (tree-shake in browser apps)
// @claucondor/sdk/adapters     JanusFlowAdapter, JanusERC20Adapter, JanusFTAdapter
// @claucondor/sdk/batchClaim   BatchClaimClient, buildBatchClaimProof types
// @claucondor/sdk/checkpoint   ShieldedCheckpointClient
// @claucondor/sdk/inbox        ShieldedInboxClient, getCadenceInboxNotes
// @claucondor/sdk/cadence      cadenceTx.*, installInbox, etc.
// @claucondor/sdk/session      MemoKeySession, SentMemoStore
// @claucondor/sdk/orchestration orchestrateWrap, orchestrateShieldedTransfer, orchestrateUnwrap
// @claucondor/sdk/network      createEvmProvider, createEvmWallet, configureFCL, NETWORK_CONFIG
// @claucondor/sdk/crypto       proof builders, ECIES helpers, commitment helpers
// @claucondor/sdk/primitives   computeCommitment, addCommitmentsLocal, subCommitmentsLocal
// @claucondor/sdk/utils        applyPiBSwap, rawToUFix64, cadenceAddrToEvmToken, isFreshSlotCommit
```

## Common patterns

**Reading multi-token portfolio:**

```typescript
import { getPortfolioView, TOKEN_REGISTRY, SHIELDED_CHECKPOINT_ADDRESS, SHIELDED_INBOX_ADDRESS } from "@claucondor/sdk";

const portfolio = await getPortfolioView(myCoaEvmAddr, {
  rpc: "https://testnet.evm.nodes.onflow.org",
  checkpointAddr: SHIELDED_CHECKPOINT_ADDRESS,
  inboxAddr: SHIELDED_INBOX_ADDRESS,
  tokens: [
    { id: 'flow',     address: TOKEN_REGISTRY.flow.proxy,     janusTokenAddr: TOKEN_REGISTRY.flow.proxy },
    { id: 'mockusdc', address: TOKEN_REGISTRY.mockusdc.proxy, janusTokenAddr: TOKEN_REGISTRY.mockusdc.proxy },
  ],
  memoPrivkey: memoKeypair.privkey,
  cadenceAddress: myFlowCadenceAddr,
});
// portfolio.tokens.flow.shielded — decrypted checkpoint balance
// portfolio.tokens.flow.pending  — sum of pending inbox notes
// portfolio.tokens.flow.checkpointHealth — "coherent" | "stale" | "corrupted" | "not_initialized"
// portfolio.tokens.flow.freshSlot — true if slot never initialized or admin-reset
```

**Atomic wrap + checkpoint in one Cadence tx:**

```typescript
import { cadenceTx, TOKEN_REGISTRY } from "@claucondor/sdk";
import * as fcl from "@onflow/fcl";

const tx = cadenceTx.wrapFlowAtomic(TOKEN_REGISTRY.flow.proxy);
await fcl.mutate({
  cadence: tx,
  args: (arg, t) => [
    arg(amountUFix64, t.UFix64),
    arg(wrapProof.txCommit.x.toString(), t.UInt256),
    arg(wrapProof.txCommit.y.toString(), t.UInt256),
    arg(wrapProof.proof.map(String), t.Array(t.UInt256)),
    arg(encryptedSnapshotHex, t.String),
    arg(ephPubkeyX.toString(), t.UInt256),
    arg(ephPubkeyY.toString(), t.UInt256),
    arg("0", t.UInt64), // lastConsumedNoteIndex
  ],
  limit: 9999,
});
```

**Batch claim notes:**

```typescript
import { BatchClaimClient, TOKEN_REGISTRY } from "@claucondor/sdk";

const client = new BatchClaimClient(signer, TOKEN_REGISTRY.flow.proxy);
const { tx, newCommit, newBalance } = await client.buildAndClaim({
  oldBalance: portfolio.tokens.flow.shielded,
  oldBlinding: cpBlinding,
  newBlinding: freshBlinding,
  notesToConsume: portfolio.tokens.flow.pendingNotes,
});
```

**Safety guard before proof build:**

```typescript
import { safeBuildSendProof } from "@claucondor/sdk";

// Throws CheckpointDivergenceError if checkpoint doesn't match on-chain commitment
const proof = await safeBuildSendProof({
  janusTokenAddr: TOKEN_REGISTRY.flow.proxy,
  owner: myCoaEvmAddr,
  checkpointAddr: SHIELDED_CHECKPOINT_ADDRESS,
  memoPrivkey: memoKeypair.privkey,
  rpc: "https://testnet.evm.nodes.onflow.org",
  // proof inputs
  oldBalance, oldBlinding, transferAmount, transferBlinding, newBlinding,
});
```

## Common gotchas

**G1 — `OpenJanusSDK` class is gone.**
v0.8 removed the `OpenJanusSDK` constructor. Use the `sdk` singleton: `sdk.token('flow')`.

**G2 — `shieldedTransfer` is now 6-arg, returns `checkpointPayload`.**
The sender-side snapshot is no longer in calldata. Call `checkpointClient.update()` (or use an
atomic Cadence template) to persist the new balance after every transfer.

**G3 — `@claucondor/sdk/recovery` subpath is removed.**
Use `ShieldedCheckpointClient.read()` + `ShieldedInboxClient.peek()` instead. The v0.7
event-scan approach is gone.

**G4 — ShieldedCheckpoint is per-token (v0.8.2).**
`ShieldedCheckpointClient.read(token, signer)` requires the EVM proxy address of the specific
token. FLOW and mUSDC checkpoints are isolated slots.

**G5 — Fresh slot after admin reset.**
`isFreshSlotCommit(commit)` detects (0,0) or (0,1) identity points. When `freshSlot=true`,
always reset `prevBalance=0`, `prevBlinding=0`, `prevCursor=0` — never use stale local state.

**G6 — Persisting `(amount, blinding)` via ShieldedCheckpoint.**
The checkpoint is the canonical sender-side state store. After every `wrap`, `shieldedTransfer`,
or `claimBatch`, update the checkpoint. If the checkpoint is ahead, use `ShieldedInbox` to find
pending incoming notes.

**G7 — Cadence FT inbox is on-chain Cadence, not EVM.**
`mockft` notes go to the Cadence `ShieldedInbox` resource (not the EVM `ShieldedInbox`).
`getPortfolioView` handles this automatically when `cadenceAddress` is provided.

**G8 — Submitting proofs without pi_b Fp2 swap.**
`buildAmountDiscloseProof` and `buildShieldedTransferProof` apply the swap automatically.
Manual proof construction must call `applyPiBSwap` before on-chain submission.

**G9 — Tarball install.**
`private-tip-v1` uses `"@claucondor/sdk": "file:claucondor-sdk-0.8.1-alpha.7.tgz"` (tarball
committed to repo). This is the recommended pattern for downstream apps until the package is
published to the npm registry under the canonical name.

## Companion Skills

- **`openjanus-primitives`** — raw BabyJubJub or Pedersen operations not exposed through the SDK facade
- **`openjanus-tokens`** — building the Solidity side (JanusToken abstract base + Janus<X> concretes)
- **`openjanus-deploy`** — deploying a new token instance or custom verifier
- **`flow-crossvm`** — deeper Cross-VM Cadence patterns beyond what JanusFTAdapter exposes
