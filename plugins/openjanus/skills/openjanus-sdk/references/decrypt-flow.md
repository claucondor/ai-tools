# Recovering a Balance From a Commitment (v0.3)

In v0.3 the on-chain state is a Pedersen commitment, not an ElGamal ciphertext.
There is **no on-chain decryption key** — the cleartext `(amount, blinding)` pair
lives on the user's device. This document covers:

1. The normal recovery path (look up locally persisted `(amount, blinding)`)
2. The exhaustive-search recovery path (`decryptBalance`) when the cleartext
   amount is lost but the blinding is still available
3. Why partial unwrap and identity-commitment handling work differently from v0.2

> Looking for the old ElGamal-on-BabyJubJub + BSGS decrypt flow? That lived in
> v0.2 and is removed in v0.3 along with the rest of the ElGamal API. See
> [migration-v02-to-v03.md](migration-v02-to-v03.md) for the rewrite.

## Pedersen commitment recap

```
commit = amount * G + blinding * H
```

`G` is the BabyJubJub generator. `H` is the second hash-to-curve generator used
by `BabyJub.sol`. Both `amount` and `blinding` are private scalars. The commitment
is computationally hiding under DDH and computationally binding under DLP.

The on-chain state per account is exactly `commitments[user] = Pedersen(amount, blinding)`
for a running residual balance, updated homomorphically on every `wrap` /
`shieldedTransfer` / `unwrap`.

## Path 1 — Read from local persistence (normal path)

Every wrap / transfer must be paired with a local persisted record. The simplest
shape:

```typescript
interface CommitRecord {
  user:      string;     // EVM address that owns the commitment
  amount:    string;     // bigint as string (cleartext residual balance)
  blinding:  string;     // bigint as string (the secret blinding factor)
  commit:    { x: string; y: string };   // for cross-checking against chain
  updatedAt: number;     // last-update tx timestamp / block
}
```

To "read" a balance, the app reads the record from its store and reconciles it
against the on-chain commitment:

```typescript
import { computeCommitment } from "@claucondor/sdk/crypto";

const onChain = await flow.balanceOfCommitment(userEvmAddr);
const local   = await loadCommitRecord(userEvmAddr);

const recomputed = await computeCommitment(BigInt(local.amount), BigInt(local.blinding));
if (recomputed.x !== onChain.x || recomputed.y !== onChain.y) {
  // The chain has moved (e.g. someone sent the user a shielded transfer the
  // app has not yet ingested). Refresh from the out-of-band channel that
  // delivers (transferAmount, transferBlinding) to the user.
  throw new Error("Local record stale — fetch latest transfer notifications");
}

console.log("Confirmed shielded balance:", local.amount);
```

## Path 2 — Exhaustive search with `decryptBalance`

If the user lost the cleartext `amount` but still has the `blinding` AND knows the
balance is within a small known range, the SDK ships `decryptBalance` for an
exhaustive Pedersen search:

```typescript
import { decryptBalance } from "@claucondor/sdk/crypto";

const commit  = await flow.balanceOfCommitment(userEvmAddr);
const amount  = await decryptBalance(commit, blinding, /* maxValue */ 1_000_000n);

if (amount === null) {
  throw new Error("Balance not found in range [0, 1_000_000] — increase maxValue");
}
console.log("Recovered amount:", amount);
```

This is O(maxValue) Pedersen recomputations — only suitable for small, known
balance ranges (e.g. a tipping UI capped at 100 FLOW). For a real wallet, use
local persistence (Path 1).

If you have lost BOTH the blinding and the cleartext, the commitment is
unrecoverable. This is by design — it is the same security property as losing
a private key.

## Recipient-discovery responsibility

Recipients of a `shieldedTransfer` cannot reconstruct `(transferAmount, transferBlinding)`
from on-chain state. Senders must deliver these out-of-band:

- Encrypted messaging channel (Signal, XMTP, end-to-end encrypted email)
- Push notification scheme tied to the app's own auth
- Off-chain receipt embedded in an unrelated tx (advanced)

Future SDK releases may ship a built-in recipient-discovery helper. As of v0.3
this is an app-level responsibility.

## Identity commitment (zero balance)

```typescript
import { isIdentityCommitment } from "@claucondor/sdk/crypto";

const commit = await flow.balanceOfCommitment(userEvmAddr);
if (isIdentityCommitment(commit)) {
  console.log("No shielded balance for this user");
}
// identity commitment: { x: 0n, y: 1n }
```

## Partial unwrap

v0.3 supports natural partial unwrap as a side-effect of the
`shieldedTransfer` + `unwrap` composition:

- To withdraw `K` FLOW while keeping the rest shielded, build a transfer proof
  that splits `oldBalance` into `(oldBalance - K)` residual and `K` transferred;
  then submit `unwrap(claimedAmount=K, ...)` carrying both proofs.
- The contract reduces the user's commitment to the residual and releases `K`
  FLOW from the custody pool to the named recipient.

This is exactly the `unwrap` flow documented in [quickstart.md](quickstart.md).

## Security: blinding storage

The blinding is equivalent to a private key for the residual balance. Apps must:

- Encrypt blindings at rest (Web Crypto API in browsers, OS keychain on native)
- Never log or expose them in HTTP responses or analytics
- Wrap them with a wallet-derived key (e.g. an FCL signature challenge) so that
  losing app state does not lose the blinding
- Plan for backup / export (the user must be able to extract their blindings to
  another device)

## See also

- [quickstart.md](quickstart.md) — Full v0.3 workflow walk-through
- [migration-v02-to-v03.md](migration-v02-to-v03.md) — v0.2 ElGamal API rewrite recipes
- [v03-architecture.md](v03-architecture.md) — Architecture + privacy validation
- [../../../openjanus-tokens/references/janus-token.md](../../../openjanus-tokens/references/janus-token.md) — JanusToken abstract base + Solidity ABI
