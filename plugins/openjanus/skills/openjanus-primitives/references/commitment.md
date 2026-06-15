# @openjanus/commitment

2-generator Pedersen commitment on BabyJubJub. The production amount-privacy primitive as of primitives v0.2.0.

## What it does

Implements the classical Pedersen commitment scheme:

```
Commit(v, r) := [v]·G + [r]·H
```

where:
- `G` = BabyJubJub prime-order subgroup generator (Base8, circomlib-compatible)
- `H` = NUMS second generator (SHA-256 hash-to-scalar — see Generator H below)
- `v` = value to commit (token amount; fits in 128 bits for practical use)
- `r` = blinding factor (cryptographically random scalar in `[1, SUBORDER)`)

### Properties

| Property | Value |
|----------|-------|
| **Computationally binding** | Finding `(v', r') ≠ (v, r)` with the same commitment requires solving ECDLP |
| **Perfectly hiding** | Every curve point is equally likely as a commitment for any value (with uniform `r`) |
| **Additively homomorphic** | `Commit(v1, r1) + Commit(v2, r2) = Commit(v1+v2, r1+r2)` |

The homomorphism is the core property: after N incoming transfer commitments, the on-chain accumulator equals `Commit(Σv_i mod l, Σr_i mod l)`. The prover reconstructs the accumulated opening from running sums `(Σv_i, Σr_i mod l)`.

## Curve constants

| Constant | Value |
|----------|-------|
| `P` (field prime) | `21888242871839275222246405745257275088548364400416034343698204186575808495617` |
| `A` | `168700` |
| `D` | `168696` |
| `SUBORDER` (`l`) | `2736030358979909402780800718157159386076813972158567259200215660948447373041` |
| `IDENTITY` | `[0n, 1n]` |

## Generator G (Base8)

```
GX = 5299619240641551281634865583518297030282874472190772894086521144482721001553
GY = 16950150798460657717958625567821834550301663161624707787222815936182638968203
```

G = Base8 is the circomlib-standard prime-order subgroup generator of BabyJubJub, used in all circomlib Pedersen circuits. It is in the prime-order subgroup by construction.

## Generator H (NUMS — nothing up my sleeve)

H is derived so that the discrete log `log_G(H)` is not known to anyone, including the authors.

**Derivation procedure:**
```
H_SEED_HASH = dab770fa437522466cc77e342af81afeeea9cf70e63ad98b83463b5819288b13
              (32 bytes, the SHA-256 hash of a domain-separation string)

H_SCALAR    = BigEndian(H_SEED_HASH bytes) mod SUBORDER
            = 431220823411395456446588864425906976884578672973864058140779376804016099631

H           = H_SCALAR · G
HX          = 20176122646359037043957983780698997220241005801156909477756461731029015465513
HY          = 12675495183377259114213499882541802147068931119123218019653136042509354750865
```

To verify independently: apply SHA-256 to the domain-separation string, decode as a big-endian integer, reduce mod `l`, multiply by `G` on BabyJubJub. The `deriveH()` export performs this re-derivation and asserts the result matches the hardcoded constants.

This approach follows Zcash §5.4.9.7 (BLAKE2s-based NUMS) and Bulletproofs §4.1.

## TypeScript API

```typescript
import {
  commit,
  addCommits,
  subCommits,
  negateCommit,
  isIdentity,
  pointsEqual,
  isOnCurve,
  verifyHomomorphism,
  deriveH,
  SUBORDER,
  P,
  GX, GY,
  HX, HY,
  H_SEED_HASH,
  H_SCALAR,
  IDENTITY,
  pointAdd,
  pointMul,
} from "@openjanus/commitment";
import type { Point } from "@openjanus/commitment";
```

### Core commitment operations

```typescript
// Commit to a value with a blinding factor
const C: Point = commit(1000n, randomBlinding);
// C = [1000]·G + [randomBlinding]·H

// Homomorphic addition
const C1 = commit(400n, r1);
const C2 = commit(600n, r2);
const sum = addCommits(C1, C2);
// sum == commit(1000n, (r1 + r2) % SUBORDER)

// Homomorphic subtraction
const diff = subCommits(C1, C2);
// diff == commit(400n - 600n mod l, r1 - r2 mod l)

// Negate a commitment
const negC = negateCommit(C);
// In twisted Edwards: -(x, y) = (P - x, y)

// Check for identity (zero commitment)
const isZero = isIdentity(commit(0n, 0n)); // true

// Structural equality
const equal = pointsEqual(sum, commit(1000n, (r1 + r2) % SUBORDER));

// Curve membership check (validate received points)
const valid = isOnCurve(C.x, C.y); // always true for output of commit()

// Self-test the homomorphism property (throws on failure)
verifyHomomorphism(); // returns true
```

### Full API table

