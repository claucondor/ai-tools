# Privacy Level Needed? (v0.8)

OpenJanus v1 ships **amount-only privacy** — transfer amounts are hidden but sender and recipient addresses are public. Stronger privacy properties (UTXO model, stealth addresses, sender hiding) are deferred to v2+.

**v1 (ships now)**: amount privacy only — `shieldedTransfer` hides amounts. Addresses remain public.
**v2+ (future)**: UTXO model + stealth addresses — deferred until demos surface the need; do not port Railgun architecture wholesale.

## What OpenJanus provides by default

| Property | Provided? |
|----------|-----------|
| Transfer amount hidden from observers | Yes |
| Sender address hidden | No |
| Recipient address hidden | No |
| Existence of transfer hidden | No |
| Balance range hidden | Partially (commitment reveals nothing, but the number of transfers is visible) |

## Choosing your privacy level

```
Do you need to hide only the amount?
├── Yes → Standard JanusToken/JanusFlow is sufficient (v1, ships now).
│         shieldedTransfer(from, to) — amount hidden, addresses public.
│         ShieldedInbox delivers encrypted notes; claimBatch accumulates them.
│
└── No — Do you need to hide sender or recipient too?
    ├── Sender only (recipient visible) → Stealth addresses (v2+ roadmap, not built)
    ├── Recipient only → Stealth addresses (v2+ roadmap)
    ├── Both → Mixer pattern (Tornado-style, L4 of zk-prop — research only, not in SDK)
    └── Full transaction graph privacy → UTXO model, deferred to v2+ only if demos surface need
```

## Current capabilities

### Amount privacy (v1 — ships now)

Use `shieldedTransfer` directly. The contract emits:
```
ConfidentialTransfer(indexed from, indexed to)
ShieldedTransferNote(indexed from, indexed to, encryptedNoteTo, ephPubkeyToX, ephPubkeyToY)
```
No amount is emitted. Observers know Alice sent something to Bob, but not how much.
The `ShieldedInbox` receives an encrypted note for Bob automatically.

### Confidential tipping with ShieldedInbox + claimBatch (v1 — ships now)

See [confidential-tipping.md](confidential-tipping.md). Tips are delivered via `ShieldedInbox`;
recipients accumulate with `claimBatch(N=10)`. Push-model warning: inbox full reverts transfers.

### UTXO model (v2+ — deferred)

Deferred until demos surface the need. Do not port Railgun / Tornado architecture wholesale.
Building UTXO on top of the current Pedersen accumulator would require a new circuit set and
a fresh ceremony.

### Mixer / anonymity set (zk-prop L4, research only)

A Tornado-style mixer with Poseidon hashing was implemented in the `zk-prop` repository for research purposes. It is not part of `@claucondor/sdk`.

## Tradeoffs to communicate to users

If you build a product on OpenJanus, be explicit with your users about what is and is not private:

**Private:**
- The exact amount of each transfer

**Public:**
- That a confidential transfer occurred
- The sender's address
- The recipient's address
- The timestamp

This is similar to private messaging apps where metadata (who messaged whom, when) may be visible even if the content is not.
