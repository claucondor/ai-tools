# Privacy Level Needed?

OpenJanus provides amount privacy out of the box. Stronger privacy properties require additional design choices.

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
├── Yes → Standard JanusToken/JanusFlow is sufficient.
│         confidentialTransfer(from, to) — amount hidden, addresses public.
│
└── No — Do you need to hide sender or recipient too?
    ├── Sender only (recipient visible) → Stealth addresses (future, L8+ roadmap)
    ├── Recipient only → Stealth addresses (future)
    ├── Both → Mixer pattern (Tornado-style, L4 of zk-prop)
    └── Full transaction graph privacy → Out of scope for v1 OpenJanus
```

## Current capabilities

### Amount privacy (available now)

Use `confidentialTransfer` directly. The contract emits:
```
ConfidentialTransfer(indexed from, indexed to)
```
No amount is emitted. Observers know Alice sent something to Bob, but not how much.

### Confidential tipping (available now)

See [confidential-tipping.md](confidential-tipping.md). The same amount privacy applies.

### Mixer / anonymity set (zk-prop L4, research only)

A Tornado-style mixer with Poseidon hashing was implemented in the `zk-prop` repository for research purposes. It is not part of `@openjanus/sdk`.

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
