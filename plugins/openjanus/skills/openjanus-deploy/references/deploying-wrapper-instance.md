# Deploying a Wrapper Instance (v0.8)

A summary of the steps to deploy a JanusToken WRAPPER instance for an existing ERC-20 using the v0.8 contract stack. See [creating-custom-instances.md](../../../openjanus-tokens/references/creating-custom-instances.md) for the full guide.

## Constructor arguments (v0.8 — 8 args)

```javascript
// deploy-args.js — v0.8 canonical addresses
module.exports = [
  "0xD79C90b797949F0956d977989aEf82A81c860e0C",  // babyJub
  "0x38e69fE7Ba7c2C586d64DFFc14742641A675666c",  // ConfidentialTransferAggregateVerifier
  "0xf7B634D41259D0613345633eE1CD193A030A6329",  // AmountDiscloseAggregateVerifier
  "<ownerAddress>",                               // owner (COA EVM address for UUPS auth)
  "0x361bD4d037838A3a9c5408AE465d36077800ee6c",  // MemoKeyRegistry
  "0x5EdF7473b1007b4855127bC40fcc89eCDD7fB561",  // Pedersen2Gen
  "0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6",  // ShieldedInbox (or address(0) to skip)
  "0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f",  // ConfidentialClaimBatchVerifier (or address(0))
];
```

> For **JanusERC20**: add a 9th step — call `setUnderlying(yourERC20Address)` after proxy
> initialization (or wire it in `initializeERC20(...)` — see JanusERC20.sol `initialize` signature).

## Quick deploy (Hardhat)

```bash
npx hardhat deploy --network flowTestnet --constructor-args deploy-args.js
```

## Post-deploy steps

1. **Initialize fees** — call `initFees(feeRecipientAddr, 10)` (10 = 0.1%) via the proxy owner.
2. **Set underlying** (JanusERC20 only) — call `initialize(...)` with the ERC20 address during proxy setup; it is immutable after that.
3. **Verify on explorer** — [evm.flowscan.io](https://evm.flowscan.io)

## ShieldedInbox push-model warning

When `ShieldedInbox` is wired at deploy time (arg 7 above), every `shieldedTransfer` atomically deposits an encrypted note to the recipient's inbox. If the recipient's inbox is full (`MAX_INBOX_NOTES = 10000`), the `shieldedTransfer` call **reverts**. Your UI must warn recipients to drain their inbox (via `claimBatch()`) if they are heavy users.

Passing `address(0)` for the inbox arg disables inbox integration — `shieldedTransfer` will not deposit notes but will still emit `ShieldedTransferNote` events for off-chain indexers.

## Key checklist

- [ ] Confirm all 8 canonical primitive addresses from [canonical-addresses.md](canonical-addresses.md)
- [ ] `owner` must be a COA EVM address if admin calls will come from Cadence (see `flow-account-vs-coa.md`)
- [ ] Call `initFees(recipient, 10)` on the proxy before any wraps
- [ ] For JanusERC20: `approve(proxy, amount)` must be called by users before `wrapWithProof()`
- [ ] Test `wrapWithProof()` + `shieldedTransfer()` + `claimBatch()` + `unwrap()` on testnet before mainnet
- [ ] Verify the deployed proxy address at [evm.flowscan.io](https://evm.flowscan.io)
- [ ] Register the proxy address in your SDK config / env vars
