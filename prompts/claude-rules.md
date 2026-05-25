# CLAUDE.md Template — Projects Building on OpenJanus

Copy this file into your project root as `CLAUDE.md` and customize the bracketed sections.

---

```markdown
# CLAUDE.md — [Your Project Name]

## Project Overview

[Brief description of what this project does using OpenJanus]

This project uses:
- `@openjanus/sdk` — TypeScript SDK for confidential transfers (v2: ElGamal-on-BabyJub)
- `JanusFlow` Cadence contract (`0x28fef3d1d6a12800`) — native FLOW wrapping (v2)
- [JanusToken instance at `0xYourAddress`] — if using a custom instance

## Key commands

```bash
npm test              # Unit tests (no network, ~5s)
npm run test:integration  # Requires Flow testnet
npm run build         # Build SDK / contracts
```

## Deployed addresses (testnet)

| Contract | Address |
|----------|---------|
| JanusFlow.cdc | `0x28fef3d1d6a12800` (contract: `JanusFlow`) |
| JanusToken.sol | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` |
| EncryptConsistencyVerifier | `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C` |
| DecryptOpenVerifier | `0x3bB139B5404fD6b152813bC3532367AAa096638b` |
| BabyJub.sol | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` |

## Circuit artifacts

WASM and zkey files are at `[path/to/circuits/]` or served from `[CDN URL]`.

## Coding conventions

- Always call `await sdk.configure()` before any JanusFlow operation
- Call `registerPubkey` once per account before the account can receive encrypted amounts
- Use `generateRandomness()` for ephemeral randomness in encrypt proofs — no need to store
- Store the account's secret key `sk` securely — it is the decryption key for the balance
- Run BSGS before generating the decrypt-open proof to determine the correct amount
- Set FCL transaction `limit: 9999` for all JanusFlow transactions
- Never log or expose `sk` or other secret material

## What NOT to do

- Do not pass plaintext amounts on-chain — use ElGamal ciphertexts (v2) or commitments (primitives)
- Do not send a `confidentialTransfer` to a recipient who has not registered a pubkey
- Do not submit a proof without first verifying locally
- Do not run proof generation on the main thread in browser — use a Web Worker
- Do not use `@openjanus/sdk/tokens` (v1, removed in 0.1.0) — use `@openjanus/sdk/tokens`

## Reference

- [@openjanus/sdk docs](https://github.com/openjanus/ai-tools/tree/main/plugins/openjanus/skills/openjanus-sdk/references)
- [OpenJanus AI tools plugin](https://github.com/openjanus/ai-tools)
```