| Export | Signature | Description |
|--------|-----------|-------------|
| `commit` | `(v: bigint, r: bigint) → Point` | Compute `[v]·G + [r]·H` |
| `addCommits` | `(p1: Point, p2: Point) → Point` | Homomorphic addition |
| `subCommits` | `(p1: Point, p2: Point) → Point` | Homomorphic subtraction |
| `negateCommit` | `(p: Point) → Point` | Negate — twisted Edwards `(-x mod P, y)` |
| `isIdentity` | `(p: Point) → boolean` | True if point is `(0, 1)` |
| `pointsEqual` | `(p1: Point, p2: Point) → boolean` | Structural equality |
| `isOnCurve` | `(x, y: bigint) → boolean` | Curve membership check |
| `verifyHomomorphism` | `() → boolean` | Self-test, throws on failure |
| `deriveH` | `() → { hx, hy, scalar }` | Re-derive H from seed hash |
| `pointAdd` | low-level | Twisted Edwards point addition |
| `pointMul` | low-level | Scalar multiplication |
| `GX, GY` | `bigint` | Generator G coordinates |
| `HX, HY` | `bigint` | Generator H coordinates |
| `H_SEED_HASH` | `string` (hex) | SHA-256 seed used for H derivation |
| `H_SCALAR` | `bigint` | Scalar: `H_SEED_HASH mod l` |
| `SUBORDER` | `bigint` | Prime-order subgroup order `l` |
| `P` | `bigint` | BN254 base field prime |
| `IDENTITY` | `[bigint, bigint]` | Identity element `[0n, 1n]` |
| `Point` | type | `{ x: bigint; y: bigint }` |

## On-chain: Pedersen2Gen.sol (Solidity)

Stateless EVM contract. Shares the same G and H constants as the TypeScript package.

```solidity
// Low-gas accumulation path (~34k gas via modexp precompile)
function addCommits(uint256 x1, uint256 y1, uint256 x2, uint256 y2)
    external view returns (uint256 rx, uint256 ry);

// Cross-verification / testing only (expensive — full scalar mul on-chain)
function commit(uint256 v, uint256 r)
    external view returns (uint256 cx, uint256 cy);

// Compute: -(x, y) = (P - x, y)
function negateCommit(uint256 x, uint256 y)
    pure external returns (uint256 nx, uint256 ny);
```

In production, `commit(v, r)` is computed off-chain and only `addCommits` is called on-chain for accumulator updates.

## On-chain: Pedersen2GenBabyJub.cdc (Cadence)

Flow Cadence contract that delegates point arithmetic to `BabyJub.sol` via the cross-VM call pattern.

```cadence
import Pedersen2GenBabyJub from 0x<address>

// Homomorphic addition (delegates babyAdd to BabyJub.sol via EVM.call)
let newCommit = Pedersen2GenBabyJub.addCommits(
    c1: { "x": oldCommit.x, "y": oldCommit.y },
    c2: { "x": transferCommit.x, "y": transferCommit.y },
    coa: coa
)

// Subtraction (negate is pure Cadence, then addCommits)
let diff = Pedersen2GenBabyJub.subCommits(c1: ..., c2: ..., coa: coa)

// Pure Cadence helpers (no EVM call)
let neg = Pedersen2GenBabyJub.negate(c)
let isZero = Pedersen2GenBabyJub.isIdentity(c)
let id = Pedersen2GenBabyJub.identity()
```

Approximate CU budget: `addCommits` ~16 CU + EVM (~34k gas); `subCommits` ~21 CU; `negate` ~5 CU. All well within the 9,999 CU Cadence transaction limit.

## Security notes

- **Blinding factor `r`** must be a cryptographically random scalar in `[1, SUBORDER)`. Never zero — `Commit(v, 0) = [v]·G` reveals the value structure.
- **Do not reuse blinding factors.** Reusing `r` across two commitments can leak the difference of the values.
- Scalars must be reduced mod `SUBORDER` before use. The `commit` function handles this internally.
- This package is **EXPERIMENTAL — not audited**. Do not use with real funds before an independent security audit.

## Accumulation pattern (shielded balance)

```typescript
import { commit, addCommits, SUBORDER } from "@openjanus/commitment";

// Events arriving at the contract
const events = [
  { v: 400n, r: randomScalar1 },
  { v: 500n, r: randomScalar2 },
  { v: 100n, r: randomScalar3 },
];

// Off-chain: each sender computes their commitment
const commitments = events.map(({ v, r }) => commit(v, r));

// On-chain (Pedersen2Gen.sol): accumulator adds each incoming commitment
// This can also be done off-chain for simulation:
const accumulated = commitments.reduce(addCommits, commit(0n, 0n));

// accumulated == commit(1000n, (r1 + r2 + r3) % SUBORDER)
// The prover can satisfy the corresponding Groth16 circuit by knowing (1000n, sumR)
```

## Relationship to Groth16 circuit

The Groth16 `ConfidentialTransfer` circuit proves that a proposed balance update is consistent with the commitment scheme:

```
Public:  C_old, C_tx, C_new  (commitment points — on-chain)
Private: old_v, old_r, tx_v, tx_r, new_r

Constraints:
  C_old = Commit(old_v, old_r)
  C_tx  = Commit(tx_v,  tx_r)
  C_new = Commit(old_v - tx_v, new_r)   // conservation of value
  old_v >= tx_v                          // no overdraft
```

The circuit uses the same G and H constants. See [groth16.md](groth16.md) for proof generation details.
