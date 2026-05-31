---
name: openjanus-sdk
description: |
  Guide for installing and using @claucondor/sdk@^0.5.4 — the generic TypeScript SDK for OpenJanus confidential token primitives on Flow. Covers package installation, FCL configuration, the fully-shielded Pedersen-commit API (JanusToken abstract base + JanusFlow concrete for native FLOW), generic wrap/shieldedTransfer/unwrap on EVM, Cadence cross-VM router (JanusFlowCadence), proof helpers (buildAmountDiscloseProof, buildShieldedTransferProof), Pedersen commitments, recovery module, snapshot events, and v0.2 → v0.3 migration recipes.
  TRIGGER when: installing @claucondor/sdk, "npm install @claucondor/sdk", importing from @claucondor/sdk, JanusToken class, JanusFlow class, JanusFlowCadence class, sdk.configure(), flow.wrap(), flow.shieldedTransfer(), flow.unwrap(), flow.balanceOfCommitment(), flow.totalSupplyCommitment(), flow.totalLocked(), buildAmountDiscloseProof, buildShieldedTransferProof, computeCommitment, generateBlinding, randomBabyJubScalar, flowToWei, weiToFlow, createEvmWallet, createEvmProvider, configureFCL, JANUS_FLOW_TESTNET, JANUS_FLOW_EVM_ADDRESS, AMOUNT_DISCLOSE_VERIFIER, CONFIDENTIAL_TRANSFER_VERIFIER, TX_WRAP, TX_SHIELDED_TRANSFER, TX_UNWRAP, "@claucondor/sdk/tokens", "@claucondor/sdk/primitives", "@claucondor/sdk/crypto", "@claucondor/sdk/network", "@claucondor/sdk/utils", "v0.3 migration", "shielded transfer", "fully shielded", "Pedersen commit token".
  DO NOT TRIGGER when: asking about low-level BabyJubJub curve math (use openjanus-primitives), deploying a new JanusFlow instance or custom ERC-20 wrapper (use openjanus-deploy), or implementing the JanusToken Solidity standard from scratch (use openjanus-tokens).
---

# @claucondor/sdk Guide — v0.5.4

`@claucondor/sdk@^0.5.4` is the generic, app-agnostic TypeScript SDK for OpenJanus
confidential token primitives on Flow. Current release ships:

- `JanusFlow` (concrete native-FLOW confidential token) — fully shielded transfers,
  leaks only at the wrap / unwrap boundary by design.
- `JanusToken` (abstract base) — ready for future ERC-20 / cross-asset extensions.
- Generic Pedersen / Groth16 crypto helpers — `buildAmountDiscloseProof`,
  `buildShieldedTransferProof`, `computeCommitment`, `generateBlinding`.
- Bundled Groth16 artifacts in `circuits/v0.3/` (Hermez pot18 + Flow VRF beacon at block 324,226,714).
- Boundary fees: 0.1% on wrap + unwrap, free on shielded transfers (v0.5.4).
- Recovery module: `@claucondor/sdk/recovery` — scan `*WithSnapshot` EVM events to reconstruct state.

> v0.3 was a **breaking** release from v0.2. The ElGamal accumulator (and its
> `buildEncryptProof` / `buildDecryptProof` / `registerPubkey` API surface) is gone.
> See `references/migration-v02-to-v03.md` for the migration recipes and
> `references/v03-architecture.md` for the new abstract/concrete pattern.

## Quick Start

```bash
npm install @claucondor/sdk@^0.5.4
```

