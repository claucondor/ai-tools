# BabyJubJub Primitive — @openjanus/babyjub

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
| `SUBORDER` (`l`) | `2736030358979909402780800718157159386076813972158567259200215660948447373041` |

## Key constants (package)

```typescript
import {
  CURVE_P,
  GENERATOR_G,
  IDENTITY,
  BABYJUB_CONTRACT_ADDRESS,
  encodeBabyAdd,
  decodeBabyAddResult,
} from "@openjanus/babyjub";

// GENERATOR_G = Base8 — the prime-order subgroup generator used by circomlib
console.log(GENERATOR_G);
// { x: 5299619240641551281634865583518297030282874472190772894086521144482721001553n,
//   y: 16950150798460657717958625567821834550301663161624707787222815936182638968203n }
```

## On-chain contract (BabyJub.sol)

| Network | Address |
|---------|---------|
| Flow EVM testnet | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |

```solidity
// Twisted Edwards point addition
function babyAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2)
    public view returns (uint256 x3, uint256 y3);

// Negate: -(x, y) = (P - x, y)
function negate(uint256 x, uint256 y)
    pure returns (uint256 nx, uint256 ny);

// Curve membership check
function isOnCurve(uint256 x, uint256 y) pure returns (bool);

// Identity element
function identity() pure returns (uint256 x, uint256 y);
```

## Off-chain usage

### Local operations (no network)

```typescript
import {
  GENERATOR_G,
  IDENTITY,
  CURVE_P,
  negatePoint,
  isOnCurveLocal,
  isIdentity,
  encodeBabyAdd,
  decodeBabyAddResult,
} from "@openjanus/babyjub";

// Check if a point is on the curve
const valid = isOnCurveLocal(GENERATOR_G.x, GENERATOR_G.y); // true

// Negate a point: -(x, y) = (P - x, y)
const negG = negatePoint(GENERATOR_G.x, GENERATOR_G.y);

// Check for identity (0, 1)
const zero = isIdentity(0n, 1n); // true

// Encode calldata for cross-VM calls
const calldata = encodeBabyAdd(point1.x, point1.y, point2.x, point2.y);
```

### On-chain calls (against deployed contract)

```typescript
import {
  babyAddOnChain,
  isOnCurveOnChain,
  identityOnChain,
  negateOnChain,
  GENERATOR_G,
} from "@openjanus/babyjub";

// Add two points using the deployed contract
const g2 = await babyAddOnChain(GENERATOR_G, GENERATOR_G);

// Check on-chain
const onCurve = await isOnCurveOnChain(g2.x, g2.y); // true
```

## Cross-VM usage from Cadence

From a Cadence transaction, call `BabyJub.sol` via `EVM.call` (with state change) or `EVM.dryCall` (read-only). The `@openjanus/babyjub` package includes ABI-encoding helpers for constructing the calldata.

```cadence
// Cadence transaction — call babyAdd on BabyJub.sol for point accumulation
import EVM from 0x...

transaction(x1: UInt256, y1: UInt256, x2: UInt256, y2: UInt256) {
    prepare(signer: auth(Storage) &Account) {
        let coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        )!
        // calldata = babyAdd(x1, y1, x2, y2) ABI-encoded
        let result = coa.call(
            to: EVM.EVMAddress(bytes: <BabyJub.sol address bytes>),
            data: <ABI-encoded calldata>,
            gasLimit: 500000,
            value: EVM.Balance(attoflow: 0)
        )
        // decode result.data as (uint256, uint256)
    }
}
```

`Pedersen2GenBabyJub.cdc` (in `@openjanus/commitment`) wraps this pattern for commitment addition and subtraction.

## Why BabyJubJub?

BabyJubJub was designed by iden3 for use inside BN254 Groth16 circuits. BabyJubJub point operations cost approximately 6 constraints in a BN254 circuit — versus ~2 million constraints for BN254 native EC operations. This makes it the practical choice for ZK-provable elliptic curve arithmetic.

## Common pitfalls

**Identity is `(0, 1)`, not `(0, 0)`.** The additive identity on BabyJubJub is the point `(0, 1)`. A point of `(0, 0)` is not on the curve.

**Negate is `(-x mod P, y)`, not `(-x, -y)`.** The negation on a twisted Edwards curve negates only the x-coordinate. `negatePoint` handles this correctly.

**Scalars must be reduced mod SUBORDER.** When constructing a scalar multiplication, always take `scalar % SUBORDER` before the operation. The `@openjanus/commitment` `commit` function handles this for you.
