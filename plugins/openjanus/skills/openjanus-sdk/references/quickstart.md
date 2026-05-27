# Quick Start — ElGamal JanusToken + JanusFlow

This guide covers the complete workflow using `@openjanus/sdk/tokens`. The stack uses additive
ElGamal-on-BabyJubJub for genuine multi-sender privacy.

> **Use case:** Any app where multiple senders deposit to the same recipient. Recipients
> learn only the accumulated total, not individual sender amounts.

**SDK version:** `@openjanus/sdk@^0.2.0` (includes router pattern — `JanusFlow` fully functional).
**JanusFlow canonical address:** `0x5dcbeb41055ec57e` (router/impl pattern, 25/25 e2e pass).

## Install

```bash
npm install @openjanus/sdk@^0.2.0
```

`@openjanus/sdk` includes the tokens module at `tokens/`. Circuit artifacts (WASM + zkeys)
are bundled and available at `@openjanus/sdk/circuits/` (included in the npm package).

## Import

```typescript
import {
  JanusToken,
  JanusFlow,
  JANUS_TOKEN_TESTNET,
  type ElGamalKeypair,
  type Ciphertext,
} from "@openjanus/sdk/tokens";
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
// EVM direct (if using JanusToken without Cadence)
const token = new JanusToken(JANUS_TOKEN_TESTNET);
await token.connectWithSigner(aliceEvmWallet);
await token.registerPubkey(aliceKeypair.pk);

// Via Cadence (if using JanusFlow)
const sdk = new JanusFlow({ network: "testnet" });
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

// Submit via JanusFlow (Cadence → EVM cross-VM)
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
const token = new JanusToken(JANUS_TOKEN_TESTNET);
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

## Admin operations (router v0.2.0-router)

For app developers integrating JanusFlow, handle the paused state and watch for
impl swap events. For admin account usage:

```typescript
import { JanusFlow } from "@openjanus/sdk/tokens";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.configure();

// Always check pause state before user-facing writes
const paused = await sdk.isPaused();
if (paused) {
  throw new Error("JanusFlow is currently paused — try again later");
}

// Get current impl version (for monitoring)
const implVersion = await sdk.getActiveImplVersion();
console.log("Active impl:", implVersion); // "0.1.0"

// Admin only: pause (emergency stop)
// Caller must hold AdminResource at /storage/janusFlowAdmin on 0x5dcbeb41055ec57e
await sdk.pause(adminAuthz);

// Admin only: unpause
await sdk.unpause(adminAuthz);

// Admin only: finalize impl swap after 48h time-lock
// (proposeImplSwap must be called on-chain first via TX_ADMIN_PROPOSE_IMPL_SWAP template)
await sdk.finalizeImplSwap(adminAuthz);

// Admin only: cancel pending impl swap proposal
await sdk.cancelImplSwap(adminAuthz);
```

See [router-pattern.md](../../../openjanus-tokens/references/router-pattern.md) for
security implications and app integration guidance.

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `registerPubkey reverts` | Point not on BabyJubJub curve | Verify `isOnCurveLocal(pk.x, pk.y) === true` |
| `encryptTo reverts` | Recipient has no registered pubkey | Call `hasPubkey(addr)` first; register if false |
| `decryptAndUnwrap returns false` | Wrong amount in proof | Use BSGS to recover exact amount before proof gen |
| `wrapAndEncrypt "9999 CU exceeded"` | Cadence tx too expensive | Remove extra operations from the Cadence tx |
| Proof verify returns false | Fixed-array mismatch (vuln/013) | Ensure verifier ABI uses `uint256[N]` not `uint256[]` |
| Any write reverts with "paused" | JanusFlow is emergency-stopped | Call `isPaused()` first; surface error to user |
| Wrong JanusFlow address | Using old `0x28fef3d1d6a12800` | Update to `0x5dcbeb41055ec57e` or use `JANUS_FLOW_CADENCE_ADDRESS` constant |

## Next steps

- [decrypt-flow.md](decrypt-flow.md) — BSGS in depth, handling large balances
- [../../../openjanus-tokens/references/router-pattern.md](../../../openjanus-tokens/references/router-pattern.md) — Router pattern + admin security guide
- [../../../openjanus-tokens/references/confidential-tipping.md](../../../openjanus-tokens/references/confidential-tipping.md) — Tipping pattern with ElGamal
- [../../../openjanus-tokens/references/funding-with-amount-privacy.md](../../../openjanus-tokens/references/funding-with-amount-privacy.md) — Donation/funding use case
- [../../../openjanus-tokens/references/janus-token.md](../../../openjanus-tokens/references/janus-token.md) — Contract interface reference
- [../../../openjanus-elgamal/references/elgamal-architecture.md](../../../openjanus-elgamal/references/elgamal-architecture.md) — ElGamal architecture deep dive
