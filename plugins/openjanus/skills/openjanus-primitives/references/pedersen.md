> **STATUS: deprecated.** `@openjanus/pedersen` implements the circomlib windowed Pedersen hash — a collision-resistant hash-to-point function. It is **not** the classical 2-generator commitment scheme and is **not** additively homomorphic. It has been superseded by [`@openjanus/commitment`](commitment.md) (primitives v0.2.0), which implements `Commit(v, r) = [v]·G + [r]·H` with the homomorphism property required for shielded balance accumulation. New code should use `@openjanus/commitment` instead.

---

# Pedersen Commitment Primitive (Historic — @openjanus/pedersen)

> This document is kept as a historical reference for code written against the v0.1.x stack.
> For the current implementation, see [commitment.md](commitment.md).

The original OpenJanus primitives used the circomlibjs `Pedersen(192)` template to commit to amounts. This function hashes 192 bits of packed input to a BabyJubJub point. While it acts as a commitment (each input maps to a unique point), it lacks the additive homomorphism property, which means on-chain commitment accumulation required a different approach.

## Commitment scheme (historic)

```
C = Pedersen(value, blinding)
  = hash_to_point(value_bits[0..63] || blinding_bits[0..127])
```

Computed via the circomlibjs `Pedersen(192)` template. The input is packed as 24 bytes little-endian:

```
bytes [0..7]  — value as 64-bit little-endian (uint64)
bytes [8..23] — blinding as 128-bit little-endian (uint128)
```

The result is a point on BabyJubJub: `{ x: bigint, y: bigint }`.

## Difference from @openjanus/commitment

| Property | @openjanus/pedersen (deprecated) | @openjanus/commitment (current) |
|----------|----------------------------------|---------------------------------|
| Scheme | circomlib windowed hash-to-point | 2-generator: `[v]·G + [r]·H` |
| Additively homomorphic | No | Yes |
| On-chain accumulation | Not directly supported | `addCommits(c1, c2)` |
| Status | Archived / historic | Production (v0.2.0) |

## Constraints (historic)

| Parameter | Range |
|-----------|-------|
| `value` | `[0, 2^64)` — amounts are 64-bit |
| `blinding` | `[0, 2^128)` — blinding is 128-bit random |

## On-chain contract (PedersenBabyJub.cdc — historic)

| Network | Address | Notes |
|---------|---------|-------|
| Flow Cadence testnet | `0x28fef3d1d6a12800` | Primitive only — historic, superseded by Pedersen2GenBabyJub.cdc |

The Cadence contract exposes:

```cadence
// Return the identity commitment (0, 1)
access(all) fun identity(): {String: UInt256}

// Negate a commitment point: -(x, y) = (P - x, y)
access(all) fun negate(_ point: {String: UInt256}): {String: UInt256}

// Check if a point is the identity
access(all) fun isIdentity(_ point: {String: UInt256}): Bool
```

## Off-chain SDK (historic v0.1.x)

```typescript
import {
  computeCommitment,
  addCommitmentsLocal,
  subCommitmentsLocal,
  identityCommitment,
  isIdentityCommitment,
  negateCommitment,
} from "@openjanus/pedersen";

// Compute commitment (async — requires circomlibjs WASM)
const c = await computeCommitment(10n, blinding);
```

## WASM warm-up note

The first call to `computeCommitment` took ~500ms to compile the circomlibjs WASM. This overhead is eliminated in `@openjanus/commitment`, which is pure BigInt arithmetic with no WASM dependency.

## Security note

The blinding factor is the secret. If `blinding` is zero or predictable, the commitment is trivially breakable. Always use `generateBlinding()` which returns a cryptographically random 128-bit value.

## Migration

Replace `@openjanus/pedersen` imports with `@openjanus/commitment`:

```typescript
// Before (deprecated)
import { computeCommitment, addCommitmentsLocal } from "@openjanus/pedersen";
const c = await computeCommitment(amount, blinding); // async, WASM

// After (current)
import { commit, addCommits } from "@openjanus/commitment";
const c = commit(amount, blinding); // sync, pure BigInt
```

See [commitment.md](commitment.md) for the full API reference.
