# _archive/

This folder contains documentation for deprecated components of the OpenJanus stack.

## Contents

| File | Was | Reason Archived |
|------|-----|----------------|
| [`janus-token-v1.md`](./janus-token-v1.md) | `docs/contracts/janus-token.md` | v1 JanusToken deprecated — Pedersen-hash privacy limitation |
| [`janus-flow-v1.md`](./janus-flow-v1.md) | `docs/contracts/janus-flow.md` | v1 JanusFlow deprecated — same reason |
| [`sdk-basic-transfer-v1.md`](./sdk-basic-transfer-v1.md) | `docs/sdk/basic-transfer.md` | v1 SDK usage patterns |
| [`sdk-advanced-usage-v1.md`](./sdk-advanced-usage-v1.md) | `docs/sdk/advanced-usage.md` | v1 JanusFlow SDK patterns |
| [`confidential-tipping-v1.md`](./confidential-tipping-v1.md) | `docs/patterns/confidential-tipping.md` | v1 tipping pattern — has privacy limitation |
| [`native-vs-wrapper-mode-v1.md`](./native-vs-wrapper-mode-v1.md) | `docs/decision-trees/native-vs-wrapper-mode.md` | v1 NATIVE vs WRAPPER decision |

## Why v1 was deprecated

v1 (Pedersen-hash JanusToken/JanusFlow) was deprecated in 0.2.0 because it did not deliver
the privacy property it promised in multi-sender scenarios. The Cadence cross-VM architecture
leaked plaintext FLOW amounts via standard `TokensWithdrawn` events, and the Pedersen hash
used for commitments was not additively homomorphic in a way that supported multi-sender
accumulation by recipients.

Full explanation: https://github.com/openjanus/sdk/blob/main/docs/why-v1-was-deprecated.md

## Policy

- Archived docs are preserved for historical reference.
- v1 contracts remain deployed on-chain (immutable). The addresses are still valid but
  should not be used for new development.
- For current documentation, start from [docs/](../) (v2 stack).