```typescript
import {
  JanusFlow,
  JANUS_FLOW_TESTNET,
} from "@claucondor/sdk/tokens";
import {
  buildAmountDiscloseProof,
  buildShieldedTransferProof,
  generateBlinding,
  flowToWei,
} from "@claucondor/sdk/crypto";

// Concrete native-FLOW client (EVM direct via ethers v6 signer)
const flow = new JanusFlow();                   // canonical testnet defaults
await flow.connectWithSigner(senderSigner);     // ethers v6

// Wrap: caller deposits FLOW; commitment hides the value, msg.value is visible (boundary)
const amountWei = flowToWei(10n);               // 10 FLOW
const blinding  = generateBlinding();           // 128-bit random
const wrapProof = await buildAmountDiscloseProof({ amount: amountWei, blinding });
await flow.wrap({
  amountWei,
  txCommit:    wrapProof.txCommit,
  amountProof: wrapProof.proof,
});

// Persist (amountWei, blinding) locally — there is no on-chain decryption key.

// Shielded transfer (amount hidden end-to-end — calldata, storage, events)
const tProof = await buildShieldedTransferProof({
  oldBalance, oldBlinding, transferAmount, transferBlinding, newBlinding,
});
await flow.shieldedTransfer({
  to: recipient,
  publicInputs: tProof.publicInputs,
  proof:        tProof.proof,
});

// Unwrap: release FLOW; needs BOTH amount-disclose AND transfer proofs
await flow.unwrap({
  claimedAmountWei,
  recipient,
  txCommit:             amtProof.txCommit,
  amountProof:          amtProof.proof,
  transferPublicInputs: tProof.publicInputs,
  transferProof:        tProof.proof,
});
```

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/install.md` — Package installation, peer deps, exports map, Node.js version
- `references/quickstart.md` — Full v0.5.4 workflow: wrap → shieldedTransfer → unwrap, with snapshot recovery
- `references/migration-v02-to-v03.md` — v0.2 ElGamal API → v0.3 generic shielded API recipes
- `references/v03-architecture.md` — JanusToken abstract base + JanusFlow concrete pattern, empirical privacy properties
- `references/decrypt-flow.md` — Range-search recovery of a balance from a commitment + locally-stored `(amount, blinding)` pair
- `references/extending-the-sdk.md` — Adding a new SDK module, contributing upstream
- `references/ts-sdk-integration.md` — Next.js / React integration: FCL wallet connection, Web Worker for proof gen, state persistence
- `references/cross-vm-coa-pattern.md` — COA pattern internals: coa.call, EVM.dryCall, ABI encoding from Cadence, CU budget breakdown

## Cross-skill references (load when context indicates)

- `../openjanus-primitives/references/pi-b-fp2-swap.md` — Why verifyProof silently returns false without the Fp2 swap
- `../openjanus-deploy/references/circuit-artifacts.md` — WASM / zkey / vkey locations for proof generation
- `../openjanus-deploy/references/canonical-addresses.md` — v0.3 canonical + v0.2 deprecated addresses
- `../openjanus-tokens/references/janus-token.md` — JanusToken abstract base (Solidity ABI)
- `../openjanus-tokens/references/janus-flow.md` — JanusFlow Cadence transaction templates (v0.3)

## Examples

**Reading the shielded-pool state:**

```typescript
const commit       = await flow.balanceOfCommitment(userEvmAddr);  // Point
const totalCommit  = await flow.totalSupplyCommitment();           // Point (sum)
const totalLocked  = await flow.totalLocked();                     // bigint attoFLOW (intentional aggregate)
```

**FCL transaction limit (Cadence router path):**

```typescript
await fcl.mutate({ cadence: TX_WRAP, args: [...], limit: 9999 }); // always 9999
```

## Common gotchas

**P1 — Persisting `(amount, blinding)` locally.**
v0.3 has no on-chain decryption key. The app MUST store the cleartext `(amount, blinding)` pair
for every commitment it produces and forward `(transferAmount, transferBlinding)` to recipients
out-of-band (encrypted message, push notification, off-chain receipt). Losing the blinding
means losing the ability to spend or recover that commitment.

**P2 — Mixing v0.2 and v0.3 calls.**
There is no `registerPubkey`, `encryptTo`, `wrapAndEncrypt`, `decryptAndUnwrap`,
`getSlot`, or `getPubkey` in v0.3. If your code references those, it is on the deprecated
v0.2 ElGamal API. See `references/migration-v02-to-v03.md`.

**P3 — Using deprecated addresses.**
The v0.2 EVM JanusToken (`0x025efe7e...`) and v0.2 Cadence router (`0xbef3c776...`)
leak amount privacy by design. The v0.1 zombie (`0x28fef3d1...`) is permanent
squat. Always import addresses from the SDK constants — never hardcode.

**P4 — Submitting proofs without pi_b Fp2 swap.**
`buildAmountDiscloseProof` and `buildShieldedTransferProof` apply the swap automatically.
Manual proof construction must call `applyPiBSwap` from `@claucondor/sdk/utils` before
on-chain submission — without it, `verifyProof` returns `false` silently.

**P5 — Wrong WASM/zkey paths.**
The v0.3 artifacts ship in `node_modules/@claucondor/sdk/circuits/v0.3/`. See
`../openjanus-deploy/references/circuit-artifacts.md`.

**P6 — Wrapping a non-whole-FLOW amount.**
Use `assertWholeFlow(amount)` before calling `wrap` if your UX expects whole-FLOW units.
Otherwise pass attoFLOW (1 FLOW = 10^18 wei) directly via `flowToWei(10n)`.

**P7 — Bypassing the cap.**
`JANUS_FLOW_MAX_WRAP_ATTOFLOW` is the on-chain per-wrap cap (18 FLOW for v0.3 testnet).
Surface this in your UI before signing.

## v0.5.x additions (shipped, no breaking changes from v0.4.x)

`@claucondor/sdk@0.5.4` ships the following exports added since v0.4:

### Memo encryption primitives (ECIES on BabyJubJub + AES-GCM)

```ts
import {
  generateBabyJubKeypair,
  encryptText,
  decryptText,
} from "@claucondor/sdk/crypto";

