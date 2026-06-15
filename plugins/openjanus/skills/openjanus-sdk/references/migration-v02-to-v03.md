> Archived migration guide (v0.2 ElGamal → v0.3 Pedersen, circa 2024).
> For the **current** migration guide (v0.7 → v0.8), see [migration-to-v08.md](migration-to-v08.md).

---

# Migration: @openjanus/sdk v0.2.x → v0.3.0 (historical reference)

> Addresses shown in the table below are historical. Current canonical addresses are in
> `../../../openjanus-deploy/references/canonical-addresses.md`.

v0.3.0 was a **breaking** major release from v0.2. The on-chain contracts moved to new
addresses with a new ABI and a new commitment scheme.

## Why v0.3 broke v0.2

The v0.2.x JanusToken (ElGamal accumulator) had two privacy regressions:

1. **Cleartext `transferUnits` on every shielded transfer.** The on-chain call signature
   accepted a small-int amount in WHOLE FLOW and updated a public `locked[user]` ledger.
   Both `transferUnits` (in calldata) and the `locked` delta (in storage) leaked the
   transferred amount to any observer.

2. **Vuln 014 (SCALE unit mismatch)** in unwrap. The v0.2.1 patch fixed the unit mismatch
   but kept the leaky `locked[user]` bookkeeping.

v0.3 moved to a **fully shielded Pedersen-commit** scheme. Per-account storage became an
opaque BabyJubJub point (`commitments[user]`), updated homomorphically.

## API changes — Removed in v0.3

```ts
// v0.2 exports — REMOVED in v0.3
JanusToken.registerPubkey(pk)
JanusToken.wrap(to, flowUnits, nonce, encryptProof)
JanusToken.confidentialTransfer(to, transferUnits, nonce, encryptProof)
JanusToken.unwrap(recipient, claimedUnits, decryptProof)
JanusToken.encryptTo(...)
JanusToken.decryptAndUnwrap(...)

buildEncryptProof(...)               // ElGamal encrypt-consistency proof
buildDecryptProof(...)               // ElGamal decrypt-open proof

Ciphertext, EncryptedSlot, ElGamalKeypair, ElGamalCiphertext
ENCRYPT_CONSISTENCY_VERIFIER, DECRYPT_OPEN_VERIFIER
```

## API changes — v0.3 replacements

```ts
// New top-level API (v0.3)
import {
  JanusFlow,
  buildAmountDiscloseProof,
  buildShieldedTransferProof,
  computeCommitment,
  generateBlinding,
  flowToWei, weiToFlow, FLOW_SCALE,
} from "@openjanus/sdk";
```

### Recipe — wrap

```ts
// v0.2
await sdk.wrapAndEncrypt(amountUFix64, recipient, encryptProof, authz);

// v0.3
const wrapProof = await buildAmountDiscloseProof({ amount: amountWei, blinding });
await flow.wrap({ amountWei, txCommit: wrapProof.txCommit, amountProof: wrapProof.proof });
```

### Recipe — shieldedTransfer

```ts
// v0.2
await sdk.confidentialTransfer(recipient, encryptProof, authz);

// v0.3 (amount HIDDEN end-to-end)
const tProof = await buildShieldedTransferProof({
  oldBalance, oldBlinding, transferAmount, transferBlinding, newBlinding,
});
await flow.shieldedTransfer({
  to: recipient,
  publicInputs: tProof.publicInputs,
  proof: tProof.proof,
});
```

### Recipe — unwrap

```ts
// v0.2
await sdk.decryptAndUnwrap(amountUFix64, to, decryptProof, authz);

// v0.3
const amtProof = await buildAmountDiscloseProof({ amount: claimedAmountWei, blinding: transferBlinding });
const tProof = await buildShieldedTransferProof({ oldBalance, oldBlinding, ... });
await flow.unwrap({ claimedAmountWei, recipient, txCommit: amtProof.txCommit, ... });
```

## Storage model changes

v0.2 stored an ElGamal ciphertext `(C1, C2)` per account plus a registered BabyJubJub pubkey.
v0.3 stores a single `Point` commitment per account — no pubkey registration needed.

## Cadence template renames (v0.3)

| v0.2 | v0.3 |
|------|------|
| `TX_REGISTER_PUBKEY` | removed |
| `TX_WRAP_AND_ENCRYPT` | `TX_WRAP` |
| `TX_CONFIDENTIAL_TRANSFER` | `TX_SHIELDED_TRANSFER` |
| `TX_DECRYPT_AND_UNWRAP` | `TX_UNWRAP` |
| `SCRIPT_GET_SLOT` | `flow.balanceOfCommitment(addr)` on EVM |
| `SCRIPT_GET_PUBKEY` | removed |

## See also

- [migration-to-v08.md](migration-to-v08.md) — **Current** migration guide: v0.7 → v0.8
- [v03-architecture.md](v03-architecture.md) — v0.8.x architecture (document rewritten in-place)
