# Decrypt Flow — BSGS and ElGamal Decryption

This document explains the decryption process in the ElGamal stack: how a recipient recovers the plaintext total from their accumulated slot using their secret key and the Baby-Step Giant-Step (BSGS) algorithm.

## Overview

The balance slot stores an ElGamal ciphertext over BabyJubJub:

```
slot = (C1, C2) where:
  C1 = r_total * G      (sum of all ephemeral r_i * G from senders)
  C2 = m_total * G + r_total * PK  (accumulated masked message)
```

To decrypt:

```
1. Compute M = C2 - sk * C1
   M = (m_total * G + r_total * PK) - sk * (r_total * G)
     = m_total * G + r_total * sk * G - sk * r_total * G
     = m_total * G   ← the recovered masked point

2. Solve M = m * G for m  (discrete log — BSGS)
```

Step 1 is straightforward elliptic curve arithmetic. Step 2 (solving the discrete log) requires BSGS.

## Step 1: Recover the masked point M

```typescript
import { negateOnChain, babyAddOnChain } from "@openjanus/sdk/primitives";

// Or use local BabyJubJub scalar multiplication if available
async function recoverMaskedPoint(
  ct: Ciphertext,
  sk: bigint
): Promise<Point> {
  // Compute sk * C1
  const skC1 = await babyMulOnChain(sk, ct.c1);

  // Negate: -sk*C1 = (P - skC1.x, skC1.y)
  const negSkC1 = { x: skC1.x === 0n ? 0n : CURVE_P - skC1.x, y: skC1.y };

  // M = C2 + (- sk*C1)
  const M = await babyAddOnChain(ct.c2, negSkC1);
  return M;
}
```

Note: scalar multiplication on BabyJubJub is not included in the `babyjub.ts` primitives (those use on-chain BabyJub.sol for add/negate). For decryption, either:
1. Use `@openjanus/elgamal`'s local scalar multiplication (off-chain, no network)
2. Call `BabyJub.sol.babyMul(sk, c1x, c1y)` if the contract exposes it

## Step 2: BSGS to recover m from M = m*G

Baby-Step Giant-Step solves `M = m*G` in O(sqrt(m_max)) time and O(sqrt(m_max)) space.

### Using @openjanus/elgamal

```typescript
import { bsgsRecover } from "@openjanus/elgamal";

const amount = await bsgsRecover(M, {
  maxValue: 1_000_000n,  // search space [0, 1M]
  // tableSize defaults to ceil(sqrt(maxValue)) ~ 1000 entries
});

if (amount === null) {
  throw new Error("Amount not found — slot encrypted to larger value than maxValue");
}

console.log("Decrypted balance:", amount); // e.g., 42n
```

### Precomputing the BSGS table

For browser apps or performance-sensitive paths, precompute the table once:

```typescript
import { buildBsgsTable, bsgsRecoverWithTable } from "@openjanus/elgamal";

// Precompute (do once at startup, ~1000 baby-step entries for maxValue=1M)
const table = await buildBsgsTable(1_000_000n);

// Recover using precomputed table
const amount = await bsgsRecoverWithTable(M, table, 1_000_000n);
```

### BSGS practical limits

| `maxValue` | Table size | Build time | Lookup time |
|-----------|------------|------------|-------------|
| 10,000 | ~100 entries | <1ms | <1ms |
| 1,000,000 | ~1000 entries | ~10ms | ~10ms |
| 100,000,000 | ~10,000 entries | ~100ms | ~100ms |

For production apps, determine the maximum realistic balance (in smallest FLOW units) and set `maxValue` to 10x that for headroom.

## Step 3: Generate the decrypt-open proof

Once you have `amount`, generate a Groth16 proof that the decryption is correct:

```typescript
import { buildDecryptProof } from "@openjanus/elgamal";

const decryptResult = await buildDecryptProof({
  ciphertext: accumulatedCT,  // (c1, c2) from on-chain slot
  secretKey: aliceSK,          // Alice's BabyJubJub secret key
  amount,                       // recovered via BSGS
  wasmPath: DECRYPT_WASM_PATH,
  zkeyPath: DECRYPT_ZKEY_PATH,
  vkPath:   DECRYPT_VK_PATH,   // recommended for local pre-verify
});

// decryptResult.locallyVerified === true  (should be true before submitting)
// decryptResult.proof:        uint256[8]  (pi_b Fp2-swapped)
// decryptResult.publicInputs: uint256[5]  [c1x, c1y, c2x, c2y, amount]
```

## Step 4: Submit decryptAndUnwrap

```typescript
// Via JanusFlow SDK (Cadence)
await sdk.decryptAndUnwrap("42.0", ALICE_CADENCE_ADDR, decryptResult, aliceAuthz);

// OR direct EVM call
const token = new JanusToken(JANUS_TOKEN_TESTNET);
await token.connectWithSigner(aliceWallet);
await token.decryptAndUnwrap(aliceEvmAddress, 42n, decryptResult);
```

## Why the decryption proof is needed

Without the decrypt-open proof, any account could claim any amount from any slot by submitting a fabricated plaintext. The proof ensures:

1. The claimer knows `sk` (the discrete log of the registered `PK`)
2. The claimed `amount` satisfies `amount * G = C2 - sk * C1`

The DecryptOpenVerifier circuit enforces both constraints. The on-chain verifier at `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` (v0.2.0, ceremony-backed) checks the Groth16 proof before releasing FLOW.

## Partial unwrap

JanusToken does not directly support partial unwrap (unwrapping less than the full accumulated balance). Options:

1. **Re-encrypt the remainder:** After unwrapping the full amount, immediately call `encryptTo` to send the remainder back to your own pubkey.
2. **App-level tracking:** Track the total amount in the app and only call `decryptAndUnwrap` when ready to exit completely.

## Handling identity slot (zero balance)

```typescript
const ct = await token.getBalanceCiphertext(address);
const isEmpty = ct.c1.x === 0n && ct.c1.y === 1n
             && ct.c2.x === 0n && ct.c2.y === 1n;

if (isEmpty) {
  console.log("No balance to decrypt");
  return;
}
```

## Security: secret key storage

The secret key `sk` must be stored securely:
- Never log or expose `sk` in HTTP responses
- Store encrypted in the app's backend (key-derived from account password or hardware key)
- In browser apps, use the Web Crypto API for wrapping the key at rest
- `sk` is equivalent to the private key for the balance — losing it means the balance cannot be decrypted or unwrapped

## See also

- [quickstart.md](quickstart.md) — Full workflow from start to finish
- [../../../openjanus-tokens/references/janus-token.md](../../../openjanus-tokens/references/janus-token.md) — DecryptOpenVerifier public inputs format
- [../../../openjanus-elgamal/SKILL.md](../../../openjanus-elgamal/SKILL.md) — AI skill for ElGamal questions
