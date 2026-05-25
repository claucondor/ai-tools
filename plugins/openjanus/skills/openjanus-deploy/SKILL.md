---
name: openjanus-deploy
description: |
  Deployment guide for OpenJanus contracts — JanusToken WRAPPER instances for custom ERC-20s, JanusFlow-style Cadence wrappers, and primitive contracts (BabyJub.sol, ConfidentialTransferVerifier). Covers constructor arguments, deployment order, flow.json registration, canonical addresses, verification steps, and common deployment failures.
  TRIGGER when: "deploy JanusToken", "deploy JanusFlow", "deploy BabyJub.sol", "deploy verifier", "create a new wrapper instance", "constructor arguments JanusToken", "deploy to testnet", "deploy to mainnet", "flow.json openjanus", "register Cadence contract", "deploy ConfidentialTransferVerifier", "what addresses do I pass at deploy", "deployment order", "hardhat deploy openjanus", "foundry deploy openjanus", "verify contract openjanus".
  DO NOT TRIGGER when: calling already-deployed contracts via the SDK (use openjanus-sdk), implementing new contract logic (use openjanus-tokens), or asking about proof generation (use openjanus-primitives).
---

# OpenJanus Deployment Guide

Deploying the OpenJanus stack follows a strict dependency order — primitives first, then the verifier, then the token contract.

## Deployment Order

```
1. BabyJub.sol              (stateless — deploy once, reuse address)
2. ConfidentialTransferVerifier.sol  (circuit-specific — must match your .zkey)
3. JanusToken.sol           (NATIVE or WRAPPER mode)
4. JanusFlow.cdc            (Cadence — only for FLOW token wrappers)
```

## Navigation Map

| Task | Reference |
|------|-----------|
| Deploy a WRAPPER instance step-by-step | [deploy-janus-flow.md](../../../../../examples/deploy-janus-flow.md) |
| Canonical testnet/mainnet addresses | [canonical-addresses.md](../../../../../docs/deployments/canonical-addresses.md) |
| JanusToken constructor args | [janus-token.md](../../../../../docs/contracts/janus-token.md) |
| Flow.json registration for Cadence | [janus-flow.md](../../../../../docs/contracts/janus-flow.md) |
| COA setup for Cadence cross-VM deploys | [cross-vm-coa-pattern.md](../../../../../docs/patterns/cross-vm-coa-pattern.md) |

## Common Pitfalls

**P1 — Mismatched verifier and zkey.**
`ConfidentialTransferVerifier.sol` is generated from a specific `.zkey` file. If you regenerate the circuit (new trusted setup), you must also redeploy the verifier. The canonical testnet verifier matches the circuit artifacts in `cadence-crypto-lab`.

**P2 — Missing `approve` at wrap time (WRAPPER mode).**
This is not a deployment issue, but it is discovered at first use. Before deploying to production, test the wrap flow end-to-end on testnet with a real approval call.

**P3 — Deploying JanusFlow without a COA on the Cadence account.**
JanusFlow stores commitments in EVM slots keyed by the user's COA address. If a user's Cadence account has no COA, `getCommitment` returns the identity point even if they have a balance.

**P4 — Wrong `underlying` address in WRAPPER mode.**
The `underlying` ERC-20 address is immutable. Passing address zero or the wrong token will lock the contract permanently in a broken state.

## Companion Skills

- **`openjanus-tokens`** — understand what you are deploying
- **`openjanus-sdk`** — TypeScript SDK to interact with the deployed contracts
- **`flow-crossvm`** — Cross-VM Cadence patterns for Cadence-hosted deployments
