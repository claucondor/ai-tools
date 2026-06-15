---
name: openjanus-elgamal
description: |
  ARCHIVED — v0.2 ElGamal-on-BabyJubJub stack. v0.8 uses Pedersen-on-BabyJub commitments + Groth16 ZK, no ElGamal. For the sign-derive / MemoKey / ECIES pattern used in v0.8, see openjanus-sdk references/decrypt-flow.md and references/cross-vm-coa-pattern.md.
  TRIGGER when: ElGamal-on-BabyJubjub (historical only), "buildEncryptProof" (v0.2 removed), "buildDecryptProof" (v0.2 removed), "bsgsRecover", EncryptConsistencyVerifier, DecryptOpenVerifier, "registerPubkey" (v0.2 removed), "decryptAndUnwrap" (v0.2 removed), "wrapAndEncrypt" (v0.2 removed), ElGamal ciphertext, "c1 c2 ciphertext", "homomorphic ElGamal", "slot ElGamal".
  DO NOT TRIGGER when: asking about sign-derive / MemoKey / ECIES in v0.8 (use openjanus-sdk), BabyJubJub curve math (use openjanus-primitives), v0.8 wallet keypair derivation (use openjanus-sdk references/decrypt-flow.md).
---

> **STATUS: archived (v0.2 stack).** v0.8 uses Pedersen-on-BabyJub + Groth16, no ElGamal.
> The ElGamal accumulator (`registerPubkey`, `encryptTo`, `decryptAndUnwrap`,
> `buildEncryptProof`, `buildDecryptProof`, BSGS solver) is entirely removed from v0.3+.
>
> For the current MemoKey / sign-derive / ECIES pattern used in v0.8, see:
> - `../openjanus-sdk/references/decrypt-flow.md`
> - `../openjanus-sdk/references/cross-vm-coa-pattern.md`
> - `../openjanus-sdk/SKILL.md`

# OpenJanus BabyJubJub Keypair and ECIES Layer

This skill covers the **ECIES (BabyJubJub + AES-GCM) encryption layer** used for
ShieldedNote delivery and the sign-derive keypair pattern.

## Current use: ECIES ShieldedNote and MemoKey

The production privacy model uses **Pedersen commitments + Groth16** for the on-chain
token state. ECIES encryption (additive ElGamal-style ECDH on BabyJubJub + AES-GCM)
is used for:

1. **Tip memos** — sender encrypts `{ amount, blinding }` to recipient's MemoKey pubkey
2. **Recovery snapshots** — sender encrypts post-action `{ balance, blinding }` to their
   own MemoKey pubkey; stored in `*WithSnapshot` EVM events

The BabyJub keypair for both is derived via sign-derive (see `references/sign-derive.md`).

## Deployed contracts (historical — v0.6.4, archived)

> These are historical v0.6.4 addresses. v0.8 deploys new contracts at different addresses.
> See `../openjanus-sdk/SKILL.md` for current addresses.

| Contract | Address | Notes |
|----------|---------|-------|
| `JanusFlow` EVM proxy | `0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156` | Archived (v0.6.4) |
| `MemoKeyRegistry` | `0x05D104962ff087441f26BA11A1E1C3b9E091D663` | Archived (v0.6.4) |
| `AmountDiscloseVerifier` | `0xD0ED3936530258C278f5357C1dB709ad34768352` | Archived verifier |
| `ConfidentialTransferVerifier` | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` | Archived verifier |


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

- `references/elgamal-architecture.md` — Cryptographic architecture: ECIES ciphertext structure, ShieldedNote format, IND-CPA security, on-chain slot encoding
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
