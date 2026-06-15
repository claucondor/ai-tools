# CLAUDE.md Template — Projects Building on the Janus Privacy Stack (v0.8.2)

Copy this file into your project root as `CLAUDE.md` and customize the
bracketed sections.

---

```markdown
# CLAUDE.md — [Your Project Name]

## Project Overview

[Brief description of what this project does using Janus privacy stack]

This project uses:
- `@claucondor/sdk@^0.8.2` — TypeScript SDK with generic `sdk.token(id)` adapter
  (3 tokens: flow/mockusdc/mockft), Pedersen commitments (`@openjanus/commitment`),
  ShieldedInbox + ShieldedCheckpoint, batchClaim N=10
- `JanusFlow` EVM proxy (`0xA64340C1d356835A2450306Ffd290Ed52c001Ad3`) for native FLOW
- `ShieldedInbox` (`0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6`) for recipient state
- `ShieldedCheckpoint` (`0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26`) for sender state
- [optional: a custom `Janus<X>` concrete at `0xYourAddress` for an ERC-20]

## Key commands

```bash
npm test                  # Unit tests (no network, ~5s)
npm run test:integration  # Requires Flow testnet
npm run build             # Build project
```

## Deployed addresses (testnet) — v0.8.2 contracts

| Contract | Address |
|----------|---------|
| JanusFlow EVM proxy             | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` |
| JanusERC20 EVM proxy (mockusdc) | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` |
| JanusFT Cadence deployer        | `0x4b6bc58bc8bf5dcc` |
| MemoKeyRegistry (immutable)     | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` |
| ShieldedInbox (EVM, immutable)  | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` |
| ShieldedCheckpoint (EVM)        | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` |
| Cadence ShieldedCheckpoint      | `0xd1a02aa46d9151bb` |
| MockUSDC underlying             | `0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524` |
| AmountDiscloseVerifier          | `0xf7B634D41259D0613345633eE1CD193A030A6329` |
| ConfidentialTransferVerifier    | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` |
| ClaimBatchVerifier N=10         | `0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f` |
| BabyJub.sol                     | `0xD79C90b797949F0956d977989aEf82A81c860e0C` |

## Circuit artifacts

WASM and zkey files for the v0.8 circuits (`amount_disclose`, `confidential_transfer`,
and `batch_claim_n10`) are bundled in `node_modules/@claucondor/sdk/circuits/v0.8/`
or at `[CDN URL]`. Provenance records live in `circuits/v0.8/CEREMONY-RECORD.json`.

## Coding conventions (v0.8.2)

- Use `sdk.token(id)` — never instantiate adapters directly
- After every shieldedTransfer or unwrap, call `checkpoint.update(token.address, payload, cursor, signer)`
- Before building any proof, run `assertCheckpointMatchesCommit` (hard gate) or
  `isOpSafeNow` (soft gate) to catch checkpoint drift early
- Use `ShieldedInboxClient.drainAndDecrypt()` to receive notes — do NOT scan events
- Use `BatchClaimClient.buildAndClaim()` when recipient has >= 2 unread inbox notes
- Use `generateBlinding()` for every new blinding — never hardcode or reuse
- Store `(amount, blinding)` pairs locally or recover via ShieldedCheckpoint
- Set FCL transaction `limit: 9999` for all JanusFlow Cadence transactions
- Never log or expose blinding factors or `(amount, blinding)` pairs
- Use the SDK address constants (`TOKEN_REGISTRY.flow.proxy`, `SHIELDED_INBOX_ADDRESS`,
  `SHIELDED_CHECKPOINT_ADDRESS`, etc.) — never hardcode addresses
- `isFreshSlotCommit(commit)` returns true for both (0,0) and (0,1)

## What NOT to do

- Do not use the old `OpenJanusSDK` class — it was removed in v0.8
- Do not call `sdk.token('wflow')` — JanusWFLOW was dropped in v0.8
- Do not scan events for received notes — use ShieldedInboxClient.drain()
- Do not skip calling checkpoint.update() after transfers — blinding loss risk
- Do not pass plaintext amounts on-chain for shieldedTransfer — use Pedersen commitment + proof
- Do not call `registerPubkey` — that API no longer exists
- Do not call `wrapAndEncrypt` / `decryptAndUnwrap` / `bsgsRecover` — v0.2 ElGamal APIs removed
- Do not submit a proof without first verifying locally
- Do not run proof generation on the main thread in browser — use a Web Worker
- Do not call the EVM impl directly — always interact via the JanusFlow EVM proxy or the Cadence router
- Do not use v0.6.x addresses — they are stale (different deployment)

## Reference

- [@claucondor/sdk docs](https://github.com/claucondor/ai-tools/tree/main/plugins/openjanus/skills/openjanus-sdk/references)
- [Janus privacy stack AI tools plugin](https://github.com/openjanus/ai-tools)
- [PrivateTip demo](https://privatetip.vercel.app)
```
