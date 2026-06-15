# Primitives Overview

Low-level cryptographic building blocks for OpenJanus. Six packages, organized by production status.

## Package status table

| Package | Role | Status | Used by v0.8.2 stack |
|---------|------|--------|----------------------|
| `@openjanus/commitment` | 2-gen Pedersen commitment on BabyJubJub — additively homomorphic accumulators | **production** | Yes — core amount-privacy primitive |
| `@openjanus/babyjub` | BabyJubJub curve ops, TypeScript + `BabyJub.sol` on-chain | **production** | Yes — underlying curve for all ZK ops |
| `@openjanus/groth16` | Groth16 verifier helpers, pi_b swap, proof encoding | **production** | Yes — proof verification |
| `@openjanus/pedersen` | circomlib windowed Pedersen hash-to-point | **archived / historic** | No — superseded by commitment |
| `@openjanus/elgamal` | ElGamal-on-BabyJub encrypted state | **experimental / lab** | No — not used in v0.8.2 |
| `@openjanus/utxo` | UTXO note scaffold | **experimental** | No — deferred to v2+ |

## What each package does

### @openjanus/commitment (production)

Implements the classical Pedersen commitment scheme: `Commit(v, r) = [v]·G + [r]·H` where G and H are independent generators on BabyJubJub. The key property is additive homomorphism — commitments can be summed on-chain without revealing the underlying amounts. This is the entry point for all amount-privacy work.

Ships three artifacts:
- `src/` — TypeScript: `commit`, `addCommits`, `subCommits`, `isIdentity`, curve constants
- `contracts/Pedersen2Gen.sol` — stateless EVM accumulator (~34k gas for `addCommits`)
- `cadence/Pedersen2GenBabyJub.cdc` — Cadence wrapper that delegates point ops to `BabyJub.sol` via cross-VM call

See [commitment.md](commitment.md) for the full API reference.

### @openjanus/babyjub (production)

BabyJubJub twisted Edwards curve over the BN254 scalar field. Provides:
- TypeScript: local operations (`isOnCurveLocal`, `negatePoint`, `isIdentity`, `encodeBabyAdd`)
- On-chain: `BabyJub.sol` with `babyAdd`, `negate`, `isOnCurve`, `identity`
- Cross-VM helpers: calldata encoders for calling `BabyJub.sol` from Cadence transactions

This package is the curve foundation. `@openjanus/commitment` builds on it; `@openjanus/groth16` circuits use BabyJubJub internally.

See [babyjub.md](babyjub.md).

### @openjanus/groth16 (production)

Groth16 proof generation and EVM verification helpers. Covers:
- `prove`, `proveForEVM` — off-chain proof generation via snarkJS
- `applyPiBSwap` — EIP-197 coordinate swap (pi_b Fp2 order flip)
- `evmProofToUint256Array` — calldata encoding for on-chain submission
- Deployed verifier contracts: `AmountDiscloseVerifier.sol`, `ConfidentialTransferVerifier.sol`

See [groth16.md](groth16.md) and [pi-b-fp2-swap.md](pi-b-fp2-swap.md).

### @openjanus/pedersen (archived / historic)

The original OpenJanus commitment primitive, based on the circomlib `Pedersen(192)` windowed hash-to-point function. **Not** additively homomorphic. Superseded by `@openjanus/commitment` in primitives v0.2.0. Maintained for historical reference only; no new code should use this package.

See [pedersen.md](pedersen.md).

### @openjanus/elgamal (experimental / lab)

ElGamal encryption on BabyJubJub — encrypts a curve point under a recipient's BabyJubJub public key using a random ephemeral scalar. Supports re-randomization and homomorphic operations on ciphertexts. Not used in the v0.8.2 production stack; present for research and potential future memo-encryption or encrypted-state use cases.

See `openjanus-elgamal` skill for details.

### @openjanus/utxo (experimental / deferred)

UTXO note scaffold for a potential UTXO-model privacy scheme (analogous to Zcash shielded notes). Architecture is defined but not integrated into the production stack. Deferred to v2+ pending product validation of UTXO over the simpler aggregated-commitment model.

## Where to start

If you want to:
- **Hide token amounts** → start with [commitment.md](commitment.md)
- **Understand the curve** → start with [babyjub.md](babyjub.md)
- **Understand proof verification** → start with [groth16.md](groth16.md)
- **Choose the right package** → see [which-primitive.md](which-primitive.md)

## Reference files

| File | Contents |
|------|----------|
| [commitment.md](commitment.md) | `@openjanus/commitment` API, generators G and H, homomorphism, on-chain contracts |
| [babyjub.md](babyjub.md) | BabyJubJub curve constants, TypeScript ops, `BabyJub.sol` interface |
| [groth16.md](groth16.md) | Groth16 circuit description, public signal ordering, proof generation |
| [pi-b-fp2-swap.md](pi-b-fp2-swap.md) | The silent pi_b Fp2 swap bug — diagnosis and fix |
| [which-primitive.md](which-primitive.md) | Decision tree: which package for which task |
| [pedersen.md](pedersen.md) | Historic reference for `@openjanus/pedersen` (deprecated) |
