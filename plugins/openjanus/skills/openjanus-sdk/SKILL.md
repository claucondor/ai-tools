---
name: openjanus-sdk
description: |
  Guide for installing and using @openjanus/sdk — the unified TypeScript SDK for OpenJanus privacy primitives on Flow. Covers package installation, FCL configuration, computing Pedersen commitments, generating Groth16 transfer proofs, reading JanusToken balances, executing JanusFlow wrap/transfer/unwrap via Cadence transactions, and creating EVM wallets for Flow EVM.
  TRIGGER when: installing @openjanus/sdk, "npm install @openjanus/sdk", importing from @openjanus/sdk, computeCommitment, buildTransferProof, generateBlinding, JanusToken class, JanusFlow class, token.connect(), sdk.configure(), sdk.wrap(), sdk.confidentialTransfer(), sdk.unwrap(), balanceOfCommitment, mintXY, confidentialTransfer, proveAndTransfer, createEvmWallet, createEvmProvider, configureFCL, JANUS_TOKEN_TESTNET, "how do I use the sdk", "how do I read a commitment", "how do I generate a proof", "wrap FLOW confidentially", "what is buildTransferProof", "@openjanus/sdk/tokens", "@openjanus/sdk/primitives", "@openjanus/sdk/crypto", "@openjanus/sdk/network", JanusFlowV2, JanusTokenV2, wrapAndEncrypt, decryptAndUnwrap, getSlot, registerPubkey, buildEncryptProof, buildDecryptProof, bsgsRecover, "v2 sdk", "tokens-v2".
  DO NOT TRIGGER when: asking about low-level BabyJubJub curve math (use openjanus-primitives), deploying a new JanusToken or JanusFlow instance (use openjanus-deploy), or implementing the JanusToken Solidity standard (use openjanus-tokens).
---

# @openjanus/sdk Guide

The OpenJanus SDK consolidates BabyJubJub, Pedersen, Groth16, JanusTokenV2, and JanusFlowV2 into one installable TypeScript package. All operations that apps need day-to-day live here.

**v2 is recommended for all new apps.** V2 uses ElGamal-on-BabyJubJub for genuine multi-sender privacy — recipients learn only the accumulated total, not per-sender amounts.

## Quick Start

```bash
npm install @openjanus/sdk
```

```typescript
import { JanusFlowV2, JANUS_TOKEN_V2_TESTNET } from "@openjanus/sdk/tokens-v2";
import { buildEncryptProof, buildDecryptProof, bsgsRecover } from "@openjanus/elgamal";

const sdk = new JanusFlowV2({ network: "testnet" });
await sdk.configure();  // must call before any operation

// One-time setup: register pubkey before first receive
await sdk.registerPubkey(aliceKeypair.pk, aliceAuthz);

// Sender: encrypt and wrap
const proof = await buildEncryptProof({ amount: 10n, randomness, recipientPubkey: alicePK, ... });
await sdk.wrapAndEncrypt("10.0", ALICE_ADDR, proof, senderAuthz);

// Recipient: read slot, BSGS decrypt, unwrap
const ct = await sdk.getSlot(ALICE_ADDR);
const amount = await bsgsRecover(recoverMaskedPoint(ct, sk), { maxValue: 1_000_000n });
const decryptProof = await buildDecryptProof({ ciphertext: ct, secretKey: sk, amount, ... });
await sdk.decryptAndUnwrap(`${amount}.0`, ALICE_ADDR, decryptProof, aliceAuthz);
```

## References (loaded on-demand)

When relevant, read these files for detail:

- `references/install.md` — Package installation, peer deps, exports map, Node.js version requirements
- `references/quickstart.md` — Full v2 workflow: register pubkey, wrapAndEncrypt, BSGS decrypt, unwrap
- `references/decrypt-flow.md` — BSGS decryption in depth: recovering masked point, table precompute, practical limits
- `references/extending-the-sdk.md` — Adding a new SDK module, custom circuits, contributing upstream
- `references/ts-sdk-integration.md` — Next.js / React integration: FCL wallet connection, Web Worker for proof gen, state persistence
- `references/cross-vm-coa-pattern.md` — COA pattern internals: coa.call, EVM.dryCall, ABI encoding from Cadence, CU budget breakdown

## Cross-skill references (load when context indicates)

- `../openjanus-primitives/references/pi-b-fp2-swap.md` — Why verifyProof silently returns false without the Fp2 swap
- `../openjanus-primitives/references/circuit-artifacts.md` — WASM / zkey / vkey file locations (wait, circuit-artifacts is in openjanus-deploy)
- `../openjanus-deploy/references/circuit-artifacts.md` — WASM / zkey / vkey locations for proof generation
- `../openjanus-tokens/references/janus-token.md` — JanusTokenV2 Solidity interface reference
- `../openjanus-tokens/references/janus-flow.md` — JanusFlowV2 Cadence transaction templates

## Examples

**Reading an accumulated slot (v2):**
```typescript
const ct = await sdk.getSlot(ALICE_CADENCE_ADDR);
// { c1: { x, y }, c2: { x, y } }
const isEmpty = ct.c1.x === 0n && ct.c1.y === 1n && ct.c2.x === 0n && ct.c2.y === 1n;
```

**FCL transaction limit:**
```typescript
await fcl.mutate({ cadence: TX, args: [...], limit: 9999 }); // always 9999
```

## Common gotchas

**P1 — Not calling `sdk.configure()` before JanusFlowV2 operations.**
`JanusFlowV2` does not auto-configure FCL. Call `await sdk.configure()` once before `wrapAndEncrypt()`, `decryptAndUnwrap()`, or `registerPubkey()`.

**P2 — Not registering pubkey before first receive.**
`wrapAndEncrypt` targeting a recipient with no registered pubkey will revert on-chain. Call `hasPubkey(addr)` first and register if false.

**P3 — Incorrect amount in decryptAndUnwrap.**
The DecryptOpenVerifier circuit rejects any amount that doesn't match the actual decrypted value. Run BSGS to find the exact amount before generating the decrypt proof. If BSGS returns null, increase `maxValue`.

**P4 — Submitting proofs without pi_b Fp2 swap.**
`buildEncryptProof` and `buildDecryptProof` apply the swap automatically. Manual proof construction must call `applyPiBSwap` before on-chain submission — without it, `verifyProof` returns `false` silently.

**P5 — Losing the secret key `sk`.**
`sk` is the decryption key for the balance slot. It is never stored on-chain. If lost, the encrypted balance cannot be recovered. Store it encrypted in persistent app state.

**P6 — Wrong WASM/zkey paths.**
`buildEncryptProof` / `buildDecryptProof` will hang or throw if paths are wrong. See `../openjanus-deploy/references/circuit-artifacts.md`.

## Companion Skills

- **`openjanus-primitives`** — when you need raw BabyJubJub or Pedersen operations not exposed through the SDK facade
- **`openjanus-tokens`** — when building the Solidity side (JanusTokenV2 standard, custom instances)
- **`openjanus-deploy`** — when deploying a new token instance or registering primitives
- **`flow-crossvm`** — when you need deeper Cross-VM Cadence patterns beyond what JanusFlowV2 exposes
