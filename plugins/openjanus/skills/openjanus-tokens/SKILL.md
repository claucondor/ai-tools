---
name: openjanus-tokens
description: |
  Guide for the JanusToken ERC-7984-style Solidity standard and JanusFlow Cadence contract. Covers the JanusToken interface (NATIVE vs WRAPPER mode, confidentialTransfer, mintXY, burnXY, wrap, unwrap), the JanusFlow Cadence wrapper for native FLOW, creating custom JanusToken instances for your own ERC-20, and integrating with the verifier and BabyJub contracts.
  TRIGGER when: JanusToken contract, JanusFlow contract, NATIVE mode, WRAPPER mode, confidentialTransfer Solidity, mintXY, burnXY, wrap, unwrap, balanceOfCommitment, "extend JanusToken", "create a custom instance", "deploy my own privacy token", "what does JanusToken do", "WRAPPER mode vs NATIVE", "JanusFlow v1.1.0", "COA slot per user", "homomorphic mintXY", "ERC-7984", "confidential ERC-20", "privacy ERC-20", "wrap ERC-20 into JanusToken", "creating-custom-instances", JanusTokenV2, JanusFlowV2, "v2 contract", "ElGamal token contract", "registerPubkey contract", "encryptTo contract", "decryptAndUnwrap contract", "v2 deployed address", "EncryptConsistencyVerifier", "DecryptOpenVerifier", "JanusTokenV2 ABI", "JanusFlowV2 Cadence", "v2 token interface".
  DO NOT TRIGGER when: using the SDK to call these contracts in TypeScript (use openjanus-sdk or openjanus-elgamal for v2), asking about low-level cryptography (use openjanus-primitives), deploying to testnet/mainnet (use openjanus-deploy), or asking about BSGS or ElGamal proof generation in TypeScript (use openjanus-elgamal).
---

# JanusToken and JanusFlow Guide

JanusToken is the Solidity standard for confidential balances on Flow EVM. JanusFlow is its Cadence-native wrapper for Flow's native token.

## Two Contract Types

| Contract | Layer | Purpose |
|----------|-------|---------|
| `JanusToken.sol` | Flow EVM | Confidential ERC-20 (NATIVE or WRAPPER mode) |
| `JanusFlow.cdc` | Cadence | Native FLOW wrapper — Cross-VM Cadence→EVM orchestration |

## Navigation Map

| Task | Reference |
|------|-----------|
| JanusToken interface, events, modes | [janus-token.md](../../../../../docs/contracts/janus-token.md) |
| JanusFlow architecture, Cadence transactions | [janus-flow.md](../../../../../docs/contracts/janus-flow.md) |
| Create a custom WRAPPER instance for your ERC-20 | [creating-custom-instances.md](../../../../../docs/contracts/creating-custom-instances.md) |
| Deploy a JanusFlow-style Cadence wrapper | [deploy-janus-flow.md](../../../../../examples/deploy-janus-flow.md) |

## Core Concepts

**NATIVE mode** — JanusToken manages its own supply. Only the owner can `mintXY` / `burnXY`. Suitable for new privacy tokens with no ERC-20 heritage.

**WRAPPER mode** — JanusToken wraps an existing ERC-20. Users call `wrap(amount, commitment)` (after approving the JanusToken contract), and `unwrap` to exit. The confidential layer sits on top of the underlying token.

**Per-user commitment slot** — Every user's balance is stored as a Pedersen commitment point `(x, y)` keyed by their EVM address (in WRAPPER mode, their COA address for Cadence users).

**`confidentialTransfer`** — Core operation. Takes a ZK proof and three commitment pairs (old, transfer, new) and atomically updates sender and recipient slots. The contract verifies the proof on-chain.

## Common Pitfalls

**P1 — Forgetting `approve` before `wrap`.**
In WRAPPER mode, `wrap(amount, commit)` calls `transferFrom` on the underlying ERC-20. Caller must approve the JanusToken address first. Forgetting this causes a revert with no clear message.

**P2 — Using `mintXY` as a setter.**
`mintXY` in v1.1.0+ uses homomorphic delta arithmetic: it adds the supplied commitment to the existing slot, not replaces it. Use `burnXY` first if you need to reset.

**P3 — Wrong verifier address at deploy time.**
The verifier address is immutable after deployment. Deploying with the wrong `ConfidentialTransferVerifier` address means every `confidentialTransfer` call will revert or return false. Double-check [canonical-addresses.md](../../../../../docs/deployments/canonical-addresses.md).

## Companion Skills

- **`openjanus-sdk`** — TypeScript SDK wrapping these contracts
- **`openjanus-deploy`** — deploy a new JanusToken or JanusFlow instance
- **`openjanus-primitives`** — the cryptographic layer the contracts depend on
- **`flow-crossvm`** — Cross-VM patterns for Cadence orchestrating EVM calls
