# CLAUDE.md Template — Projects Building on OpenJanus (v0.3)

Copy this file into your project root as `CLAUDE.md` and customize the
bracketed sections.

---

```markdown
# CLAUDE.md — [Your Project Name]

## Project Overview

[Brief description of what this project does using OpenJanus]

This project uses:
- `@openjanus/sdk@^0.3.0` — TypeScript SDK for fully shielded confidential
  transfers (Pedersen commitments on BabyJubJub, abstract `JanusToken` base +
  `Janus<X>` concretes)
- `JanusFlow` Cadence router (`0x5dcbeb41055ec57e`) over the EVM proxy
  (`0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078`) for native FLOW wrapping
- [optional: a custom `Janus<X>` concrete at `0xYourAddress` for an ERC-20]

## Key commands

```bash
npm test                  # Unit tests (no network, ~5s)
npm run test:integration  # Requires Flow testnet
npm run build             # Build SDK / contracts
```

## Deployed addresses (testnet) — v0.3.0

| Contract | Address |
|----------|---------|
| JanusFlow EVM proxy           | `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078` |
| JanusFlow EVM impl            | `0x9321dF5884021D7E19Ad0EB5F582f8E2A70236eC` |
| JanusFlow Cadence router      | `0x5dcbeb41055ec57e` |
| AmountDiscloseVerifier        | `0xD0ED3936530258C278f5357C1dB709ad34768352` |
| ConfidentialTransferVerifier  | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` |
| BabyJub.sol (lab)             | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |
| Owner (admin COA)             | `0x0000000000000000000000022f6b30af48a94787` |

DEPRECATED (DO NOT USE):
- `0x025efe7e89acdb8F315C804BE7245F348AA9c538` — v0.2 EVM JanusToken (leaks amounts)
- `0xbef3c77681c15397` — v0.2 Cadence router
- `0x28fef3d1d6a12800.JanusFlow` — v1 zombie (Pedersen-hash, unremovable)

## Circuit artifacts

WASM and zkey files for the v0.3 circuits (`amount_disclose` and
`confidential_transfer`) are bundled in
`node_modules/@openjanus/sdk/circuits/v0.3/` or at `[CDN URL]`. Provenance
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

See [`openjanus-sdk/references/migration-v02-to-v03.md`](https://github.com/openjanus/ai-tools/blob/main/plugins/openjanus/skills/openjanus-sdk/references/migration-v02-to-v03.md)
for rewrite recipes (ElGamal → Pedersen, encrypt/decrypt → wrap/unwrap +
shieldedTransfer, pubkey registry → OOB blinding delivery).

## Reference

- [@openjanus/sdk docs](https://github.com/openjanus/ai-tools/tree/main/plugins/openjanus/skills/openjanus-sdk/references)
- [OpenJanus AI tools plugin](https://github.com/openjanus/ai-tools)
```
