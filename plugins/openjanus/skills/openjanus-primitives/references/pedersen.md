# Pedersen Commitment Primitive

OpenJanus uses Pedersen commitments on BabyJubJub to hide token amounts while preserving homomorphic properties.

## Commitment scheme

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

## Constraints

| Parameter | Range |
|-----------|-------|
| `value` | `[0, 2^64)` — amounts are 64-bit |
| `blinding` | `[0, 2^128)` — blinding is 128-bit random |

## On-chain contract (PedersenBabyJub.cdc)

| Network | Address | Notes |
|---------|---------|-------|
| Flow Cadence testnet | `0x28fef3d1d6a12800` | Primitive only — NOT JanusFlow (JanusFlow is at `0xbef3c77681c15397`) |

The Cadence contract exposes:

```cadence
// Return the identity commitment (0, 1)
access(all) fun identity(): {String: UInt256}

// Negate a commitment point: -(x, y) = (P - x, y)
access(all) fun negate(_ point: {String: UInt256}): {String: UInt256}

// Check if a point is the identity
access(all) fun isIdentity(_ point: {String: UInt256}): Bool
```

## Off-chain usage (SDK)

```typescript
import {
  computeCommitment,
  addCommitmentsLocal,
  subCommitmentsLocal,
  identityCommitment,
  isIdentityCommitment,
  negateCommitment,
} from "@openjanus/sdk/primitives";

// Compute commitment (async — requires circomlibjs WASM)
const c = await computeCommitment(10n, blinding);

// Homomorphic addition (local, no network)
const sum = await addCommitmentsLocal(c1, c2);

// Subtraction (local, no network)
const diff = await subCommitmentsLocal(c1, c2);

// Identity and negation
const zero = identityCommitment(); // { x: 0n, y: 1n }
const isZero = isIdentityCommitment(c);
const neg = negateCommitment(c);
```

## Homomorphic property

```
addCommitmentsLocal(Pedersen(a, r1), Pedersen(b, r2)) = Pedersen(a+b, r1+r2)
```

This means: if Alice has commitment `C_a` and Bob has `C_b`, the sum commitment `C_a + C_b` commits to `a + b` with blinding `r1 + r2`. JanusToken uses this for `totalSupplyCommitment()`.

## WASM warm-up

The first call to `computeCommitment` takes ~500ms to compile the circomlibjs WASM. Subsequent calls are fast (~1ms). Cache the `getPedersenHash()` and `getBabyJub()` instances if you call this in a hot path.

## Security note

The blinding factor is the secret. If `blinding` is zero or predictable, the commitment is trivially breakable. Always use `generateBlinding()` which returns a cryptographically random 128-bit value.
