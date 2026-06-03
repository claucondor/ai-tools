# Sign-Derive: Deterministic BabyJubJub Keypairs from Wallet Signatures

SDK version: `@claucondor/sdk@0.6.5`
Source: `@claucondor/sdk/src/crypto/derive-keypair.ts`

> **Security invariant:** The BabyJubJub privkey MUST NEVER go on-chain.
> `deriveMemoKeyFromSignature` + `publishMemoKey` take only `(pubkeyX, pubkeyY)`.
> The `MemoKeyRegistry` at `0x05D104962ff087441f26BA11A1E1C3b9E091D663` is the
> single source of truth — one `publishMemoKey` call covers all 4 tokens.
> The privkey lives exclusively in `sessionStorage`.

> **v0.6.5 change:** `deriveMemoKeyFromSignature` replaces the lower-level
> `deriveBabyJubKeypairFromBytes` as the recommended entry point. Both exist;
> `deriveMemoKeyFromSignature` wraps the ethers signature bytes pattern.

---

## What

Sign-derive is a pattern for producing a deterministic BabyJubJub keypair from
a wallet signature rather than from a random seed. The SDK primitive is:

```typescript
deriveBabyJubKeypairFromBytes(
  inputBytes: Uint8Array,
  context?: string        // default: "openjanus/memokey/v1"
): Promise<BabyJubKeypair>
```

Given the same `inputBytes` and `context` the function always returns the same
`{ privkey: bigint, pubkey: { x: bigint, y: bigint } }`. The wallet never
needs to sign twice for the same context; the derived keypair is stable across
browsers, devices, and sessions.

---

## Why

BabyJubJub keypairs in OpenJanus serve two roles:

| Role | Used by |
|------|---------|
| `privkey` | ECIES decryption of `ShieldedNote` memo payloads |
| `pubkey` | Published on-chain for senders to encrypt to (MemoKey resource) |

These keypairs must be **recoverable** after the user clears their browser or
switches devices. Three naive approaches all fail:

| Approach | Problem |
|----------|---------|
| `localStorage` | Cleared on browser reset; not portable across devices |
| `sessionStorage` | Lost on tab close; a hard session expiry forces re-derivation (see Trade-offs) |
| Encrypted on-chain | Flow Wallet does not expose decryption of arbitrary ciphertext; no path today |
| New random keypair each login | Every new keypair requires re-registering the pubkey on-chain and invalidates historical memos |

**Sign-derive** solves this without any persistent storage: the wallet's signing
key is the root secret. Any device the user can authenticate with produces the
same keypair automatically — no backup phrases, no migration.

Conceptual precedents: Phantom wallet's seed-key derivation, Argent's encrypted
messaging keys, EIP-2334 BLS12 key trees (same principle: deterministic
derivation from a root secret into application-specific sub-keys).

---

## The SDK Primitive

```typescript
import { deriveBabyJubKeypairFromBytes } from "@claucondor/sdk";
// also available from the crypto subpath:
import { deriveBabyJubKeypairFromBytes } from "@claucondor/sdk/crypto";
```

### Signature

```typescript
/**
 * Derive a deterministic BabyJubJub keypair from arbitrary secret bytes.
 *
 * @param inputBytes  Secret entropy source (wallet signature, seed, …).
 *                    Must be ≥ 32 bytes. Wallet signatures (65 B) are ideal.
 * @param context     Domain-separation label for key separation.
 *                    Defaults to "openjanus/memokey/v1".
 * @returns           BabyJubKeypair { privkey: bigint, pubkey: { x, y } }
 *                    privkey ∈ [1, l); pubkey = privkey × BASE8
 */
export async function deriveBabyJubKeypairFromBytes(
  inputBytes: Uint8Array,
  context: string = "openjanus/memokey/v1"
): Promise<BabyJubKeypair>
```

### Return type

```typescript
interface BabyJubKeypair {
  privkey: bigint;          // scalar in [1, BABYJUB_SUBGROUP_ORDER)
  pubkey: {
    x: bigint;              // BabyJub curve x-coordinate
    y: bigint;              // BabyJub curve y-coordinate
  };
}
```

### Constraint

`inputBytes.length < 32` throws synchronously with a descriptive error. Pass at
least 32 bytes; a wallet signature (65 bytes) is the recommended minimum.

---

## How It Works Internally

