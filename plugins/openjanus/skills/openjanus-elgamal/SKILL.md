---
name: openjanus-elgamal
description: |
  Guide for the OpenJanus BabyJubJub keypair and ECIES encryption layer. Covers the sign-derive pattern (deterministic BabyJub keypair from wallet signature), ECIES ShieldedNote encryption/decryption, MemoKey primitive, and historical ElGamal accumulator architecture (v0.2, deprecated). The ElGamal accumulator (registerPubkey / wrapAndEncrypt / decryptAndUnwrap / bsgsRecover) is deprecated — use openjanus-sdk for current wrap/transfer/unwrap workflows.
  TRIGGER when: ElGamal-on-BabyJubjub, additive homomorphism ElGamal, recipient pubkey, encrypt-to-pubkey, encryption proof, decryption proof, BSGS solver, BSGS discrete log, JanusToken, JanusFlow, ElGamal ciphertext, "registerPubkey", "encryptTo", "decryptAndUnwrap", "wrapAndEncrypt", "buildEncryptProof", "buildDecryptProof", "bsgsRecover", "@claucondor/sdk/tokens", "tokens", EncryptConsistencyVerifier, DecryptOpenVerifier, "multi-sender privacy", "per-sender amount hidden", "decrypt", "ElGamal keypair BabyJubJub", "derive pubkey", "BabyJubJub private key", "c1 c2 ciphertext", "ElGamal accumulation", "homomorphic encryption BabyJubJub", "slot ElGamal", "PrivateTip", "sign-derive", "deriveBabyJubKeypairFromBytes", "derive keypair from signature", "wallet signature derive", "MemoKey derivation", "deterministic BabyJub keypair", "HKDF derive keypair", "key recovery without storage", "multi-device key", "openjanus/memokey/v1", "sessionStorage keypair", "sign to derive", "memo key derive".
  DO NOT TRIGGER when: asking about v1 Pedersen commitments only (use openjanus-tokens or openjanus-primitives), asking about BabyJubJub curve math without context of ElGamal (use openjanus-primitives), deploying generic ZK verifiers (use openjanus-deploy).
---

# OpenJanus BabyJubJub Keypair and ECIES Layer

This skill covers the **ECIES (BabyJubJub + AES-GCM) encryption layer** used for
ShieldedNote delivery and the sign-derive keypair pattern. It also includes historical
reference material for the v0.2 ElGamal accumulator (deprecated).

## Current use: ECIES ShieldedNote and MemoKey

The production privacy model uses **Pedersen commitments + Groth16** for the on-chain
token state. ECIES encryption (additive ElGamal-style ECDH on BabyJubJub + AES-GCM)
is used for:

1. **Tip memos** — sender encrypts `{ amount, blinding }` to recipient's MemoKey pubkey
2. **Recovery snapshots** — sender encrypts post-action `{ balance, blinding }` to their
   own MemoKey pubkey; stored in `*WithSnapshot` EVM events

The BabyJub keypair for both is derived via sign-derive (see `references/sign-derive.md`).

## Historical reference: ElGamal accumulator (v0.2, deprecated)

The v0.2 `JanusToken.sol` used an additive ElGamal-on-BabyJubJub accumulator:

```
Encrypt(amount, r, PK):
  c1 = r * G               # ephemeral public key
  c2 = amount * G + r * PK # masked message point
```

Multiple ciphertexts added homomorphically. The recipient ran BSGS to recover the
cleartext total. This scheme was **deprecated in v0.3** due to two privacy regressions
(amounts leaked on `msg.value` and calldata) documented in audits-kb as vuln 013/014.
See `references/elgamal-architecture.md` for the full historical design.

### Deployed contracts (current — v0.5.4)

> The ElGamal accumulator (`JanusToken.sol@0x025efe7e...`, `EncryptConsistencyVerifier`,
> `DecryptOpenVerifier`) is **deprecated** — superseded by the Pedersen+Groth16 scheme.
> This skill now covers the ECIES/MemoKey primitive layer (keypair derivation, ShieldedNote
> encryption/decryption), which is still active and used for tip memos and recovery snapshots.

| Contract | Address | Notes |
|----------|---------|-------|
| `JanusFlow.cdc` (router) | `0x5dcbeb41055ec57e` | Canonical — stable forever |
| `JanusFlow` EVM proxy | `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078` | UUPS proxy |
| `AmountDiscloseVerifier` | `0x9c83b2b1EFFD3bd375b9Bee93Cb618005D6A2Dc4` | Active verifier |
| `ConfidentialTransferVerifier` | `0x48f791D2a4992F448Cc36F12e5500b6553e969b3` | Active verifier |

DEPRECATED: `0x025efe7e...` (v0.2 ElGamal JanusToken), `0x0C1e731036...` (EncryptConsistencyVerifier),
`0x1c248dA94...` (DecryptOpenVerifier), `0x28fef3d1d6a12800.JanusFlow` (zombie)

## SDK Quick Start — MemoKey / ECIES

```typescript
import { deriveBabyJubKeypairFromBytes, encryptText, decryptText } from "@claucondor/sdk/crypto";

// Derive a deterministic BabyJub keypair from a wallet signature (sign-derive pattern)
const sig = await wallet.signMessage("openjanus/memokey/v1");
const keypair = await deriveBabyJubKeypairFromBytes(new TextEncoder().encode(sig));
// keypair.privkey: bigint scalar (keep in sessionStorage only — never on-chain)
// keypair.pubkey:  { x: bigint, y: bigint } — publish via setup_memo_key.cdc

// Sender: encrypt a ShieldedNote to recipient's MemoKey pubkey (ECIES)
const { ciphertext, ephemeralPubkey } = await encryptText(
  JSON.stringify({ amount: "10", blinding: blinding.toString() }),
  recipientMemoKeyPubkey
);

// Recipient: decrypt with their privkey
const plaintext = await decryptText(ciphertext, ephemeralPubkey, keypair.privkey);
const { amount, blinding } = JSON.parse(plaintext);
```

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/elgamal-architecture.md` — Detailed ElGamal architecture: slot format, multi-sender privacy, homomorphic accumulation
- `references/elgamal-architecture.md` — Cryptographic architecture: ciphertext structure, homomorphic accumulation, ZK proof system, IND-CPA security, on-chain slot encoding
- `references/keypair-derivation.md` — HKDF Flow key derivation pattern for BabyJubJub keypairs, storage recommendations, multi-account scenarios
- `references/sign-derive.md` — Deterministic BabyJub keypair from a wallet signature (sign-derive pattern): `deriveBabyJubKeypairFromBytes`, HKDF-SHA256 internals, context strings, multi-device recovery, anti-patterns, trade-offs

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
