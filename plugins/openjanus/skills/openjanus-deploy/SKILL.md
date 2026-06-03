---
name: openjanus-deploy
description: |
  Deployment guide for OpenJanus contracts — JanusToken WRAPPER instances for custom ERC-20s, JanusFlow-style Cadence wrappers, and primitive contracts (BabyJub.sol, ConfidentialTransferVerifier, EncryptConsistencyVerifier, DecryptOpenVerifier). Covers constructor arguments, deployment order, flow.json registration, canonical addresses, circuit artifact locations, COA setup, and common deployment failures.
  TRIGGER when: "deploy JanusToken", "deploy JanusFlow", "deploy BabyJub.sol", "deploy verifier", "create a new wrapper instance", "constructor arguments JanusToken", "deploy to testnet", "deploy to mainnet", "flow.json openjanus", "register Cadence contract", "deploy ConfidentialTransferVerifier", "what addresses do I pass at deploy", "deployment order", "hardhat deploy openjanus", "foundry deploy openjanus", "verify contract openjanus", "canonical addresses", "testnet addresses", "circuit artifacts", "WASM path", "zkey path", "compute units limit", "9999 CU", "flow account vs COA", "COA address".
  DO NOT TRIGGER when: calling already-deployed contracts via the SDK (use openjanus-sdk), implementing new contract logic (use openjanus-tokens), or asking about proof generation algorithms (use openjanus-primitives).
---

# OpenJanus Deployment Guide

Deploying the OpenJanus stack follows a strict dependency order — primitives first, then the verifier, then the token contract.

## Deployment Order

```
1. BabyJub.sol              (stateless — deploy once, reuse address)
2. EncryptConsistencyVerifier.sol  (circuit-specific, matches your .zkey)
3. DecryptOpenVerifier.sol         (circuit-specific, matches your .zkey)
4. JanusToken.sol         (references verifiers in constructor)
5. JanusFlow.cdc          (Cadence — only for FLOW token wrappers)
```

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/canonical-addresses.md` — All deployed OpenJanus contracts on Flow testnet: primitives, token contracts, network endpoints, chain IDs, known COA mappings, SDK constants
- `references/deploying-wrapper-instance.md` — Quick reference for deploying a JanusToken WRAPPER for an existing ERC-20
- `references/circuit-artifacts.md` — WASM, zkey, and vkey file locations; serving artifacts in browser apps; CDN hosting; verifying artifact integrity
- `references/compute-units-limit.md` — 9999 CU ceiling on Flow: per-operation estimates, rules for avoiding budget overrun, diagnostic for "computation exceeds limit" error
- `references/flow-account-vs-coa.md` — Two address spaces on Flow: when to use Cadence address vs COA (EVM) address, looking up a COA, handling accounts with no COA

## Cross-skill references (load when context indicates)

- `../openjanus-tokens/references/creating-custom-instances.md` — Full guide: WRAPPER vs NATIVE mode, constructor args, SDK registration
- `../openjanus-tokens/references/janus-token.md` — What you are deploying: JanusToken interface
- `../openjanus-sdk/references/cross-vm-coa-pattern.md` — COA internals for Cadence-hosted deploys

## Examples

**Deploy JanusToken WRAPPER (Hardhat):**
```javascript
// deploy-args.js — v0.6.4 canonical verifier addresses
module.exports = [
  "0xD0ED3936530258C278f5357C1dB709ad34768352",  // AmountDiscloseVerifier
  "0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B",  // ConfidentialTransferVerifier
  "0x27139AFda7425f51F68D32e0A38b7D43BcB0f870",  // BabyJub.sol
  true,         // wrapperMode
  "0xYourERC20" // underlying
];
// npx hardhat deploy --network flowTestnet --constructor-args deploy-args.js
```

**Point SDK at your deployed instance:**
```typescript
import { JanusToken } from "@claucondor/sdk/tokens";
const token = new JanusToken({ evmAddress: "0xYourDeployedAddress", network: "testnet" });
await token.connect();
```

## Common gotchas

**P1 — Mismatched verifier and zkey.**
`EncryptConsistencyVerifier.sol` and `DecryptOpenVerifier.sol` are generated from specific `.zkey` files. If you regenerate the circuit (new trusted setup), you must also redeploy both verifiers. The canonical testnet verifiers match the circuit artifacts at canonical paths — see `references/circuit-artifacts.md`.

**P2 — Wrong `underlying` address in WRAPPER mode.**
The `underlying` ERC-20 address is immutable. Passing address zero or the wrong token will lock the contract permanently in a broken state.

**P3 — Deploying JanusFlow without a COA on the Cadence account.**
JanusFlow stores ciphertexts in EVM slots keyed by the user's COA address. If a user's Cadence account has no COA, `wrapAndEncrypt` will fail. See `references/flow-account-vs-coa.md`.

**P4 — CU budget exceeded in Cadence transactions.**
Cross-VM Groth16 verification is the most expensive operation in JanusFlow. Always set `limit: 9999` in FCL mutate calls. Do not add extra EVM calls in the same transaction as `wrapAndEncrypt` or `decryptAndUnwrap`. See `references/compute-units-limit.md`.

**P5 — Missing `approve` at wrap time (WRAPPER mode).**
Users must call `ERC20.approve(janusTokenAddress, amount)` before `wrapAndEncrypt`. Test this end-to-end on testnet before deploying to production.

## Companion Skills

- **`openjanus-tokens`** — understand what you are deploying (JanusToken, JanusFlow)
- **`openjanus-sdk`** — TypeScript SDK to interact with the deployed contracts
- **`flow-crossvm`** — Cross-VM Cadence patterns for Cadence-hosted deployments
