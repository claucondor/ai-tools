# Advanced SDK Usage — JanusFlow (Cadence)

JanusFlow is the Cadence-native FLOW token wrapper. Operations go through Cadence transactions that call into Flow EVM via Cross-VM (`EVM.dryCall`, COA calls). Use the `JanusFlow` SDK class to orchestrate these.

## Architecture recap

```
User's Cadence account
  └── FlowToken.Vault  ←─ locked during wrap
  └── COA (EVM address) ─→ JanusToken EVM slot (commitment stored here)
```

Each user's commitment is stored in the JanusToken EVM slot keyed by their COA address, not their Cadence address. The Cadence JanusFlow contract reads/writes this slot via Cross-VM calls.

## Setup

```typescript
import { JanusFlow } from "@openjanus/sdk/tokens";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.configure(); // configures FCL — must call before any operation
```

## Reading a commitment

```typescript
const commit = await sdk.getCommitment("0xd807a3992d7be612"); // Cadence address
// Returns { x: bigint, y: bigint }
// Identity (0, 1) means zero balance
```

## Wrapping FLOW

```typescript
import { generateBlinding } from "@openjanus/sdk/crypto";

const blinding = generateBlinding(); // 128-bit random — STORE THIS
const { txId, commitment } = await sdk.wrap(
  "10.0",    // UFix64 string — amount of FLOW to lock
  10n,       // same amount as uint64 (for commitment computation)
  blinding,
  aliceAuthz // FCL authorization function from the user's wallet
);

console.log("Wrap TX:", txId);
// Store: { commitment, blinding } — you need these to transfer or unwrap
```

The `aliceAuthz` is an FCL authorization function. In a Next.js app, this comes from `fcl.authz` after wallet connection.

## Confidential transfer (Cadence)

```typescript
const { txId, proofResult } = await sdk.confidentialTransfer(
  "0x3c601a443c81e6cd", // recipient Cadence address (Charlie)
  {
    oldBalance:       10n,
    oldBlinding:      aliceBlinding,
    transferAmount:   3n,
    transferBlinding: generateBlinding(),
    newBlinding:      generateBlinding(),
    wasmPath: WASM_PATH,
    zkeyPath: ZKEY_PATH,
  },
  aliceAuthz
);

console.log("Transfer TX:", txId);
// Update Alice's commitment to proofResult.commitments.newCommit
```

## Unwrapping FLOW

```typescript
const { txId, commitment } = await sdk.unwrap(
  "3.0",            // UFix64 string — amount to release
  3n,               // same as uint64
  charlieBlinding,  // blinding used when this commitment was created/received
  "0x3c601a443c81e6cd", // recipient Cadence address
  charlieAuthz
);

console.log("Unwrap TX:", txId);
```

## Getting the raw Cadence transaction strings

If you need to submit transactions manually (e.g., via `flow transactions send`), the transaction strings are exported:

```typescript
import {
  TX_WRAP,
  TX_CONFIDENTIAL_TRANSFER,
  TX_UNWRAP,
  SCRIPT_GET_COMMITMENT,
} from "@openjanus/sdk/tokens";
```

These are the exact Cadence strings the SDK submits. You can use them with the Flow CLI or any FCL-compatible wallet.

## Gas limit

All JanusFlow transactions use `limit: 9999` (the Cross-VM ceiling on Flow testnet). Do not lower this — the cross-VM proof verification call approaches the limit. See [compute-units-limit.md](../gotchas/compute-units-limit.md).

## COA requirement

Every user who wraps FLOW must have a COA (Cadence Owned Account). If they do not, the EVM slot write fails. Check for COA existence with:

```typescript
import { getCOAAddressOnChain } from "@openjanus/sdk/network";

const coaAddr = await getCOAAddressOnChain("0xd807a3992d7be612", "testnet");
if (!coaAddr) {
  // User needs to create a COA — see docs/gotchas/flow-account-vs-coa.md
}
```

## Next steps

- [extending-the-sdk.md](extending-the-sdk.md) — Add a custom module
- [../patterns/cross-vm-coa-pattern.md](../patterns/cross-vm-coa-pattern.md) — Deep-dive on COA orchestration
- [../gotchas/flow-account-vs-coa.md](../gotchas/flow-account-vs-coa.md) — Account vs COA gotcha
- [../gotchas/compute-units-limit.md](../gotchas/compute-units-limit.md) — CU ceiling and how to stay under it
