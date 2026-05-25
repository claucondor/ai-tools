---
name: openjanus-tokens
description: |
  Guide for the JanusTokenV2 ElGamal accumulator contract and JanusFlowV2 Cadence wrapper.
  Covers the JanusTokenV2 interface (registerPubkey, wrap, confidentialTransfer, unwrap, commitPubkeyRotation, finalizePubkeyRotation), the JanusFlowV2 Cadence wrapper for native FLOW, creating custom JanusTokenV2 instances, and integrating with the v2 ZK verifiers (EncryptConsistencyVerifier, DecryptOpenVerifier).
  TRIGGER when: JanusTokenV2 contract, JanusFlowV2 contract, ElGamal accumulator, registerPubkey, pubkey rotation, confidentialTransfer v2, wrap v2, unwrap v2, getBalanceCiphertext, hasPubkey, "extend JanusTokenV2", "create a custom instance", "deploy my own privacy token", "what does JanusTokenV2 do", "JanusFlowV2", "COA slot per user", "homomorphic ElGamal", "ERC-7984 v2", "confidential ERC-20 v2", "privacy ERC-20 v2", "wrap ERC-20 into JanusTokenV2", "EncryptConsistencyVerifier", "DecryptOpenVerifier", "BSGS decrypt", "encrypt consistency proof", "decrypt open proof", "multi-sender privacy", "IND-CPA BabyJubJub", "v2 contract", "ElGamal token contract", "JanusTokenV2 ABI", "JanusFlowV2 Cadence", "v2 token interface".
  DO NOT TRIGGER when: using the SDK to call these contracts in TypeScript (use openjanus-sdk or openjanus-elgamal), asking about low-level cryptography (use openjanus-primitives), deploying to testnet/mainnet (use openjanus-deploy), or asking about v1 JanusToken/JanusFlow (see docs/_archive/).
---

# JanusTokenV2 and JanusFlowV2 Guide

JanusTokenV2 is the v2 confidential token contract using ElGamal-on-BabyJub accumulation.
JanusFlowV2 is its Cadence-native wrapper for Flow's native token.

> **v1 (JanusToken/JanusFlow, Pedersen-hash) has been deprecated.** See
> [docs/_archive/](../../../../../docs/_archive/) for archived v1 documentation.
> Migration: https://github.com/openjanus/sdk/blob/main/docs/why-v1-was-deprecated.md

## Two Contract Types

| Contract | Layer | Purpose |
|----------|-------|---------|
| `JanusTokenV2.sol` | Flow EVM | Confidential token with ElGamal accumulator |
| `JanusFlowV2.cdc` | Cadence | Native FLOW wrapper — Cross-VM Cadence→EVM orchestration |

## Navigation Map

| Task | Reference |
|------|-----------|
| JanusTokenV2 interface, deployed addresses | [canonical-addresses.md](../../../../../docs/deployments/canonical-addresses.md) |
| JanusFlowV2 architecture, Cadence transactions | [openjanus/contracts/packages/janus-token-v2](https://github.com/openjanus/contracts/tree/main/packages/janus-token-v2) |
| Migration from v1 | [why-v1-was-deprecated.md](https://github.com/openjanus/sdk/blob/main/docs/why-v1-was-deprecated.md) |
| SDK usage | [openjanus-sdk skill](../openjanus-sdk/SKILL.md) |

## Core Concepts

**ElGamal accumulator** — Each user's balance is stored as an encrypted ciphertext
`(c1, c2) = (r*G, m*G + r*PK)`. Multiple senders can encrypt to the same recipient pubkey
independently. The recipient decrypts the accumulated total without learning per-sender amounts.

**IND-CPA under DDH on BabyJubJub** — Security relies on the Decisional Diffie-Hellman problem
on the BabyJubJub curve. Computationally indistinguishable from random under DDH.

**Multi-sender privacy** — The defining property of v2: a recipient accumulating tips from N
senders learns only the total, not each individual amount.

**Per-user pubkey registration** — Before receiving, users must call `registerPubkey(pk)` once.
The pubkey is a BabyJubJub public key derived from the user's account key.

**Pubkey rotation** — Two-step rotation: `commitPubkeyRotation` (1-hour timelock) then
`finalizePubkeyRotation`. Old ciphertext slot must be emptied before rotation completes.

**`confidentialTransfer`** — Reassigns locked FLOW + accumulates ciphertext to recipient slot.
Requires `encrypt_consistency` Groth16 proof.

**`unwrap`** — Proves decryption of accumulated slot + releases FLOW. Requires `decrypt_open`
Groth16 proof.

## Deployed Addresses (testnet)

| Contract | Address |
|----------|---------|
| JanusTokenV2.sol | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` |
| JanusFlowV2.cdc | `0x28fef3d1d6a12800` (contract: `JanusFlowV2`) |
| EncryptConsistencyVerifier | `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C` |
| DecryptOpenVerifier | `0x3bB139B5404fD6b152813bC3532367AAa096638b` |

## Common Pitfalls

**P1 — Registering pubkey before sending.** Every recipient must call `registerPubkey` before
receiving a `confidentialTransfer`. Sending to an address without a registered pubkey reverts.

**P2 — Pubkey rotation with non-empty slot.** Rotation cannot finalize while the user still has
an encrypted balance. Users must unwrap all FLOW before rotating keys.

**P3 — Using v1 SDK constants.** `@openjanus/sdk/tokens` was removed in 0.2.0. Use
`@openjanus/sdk/tokens-v2` for all v2 operations.

## Companion Skills

- **`openjanus-sdk`** — TypeScript SDK wrapping these contracts
- **`openjanus-deploy`** — deploy a new JanusTokenV2 or JanusFlowV2 instance
- **`openjanus-primitives`** — the cryptographic layer the contracts depend on
- **`flow-crossvm`** — Cross-VM patterns for Cadence orchestrating EVM calls
