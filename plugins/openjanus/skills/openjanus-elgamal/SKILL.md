---
name: openjanus-elgamal
description: |
  Guide for the OpenJanus v2 ElGamal-on-BabyJubJub encryption stack. Covers additive ElGamal ciphertexts on BabyJubJub, multi-sender homomorphic accumulation, recipient pubkey registration, encrypt-to-pubkey workflow, encrypt-consistency proof generation, decrypt-open proof generation, BSGS discrete log solver for decryption, JanusTokenV2 EVM contract, JanusFlowV2 Cadence contract, and migrating from v1 Pedersen to v2 ElGamal.
  TRIGGER when: ElGamal-on-BabyJubjub, additive homomorphism ElGamal, recipient pubkey, encrypt-to-pubkey, encryption proof, decryption proof, BSGS solver, BSGS discrete log, accumulator slot v2, JanusTokenV2, JanusFlowV2, v2 stack, ElGamal ciphertext, "registerPubkey", "encryptTo", "decryptAndUnwrap", "wrapAndEncrypt", "buildEncryptProof", "buildDecryptProof", "bsgsRecover", "@openjanus/sdk/tokens-v2", "tokens-v2", EncryptConsistencyVerifier, DecryptOpenVerifier, "multi-sender privacy", "per-sender amount hidden", "v2 quickstart", "v2 decrypt", "v1 vs v2", "migrate v1 to v2", "ElGamal keypair BabyJubJub", "derive pubkey", "BabyJubJub private key", "c1 c2 ciphertext", "ElGamal accumulation", "homomorphic encryption BabyJubJub", "slot not Pedersen", "slot ElGamal", "PrivateTip v2".
  DO NOT TRIGGER when: asking about v1 Pedersen commitments only (use openjanus-tokens or openjanus-primitives), asking about BabyJubJub curve math without context of ElGamal (use openjanus-primitives), deploying generic ZK verifiers (use openjanus-deploy).
---

# OpenJanus ElGamal Stack Guide (V2)

The v2 stack replaces Pedersen commitments with additive ElGamal-on-BabyJubJub. This enables genuine multi-sender privacy: multiple senders can encrypt amounts to the same recipient pubkey independently, and ciphertexts accumulate homomorphically. The recipient decrypts the total without learning individual sender amounts.

**Privacy property (confirmed Phase 3 e2e 24/24):** Bob receives deposits from Alice (10), Carol (25), Dave (7). Bob decrypts accumulated slot → 42. Bob cannot determine individual sender amounts from on-chain data.

## Core Concepts

### ElGamal on BabyJubJub

```
Encrypt(amount, r, PK):
  c1 = r * G               # ephemeral public key
  c2 = amount * G + r * PK # masked message point

Decrypt(c1, c2, sk):
  M = c2 - sk * c1         # recover amount * G
    = amount * G
  amount = BSGS(M)         # Baby-Step Giant-Step to solve discrete log
```

### Homomorphic accumulation

Multiple ciphertexts add together component-wise — the result decrypts to the sum. No individual amounts are recoverable without all individual `r_i` values (which stay off-chain with senders).

### Deployed contracts (testnet)

| Contract | Address |
|----------|---------|
| `JanusTokenV2.sol` | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` |
| `JanusFlowV2.cdc` | `0x28fef3d1d6a12800` |
| `EncryptConsistencyVerifier` | `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C` |
| `DecryptOpenVerifier` | `0x3bB139B5404fD6b152813bC3532367AAa096638b` |

## SDK Quick Start

```typescript
import { JanusFlowV2, JANUS_TOKEN_V2_TESTNET } from "@openjanus/sdk/tokens-v2";
import { buildEncryptProof, buildDecryptProof, bsgsRecover } from "@openjanus/elgamal";

const sdk = new JanusFlowV2({ network: "testnet" });
await sdk.configure();

// One-time setup: register pubkey
await sdk.registerPubkey(aliceKeypair.pk, aliceAuthz);

// Sender: encrypt and wrap
const proof = await buildEncryptProof({ amount: 10n, randomness: r, recipientPubkey: alicePK, ... });
await sdk.wrapAndEncrypt("10.0", ALICE_ADDR, proof, senderAuthz);

// Recipient: read slot, decrypt, unwrap
const ct = await sdk.getSlot(ALICE_ADDR);
const M = recoverMaskedPoint(ct, aliceSK);
const amount = await bsgsRecover(M, { maxValue: 1_000_000n });
const decryptProof = await buildDecryptProof({ ciphertext: ct, secretKey: aliceSK, amount, ... });
await sdk.decryptAndUnwrap(`${amount}.0`, ALICE_ADDR, decryptProof, aliceAuthz);
```

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/v1-vs-v2.md` — Detailed v1 (Pedersen) vs v2 (ElGamal) comparison: slot format, multi-sender privacy, migration options
- `references/elgamal-architecture.md` — Cryptographic architecture: ciphertext structure, homomorphic accumulation, ZK proof system, IND-CPA security, on-chain slot encoding
- `references/keypair-derivation.md` — HKDF Flow key derivation pattern for BabyJubJub keypairs, storage recommendations, multi-account scenarios

## Cross-skill references (load when context indicates)

- `../openjanus-sdk/references/quickstart.md` — Full v2 workflow from registration to unwrap
- `../openjanus-sdk/references/decrypt-flow.md` — BSGS decryption in depth: masked point recovery, table precompute, partial unwrap patterns
- `../openjanus-tokens/references/janus-token.md` — JanusTokenV2 Solidity interface and public inputs format
- `../openjanus-tokens/references/janus-flow.md` — JanusFlowV2 Cadence transaction templates
- `../openjanus-tokens/references/confidential-tipping.md` — Multi-sender tipping pattern (canonical v2 use case)
- `../openjanus-tokens/references/funding-with-amount-privacy.md` — Fundraising / donation use case

## Common gotchas

**P1 — Not registering pubkey before first receive.**
`encryptTo` targeting an unregistered account will revert. Call `hasPubkey(addr)` first.

**P2 — Incorrect amount in decryptAndUnwrap.**
The DecryptOpenVerifier circuit rejects any amount that doesn't match the actual decrypted value. Run BSGS to find the exact amount before generating the decrypt proof.

**P3 — Fixed-array verifier interface mismatch (vuln/013).**
snarkjs generates verifiers with `uint[N]` (fixed arrays). Your consumer interface must match exactly — `uint256[6]` not `uint256[] calldata`. Wrong selector causes silent revert.

**P4 — BSGS maxValue too small.**
If `maxValue` is smaller than the actual accumulated amount, BSGS returns null. Set `maxValue` to a safe upper bound (10x expected maximum balance).

**P5 — Secret key exposure.**
`sk` is equivalent to the private key for the balance. Never log it, never send it over HTTP, never expose it in client-side code without key management.

## Companion Skills

- **`openjanus-tokens`** — JanusTokenV2/JanusFlowV2 contract interface and patterns
- **`openjanus-sdk`** — general SDK usage (v2 workflow)
- **`openjanus-primitives`** — BabyJubJub curve math, Groth16 low-level
- **`openjanus-deploy`** — deploying a new JanusTokenV2 or JanusFlowV2 instance
- **`flow-crossvm`** — Cross-VM Cadence → EVM patterns for custom integrations
