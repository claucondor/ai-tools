# CLAUDE.md Template — Projects Building on Janus privacy stack (v0.3)

Copy this file into your project root as `CLAUDE.md` and customize the
bracketed sections.

---

```markdown
# CLAUDE.md — [Your Project Name]

## Project Overview

[Brief description of what this project does using Janus privacy stack]

This project uses:
- `@claucondor/sdk@^0.6.5` — TypeScript SDK with generic `sdk.token(id)` adapter
  (4 tokens: flow/wflow/mockusdc/mockft), Pedersen commitments, MemoKeyRegistry
- `JanusFlow` EVM proxy (`0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156`) for native FLOW
- [optional: a custom `Janus<X>` concrete at `0xYourAddress` for an ERC-20]

## Key commands

```bash
npm test                  # Unit tests (no network, ~5s)
npm run test:integration  # Requires Flow testnet
npm run build             # Build SDK / contracts
```

## Deployed addresses (testnet) — v0.6.4 contracts

| Contract | Address |
|----------|---------|
| JanusFlow EVM proxy           | `0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156` |
| JanusWFLOW EVM proxy          | `0x00129E94d5340bd19d0b4ed9CDf718BB6e0A9400` |
| JanusMockUSDC EVM proxy       | `0xd45FDa099Cf67eD842eA379865AB08E18D62BAf3` |
| JanusFT Cadence               | `0x7599043aea001283` |
| MemoKeyRegistry (immutable)   | `0x05D104962ff087441f26BA11A1E1C3b9E091D663` |
| WFLOW9 underlying             | `0xe7BbEAcC04A589e4B70922b2796Bb4F8e6e4873C` |
| MockUSDC underlying           | `0x8405E8831737aE72204c271581b7d4fAD9f622bE` |
| AmountDiscloseVerifier        | `0xD0ED3936530258C278f5357C1dB709ad34768352` |
| ConfidentialTransferVerifier  | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` |
| BabyJub.sol                   | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |

DEPRECATED (DO NOT USE):
- `0x025efe7e89acdb8F315C804BE7245F348AA9c538` — v0.2 EVM JanusToken (leaks amounts)
- `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078` — v0.5.x JanusFlow proxy (OLD)
- `0xf2C04b1A32B815ac7Ffd87a4C312096592BBCa1e` — v0.5.x JanusERC20 proxy (OLD)
- `0xbef3c77681c15397` — v0.5.x JanusFT Cadence (OLD)
- `0x28fef3d1d6a12800.JanusFlow` — v1 zombie (Pedersen-hash, unremovable)

## Circuit artifacts

WASM and zkey files for the v0.3 circuits (`amount_disclose` and
`confidential_transfer`) are bundled in
`node_modules/@claucondor/sdk/circuits/v0.3/` or at `[CDN URL]`. Provenance
records live in `circuits/v0.3/CEREMONY-RECORD.json`.

## Coding conventions (v0.3)

- Always call `await token.connect()` or `await token.connectWithSigner(signer)`
  before any JanusFlow operation
- Call `await token.isPaused()` (if your concrete exposes it) before write
  operations — surface error to user if paused
- Use `generateBlinding()` for every new blinding — never hardcode or reuse
- Store `(amount, blinding)` pairs locally per commitment — this is the
  decryption material in v0.3
- Deliver `(transferAmount, transferBlinding)` to recipients out-of-band
  (encrypted DM, signed payload). On-chain channels do not carry the amount.
- Set FCL transaction `limit: 9999` for all JanusFlow Cadence transactions
- Never log or expose blinding factors or `(amount, blinding)` pairs
- Use the SDK address constants (`JANUS_FLOW_EVM_TESTNET`,
  `JANUS_FLOW_CADENCE_TESTNET`, etc.) — never hardcode addresses

## What NOT to do

- Do not import from any deprecated v0.2 address (see deprecated list above) —
  those leak amounts on every transfer
- Do not pass plaintext amounts on-chain for shieldedTransfer — use the
  Pedersen commitment + proof
- Do not call `registerPubkey` — that API no longer exists in v0.3
- Do not call `wrapAndEncrypt` / `decryptAndUnwrap` / `bsgsRecover` — those
  are v0.2 ElGamal APIs and have been removed
- Do not submit a proof without first verifying locally
- Do not run proof generation on the main thread in browser — use a Web Worker
- Do not call the EVM impl directly — always interact via the JanusFlow EVM
  proxy or the Cadence router

## If you're migrating from v0.2

See [`openjanus-sdk/references/migration-v02-to-v03.md`](https://github.com/claucondor/ai-tools/blob/main/plugins/openjanus/skills/openjanus-sdk/references/migration-v02-to-v03.md)
for rewrite recipes (ElGamal → Pedersen, encrypt/decrypt → wrap/unwrap +
shieldedTransfer, pubkey registry → OOB blinding delivery).

## Reference

- [@claucondor/sdk docs](https://github.com/claucondor/ai-tools/tree/main/plugins/openjanus/skills/openjanus-sdk/references)
- [Janus privacy stack AI tools plugin](https://github.com/claucondor/ai-tools)
```