```
IKM   = inputBytes                             (wallet signature, ≥32 B)
salt  = UTF-8("openjanus/derive-babyjub/v1")   (hard-coded, versioned)
info  = UTF-8(context)                         (caller-supplied)
L     = 64 bytes

output_bytes = HKDF-SHA256(IKM, salt, info, L)
output_int   = big-endian decode(output_bytes) as BigInt
scalar       = output_int mod BABYJUB_SUBGROUP_ORDER
if scalar == 0: scalar = 1                    (probability ≈ 2⁻²⁵¹; defensive only)

pubkey = scalar × BASE8                        (BabyJub scalar multiplication)
```

**Why 64 bytes?** HKDF produces a 512-bit integer. Reducing a 512-bit uniform
random integer modulo the 251-bit BabyJub subgroup order leaves a statistical
bias of less than 2⁻¹²⁷ — negligible for all practical purposes.

**Why WebCrypto?** The HKDF operation uses `SubtleCrypto.deriveBits` with the
key flagged `extractable: false`. The IKM bytes do not persist in a
`CryptoKey` object after the call returns. The function falls back to Node.js
`crypto.webcrypto` in Node 18+ (no `node:crypto` shim needed).

**Why a hard-coded salt?** The salt domain-separates all OpenJanus BabyJub
derivations from all other HKDF usages in the SDK. It is versioned (`/v1`) so
a future breaking change in the derivation scheme can coexist with existing
keys by bumping the salt without breaking old keys.

---

## Usage Pattern

### 1. Prompt for a wallet signature

```typescript
import * as fcl from "@onflow/fcl";

const SIGN_DERIVE_MESSAGE = "OpenJanus MemoKey v1";

// FCL signUserMessage returns composite signatures from each signing key.
// Concat the raw sig bytes from all composites to form the HKDF input.
async function collectSignatureBytes(message: string): Promise<Uint8Array> {
  const composites = await fcl.signUserMessage(message);
  // Each composite: { addr, keyId, signature } — signature is hex-encoded
  const allBytes: number[] = [];
  for (const c of composites) {
    const bytes = Array.from(Buffer.from(c.signature, "hex"));
    allBytes.push(...bytes);
  }
  return new Uint8Array(allBytes);
}
```

> The signature bytes **never travel to the chain or to any server**. They are
> used locally as HKDF input material and then discarded.

### 2. Derive the keypair

```typescript
import { deriveBabyJubKeypairFromBytes } from "@claucondor/sdk/crypto";

const sigBytes = await collectSignatureBytes(SIGN_DERIVE_MESSAGE);
const keypair  = await deriveBabyJubKeypairFromBytes(
  sigBytes,
  "openjanus/memokey/v1"
);
// keypair.privkey — keep in memory only; never log, never serialize to disk
// keypair.pubkey  — safe to publish; register on-chain via MemoKey resource
```

### 3. Cache in sessionStorage (optional)

Caching the **pubkey** in sessionStorage is safe (it is already public). Cache
the privkey only if your UX requires re-use within a session without re-prompting
the user — understand the implications before doing so (see Trade-offs).

```typescript
// Safe to cache — already public material
sessionStorage.setItem(
  "oj:memokey:pubkey",
  JSON.stringify({ x: keypair.pubkey.x.toString(), y: keypair.pubkey.y.toString() })
);

// Only cache privkey if you accept the session-expiry trade-off.
// Do NOT cache in localStorage.
sessionStorage.setItem("oj:memokey:privkey", keypair.privkey.toString());
```

### 4. Register the pubkey on-chain (first-time setup)

In v0.6.5, use the `publishMemoKey` adapter method — it writes to the shared
`MemoKeyRegistry` (`0x05D104962ff087441f26BA11A1E1C3b9E091D663`). One call covers all 4 tokens.

```typescript
import { OpenJanusSDK, deriveMemoKeyFromSignature } from "@claucondor/sdk";
import { ethers } from "ethers";

const sdk = new OpenJanusSDK({ network: "testnet" });
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));

// One publish covers flow / wflow / mockusdc / mockft
await sdk.token('flow').publishMemoKey(memoKeypair, wallet);
```

For FCL-only environments (no ethers signer), you can still use the low-level pattern:

```typescript
import { getRecipientMemoPubkey } from "@claucondor/sdk/crypto";

const existing = await getRecipientMemoPubkey(userFlowAddress);
if (!existing) {
  await fcl.mutate({
    cadence: TX_SETUP_MEMO_KEY,           // from @claucondor/sdk/tokens
    args: () => [
      { type: "UInt256", value: keypair.pubkey.x.toString() },
      { type: "UInt256", value: keypair.pubkey.y.toString() },
    ],
    limit: 9999,
  });
}
```

