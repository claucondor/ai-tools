# CLAUDE.md Template — Projects Building on OpenJanus

Copy this file into your project root as `CLAUDE.md` and customize the bracketed sections.

---

```markdown
# CLAUDE.md — [Your Project Name]

## Project Overview

[Brief description of what this project does using OpenJanus]

This project uses:
- `@openjanus/sdk` — TypeScript SDK for confidential transfers (v1 + v2)
- `JanusFlowV2` Cadence contract (`0x28fef3d1d6a12800`) — native FLOW wrapping with ElGamal (v2, RECOMMENDED)
- `JanusFlow` Cadence contract (`0x28fef3d1d6a12800`) — native FLOW wrapping with Pedersen (v1, legacy)
- [JanusTokenV2 instance at `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D`] — v2 canonical testnet deployment
- [JanusToken instance at `0xYourAddress`] — if using a v1 custom instance

## Key commands

```bash
npm test              # Unit tests (no network, ~5s)
npm run test:integration  # Requires Flow testnet
npm run build         # Build SDK / contracts
```

## Deployed addresses (testnet)

### V2 (RECOMMENDED for new apps)

| Contract | Address |
|----------|---------|
| JanusFlowV2.cdc | `0x28fef3d1d6a12800` (contract: JanusFlowV2) |
| JanusTokenV2.sol | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` |
| EncryptConsistencyVerifier | `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C` |
| DecryptOpenVerifier | `0x3bB139B5404fD6b152813bC3532367AAa096638b` |
| BabyJub.sol (v2) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |

### V1 (legacy)

| Contract | Address |
|----------|---------|
| JanusFlow.cdc | `0x28fef3d1d6a12800` |
| JanusToken.sol | `[your address]` |
| ConfidentialTransferVerifier | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` |
| BabyJub.sol | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` |

## Circuit artifacts

WASM and zkey files are at `[path/to/circuits/]` or served from `[CDN URL]`.

## Coding conventions

### V2 (ElGamal — new apps)
- Always call `await sdk.configure()` before any JanusFlowV2 operation
- Call `registerPubkey` once per account before the account can receive encrypted amounts
- Use `generateRandomness()` for ephemeral randomness in encrypt proofs — no need to store
- Store the account's secret key `sk` securely — it is the decryption key for the balance
- Run BSGS before generating the decrypt-open proof to determine the correct amount
- Set FCL transaction `limit: 9999` for all JanusFlowV2 transactions
- Never log or expose `sk`

### V1 (Pedersen — legacy)
- Always call `await token.connect()` or `await sdk.configure()` before any SDK operation
- Always generate fresh blindings with `generateBlinding()` — never reuse or hardcode
- Always persist blinding factors alongside commitments in the app database
- Apply `applyPiBSwap` to every proof before on-chain submission (SDK does this automatically)
- Set FCL transaction `limit: 9999` for all JanusFlow transactions
- Never log or expose blinding factors

## What NOT to do

- Do not pass plaintext amounts on-chain — use commitments
- Do not reuse blinding factors between commitments
- Do not submit a proof without first verifying locally (`vkPath` in `buildTransferProof`)
- Do not run proof generation on the main thread in browser — use a Web Worker

## Reference

- [@openjanus/sdk docs](https://github.com/openjanus/ai-tools/tree/main/docs/sdk)
- [OpenJanus AI tools plugin](https://github.com/openjanus/ai-tools)
```
