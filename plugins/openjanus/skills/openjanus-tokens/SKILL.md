---
name: openjanus-tokens
description: |
  Guide for the JanusToken ElGamal accumulator contract and JanusFlow Cadence wrapper.
  Covers the JanusToken interface (registerPubkey, wrap, confidentialTransfer, unwrap, commitPubkeyRotation, finalizePubkeyRotation), the JanusFlow Cadence wrapper for native FLOW, creating custom JanusToken instances, and integrating with the v2 ZK verifiers (EncryptConsistencyVerifier, DecryptOpenVerifier).
  TRIGGER when: JanusToken contract, JanusFlow contract, ElGamal accumulator, registerPubkey, pubkey rotation, confidentialTransfer v2, wrap v2, unwrap v2, getBalanceCiphertext, hasPubkey, "extend JanusToken", "create a custom instance", "deploy my own privacy token", "what does JanusToken do", "JanusFlow", "COA slot per user", "homomorphic ElGamal", "ERC-7984 v2", "confidential ERC-20 v2", "privacy ERC-20 v2", "wrap ERC-20 into JanusToken", "EncryptConsistencyVerifier", "DecryptOpenVerifier", "BSGS decrypt", "encrypt consistency proof", "decrypt open proof", "multi-sender privacy", "IND-CPA BabyJubJub", "v2 contract", "ElGamal token contract", "JanusToken ABI", "JanusFlow Cadence", "v2 token interface", "confidential tipping", "privacy token pattern", "funding with amount privacy", "what privacy level".
  DO NOT TRIGGER when: using the SDK to call these contracts in TypeScript (use openjanus-sdk or openjanus-elgamal), asking about low-level cryptography (use openjanus-primitives), deploying to testnet/mainnet (use openjanus-deploy), or asking about v1 JanusToken/JanusFlow (content is in git history at v0.1.0-final).
---

# JanusToken and JanusFlow Guide

JanusToken is the v2 confidential token contract using ElGamal-on-BabyJub accumulation.
JanusFlow is its Cadence-native wrapper for Flow's native token.

> **v1 (JanusToken/JanusFlow, Pedersen-hash) has been deprecated.** See
> [why-v1-was-deprecated](https://github.com/openjanus/sdk/blob/main/docs/why-v1-was-deprecated.md).
> V1 docs are in git history at tag `v0.1.0-final`.

## Two Contract Types

| Contract | Layer | Purpose |
|----------|-------|---------|
| `JanusToken.sol` | Flow EVM | Confidential token with ElGamal accumulator |
| `JanusFlow.cdc` | Cadence | Native FLOW wrapper — Cross-VM Cadence→EVM orchestration |

## Core Concepts

**ElGamal accumulator** — Each user's balance is stored as an encrypted ciphertext
`(c1, c2) = (r*G, m*G + r*PK)`. Multiple senders can encrypt to the same recipient pubkey
independently. The recipient decrypts the accumulated total without learning per-sender amounts.

**IND-CPA under DDH on BabyJubJub** — Security relies on the Decisional Diffie-Hellman problem
on the BabyJubJub curve. Computationally indistinguishable from random under DDH.

**Multi-sender privacy** — The defining property of v2: a recipient accumulating tips from N
senders learns only the total, not each individual amount.

**Per-user pubkey registration** — Before receiving, users must call `registerPubkey(pk)` once.

## Deployed Addresses — v0.2.0 (testnet, 2026-05-26, ceremony-backed)

Trusted setup: Hermez pot14 (200+ contributors) + Flow VRF beacon.

| Contract | Address |
|----------|---------|
| JanusToken.sol | `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499` |
| JanusFlow.cdc | `0x28fef3d1d6a12800` (contract: `JanusFlow`, LEGACY v1) |
| EncryptConsistencyVerifier | `0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e` |
| DecryptOpenVerifier | `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` |

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/README.md` — Contracts overview: file map and quick lookup
- `references/janus-token.md` — JanusToken Solidity interface, slot lifecycle, public inputs format, comparison to v1
- `references/janus-flow.md` — JanusFlow Cadence contract: transaction templates (register, wrapAndEncrypt, getSlot, decryptAndUnwrap), CU notes
- `references/creating-custom-instances.md` — Deploy a custom JanusToken for your ERC-20 (WRAPPER mode) or new privacy token (NATIVE mode)
- `references/confidential-tipping.md` — Step-by-step multi-sender tipping pattern using v2 (recommended for new apps)
- `references/funding-with-amount-privacy.md` — Public fundraising / crowdfunding with hidden contribution amounts
- `references/privacy-level-needed.md` — Decision tree: what OpenJanus provides vs stealth addresses vs mixer

## Cross-skill references (load when context indicates)

- `../openjanus-elgamal/references/v1-vs-v2.md` — Detailed v1 vs v2 comparison, migration options
- `../openjanus-deploy/references/canonical-addresses.md` — All testnet/mainnet deployed addresses
- `../openjanus-sdk/references/quickstart.md` — SDK-level v2 quick start (TypeScript)
- `../openjanus-sdk/references/decrypt-flow.md` — BSGS decryption from the SDK perspective

## Examples

**JanusToken Solidity interface (brief):**
```solidity
function registerPubkey(uint256 pkx, uint256 pky) external;
function hasPubkey(address account) external view returns (bool);
function encryptTo(address recipient, uint256 c1x, uint256 c1y, uint256 c2x, uint256 c2y,
    uint256[8] calldata proof, uint256[6] calldata pubInputs) external payable;
function decryptAndUnwrap(address to, uint256 amount,
    uint256[8] calldata proof, uint256[5] calldata pubInputs) external;
```

**JanusFlow Cadence (register pubkey):**
```cadence
import JanusFlow from 0x28fef3d1d6a12800
transaction(pkx: UInt256, pky: UInt256) {
    execute { JanusFlow.registerPubkey(pkx: pkx, pky: pky) }
}
```

## Common gotchas

**P1 — Registering pubkey before sending.**
Every recipient must call `registerPubkey` before receiving a `confidentialTransfer`. Sending to an address without a registered pubkey reverts.

**P2 — Pubkey rotation with non-empty slot.**
`finalizePubkeyRotation` cannot complete while the user has an encrypted balance. Users must `decryptAndUnwrap` all FLOW before rotating keys.

**P3 — Using v1 SDK imports.**
`@openjanus/sdk/tokens` (v1, removed in 0.2.0). Use `@openjanus/sdk/tokens` for all v2 operations.

**P4 — Fixed-array verifier interface mismatch.**
snarkjs generates verifiers with `uint[N]` (fixed arrays). Interface declarations must match exactly — `uint256[6]` not `uint256[] calldata`. Selector mismatch causes silent revert. See vuln/013.

**P5 — Pubkey point not on BabyJubJub.**
Always verify `isOnCurveLocal(pk.x, pk.y) === true` before calling `registerPubkey`. An off-curve point will produce ciphertexts that can never be correctly decrypted.

## Companion Skills

- **`openjanus-sdk`** — TypeScript SDK wrapping these contracts
- **`openjanus-elgamal`** — The ElGamal encryption/decryption layer in detail
- **`openjanus-deploy`** — deploy a new JanusToken or JanusFlow instance
- **`openjanus-primitives`** — the cryptographic layer the contracts depend on
- **`flow-crossvm`** — Cross-VM patterns for Cadence orchestrating EVM calls
