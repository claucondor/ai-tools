# Compute Units Limit — 9999 CU Ceiling

## What is the CU ceiling?

All Cadence computation (including any EVM calls made from Cadence) in a single transaction shares a compute unit (CU) budget. On Flow testnet, this ceiling is 9999 CU.

JanusFlow's `confidentialTransfer` transaction approaches this limit because the Cross-VM proof verification call (`EVM.dryCall` to `ConfidentialTransferVerifier`) is expensive.

## JanusFlow CU consumption (approximate)

| Operation | CU range |
|-----------|----------|
| `wrap` | 4000-6000 |
| `confidentialTransfer` | 7000-9000 |
| `unwrap` | 3000-5000 |

These are estimates. Actual consumption depends on the network state and contract version. Always use `limit: 9999` for all JanusFlow transactions.

## Rules

1. **Set `limit: 9999`** on all JanusFlow FCL transactions. Lower limits will cause the transaction to fail with `computation exceeds limit`.

2. **Do not add extra EVM calls** in the same transaction as `confidentialTransfer`. Each `EVM.dryCall` consumes additional CU.

3. **Batch separate from proof verification.** If you need to do administrative work alongside a transfer, put it in a separate transaction.

## What happens when the limit is exceeded?

The Cadence transaction fails and is reverted. No state changes occur. The user pays the computation fee up to the limit, but the transfer does not happen.

## Mainnet

The CU ceiling on mainnet may differ from testnet. Check the current Flow documentation for the latest mainnet ceiling before deploying.

## Diagnostic

If a JanusFlow transaction fails with an error like:

```
computation exceeds limit [9999]
```

The CU budget was exceeded. Check if `limit` is set to 9999 in the FCL mutate call, and ensure no extra EVM calls were added to the transaction.

```typescript
await fcl.mutate({
  cadence: TX_CONFIDENTIAL_TRANSFER,
  args: [...],
  proposer: authz,
  payer: authz,
  authorizations: [authz],
  limit: 9999,  // must be exactly this
});
```

## Reference

- [flow-crossvm skill](https://github.com/onflow/flow-ai-tools) — `flow-crossvm` skill covers the 9999 CU ceiling in detail for general Cross-VM development
- [../../../openjanus-sdk/references/cross-vm-coa-pattern.md](../../../openjanus-sdk/references/cross-vm-coa-pattern.md) — CU breakdown per operation type
