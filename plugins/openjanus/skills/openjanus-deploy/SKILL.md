---
name: openjanus-deploy
description: |
  Deployment guide for OpenJanus v0.8 contracts — JanusFlow (native FLOW), JanusERC20 (ERC20 wrapper), JanusFT (Cadence FT), plus shared primitives (BabyJub, Pedersen2Gen, ConfidentialTransferAggregateVerifier, AmountDiscloseAggregateVerifier, ConfidentialClaimBatchVerifier, ShieldedInbox, ShieldedCheckpoint, MemoKeyRegistry). Covers 8-arg constructor, deployment order, ShieldedInbox push-model warning, flow.json registration, canonical v0.8 addresses, circuit artifacts (pot22 ceremony), COA setup, and common deployment failures.
  TRIGGER when: "deploy JanusToken", "deploy JanusFlow", "deploy JanusERC20", "deploy BabyJub.sol", "deploy verifier", "create a new wrapper instance", "constructor arguments JanusToken", "deploy to testnet", "deploy to mainnet", "flow.json openjanus", "register Cadence contract", "deploy ConfidentialTransferVerifier", "what addresses do I pass at deploy", "deployment order", "hardhat deploy openjanus", "foundry deploy openjanus", "verify contract openjanus", "canonical addresses", "testnet addresses", "circuit artifacts", "WASM path", "zkey path", "compute units limit", "9999 CU", "flow account vs COA", "COA address", "ShieldedInbox deploy", "ShieldedCheckpoint deploy", "initFees", "wrapWithProof constructor", "pot22 ceremony", "N=10 batch claim", "push-model inbox warning".
  DO NOT TRIGGER when: calling already-deployed contracts via the SDK (use openjanus-sdk), implementing new contract logic (use openjanus-tokens), or asking about proof generation algorithms (use openjanus-primitives).
---

# OpenJanus Deployment Guide (v0.8)

Deploying the OpenJanus v0.8 stack follows a strict dependency order — primitives first, then verifiers, then token contracts.

## Deployment Order

