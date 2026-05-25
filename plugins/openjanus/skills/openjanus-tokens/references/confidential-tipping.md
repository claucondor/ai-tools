# Confidential Tipping V2 — RECOMMENDED for New Apps

This is the v2 upgrade of the confidential tipping pattern. It uses JanusFlowV2's ElGamal stack to provide genuine multi-sender privacy: the recipient cannot learn individual tip amounts from on-chain data.

> **v1 vs v2 privacy:** In v1, multiple senders tip the same recipient. Each sender's tip commitment is independently discernible from the accumulated slot. In v2, all tips accumulate as a single ElGamal ciphertext that reveals only the total — not individual amounts.

See [confidential-tipping.md](confidential-tipping.md) for the v1 pattern (maintained for backward compatibility).

## What this pattern provides

- **Amount privacy:** On-chain data reveals that *some* transfer happened, not how much
- **Multi-sender privacy (v2-exclusive):** Recipient learns the total, not per-sender amounts
- **Sender independence:** Senders do not need to coordinate or share blinding factors
- **Recipient pubkey-based:** Sender only needs the recipient's registered BabyJubJub public key

## High-level flow

```
1. Alice registers her BabyJubJub pubkey (one-time)
2. Bob reads Alice's pubkey → encrypts 5 FLOW to it → wrapAndEncrypt
3. Carol reads Alice's pubkey → encrypts 3 FLOW to it → wrapAndEncrypt
4. Dave reads Alice's pubkey → encrypts 12 FLOW to it → wrapAndEncrypt
   (Accumulated slot now contains ElGamal encryption of 20 FLOW)
5. Alice runs BSGS to recover 20, generates decrypt proof → decryptAndUnwrap
   (Alice receives 20 FLOW; cannot determine 5+3+12 breakdown from chain)
```

## Step-by-step implementation

### 1. Alice sets up (one time)

```typescript
import { JanusFlowV2 } from "@openjanus/sdk/tokens-v2";
import { deriveBabyJubKeypair } from "@openjanus/elgamal";

const sdk = new JanusFlowV2({ network: "testnet" });
await sdk.configure();

// Derive keypair from Flow account key (deterministic)
const aliceKeypair = deriveBabyJubKeypair(aliceFlowAccountKey);
// Store sk securely — it's Alice's decryption key

// Register pubkey on-chain (once, permanent)
await sdk.registerPubkey(aliceKeypair.pk, aliceAuthz);
// Now Alice's PK is published — anyone can encrypt tips to her
```

### 2. Publisher exposes Alice's pubkey

Apps typically expose an endpoint:

```typescript
// App API (e.g., /api/user/alice/pubkey)
const pk = await sdk.getPubkey(ALICE_CADENCE_ADDR);
// { x: <bigint>, y: <bigint> } — safe to publish, it's a public key
```

### 3. Bob sends a tip

```typescript
import { buildEncryptProof, generateRandomness } from "@openjanus/elgamal";

// Fetch Alice's pubkey
const alicePK = await sdk.getPubkey(ALICE_CADENCE_ADDR);

// Encrypt 5 FLOW to Alice's pubkey
const tipProof = await buildEncryptProof({
  amount: 5n,
  randomness: generateRandomness(),  // ephemeral — no need to store
  recipientPubkey: alicePK,
  wasmPath: ENCRYPT_WASM_PATH,
  zkeyPath: ENCRYPT_ZKEY_PATH,
  vkPath: ENCRYPT_VK_PATH,
});

// Submit tip
const { txId } = await sdk.wrapAndEncrypt(
  "5.0",              // UFix64 FLOW amount
  ALICE_CADENCE_ADDR,
  tipProof,
  bobAuthz
);
console.log("Tip TX:", txId);
// On-chain: slot updated, amount hidden, Bob's randomness ephemeral
```

Carol and Dave follow identical steps with amounts 3 and 12.

### 4. Alice reads accumulated tips

```typescript
const ciphertext = await sdk.getSlot(ALICE_CADENCE_ADDR);
// { c1: Point, c2: Point } — accumulated ciphertext for 20 FLOW
// Reveals nothing about 5, 3, or 12 individually
```

### 5. Alice decrypts and withdraws

```typescript
import { buildDecryptProof, bsgsRecover, recoverMaskedPoint } from "@openjanus/elgamal";

// Decrypt: M = C2 - sk * C1
const M = await recoverMaskedPoint(ciphertext, aliceKeypair.sk);

// BSGS: recover total
const total = await bsgsRecover(M, { maxValue: 1_000_000n });
// total === 20n

// Generate decrypt-open proof
const decryptProof = await buildDecryptProof({
  ciphertext,
  secretKey: aliceKeypair.sk,
  amount: total,
  wasmPath: DECRYPT_WASM_PATH,
  zkeyPath: DECRYPT_ZKEY_PATH,
});

// Unwrap
await sdk.decryptAndUnwrap("20.0", ALICE_CADENCE_ADDR, decryptProof, aliceAuthz);
// Alice receives 20 FLOW in her FlowToken.Vault
```

## Privacy properties

| Property | v1 tipping | v2 tipping |
|----------|-----------|-----------|
| Amount hidden from observers | Yes | Yes |
| Per-sender amount hidden from recipient | **No** | **Yes** |
| Sender address visible on-chain | Yes | Yes |
| Blinding factor coordination | Sender must track own | Not needed |

## State the app must persist

| Data | Owner | Why |
|------|-------|-----|
| `aliceKeypair.sk` | Alice | Required for decryption — equivalent to private key for balance |
| Nothing | Senders | v2 senders use ephemeral randomness, nothing to track |

Compare to v1 where the sender must persist a blinding factor per transfer.

## When to use v1 tipping instead

- You're upgrading an existing v1 deployment (no migration path for live slots)
- You're building a single-sender scenario (only one person ever tips Alice)
- You need brute-force balance recovery with no BSGS setup

For all new apps, prefer v2.

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