### Full inline example (v0.6.5 — ethers signer)

```typescript
import { deriveMemoKeyFromSignature } from "@claucondor/sdk";
import { ethers } from "ethers";

async function getMemoKeypair(wallet: ethers.Signer) {
  // 1. Get or re-derive from session cache.
  const cached = sessionStorage.getItem("oj:memokey:privkey");
  if (cached) {
    const { pubkeyFromPrivkey } = await import("@claucondor/sdk/crypto");
    const privkey = BigInt(cached);
    const pubkey  = await pubkeyFromPrivkey(privkey);
    return { privkey, pubkey };
  }

  // 2. Sign the derivation message.
  const sig = await wallet.signMessage('OpenJanus MemoKey v1');

  // 3. Derive deterministic BabyJub keypair.
  const keypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));

  // 4. Cache privkey for this session only.
  sessionStorage.setItem("oj:memokey:privkey", keypair.privkey.toString());

  return keypair;
}
```

### FCL variant (no ethers signer)

```typescript
import * as fcl from "@onflow/fcl";
import { deriveBabyJubKeypairFromBytes } from "@claucondor/sdk/crypto";

async function getMemoKeypairFCL() {
  const cached = sessionStorage.getItem("oj:memokey:privkey");
  if (cached) {
    const { pubkeyFromPrivkey } = await import("@claucondor/sdk/crypto");
    const privkey = BigInt(cached);
    const pubkey  = await pubkeyFromPrivkey(privkey);
    return { privkey, pubkey };
  }

  const composites = await fcl.signUserMessage("OpenJanus MemoKey v1");
  const sigBytes = new Uint8Array(
    composites.flatMap((c) => Array.from(Buffer.from(c.signature, "hex")))
  );

  const keypair = await deriveBabyJubKeypairFromBytes(sigBytes, "openjanus/memokey/v1");
  sessionStorage.setItem("oj:memokey:privkey", keypair.privkey.toString());

  return keypair;
}
```

---

## Context Strings

Convention: `"openjanus/<purpose>/v<n>"` — lower-case, forward-slash separated,
version suffix mandatory.

| Context string | Purpose | Status |
|----------------|---------|--------|
| `"openjanus/memokey/v1"` | Persistent memo-encryption keypair (ECIES payload decryption) | **Active** — JanusFlow MemoKey, PrivateTip, recovery snapshots |
| `"openjanus/viewkey/v1"` | Read-only audit key (can verify notes without spending) | Reserved — not yet deployed |
| `"openjanus/spendkey/v1"` | Spend-authorization key (future shielded spend proofs) | Reserved — not yet deployed |

Rules:
- Never reuse a context string for a different cryptographic role.
- Bump the version suffix (`/v2`, `/v3`, …) if the on-chain registration
  format or circuit interface changes in a way that makes old and new keys
  incompatible.
- New applications should pick a distinct prefix to avoid any theoretical
  cross-app collisions even though HKDF context-separates them already:
  `"myapp/memokey/v1"` is preferable to reusing `"openjanus/memokey/v1"`.

---

## Properties

- **Determinism.** Same wallet + same context always produces the same scalar.
  Users cannot accidentally create two incompatible keys for the same role.
- **Context separation.** Changing one character in `context` produces a
  cryptographically independent scalar. Memo key and view key from the same
  wallet signature leak nothing about each other.
- **No on-chain secret material.** The privkey never leaves the client. The
  signature bytes (the HKDF input) are ephemeral — they are consumed and
  discarded inside `deriveBabyJubKeypairFromBytes`.
- **Multi-device by construction.** Any browser or device where the user can
  authenticate with the same wallet key derives the same keypair. No export,
  import, or backup phrase required.
- **Wallet-agnostic.** Any FCL-compatible wallet that implements
  `fcl.signUserMessage` works. The derivation does not depend on the wallet's
  specific signing algorithm (P-256 or secp256k1 both produce usable entropy).
- **Pure / stateless.** The function has no side effects; concurrent calls are
  safe. It only calls WebCrypto HKDF — no network, no chain access.

---

## Anti-Patterns

**Do not cache `privkey` in `localStorage`.**
`localStorage` persists across browser restarts and is readable by any
same-origin JavaScript. An XSS vulnerability would expose the privkey
permanently. Use `sessionStorage` (scoped to the tab) or keep privkey in
memory only and re-derive on demand.

