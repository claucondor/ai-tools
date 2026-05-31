# BabyJubJub Keypair Derivation

Each account that uses JanusFlow MemoKey (tip memos, recovery snapshots) needs a BabyJubJub
keypair. This document describes how to derive that keypair securely and deterministically.

> **Note:** The original `registerPubkey` pattern (v0.2 ElGamal accumulator) is deprecated.
> The current pattern uses `JanusFlow.MemoKey` — a Cadence resource published at
> `/public/openjanusMemoKey` and mirrored in the EVM proxy via `publishMemoKey(x, y)`.
> See `../../../openjanus-tokens/references/janus-flow.md` (MemoKey section).

## What the keypair is used for

| Key | Usage |
|-----|-------|
| Secret key `sk` | Decrypt ShieldedNote tip memos and recovery snapshots |
| Public key `PK = sk * G` | Published on-chain via `JanusFlow.publishMemoKey(x, y)`; senders encrypt ShieldedNotes to it |

The keypair is **separate** from the account's Flow signing key. Losing `sk` means
existing ShieldedNote memos become unreadable (but the keypair is re-derivable from the
wallet signature — see `sign-derive.md`).

## Derivation method: HKDF from Flow key material

The recommended approach is deterministic derivation using HKDF (HMAC-based Key Derivation
Function) so the keypair can be regenerated from the same seed without storage.

```typescript
import { hkdf } from "@noble/hashes/hkdf";
import { sha256 } from "@noble/hashes/sha256";
import { CURVE_P } from "@openjanus/sdk/primitives";

/**
 * Derive a BabyJubJub secret key from a Flow account private key.
 *
 * @param flowPrivateKeyHex  The account's Flow signing key as hex (32 bytes)
 * @param salt               Domain separation string — use a fixed, unique value per app
 * @returns sk as bigint, in range [1, CURVE_P - 1]
 */
function deriveSkFromFlowKey(flowPrivateKeyHex: string, salt: string = "openjanus/memokey/v1"): bigint {
  const ikm = Buffer.from(flowPrivateKeyHex, "hex");  // 32 bytes
  const derived = hkdf(sha256, ikm, salt, "babyjubjub-sk", 32);  // 32 bytes output
  const sk = BigInt("0x" + Buffer.from(derived).toString("hex")) % CURVE_P;
  return sk === 0n ? 1n : sk;  // 0 is invalid (identity scalar)
}
```

This produces a deterministic, domain-separated secret key. If the user has their Flow private
key, they can regenerate `sk` without persistent storage.

## Deriving the public key

```typescript
import { deriveBabyJubKeypairFromBytes } from "@openjanus/sdk/crypto";

// Recommended: derive from wallet signature (sign-derive pattern — see sign-derive.md)
const sig = await wallet.signMessage("openjanus/memokey/v1");
const keypair = await deriveBabyJubKeypairFromBytes(new TextEncoder().encode(sig));
// { privkey: bigint, pubkey: { x: bigint, y: bigint } }
```

## Validating the derived keypair

Before calling `JanusFlow.publishMemoKey`, always validate:

```typescript
import { isOnCurveLocal } from "@openjanus/sdk/primitives";

const { sk, pk } = keypair;

// 1. sk must be non-zero and less than the curve order
if (sk === 0n || sk >= CURVE_P) throw new Error("Invalid sk");

// 2. pk must be on the BabyJubJub curve
if (!isOnCurveLocal(pk.x, pk.y)) throw new Error("pk not on curve");

// 3. Publish on-chain via setup_memo_key.cdc (see janus-flow.md MemoKey section)
// JanusFlow.publishMemoKey(pubkeyX, pubkeyY) — only the pubkey goes on-chain
```

## Storage recommendations

| Environment | Recommendation |
|-------------|---------------|
| Backend / server | Derive from Flow key on demand via HKDF — no persistent storage needed |
| Browser app | Derive at login; store `sk` encrypted with Web Crypto API using a user password or hardware key |
| Mobile | Derive from biometric-unlocked account key; store encrypted in secure storage |
| Testing | Use hardcoded known scalars (see SDK test fixtures) |

**Never** store `sk` in plaintext. Never log it. Never send it in an HTTP response.

## Multi-account scenarios

If a user has multiple Flow accounts, each account should have its own keypair:

```typescript
const keypairA = deriveBabyJubKeypair(accountAPrivateKey);
const keypairB = deriveBabyJubKeypair(accountBPrivateKey);
// Different Flow keys → different BabyJubJub keypairs
```

If an account has multiple signing keys (key rotation), derive `sk` from the **current** signing
key. After key rotation, the new keypair should be registered on-chain (see pubkey rotation in
`../openjanus-tokens/references/janus-token.md`).

## Relationship between Flow address, COA, and BabyJubJub pubkey

```
Flow account key (secp256k1 or P-256)
    │
    └── HKDF → BabyJubJub sk  →  PK = sk * G  (registered in JanusToken)
    │
    └── Flow Cadence address (e.g., 0xd807...)
             │
             └── COA → EVM address (e.g., 0x0000...250d93ef...)
                        (keyed in JanusToken slot: PK registered against EVM address)
```

`JanusFlow.publishMemoKey(x, y)` on the EVM stores the pubkey at `msg.sender` (the COA EVM address).
The BabyJubJub keypair is logically tied to the account, accessed via the COA.

## See also

- `sign-derive.md` — Current recommended keypair derivation (sign-derive from wallet signature)
- `elgamal-architecture.md` — ECIES ShieldedNote architecture + historical ElGamal reference
- `../openjanus-sdk/references/quickstart.md` — SDK workflow including snapshot recovery
- `../openjanus-tokens/references/janus-flow.md` — MemoKey setup and EVM API
- `../openjanus-deploy/references/flow-account-vs-coa.md` — COA address lookup
