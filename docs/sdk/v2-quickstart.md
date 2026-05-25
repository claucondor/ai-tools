# V2 Quick Start — ElGamal JanusTokenV2 + JanusFlowV2

This guide covers the complete v2 workflow using `@openjanus/sdk/tokens-v2`. The v2 stack uses additive ElGamal-on-BabyJubJub instead of Pedersen commitments.

> **When to use v2:** Any new app where multiple senders will deposit to the same recipient. V2 ensures recipients learn only the accumulated total, not individual sender amounts.

## Install

```bash
npm install @openjanus/sdk
```

No extra dependencies beyond v1 — `@openjanus/sdk` includes v2 module at `tokens-v2/`.

## Import

```typescript
import {
  JanusTokenV2,
  JanusFlowV2,
  JANUS_TOKEN_V2_TESTNET,
  type ElGamalKeypair,
  type Ciphertext,
} from "@openjanus/sdk/tokens-v2";
```

## Step 1 — Derive a BabyJubJub keypair

Each account needs a BabyJubJub keypair. The secret key `sk` is a scalar in the BabyJubJub scalar field. The public key `PK = sk * G`.

```typescript
import { CURVE_P, GENERATOR_G } from "@openjanus/sdk/primitives";
// Import or build a scalar multiplication function
// (included in @openjanus/elgamal or implement via babyjub primitives)

// Simplest approach: derive sk from account key material (deterministic)
// For testing, use a hardcoded known scalar
const aliceSK = 12345678901234567890n % CURVE_P; // must be < curve order
const alicePK = await babyMulOnChain(aliceSK, GENERATOR_G);
// OR compute locally if you have a scalarMul implementation

const aliceKeypair: ElGamalKeypair = { sk: aliceSK, pk: alicePK };
```

## Step 2 — Register pubkey (once per account)

```typescript
// EVM direct (if using JanusTokenV2 without Cadence)
const token = new JanusTokenV2(JANUS_TOKEN_V2_TESTNET);
await token.connectWithSigner(aliceEvmWallet);
await token.registerPubkey(aliceKeypair.pk);

// Via Cadence (if using JanusFlowV2)
const sdk = new JanusFlowV2({ network: "testnet" });
await sdk.configure();
await sdk.registerPubkey(aliceKeypair.pk, aliceAuthz);
```

This is a **one-time operation** per account. Once registered, any sender can encrypt amounts to Alice's pubkey without coordination.

## Step 3 — Sender wraps FLOW and encrypts to recipient

```typescript
import { buildEncryptProof, generateRandomness } from "@openjanus/elgamal";

// Get Alice's registered pubkey (or fetch from chain)
const alicePK = await sdk.getPubkey(ALICE_CADENCE_ADDR);

// Generate an ElGamal ciphertext for 10 FLOW encrypted to Alice
const proofResult = await buildEncryptProof({
  amount: 10n,
  randomness: generateRandomness(),  // ephemeral — no need to store
  recipientPubkey: alicePK,
  wasmPath: ENCRYPT_WASM_PATH,
  zkeyPath: ENCRYPT_ZKEY_PATH,
  vkPath: ENCRYPT_VK_PATH,  // optional: verify locally before submitting
});

// proofResult.locallyVerified === true  (if vkPath provided)
// proofResult.ciphertext = { c1: Point, c2: Point }
// proofResult.proof: uint256[8] (pi_b Fp2-swapped, ready for EVM)

// Submit via JanusFlowV2 (Cadence → EVM cross-VM)
const { txId } = await sdk.wrapAndEncrypt(
  "10.0",           // UFix64 FLOW amount
  ALICE_CADENCE_ADDR,
  proofResult,
  senderAuthz       // FCL authorization function
);
console.log("Wrap TX:", txId);
```

Multiple senders can repeat this step independently. Each call accumulates into Alice's slot via homomorphic ElGamal addition.

## Step 4 — Read accumulated slot

```typescript
// Via Cadence script
const ciphertext = await sdk.getSlot(ALICE_CADENCE_ADDR);
// Returns: { c1: { x: bigint, y: bigint }, c2: { x: bigint, y: bigint } }

// Via EVM direct
const token = new JanusTokenV2(JANUS_TOKEN_V2_TESTNET);
await token.connect();
const ct = await token.getBalanceCiphertext(aliceEvmAddress);
```

## Step 5 — Alice decrypts accumulated total

Alice uses her secret key to decrypt the slot and recover the total amount (sum of all received encryptions).

