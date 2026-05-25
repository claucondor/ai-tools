---
name: openjanus-primitives
description: |
  Low-level reference for the OpenJanus cryptographic primitives: BabyJubJub elliptic curve operations, Pedersen commitments on BabyJubJub, and Groth16 proof encoding for Flow EVM. Covers on-chain callers (BabyJub.sol, PedersenBabyJub.cdc, ConfidentialTransferVerifier.sol), off-chain JavaScript utilities, curve constants, commitment packing format, and EIP-197 Fp2 coordinate swap.
  TRIGGER when: BabyJubJub curve equation, isOnCurve, babyAdd, negatePoint, BASE8, GENERATOR_G, CURVE_P, CURVE_A, CURVE_D, Pedersen commitment packing format, computeCommitment internals, addCommitmentsLocal, subCommitmentsLocal, identityCommitment, homomorphic addition, circomlibjs, groth16 verifyProof, ConfidentialTransferVerifier, pi_b Fp2 swap, applyPiBSwap, evmProofToUint256Array, snarkjs fullProve, verifyLocally, "how does the commitment scheme work", "what is the curve prime", "BabyJub on-chain", "call BabyJub.sol", "Pedersen packing", "groth16 on Flow EVM", "what is pi_b swap", "EIP-197", "which primitive should I use", "when to use ElGamal vs Pedersen".
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

## Key Facts

- **Curve**: BabyJubJub (twisted Edwards), field prime `P = 21888242871839275222246405745257275088548364400416034343698204186575808495617`
- **Commitment packing**: `24 bytes little-endian: [value_LE_8 || blinding_LE_16]`, fed to `circomlibjs Pedersen(192)` template
- **Groth16 pi_b** output from snarkJS is in `(re, im)` order; EIP-197 expects `(im, re)`. `applyPiBSwap` handles this — every proof submitted on-chain must go through it.
- **Identity point**: `(0, 1)` — represents zero balance in all commitment slots

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/overview.md` — Primitives index: which file covers what
- `references/babyjub.md` — BabyJubJub curve ops, constants, on-chain contract (BabyJub.sol), off-chain SDK usage, cross-VM usage from Cadence
- `references/pedersen.md` — Pedersen commitment packing format, homomorphic ops, WASM warm-up, on-chain Cadence contract
- `references/groth16.md` — Groth16 proof generation, public signal ordering, EIP-197 pi_b swap, on-chain verification
- `references/which-primitive.md` — Decision tree: ElGamal vs Pedersen vs raw BabyJubJub; SDK vs primitives directly
- `references/pi-b-fp2-swap.md` — The silent correctness bug: why verifyProof returns false without the coordinate swap; diagnostic + fix

## Cross-skill references (load when context indicates)

- `../openjanus-sdk/references/quickstart.md` — how these primitives are consumed in the SDK workflow
- `../openjanus-deploy/references/circuit-artifacts.md` — where to find WASM / zkey / vkey files used by Groth16

## Examples

**Check a point is on the BabyJubJub curve before using it:**
```typescript
import { isOnCurveLocal } from "@openjanus/sdk/primitives";
const valid = isOnCurveLocal(pk.x, pk.y);  // must be true before registerPubkey
```

**Compute a Pedersen commitment (v1 / primitives layer):**
```typescript
import { computeCommitment, generateBlinding } from "@openjanus/sdk/crypto";
const blinding = generateBlinding();   // 128-bit cryptographically random
const commit = await computeCommitment(10n, blinding);
// Store blinding — it cannot be recovered from commit
```

**Apply pi_b swap before on-chain submission:**
```typescript
import { applyPiBSwap } from "@openjanus/sdk/utils";
const { pA, pB, pC } = applyPiBSwap(rawSnarkProof);
// pB is now in EIP-197 (im, re) order — safe for verifyProof
```

## Common gotchas

**P1 — pi_b Fp2 swap missing.**
If you call `verifyProof` on-chain without applying `applyPiBSwap`, it returns `false` for every valid proof — silently, no revert. This is the most common ZK bug. `proveForEVM` applies it automatically; manual callers must not skip it. Full details: `references/pi-b-fp2-swap.md`.

**P2 — circomlibjs WASM cold start.**
`getPedersenHash()` and `getBabyJub()` take ~500ms on first call (WASM compilation). The SDK caches instances. In serverless environments, cold starts re-pay this cost on each invocation.

**P3 — Commitment range constraints.**
`value` must be in `[0, 2^64)` and `blinding` must be in `[0, 2^128)`. Violating these will cause the circuit witness computation to fail with an unhelpful error.

**P4 — Identity is `(0, 1)`, not `(0, 0)`.**
The additive identity on BabyJubJub is the point `(0, 1)`. A point of `(0, 0)` is not on the curve. Both commitment slots and ElGamal ciphertext slots use `(0, 1)` for "zero / empty".

**P5 — Negate on twisted Edwards is `(-x mod P, y)`, not `(-x, -y)`.**
`negatePoint` handles this correctly. Manually negating both coordinates is wrong.

## Companion Skills

- **`openjanus-sdk`** — use for high-level app development; primitives are accessed through the SDK facade
- **`openjanus-tokens`** — the Solidity and Cadence contracts that consume these primitives
- **`openjanus-elgamal`** — the ElGamal layer (built on top of BabyJubJub)
