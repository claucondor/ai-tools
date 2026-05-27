# CLAUDE.md Template — Projects Building on OpenJanus

Copy this file into your project root as `CLAUDE.md` and customize the bracketed sections.

---

```markdown
# CLAUDE.md — [Your Project Name]

## Project Overview

[Brief description of what this project does using OpenJanus]

This project uses:
- `@openjanus/sdk@^0.2.0` — TypeScript SDK for confidential transfers (ElGamal-on-BabyJub)
- `JanusFlow` Cadence contract (`0x5dcbeb41055ec57e`) — native FLOW wrapping (router/impl)
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
| JanusFlow.cdc (router) | `0x5dcbeb41055ec57e` (contract: `JanusFlow`) |
| JanusToken.sol | `0x025efe7e89acdb8F315C804BE7245F348AA9c538` |
| EncryptConsistencyVerifier | `0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e` |
| DecryptOpenVerifier | `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` |
| BabyJub.sol | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |

DO NOT USE: `0x28fef3d1d6a12800.JanusFlow` — legacy zombie, Pedersen-based, cannot be removed.

## Circuit artifacts

WASM and zkey files are bundled in `node_modules/@openjanus/sdk/circuits/` or at `[CDN URL]`.

## Coding conventions

- Always call `await sdk.configure()` before any JanusFlow operation
- Call `await sdk.isPaused()` before write operations — surface error to user if paused
- Call `registerPubkey` once per account before the account can receive encrypted amounts
- Use `generateRandomness()` for ephemeral randomness in encrypt proofs — no need to store
- Store the account's secret key `sk` securely — it is the decryption key for the balance
- Run BSGS before generating the decrypt-open proof to determine the correct amount
- Set FCL transaction `limit: 9999` for all JanusFlow transactions
- Never log or expose `sk` or other secret material
- Use `JANUS_FLOW_CADENCE_ADDRESS` constant from SDK — never hardcode the address

## What NOT to do

- Do not import from `0x28fef3d1d6a12800.JanusFlow` — use `0x5dcbeb41055ec57e`
- Do not pass plaintext amounts on-chain — use ElGamal ciphertexts
- Do not send a `confidentialTransfer` to a recipient who has not registered a pubkey
- Do not submit a proof without first verifying locally
- Do not run proof generation on the main thread in browser — use a Web Worker
- Do not call JanusFlowImpl directly — always go through the JanusFlow router

## Reference

- [@openjanus/sdk docs](https://github.com/openjanus/ai-tools/tree/main/plugins/openjanus/skills/openjanus-sdk/references)
- [OpenJanus AI tools plugin](https://github.com/openjanus/ai-tools)
```
