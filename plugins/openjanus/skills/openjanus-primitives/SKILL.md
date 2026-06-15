---
name: openjanus-primitives
description: |
  Low-level reference for the OpenJanus cryptographic primitive packages (primitives v0.2.0):
  @openjanus/commitment (2-generator Pedersen commitment on BabyJubJub — default entry for amount-privacy),
  @openjanus/babyjub (BabyJubJub curve ops, BabyJub.sol on-chain),
  @openjanus/groth16 (Groth16 verifier helpers, proof encoding),
  @openjanus/pedersen (DEPRECATED — replaced by commitment),
  @openjanus/elgamal (ElGamal-on-BabyJub, lab/historic — not used in v0.8.2 stack),
  @openjanus/utxo (UTXO scaffold, deferred to v2+).

  Covers: commit/addCommits/subCommits/isIdentity homomorphism, generators G and H (NUMS derivation), Pedersen2Gen.sol on-chain accumulator, Pedersen2GenBabyJub.cdc cross-VM contract, BabyJubJub curve equation and constants, BabyJub.sol interface (babyAdd/negate/isOnCurve/identity), Groth16 proof encoding, EIP-197 Fp2 coordinate swap, applyPiBSwap, evmProofToUint256Array, ConfidentialTransferVerifier, public signal ordering, pi_b swap bug.

  TRIGGER when: BabyJubJub curve equation, isOnCurve, babyAdd, negatePoint, BASE8, GENERATOR_G, CURVE_P, CURVE_A, CURVE_D, commitment scheme, commit(v, r), addCommits, subCommits, negateCommit, isIdentity, additive homomorphism, generators G and H, NUMS generator, H derivation, Pedersen2Gen.sol, Pedersen2GenBabyJub.cdc, @openjanus/commitment, @openjanus/babyjub, @openjanus/groth16, @openjanus/pedersen deprecated, groth16 verifyProof, ConfidentialTransferVerifier, pi_b Fp2 swap, applyPiBSwap, evmProofToUint256Array, snarkjs fullProve, verifyLocally, "how does the commitment scheme work", "what is the curve prime", "BabyJub on-chain", "Pedersen commitment", "homomorphic addition", "which primitive should I use", "when to use ElGamal vs commitment", "what replaced pedersen", "commitment vs pedersen", "SUBORDER", "EIP-197".
  DO NOT TRIGGER when: asking how to install or use the SDK in an app (use openjanus-sdk), building a JanusToken Solidity contract (use openjanus-tokens), or deploying contracts (use openjanus-deploy).
---

# OpenJanus Primitives Guide

The OpenJanus primitive layer (v0.2.0) ships six packages. Three are production-active in the v0.8.2 stack; three are archived, experimental, or deferred.

## Package inventory

| Package | Status | Role |
|---------|--------|------|
| `@openjanus/commitment` | **production** | Amount-privacy default — 2-gen Pedersen `[v]·G+[r]·H`, homomorphic |
| `@openjanus/babyjub` | **production** | BabyJubJub curve ops, `BabyJub.sol` on-chain |
| `@openjanus/groth16` | **production** | Groth16 proof encoding, pi_b swap, on-chain verifier helpers |
| `@openjanus/pedersen` | **deprecated** | circomlib windowed hash — not homomorphic → migrate to commitment |
| `@openjanus/elgamal` | experimental / lab | ElGamal-on-BabyJub — not used in v0.8.2 |
| `@openjanus/utxo` | experimental | UTXO scaffold — deferred to v2+ |

## Key facts

- **Curve**: BabyJubJub (twisted Edwards), field prime `P = 21888242871839275222246405745257275088548364400416034343698204186575808495617`
- **Commitment scheme**: `Commit(v, r) = [v]·G + [r]·H` — additively homomorphic, perfectly hiding
- **Generators**: G = Base8 (circomlib-compatible); H = NUMS via SHA-256 hash-to-scalar derivation
- **Groth16 pi_b**: snarkJS outputs `(re, im)` order; EIP-197 expects `(im, re)`. `applyPiBSwap` handles this — every proof submitted on-chain must go through it.
- **Identity point**: `(0, 1)` — represents zero balance in all commitment slots

## Default path for amount-privacy

```typescript
import { commit, addCommits, isIdentity, SUBORDER } from "@openjanus/commitment";

// Compute a commitment off-chain
const C = commit(1000n, randomBlinding);   // C = [1000]·G + [blinding]·H

// Homomorphic accumulation (matches on-chain Pedersen2Gen.sol behavior)
const accumulated = addCommits(C1, C2);   // = Commit(v1+v2, r1+r2)
```

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/overview.md` — All 6 packages: role, status, when to use each
- `references/commitment.md` — `@openjanus/commitment` API, generators, homomorphism, on-chain contracts
- `references/babyjub.md` — BabyJubJub curve ops, constants, BabyJub.sol, cross-VM usage
- `references/groth16.md` — Groth16 proof generation, public signal ordering, EIP-197 pi_b swap
- `references/which-primitive.md` — Decision tree: which package for which task
- `references/pi-b-fp2-swap.md` — The silent correctness bug: why verifyProof returns false without the coordinate swap
- `references/pedersen.md` — Historic reference for `@openjanus/pedersen` (deprecated, replaced by commitment)

## Cross-skill references (load when context indicates)

- `../openjanus-sdk/references/quickstart.md` — how these primitives are consumed in the SDK workflow
- `../openjanus-deploy/references/circuit-artifacts.md` — where to find WASM / zkey / vkey files used by Groth16

## Common gotchas

**P1 — pi_b Fp2 swap missing.**
If you call `verifyProof` on-chain without applying `applyPiBSwap`, it returns `false` for every valid proof — silently, no revert. This is the most common ZK bug. `proveForEVM` applies it automatically; manual callers must not skip it. Full details: `references/pi-b-fp2-swap.md`.

**P2 — commit vs pedersen.**
`@openjanus/commitment` uses the classical 2-generator scheme `[v]·G + [r]·H` and IS homomorphic. `@openjanus/pedersen` uses the circomlib windowed hash-to-point and is NOT homomorphic. Always use `@openjanus/commitment` for shielded balance accumulation.

**P3 — Identity is `(0, 1)`, not `(0, 0)`.**
The additive identity on BabyJubJub is the point `(0, 1)`. A point of `(0, 0)` is not on the curve.

**P4 — Negate on twisted Edwards is `(-x mod P, y)`, not `(-x, -y)`.**
`negateCommit` and `negatePoint` handle this correctly. Manually negating both coordinates is wrong.

**P5 — Do not reuse blinding factors.**
Reusing the same blinding `r` across two commitments can leak the value difference. Always generate a fresh cryptographically random scalar for each commitment.

## Companion skills

- **`openjanus-sdk`** — use for high-level app development; primitives are accessed through the SDK facade
- **`openjanus-tokens`** — the Solidity and Cadence contracts that consume these primitives
- **`openjanus-elgamal`** — the ElGamal layer (built on top of BabyJubJub, lab/historic)
