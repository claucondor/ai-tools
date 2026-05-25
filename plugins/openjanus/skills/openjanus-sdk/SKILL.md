---
name: openjanus-sdk
description: |
  Guide for installing and using @openjanus/sdk — the unified TypeScript SDK for OpenJanus privacy primitives on Flow. Covers package installation, FCL configuration, computing Pedersen commitments, generating Groth16 transfer proofs, reading JanusToken balances, executing JanusFlow wrap/transfer/unwrap via Cadence transactions, and creating EVM wallets for Flow EVM.
  TRIGGER when: installing @openjanus/sdk, "npm install @openjanus/sdk", importing from @openjanus/sdk, computeCommitment, buildTransferProof, generateBlinding, JanusToken class, JanusFlow class, token.connect(), sdk.configure(), sdk.wrap(), sdk.confidentialTransfer(), sdk.unwrap(), balanceOfCommitment, mintXY, confidentialTransfer, proveAndTransfer, createEvmWallet, createEvmProvider, configureFCL, JANUS_TOKEN_TESTNET, "how do I use the sdk", "how do I read a commitment", "how do I generate a proof", "wrap FLOW confidentially", "what is buildTransferProof", "@openjanus/sdk/tokens", "@openjanus/sdk/primitives", "@openjanus/sdk/crypto", "@openjanus/sdk/network".
  DO NOT TRIGGER when: asking about low-level BabyJubJub curve math (use openjanus-primitives), deploying a new JanusToken or JanusFlow instance (use openjanus-deploy), or implementing the JanusToken Solidity standard (use openjanus-tokens).
---

# @openjanus/sdk Guide

The OpenJanus SDK consolidates BabyJubJub, Pedersen, Groth16, JanusToken, and JanusFlow into one installable TypeScript package. All operations that apps need day-to-day live here.

## Quick Start

```bash
npm install @openjanus/sdk
```

```typescript
import { JanusToken, JANUS_TOKEN_TESTNET } from "@openjanus/sdk";

const token = new JanusToken(JANUS_TOKEN_TESTNET);
await token.connect();

const commit = await token.balanceOfCommitment("0xAliceAddress");
// identity (0, 1) means zero balance
```

## Navigation Map

| Task | Reference |
|------|-----------|
| Install, peer deps, exports map | [install.md](../../../../../docs/sdk/install.md) |
| Read balances, build proofs, basic transfers | [basic-transfer.md](../../../../../docs/sdk/basic-transfer.md) |
| JanusFlow wrap/transfer/unwrap (Cadence) | [advanced-usage.md](../../../../../docs/sdk/advanced-usage.md) |
| Add a new module, fork and extend | [extending-the-sdk.md](../../../../../docs/sdk/extending-the-sdk.md) |
| Circuit WASM/zkey paths, artifact locations | [../../../../../docs/gotchas/circuit-artifacts.md](../../../../../docs/gotchas/circuit-artifacts.md) |
| pi_b swap — why every proof needs it | [../../../../../docs/gotchas/pi-b-fp2-swap.md](../../../../../docs/gotchas/pi-b-fp2-swap.md) |

## Common Pitfalls

**P1 — Not calling `.connect()` before view functions.**
`JanusToken` is not connected by default. Call `await token.connect()` (read-only) or `await token.connectWithSigner(wallet)` before any method.

**P2 — Losing the blinding factor.**
`computeCommitment(amount, blinding)` returns the commitment point. The `blinding` input is never stored on-chain. If you lose it, you cannot prove ownership or unwrap. Store it in your app's persistent state immediately.

**P3 — Skipping `sdk.configure()` on JanusFlow.**
`JanusFlow` does not auto-configure FCL. Call `await sdk.configure()` once before `wrap()`, `confidentialTransfer()`, or `unwrap()`.

**P4 — Wrong WASM/zkey paths.**
`buildTransferProof` will hang or throw if the paths are wrong. See [circuit-artifacts.md](../../../../../docs/gotchas/circuit-artifacts.md) for where to find them.

## Companion Skills

- **`openjanus-primitives`** — when you need raw BabyJubJub or Pedersen operations not exposed through the SDK facade
- **`openjanus-tokens`** — when building the Solidity side (JanusToken standard, custom instances)
- **`openjanus-deploy`** — when deploying a new token instance or registering primitives
- **`flow-crossvm`** — when you need deeper Cross-VM Cadence patterns beyond what JanusFlow exposes