// Recipient sets up a long-lived keypair (publish pubkey on-chain).
const recipient = await generateBabyJubKeypair();
// recipient.privkey: bigint scalar
// recipient.pubkey:  { x: bigint, y: bigint } — BabyJub subgroup point

// Sender encrypts to recipient's pubkey.
const { ciphertext, ephemeralPubkey } = await encryptText(
  "private hello bob",
  recipient.pubkey
);
// ciphertext: Uint8Array (iv 12B || ct || tag 16B)
// ephemeralPubkey: BabyJub point — transmit alongside ciphertext

// Recipient decrypts with their privkey.
const plaintext = await decryptText(
  ciphertext,
  ephemeralPubkey,
  recipient.privkey
);
```

Use cases:
- PrivateTip encrypted memos (replaces plaintext `String?` memo).
- Any app-level shielded notes / DM-style messages bound to a recipient's BabyJub key.
- The same primitive is used inside `PrivateTip.MemoKey` resources stored at
  `/storage/openjanusMemoKey` and published at `/public/openjanusMemoKey`.

### JanusFlow extractions from app code

```ts
import {
  TX_WRAP_FROM_COA,      // COA-source wrap (atomic COA→vault→COA in one tx)
  TX_UNWRAP_TO_VAULT,    // atomic unwrap + sweep COA → Cadence FlowToken.Vault
  buildWrapCalldata,
  buildShieldedTransferCalldata,
  buildUnwrapCalldata,
  readCommitment,        // browser-safe EVM read (provider only, no Contract)
  readTotalLocked,       // browser-safe EVM read
  resolveWrapSource,     // pure decision: auto | vault | coa
} from "@claucondor/sdk/tokens";
```

### COA helpers + setup template

```ts
import {
  TX_SETUP_COA,          // idempotent EVM.CadenceOwnedAccount creation
  getCoaEvmAddress,      // throws if no COA (use hasCOA to soft-check)
  hasCOA,
  getCoaBalanceWei,
  getFlowVaultBalanceWei,
} from "@claucondor/sdk/network";
```

### Utility formatters / validators

```ts
import {
  formatPoint,           // (0x..., 0x...) for logs
  isValidFlowAddress,    // 0x + 16 hex
  isValidFlowAmount,     // UFix64-ish > 0
} from "@claucondor/sdk/utils";

import {
  parseFlowToWei,
  formatWeiToFlow,
  weiToFlowUFix64,       // always 8-decimal — safe for Cadence UFix64 args
} from "@claucondor/sdk/crypto";
```

### Pattern: encrypt-memo + shielded-transfer atomic tx

```ts
// 1. Resolve recipient's published memo pubkey.
const recipientMemoPubkey = await getRecipientMemoPubkey(recipientFlowAddr);
if (!recipientMemoPubkey) throw new Error("Recipient has no MemoKey");

// 2. Encrypt the memo.
const { ciphertext, ephemeralPubkey } = await encryptText(
  memoPlaintext,
  recipientMemoPubkey
);

// 3. Bundle JanusFlow.shieldedTransfer + PrivateTip.recordTip + encrypted memo.
//    See private-tip-v1's send_shielded_tip.cdc for the full tx template.
await fcl.mutate({
  cadence: TX_SEND_SHIELDED_TIP,
  args: () => [
    /* ... shielded transfer args ... */,
    arrUInt8(ciphertext),
    { type: "UInt256", value: ephemeralPubkey.x.toString() },
    { type: "UInt256", value: ephemeralPubkey.y.toString() },
  ],
});
```

## Companion Skills

- **`openjanus-primitives`** — when you need raw BabyJubJub or Pedersen operations not exposed through the SDK facade
- **`openjanus-tokens`** — when building the Solidity side (JanusToken abstract base + Janus<X> concretes)
- **`openjanus-deploy`** — when deploying a new token instance or custom verifier
- **`flow-crossvm`** — when you need deeper Cross-VM Cadence patterns beyond what JanusFlowCadence exposes
