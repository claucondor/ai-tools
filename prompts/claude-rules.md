# CLAUDE.md Template — Projects Building on OpenJanus

Copy this file into your project root as `CLAUDE.md` and customize the bracketed sections.

---

```markdown
# CLAUDE.md — [Your Project Name]

## Project Overview

[Brief description of what this project does using OpenJanus]

This project uses:
- `@openjanus/sdk` — TypeScript SDK for confidential transfers
- `JanusFlow` Cadence contract (`0x28fef3d1d6a12800`) — native FLOW wrapping
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
| JanusFlow.cdc | `0x28fef3d1d6a12800` |
| JanusToken.sol | `[your address]` |
| ConfidentialTransferVerifier | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` |
| BabyJub.sol | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` |

## Circuit artifacts

WASM and zkey files are at `[path/to/circuits/]` or served from `[CDN URL]`.

## Coding conventions

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
