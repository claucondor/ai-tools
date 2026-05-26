---
name: openjanus-elgamal
description: |
  Guide for the OpenJanus ElGamal-on-BabyJubJub encryption stack. Covers additive ElGamal ciphertexts on BabyJubJub, multi-sender homomorphic accumulation, recipient pubkey registration, encrypt-to-pubkey workflow, encrypt-consistency proof generation, decrypt-open proof generation, BSGS discrete log solver for decryption, JanusToken EVM contract, JanusFlow Cadence contract.
  TRIGGER when: ElGamal-on-BabyJubjub, additive homomorphism ElGamal, recipient pubkey, encrypt-to-pubkey, encryption proof, decryption proof, BSGS solver, BSGS discrete log, JanusToken, JanusFlow, ElGamal ciphertext, "registerPubkey", "encryptTo", "decryptAndUnwrap", "wrapAndEncrypt", "buildEncryptProof", "buildDecryptProof", "bsgsRecover", "@openjanus/sdk/tokens", "tokens", EncryptConsistencyVerifier, DecryptOpenVerifier, "multi-sender privacy", "per-sender amount hidden", "decrypt", "ElGamal keypair BabyJubJub", "derive pubkey", "BabyJubJub private key", "c1 c2 ciphertext", "ElGamal accumulation", "homomorphic encryption BabyJubJub", "slot ElGamal", "PrivateTip".
  DO NOT TRIGGER when: asking about v1 Pedersen commitments only (use openjanus-tokens or openjanus-primitives), asking about BabyJubJub curve math without context of ElGamal (use openjanus-primitives), deploying generic ZK verifiers (use openjanus-deploy).
---

# OpenJanus ElGamal Stack Guide

The openjanus stack uses additive ElGamal-on-BabyJubJub for genuine multi-sender privacy: multiple senders can encrypt amounts to the same recipient pubkey independently, and ciphertexts accumulate homomorphically. The recipient decrypts the total without learning individual sender amounts.

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

### Deployed contracts (testnet) — v0.2.0-router

| Contract | Address | Notes |
|----------|---------|-------|
| `JanusToken.sol` | `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499` | Ceremony-backed |
| `JanusFlow.cdc` (router) | `0xbef3c77681c15397` | Canonical — stable forever |
| `EncryptConsistencyVerifier` | `0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e` | Groth16 |
| `DecryptOpenVerifier` | `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` | Groth16 |

DEPRECATED (zombie): `0x28fef3d1d6a12800.JanusFlow`

## SDK Quick Start

```typescript
import { JanusFlow, JANUS_TOKEN_TESTNET } from "@openjanus/sdk/tokens";
import { buildEncryptProof, buildDecryptProof, bsgsRecover } from "@openjanus/elgamal";

const sdk = new JanusFlow({ network: "testnet" });
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

- `references/elgamal-architecture.md` — Detailed ElGamal architecture: slot format, multi-sender privacy, homomorphic accumulation
- `references/elgamal-architecture.md` — Cryptographic architecture: ciphertext structure, homomorphic accumulation, ZK proof system, IND-CPA security, on-chain slot encoding
- `references/keypair-derivation.md` — HKDF Flow key derivation pattern for BabyJubJub keypairs, storage recommendations, multi-account scenarios

## Cross-skill references (load when context indicates)

- `../openjanus-sdk/references/quickstart.md` — Full workflow from registration to unwrap
- `../openjanus-sdk/references/decrypt-flow.md` — BSGS decryption in depth: masked point recovery, table precompute, partial unwrap patterns
- `../openjanus-tokens/references/janus-token.md` — JanusToken Solidity interface and public inputs format
- `../openjanus-tokens/references/janus-flow.md` — JanusFlow Cadence transaction templates
- `../openjanus-tokens/references/confidential-tipping.md` — Multi-sender tipping pattern (canonical use case)
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

- **`openjanus-tokens`** — JanusToken/JanusFlow contract interface and patterns
- **`openjanus-sdk`** — general SDK usage
- **`openjanus-primitives`** — BabyJubJub curve math, Groth16 low-level
- **`openjanus-deploy`** — deploying a new JanusToken or JanusFlow instance
- **`flow-crossvm`** — Cross-VM Cadence → EVM patterns for custom integrations