```typescript
import { buildDecryptProof, bsgsRecover } from "@openjanus/elgamal";

// Read Alice's accumulated ciphertext
const accumulatedCT = await sdk.getSlot(ALICE_CADENCE_ADDR);

// Recover M = C2 - sk * C1  (the masked message point = amount*G)
const M = await recoverMaskedPoint(accumulatedCT, aliceSK);

// Solve DLOG: m such that M = m*G  (BSGS, practical up to ~10M)
const amount = await bsgsRecover(M, { maxValue: 1_000_000n });
// amount === 42n  (10 + 25 + 7 from three senders)

// Generate decrypt-open proof
const decryptResult = await buildDecryptProof({
  ciphertext: accumulatedCT,
  secretKey: aliceSK,
  amount,
  wasmPath: DECRYPT_WASM_PATH,
  zkeyPath: DECRYPT_ZKEY_PATH,
  vkPath: DECRYPT_VK_PATH,
});
```

## Step 6 — Unwrap FLOW to recipient

```typescript
const { txId: unwrapTx } = await sdk.decryptAndUnwrap(
  "42.0",             // UFix64 — must match decrypted amount
  ALICE_CADENCE_ADDR, // recipient of unwrapped FLOW
  decryptResult,
  aliceAuthz
);
console.log("Unwrap TX:", unwrapTx);
```

## Complete example (3 senders, 1 recipient)

```typescript
// Three senders encrypt different amounts to Alice
for (const [sender, amount, authz] of [
  [ALICE_CADENCE_ADDR, 10n, aliceAuthz],  // self-send (setup)
  [BOB_CADENCE_ADDR,   25n, bobAuthz],
  [CAROL_CADENCE_ADDR,  7n, carolAuthz],
]) {
  const pk = await sdk.getPubkey(ALICE_CADENCE_ADDR);
  const proof = await buildEncryptProof({ amount, randomness: generateRandomness(), recipientPubkey: pk, ... });
  await sdk.wrapAndEncrypt(`${amount}.0`, ALICE_CADENCE_ADDR, proof, authz);
}

// Alice reads slot, decrypts, unwraps
const ct = await sdk.getSlot(ALICE_CADENCE_ADDR);
// BSGS to recover: amount === 42n
// Alice cannot tell which sender sent which amount — only the total
const decryptProof = await buildDecryptProof({ ciphertext: ct, secretKey: aliceSK, amount: 42n, ... });
await sdk.decryptAndUnwrap("42.0", ALICE_CADENCE_ADDR, decryptProof, aliceAuthz);
```

Privacy property: Bob (or anyone) reading Alice's slot `(C1, C2)` only sees two BabyJubJub points that reveal nothing about individual amounts. This was confirmed in Phase 3 e2e testing (24/24 pass).

## Circuit artifact paths

```typescript
// Replace with your actual paths or CDN URLs
const ENCRYPT_WASM_PATH = "./circuits/encryptConsistency.wasm";
const ENCRYPT_ZKEY_PATH = "./circuits/encryptConsistency_final.zkey";
const ENCRYPT_VK_PATH   = "./circuits/encryptConsistency_vk.json";

const DECRYPT_WASM_PATH = "./circuits/decryptOpen.wasm";
const DECRYPT_ZKEY_PATH = "./circuits/decryptOpen_final.zkey";
const DECRYPT_VK_PATH   = "./circuits/decryptOpen_vk.json";
```

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `registerPubkey reverts` | Point not on BabyJubJub curve | Verify `isOnCurveLocal(pk.x, pk.y) === true` |
| `encryptTo reverts` | Recipient has no registered pubkey | Call `hasPubkey(addr)` first; register if false |
| `decryptAndUnwrap returns false` | Wrong amount in proof | Use BSGS to recover exact amount before proof gen |
| `wrapAndEncrypt "9999 CU exceeded"` | Cadence tx too expensive | Remove extra operations from the Cadence tx |
| Proof verify returns false | Fixed-array mismatch (vuln/013) | Ensure verifier ABI uses `uint256[N]` not `uint256[]` |

## Next steps

- [v2-decrypt-flow.md](v2-decrypt-flow.md) — BSGS in depth, handling large balances
- [../patterns/confidential-tipping-v2.md](../patterns/confidential-tipping-v2.md) — Tipping pattern with v2
- [../patterns/funding-with-amount-privacy.md](../patterns/funding-with-amount-privacy.md) — Donation/funding use case
- [../contracts/janus-token-v2.md](../contracts/janus-token-v2.md) — Contract interface reference
- [../decision-trees/v1-vs-v2.md](../decision-trees/v1-vs-v2.md) — Choosing between v1 and v2
