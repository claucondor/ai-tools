# Cross-VM COA Pattern

This document describes how JanusFlow (and applications built on it) use the Cadence Owned Account (COA) pattern to orchestrate EVM contract calls from Cadence transactions.

## What is a COA?

A COA (Cadence Owned Account) is an EVM address that is controlled by a Cadence account. When a Cadence transaction calls `coa.call(...)` or `EVM.dryCall(...)`, the EVM sees `msg.sender` as the COA address.

This means: a user with Cadence address `0xd807a3992d7be612` has a COA at EVM address `0x00000000000000000000000250d93efba617e0bf`. Commitments in JanusToken are keyed by the COA address, so each Cadence user has exactly one EVM commitment slot.

## Checking if an account has a COA

```cadence
import EVM from 0x8c5303eaa26202d6

access(all) fun main(address: Address): String {
    if let coa = getAuthAccount<auth(Storage) &Account>(address)
            .storage
            .borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm) {
        return coa.address().toString()
    }
    return ""
}
```

Or via SDK:

```typescript
import { getCOAAddressOnChain } from "@openjanus/sdk/network";

const coaAddr = await getCOAAddressOnChain("0xd807a3992d7be612", "testnet");
// null if no COA
```

## How JanusFlow uses the COA

JanusFlow uses three EVM call patterns:

### 1. `coa.call` — state-changing EVM write

Used by `wrap()` to call `JanusToken.mintXY(userCOA, cx, cy)`:

```cadence
// Inside JanusFlow.wrap():
let callResult = self.coa.call(
    to: janusTokenEVMAddress,
    data: mintXYCalldata,
    gasLimit: 300000,
    value: EVM.Balance(attoflow: 0)
)
// Always check callResult.status == EVM.Status.successful
```

### 2. `EVM.dryCall` — read-only EVM call (no state change)

Used by `confidentialTransfer()` to call `verifyProof` without altering EVM state:

```cadence
let dryResult = EVM.dryCall(
    from: callerCOA.address(),
    to: verifierEVMAddress,
    data: verifyProofCalldata,
    gasLimit: 500000,
    value: EVM.Balance(attoflow: 0)
)
// Check dryResult.status == EVM.Status.successful
// Decode boolean return value from dryResult.data
```

`EVM.dryCall` is preferred for proof verification because it avoids `msg.sender` issues when the COA is not the transaction sender.

### 3. `EVM.dryCall` for point negation

The BabyJub `negate()` function is stateless, so it is called via `dryCall`:

```cadence
let negResult = EVM.dryCall(
    from: callerCOA.address(),
    to: babyJubEVMAddress,
    data: negateCalldata,
    gasLimit: 100000,
    value: EVM.Balance(attoflow: 0)
)
```

## Compute Unit budget

All Cadence + EVM work within a single transaction shares the 9999 CU ceiling. JanusFlow operations approach this limit:

| Operation | Approximate CU |
|-----------|---------------|
| `wrap` | ~4000-6000 |
| `confidentialTransfer` | ~7000-9000 |
| `unwrap` | ~3000-5000 |

Do not add extra EVM calls in the same transaction as `confidentialTransfer`. See [../gotchas/compute-units-limit.md](../gotchas/compute-units-limit.md).

## ABI encoding from Cadence

Cadence does not have a native ABI encoder. Calldata is constructed manually using `[UInt8]` arrays with the function selector + padded arguments:

```cadence
// Encode: mintXY(address to, uint256 cx, uint256 cy)
// selector: keccak256("mintXY(address,uint256,uint256)")[:4]
let selector: [UInt8] = [0x..., 0x..., 0x..., 0x...]
let paddedTo:  [UInt8] = // 32 bytes, zero-padded address
let paddedCx:  [UInt8] = // 32 bytes, big-endian UInt256
let paddedCy:  [UInt8] = // 32 bytes, big-endian UInt256
let calldata = selector.concat(paddedTo).concat(paddedCx).concat(paddedCy)
```

The JanusFlow Cadence contract handles this encoding internally. Applications using the SDK do not need to construct calldata manually.

## Result status check

Always check the EVM call result status before proceeding:

```cadence
if callResult.status != EVM.Status.successful {
    panic("EVM call failed")
}
```

Failing to check this is the most common Cross-VM bug. The Cadence transaction will succeed even if the EVM call fails, silently losing state.

## Further reading

- [flow-crossvm skill](https://github.com/onflow/flow-ai-tools) — Comprehensive Cross-VM guide from flow-ai-tools
- [../gotchas/flow-account-vs-coa.md](../gotchas/flow-account-vs-coa.md) — When to use Cadence address vs COA address
- [../gotchas/compute-units-limit.md](../gotchas/compute-units-limit.md) — CU budget management