**Do not reuse `privkey` for non-BabyJub operations.**
The derived scalar lives in the BabyJub subgroup, not on secp256k1 or P-256.
Do not use it as an ECDSA signing key, as a symmetric key, or as an IV. It is
only safe to use as a BabyJub private scalar.

**Do not change the context string without versioning.**
If you rename `"openjanus/memokey/v1"` to `"openjanus/memokey/v2"` in
production, existing users will derive a different keypair, losing access to
all previously encrypted memos and invalidating their registered on-chain
pubkey. Only bump the version when a coordinated migration with on-chain
re-registration is planned.

**Do not use the raw wallet signature for any other purpose after passing it to
`deriveBabyJubKeypairFromBytes`.**
The signature is high-entropy secret material that becomes the root of the
derived key tree. Sending it to a server, logging it, or displaying it in the
UI exposes the ability for anyone with the signature to re-derive all context
keys.

**Do not pass low-entropy inputs.**
Block numbers, user passwords, or fixed strings do not provide the 32+ bytes of
CSPRNG-quality entropy that HKDF requires. The function will accept them (as
long as they are ≥ 32 bytes) but the derived key will be weak. Use a wallet
signature or CSPRNG output.

**Do not call `deriveBabyJubKeypairFromBytes` with the same context for two
different logical roles.**
Even if two roles could technically share a key, keeping them separated by
context makes future key rotation or revocation much simpler and prevents
accidental cross-role attacks.

---

## Trade-offs

### sessionStorage vs in-memory vs localStorage

| Storage | Privacy | Persistence | Recommendation |
|---------|---------|-------------|----------------|
| In-memory (module variable) | Best — GC'd on tab close | Lost on refresh | Preferred for high-security contexts |
| `sessionStorage` | Good — cleared on tab close | Survives within-session navigations | Acceptable UX trade-off for most apps |
| `localStorage` | Poor — persists indefinitely | Survives browser restarts | **Do not use for privkey** |

### User friction on session expiry

When the derived keypair is kept in `sessionStorage` or memory only, the user
must re-sign the derivation message on every new session (new tab, browser
restart). This involves one wallet popup. For most apps one popup at login is
acceptable. If your UX budget is tighter, store only the **pubkey** persistently
and prompt for the privkey re-derivation lazily (only when decryption is actually
needed).

### Key rotation

If a user rotates their Flow signing key (key weight management), the same
wallet address will produce a different signature, and therefore a different
derived keypair. The previous pubkey registered on-chain will no longer be
derivable from the new signing key without a migration step. Plan for this if
your app targets power users who perform key rotation.

### Multiple signing keys on one account

Flow accounts can have multiple signing keys with different weights. FCL
`signUserMessage` may return composite signatures from all required signers
(depending on the account's key-weight threshold). The derivation function
concatenates all composite bytes before hashing. This means a multi-sig
account produces consistent results as long as the signer set and key weights
are unchanged — but any key rotation or threshold change breaks derivation
continuity.

---

## Related Primitives in the OpenJanus Stack

- **`encryptText` / `decryptText`** — ECIES-on-BabyJub text encryption. The
  derived keypair's `pubkey` is the recipient key passed to `encryptText`.
  See `openjanus-sdk/SKILL.md` § Memo encryption primitives.

- **`ShieldedNote`** — on-chain Cadence resource that stores `(ciphertext,
  ephemeralPubkey)` emitted during a shielded transfer. The receiver calls
  `decryptText(note.ciphertext, note.ephemeralPubkey, derivedPrivkey)` to
  read the memo.

- **`MemoKey` resource** — Cadence resource at `/storage/openjanusMemoKey`,
  published as a capability at `/public/openjanusMemoKey`. Holds the user's
  BabyJub `pubkey` (not the privkey) so senders can look it up without an
  on-chain write per message.

- **`keypair-derivation.md`** (this folder) — the older HKDF-from-Flow-private-key
  pattern. Sign-derive supersedes it for browser contexts where the raw Flow
  private key is not accessible. Use sign-derive for all new integrations.

- **`elgamal-architecture.md`** (this folder) — full ElGamal accumulator design;
  the same BabyJub keypair can be used as the ElGamal recipient key if your app
  also uses the accumulator model.

- **`openjanus-primitives/references/babyjub.md`** — BabyJub curve constants,
  `isOnCurveLocal`, `BASE8`, subgroup order `l`.

### App integration reference

The canonical integration lives at:

```
/home/oydual3/zkapps/private-tip-v1/web/lib/memo-key-derive.ts
```

(Reference the file at that path for the production-tested implementation of
the sign-derive pattern.)
