---
name: openjanus-primitives
description: |
  Low-level reference for the OpenJanus cryptographic primitives: BabyJubJub elliptic curve operations, Pedersen commitments on BabyJubJub, and Groth16 proof encoding for Flow EVM. Covers on-chain callers (BabyJub.sol, PedersenBabyJub.cdc, ConfidentialTransferVerifier.sol), off-chain JavaScript utilities, curve constants, commitment packing format, and EIP-197 Fp2 coordinate swap.
  TRIGGER when: BabyJubJub curve equation, isOnCurve, babyAdd, negatePoint, BASE8, GENERATOR_G, CURVE_P, CURVE_A, CURVE_D, Pedersen commitment packing format, computeCommitment internals, addCommitmentsLocal, subCommitmentsLocal, identityCommitment, homomorphic addition, circomlibjs, groth16 verifyProof, ConfidentialTransferVerifier, pi_b Fp2 swap, applyPiBSwap, evmProofToUint256Array, snarkjs fullProve, verifyLocally, "how does the commitment scheme work", "what is the curve prime", "BabyJub on-chain", "call BabyJub.sol", "Pedersen packing", "groth16 on Flow EVM", "what is pi_b swap", "EIP-197".
  DO NOT TRIGGER when: asking how to install or use the SDK in an app (use openjanus-sdk), building a JanusToken Solidity contract (use openjanus-tokens), or deploying contracts (use openjanus-deploy).
---

# OpenJanus Primitives Guide

The OpenJanus primitive layer consists of three components: BabyJubJub curve, Pedersen commitments, and Groth16 proofs. These are the building blocks that JanusToken and JanusFlow are built on.

## The Three Primitives

| Primitive | On-chain | Off-chain |
|-----------|----------|-----------|
| BabyJubJub | `BabyJub.sol` (Flow EVM) | `@openjanus/sdk/primitives` — `isOnCurveLocal`, `negatePoint` |
| Pedersen | `PedersenBabyJub.cdc` (Cadence) | `computeCommitment`, `addCommitmentsLocal` |
| Groth16 | `ConfidentialTransferVerifier.sol` (Flow EVM) | `prove`, `proveForEVM`, `verifyLocally` |

## Navigation Map

| Task | Reference |
|------|-----------|
| BabyJubJub curve ops, constants, on-chain callers | [babyjub.md](../../../../../docs/primitives/babyjub.md) |
| Pedersen commitment packing, homomorphic ops | [pedersen.md](../../../../../docs/primitives/pedersen.md) |
| Groth16 proof generation, EIP-197 swap, verification | [groth16.md](../../../../../docs/primitives/groth16.md) |
| pi_b Fp2 swap — the silent correctness bug | [pi-b-fp2-swap.md](../../../../../docs/gotchas/pi-b-fp2-swap.md) |

## Key Facts

- **Curve**: BabyJubJub (twisted Edwards), field prime `P = 21888242871839275222246405745257275088548364400416034343698204186575808495617`
- **Commitment packing**: `24 bytes little-endian: [value_LE_8 || blinding_LE_16]`, fed to `circomlibjs Pedersen(192)` template
- **Groth16 pi_b** output from snarkJS is in `(re, im)` order; EIP-197 expects `(im, re)`. `applyPiBSwap` handles this — every proof submitted on-chain must go through it.
- **Identity point**: `(0, 1)` — represents zero balance in all commitment slots

## Common Pitfalls

**P1 — pi_b Fp2 swap missing.**
If you call `verifyProof` on-chain without applying `applyPiBSwap`, it returns `false` for every valid proof. This is silent — no revert. See [pi-b-fp2-swap.md](../../../../../docs/gotchas/pi-b-fp2-swap.md).

**P2 — circomlibjs WASM cold start.**
`getPedersenHash()` and `getBabyJub()` take ~500ms on first call (WASM compilation). The SDK caches instances. In serverless environments, cold starts re-pay this cost on each invocation.

**P3 — Commitment range constraints.**
`value` must be in `[0, 2^64)` and `blinding` must be in `[0, 2^128)`. Violating these will cause the circuit witness computation to fail with an unhelpful error.

## Companion Skills

- **`openjanus-sdk`** — use for high-level app development; primitives are usually accessed through the SDK facade
- **`openjanus-tokens`** — the Solidity contracts that consume these primitives
