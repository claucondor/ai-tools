# Confidential Tipping — JanusToken on Flow

Uses JanusFlow's Pedersen-commitment scheme to provide genuine multi-sender
privacy: the recipient cannot learn individual tip amounts from on-chain data.
State recovery is built-in via inline snapshot events.

> **SDK version:** `@claucondor/sdk@^0.5.4`
> **MemoKey type:** `JanusFlow.MemoKey` (generic primitive, NOT `PrivateTip.MemoKey`)
> **Recovery:** use `@claucondor/sdk/recovery` — no self-tip pattern needed.

## What this pattern provides

- **Amount privacy:** On-chain data reveals that *some* transfer happened, not how much
- **Multi-sender privacy:** Recipient learns the total, not per-sender amounts
- **Sender independence:** Senders do not need to coordinate or share blinding factors
- **Recipient pubkey-based (MemoKey):** Sender encrypts a ShieldedNote to the recipient's `JanusFlow.MemoKey` pubkey; recipient decrypts with their privkey
- **Cross-device recovery (v0.5.2):** `*WithSnapshot` EVM events carry encrypted state blobs;
  the SDK `recovery` module reconstructs local state from any device with just a wallet signature

## High-level flow

```
1. Alice sets up a JanusFlow.MemoKey (BabyJubJub pubkey published on-chain) — one time
2. Bob wraps 5 FLOW → generates amountDiscloseProof → calls JanusFlow.wrap
   (Alice's commitment slot += Pedersen(5 FLOW, bobBlinding); amount hidden)
3. Bob sends Alice a ShieldedNote encrypted to her MemoKey pubkey:
   { amount: 5, blinding: bobBlinding } — decryptable only by Alice's privkey
4. Carol and Dave repeat steps 2-3 with 3 FLOW and 12 FLOW respectively
5. Alice decrypts each ShieldedNote → recovers (amount, blinding) → generates unwrap proofs
   → calls JanusFlow.unwrap → receives FLOW. On-chain: amounts never revealed.
```

Note: senders must deliver a ShieldedNote (encrypted tip memo) to the recipient out-of-band.
The `@claucondor/sdk/crypto` `encryptText` / `decryptText` primitives handle this. The
`PrivateTip` app does this automatically via the tip event flow.

## Step-by-step implementation

### 1. Alice sets up MemoKey (one time)

```typescript
import { deriveBabyJubKeypairFromBytes } from "@claucondor/sdk/crypto";
import { TX_SETUP_COA, getCoaEvmAddress } from "@claucondor/sdk/network";

// Derive deterministic BabyJub keypair from wallet signature (sign-derive pattern)
const signature = await wallet.signMessage("openjanus/memokey/v1");
const aliceKeypair = await deriveBabyJubKeypairFromBytes(
  new TextEncoder().encode(signature)
);
// Store aliceKeypair.privkey in sessionStorage only — never on-chain

// Publish pubkey on-chain via setup_memo_key.cdc (see janus-flow.md MemoKey section)
// This calls JanusFlow.publishMemoKey(pubkeyX, pubkeyY) on the EVM side via COA
```

### 2. Publisher exposes Alice's pubkey

```typescript
import { JanusFlowCadence } from "@claucondor/sdk/tokens";
const cadence = new JanusFlowCadence();
await cadence.configure();

// Read from the EVM registry
const pk = await cadence.getMemoPubkey(ALICE_CADENCE_ADDR);
// { x: bigint, y: bigint } — safe to publish, it's a public key
```

### 3. Bob wraps and sends a ShieldedNote to Alice

```typescript
import { JanusFlow } from "@claucondor/sdk/tokens";
import {
  buildAmountDiscloseProof,
  generateBlinding,
  flowToWei,
  encryptText,
} from "@claucondor/sdk/crypto";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.connectWithSigner(bobSigner);

const tipAmountWei = flowToWei(5n);        // 5 FLOW
const blinding = generateBlinding();       // fresh per wrap

// Build proof (binds commitment to amount)
const proof = await buildAmountDiscloseProof({ amount: tipAmountWei, blinding });

// Wrap — amount hidden in commitment after boundary
const tx = await sdk.wrap({
  amountWei: tipAmountWei,
  txCommit:  proof.txCommit,
  amountProof: proof.proof,
});
console.log("Wrap TX:", tx.hash);

// Send ShieldedNote to Alice out-of-band (encrypted to her MemoKey pubkey)
const { ciphertext, ephemeralPubkey } = await encryptText(
  JSON.stringify({ amount: "5", blinding: blinding.toString() }),
  aliceMemoKeyPubkey
);
// Deliver (ciphertext, ephemeralPubkey) to Alice via PrivateTip or another channel
```

Carol and Dave follow identical steps with amounts 3 and 12.

### 4. Alice reads her commitment

```typescript
const commit = await sdk.balanceOfCommitment(aliceEvmAddr);
// Opaque Point — reveals nothing about 5+3+12 individually
```

### 5. Alice decrypts ShieldedNotes and unwraps

```typescript
import { decryptText } from "@claucondor/sdk/crypto";
import { buildAmountDiscloseProof, buildShieldedTransferProof, generateBlinding } from "@claucondor/sdk/crypto";

// Decrypt each ShieldedNote with Alice's privkey
const bobNote = JSON.parse(await decryptText(ciphertext, ephemeralPubkey, alicePrivkey));
// { amount: "5", blinding: "..." }

// For unwrap: generate both proofs for the slice being released
const amtProof = await buildAmountDiscloseProof({
  amount: BigInt(bobNote.amount) * 10n**18n,
  blinding: BigInt(bobNote.blinding),
});
const tProof = await buildShieldedTransferProof({ ... });

await sdk.unwrap({
  claimedAmountWei: BigInt(bobNote.amount) * 10n**18n,
  recipient: aliceEvmAddr,
  txCommit: amtProof.txCommit,
  amountProof: amtProof.proof,
  transferPublicInputs: tProof.publicInputs,
  transferProof: tProof.proof,
});
// Alice receives FLOW; net = claimedAmount - 0.1% fee
```

## Privacy properties

| Property | JanusFlow (Pedersen + Groth16) |
|----------|-------------------------------|
| Amount hidden from observers | Yes (shieldedTransfer and commitment slot) |
| Per-sender amount hidden from recipient | Yes — each sender's ShieldedNote is encrypted to recipient only |
| Sender address visible on-chain | Yes — unavoidable (EVM msg.sender) |
| Coordination required between senders | No — independent wraps, independent notes |
| Boundary visibility | `wrap` leaks amount via msg.value (by design) |

## State the app must persist

| Data | Owner | Why |
|------|-------|-----|
| `aliceKeypair.privkey` | Alice | Decrypts incoming ShieldedNotes; derived from wallet sig, can be re-derived |
| `(amount, blinding)` per commitment | Alice | Required for unwrap proofs |
| Nothing permanent | Senders | Blinding is in the ShieldedNote delivered to Alice; sender only needs ephemeral randomness at wrap time |

## Gas and CU notes

- Encrypt proof generation: ~2-10 seconds (Groth16 on BabyJubJub)
- Decrypt proof generation: ~2-10 seconds
- Cadence TX CU: near 9999 CU ceiling (cross-VM Groth16 verify)
- EVM gas for `encryptTo`: ~300k gas on Flow EVM
- BSGS table build for 1M range: ~10ms, ~1000 entries

## See also

- [funding-with-amount-privacy.md](funding-with-amount-privacy.md) — Public fundraising use case
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — Full SDK quick start
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — BSGS decrypt guide
