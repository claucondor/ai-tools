# BabyJubJub Primitive

BabyJubJub is a twisted Edwards elliptic curve defined over the BN254 scalar field. It is the curve underlying Pedersen commitments and the Groth16 circuits in OpenJanus.

## Curve equation

```
A * x^2 + y^2 = 1 + D * x^2 * y^2   (mod P)
```

| Parameter | Value |
|-----------|-------|
| `P` (field prime) | `21888242871839275222246405745257275088548364400416034343698204186575808495617` |
| `A` | `168700` |
| `D` | `168696` |
| Identity | `(0, 1)` |

## Key constants (SDK)

```typescript
import {
  CURVE_P,
  CURVE_A,
  CURVE_D,
  GENERATOR_G,
  BASE8,
  BABYJUB_CONTRACT_ADDRESS,
} from "@openjanus/sdk/primitives";

// BASE8 = 8 * G — the Pedersen hash base point used by circomlibjs
console.log(BASE8);
// { x: 5299619240641551281634865583518297030282874472190772894086521144482721001553n,
//   y: 16950150798460657717958625567821834550301663161624707787222815936182638968203n }
```

## On-chain contract (BabyJub.sol)

| Network | Address |
|---------|---------|
| Flow EVM testnet (canonical) | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` |
| Flow EVM testnet (lab, stateless) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |

```solidity
// BabyJub.sol interface
function babyAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2) view returns (uint256 x3, uint256 y3);
function negate(uint256 x, uint256 y) pure returns (uint256 nx, uint256 ny);
function isOnCurve(uint256 x, uint256 y) pure returns (bool);
function identity() pure returns (uint256 x, uint256 y);
```

## Off-chain usage (SDK)

```typescript
import {
  isOnCurveLocal,
  negatePoint,
  isIdentity,
  babyAddOnChain,
} from "@openjanus/sdk/primitives";

// Check if a point is on the curve (no network)
const valid = isOnCurveLocal(x, y);

// Negate a point (no network)
const neg = negatePoint(x, y); // { x: P - x, y: y }

// Check for identity
const isZero = isIdentity(x, y); // x === 0n && y === 1n

// Add two points on-chain
const sum = await babyAddOnChain({ x: x1, y: y1 }, { x: x2, y: y2 });
```

## Cross-VM usage

From a Cadence transaction, you can call BabyJub.sol via `EVM.dryCall` (stateless). JanusFlow uses this for point negation during `confidentialTransfer`.

## Common Pitfalls

**Identity is `(0, 1)`, not `(0, 0)`.** The additive identity on BabyJubJub is the point `(0, 1)`. A commitment of `(0, 0)` is not a valid curve point.

**Negate is `(-x mod P, y)`, not `(-x, -y)`.** The negation on a twisted Edwards curve negates only the x-coordinate. `negatePoint` handles this correctly.