```
1. BabyJub.sol              (stateless — deploy once, reuse address)
2. Pedersen2Gen.sol         (stateless — 2-generator Pedersen library, v0.7+)
3. MemoKeyRegistry.sol      (immutable — one publish covers all tokens)
4. ShieldedInbox.sol        (immutable — per-user mailbox, no proxy)
5. ShieldedCheckpoint.sol   (immutable — per-user per-token state, no proxy)
6. AmountDiscloseAggregateVerifier.sol  (circuit-specific, matches .zkey, pot22)
7. ConfidentialTransferAggregateVerifier.sol  (circuit-specific, pot22)
8. ConfidentialClaimBatchVerifier.sol   (N=10 batch claim, pot22)
9. JanusFlow.sol (impl) + JanusFlow_Proxy  (native FLOW — 8-arg initialize)
  OR
   JanusERC20.sol (impl) + JanusERC20_Proxy  (ERC20 wrapper — 8-arg initialize)
10. JanusFT.cdc             (Cadence — for Cadence FT integrations)
```

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/canonical-addresses.md` — All deployed OpenJanus v0.8 contracts on Flow testnet: primitives, token contracts, ShieldedInbox, ShieldedCheckpoint, network endpoints, chain IDs
- `references/deploying-wrapper-instance.md` — Quick reference for deploying a v0.8 JanusToken WRAPPER with all 8 constructor args
- `references/circuit-artifacts.md` — WASM, zkey, and vkey file locations; pot22 ceremony; vkey SHA256 hashes; N=10 batch claim
- `references/compute-units-limit.md` — 9999 CU ceiling on Flow: per-operation estimates (wrapWithProof, shieldedTransfer, claimBatch, unwrap), rules for avoiding budget overrun
- `references/flow-account-vs-coa.md` — Two address spaces on Flow: when to use Cadence address vs COA (EVM) address, looking up a COA, handling accounts with no COA

## Cross-skill references (load when context indicates)

- `../openjanus-tokens/references/creating-custom-instances.md` — Full guide: 8-arg constructor, ShieldedInbox/Checkpoint wiring, SDK registration
- `../openjanus-tokens/references/janus-token.md` — What you are deploying: JanusToken interface and slot layout
- `../openjanus-sdk/references/cross-vm-coa-pattern.md` — COA internals for Cadence-hosted deploys

## Examples

**Deploy JanusFlow proxy (Hardhat, v0.8):**
```javascript
// deploy-args.js — v0.8 canonical addresses
module.exports = [
  "0xD79C90b797949F0956d977989aEf82A81c860e0C",  // babyJub
  "0x38e69fE7Ba7c2C586d64DFFc14742641A675666c",  // transferVerifier (aggregate, pot22)
  "0xf7B634D41259D0613345633eE1CD193A030A6329",  // amountDiscloseVerifier (aggregate, pot22)
  "<COA_OWNER_EVM_ADDRESS>",                      // owner (UUPS upgrade authority)
  "0x361bD4d037838A3a9c5408AE465d36077800ee6c",  // memoRegistry
  "0x5EdF7473b1007b4855127bC40fcc89eCDD7fB561",  // pedersen2Gen
  "0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6",  // shieldedInbox
  "0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f",  // batchClaimVerifier (N=10, pot22)
];
// npx hardhat deploy --network flowTestnet --constructor-args deploy-args.js
```

**Point SDK at your deployed instance:**
```typescript
import { OpenJanusSDK } from "@claucondor/sdk";
const sdk = new OpenJanusSDK({
  network: "testnet",
  overrides: { JANUS_FLOW_PROXY: "0xYourDeployedAddress" }
});
```

## Common gotchas

**P1 — Mismatched verifier and zkey (pot22 required).**
`ConfidentialTransferAggregateVerifier.sol` and `AmountDiscloseAggregateVerifier.sol` must match the pot22 zkeys. If you regenerate a circuit (new trusted setup), you must redeploy both affected verifiers. The canonical testnet verifiers match the pot22 artifacts — see `references/circuit-artifacts.md`.

**P2 — Wrong `underlying` address in JanusERC20 (immutable after init).**
The underlying ERC-20 address is pinned in `initialize()`. Passing address zero or the wrong token will lock the contract permanently in a broken state. Verify the underlying address with a testnet `balanceOf` call before deployment.

**P3 — Deploying JanusFlow without a COA on the Cadence account.**
JanusFlow stores commitments in EVM slots keyed by the user's COA address. If a user's Cadence account has no COA, cross-VM wrap transactions will fail. See `references/flow-account-vs-coa.md`.

**P4 — CU budget exceeded in Cadence transactions.**
Cross-VM Groth16 verification is the most expensive operation in JanusFlow. Always set `limit: 9999` in FCL mutate calls. Do not add extra EVM calls in the same transaction as `wrapWithProof` or `shieldedTransfer`. See `references/compute-units-limit.md`.

**P5 — Missing `approve` at wrap time (JanusERC20).**
Users must call `ERC20.approve(janusERC20Address, amount)` before `wrapWithProof`. Test this end-to-end on testnet before deploying to production.

**P6 — ShieldedInbox push-model: inbox full reverts shieldedTransfer.**
When ShieldedInbox is wired, every `shieldedTransfer` atomically pushes a note to the recipient's inbox. If the recipient inbox is full (`MAX_INBOX_NOTES = 10000`), the call reverts. Recipients must drain their inbox (via `claimBatch()`) before more transfers can arrive. Warn users in the UI.

**P7 — initFees not called.**
A freshly deployed proxy has `feeBps = 0` and `feeRecipient = address(0)`. Call `initFees(recipient, 10)` as the proxy owner before opening to users. Fees cannot be initialized a second time (safeguard against re-init).

## Companion Skills

- **`openjanus-tokens`** — understand what you are deploying (JanusToken, JanusFlow, JanusERC20, JanusFT)
- **`openjanus-sdk`** — TypeScript SDK to interact with the deployed contracts
- **`flow-crossvm`** — Cross-VM Cadence patterns for Cadence-hosted deployments
