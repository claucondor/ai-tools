# Deploying a Wrapper Instance

A summary of the steps to deploy a JanusToken WRAPPER instance for an existing ERC-20. See [../contracts/creating-custom-instances.md](../contracts/creating-custom-instances.md) for the full guide, and [../../examples/deploy-janus-flow.md](../../examples/deploy-janus-flow.md) for a step-by-step walkthrough with actual commands.

## Quick reference

```bash
# Using Hardhat
npx hardhat deploy --network flowTestnet --constructor-args args.js

# args.js:
module.exports = [
  "0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5", // verifier
  "0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07", // BabyJub
  true,        // wrapperMode
  "0xYourERC20"
];
```

## Key checklist

- [ ] Confirm canonical verifier and BabyJub addresses from [../deployments/canonical-addresses.md](../deployments/canonical-addresses.md)
- [ ] Set `wrapperMode = true` and `underlying = <your ERC-20 address>`
- [ ] Test `wrap()` + `confidentialTransfer()` + `unwrap()` on testnet before mainnet
- [ ] Verify the deployed contract at [flowscan.io](https://flowscan.io) or [evm.flowscan.io](https://evm.flowscan.io)
- [ ] Register the address in your SDK config
