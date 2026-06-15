# Note and Snapshot Decryption (v0.8)

v0.8 uses ECIES on BabyJubJub + AES-GCM for two distinct encrypted payloads:

| Payload | Encrypted to | Content | Stored in |
|---------|-------------|---------|-----------|
| **Snapshot** | Sender's own MemoKey pubkey | `{ balance, blinding }` | `ShieldedCheckpoint` slot |
| **Note** | Recipient's MemoKey pubkey | `{ amount, blinding, memo? }` | `ShieldedInbox` (EVM or Cadence) |

There is no on-chain decryption key. The BabyJub privkey lives in the caller's
sessionStorage (via `MemoKeySession`) or in memory.

---

## Step 1 — Derive and cache the MemoKey privkey

```typescript
import { deriveMemoKeyFromSignature, MemoKeySession } from "@claucondor/sdk";
import { ethers } from "ethers";

// One wallet signature → deterministic BabyJub keypair (HKDF-SHA256 internally)
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const keypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
// keypair.privkey: bigint scalar in [1, BABYJUB_SUBGROUP_ORDER)
// keypair.pubkey:  { x: bigint, y: bigint } — published on-chain in MemoKeyRegistry

// Cache in sessionStorage (cleared on tab close)
MemoKeySession.set(keypair.privkey);

// FCL path (no ethers signer):
import { deriveBabyJubKeypairFromBytes } from "@claucondor/sdk";
const composites = await fcl.signUserMessage("OpenJanus MemoKey v1");
const sigBytes = new Uint8Array(
  composites.flatMap((c) => Array.from(Buffer.from(c.signature, "hex")))
);
const kp = await deriveBabyJubKeypairFromBytes(sigBytes, "openjanus/memokey/v1");
MemoKeySession.set(kp.privkey);
```

On page reload, restore from session cache (avoids wallet popup on every navigation):

```typescript
const privkey = MemoKeySession.get();
// null if session expired — prompt wallet signature again
if (!privkey) {
  // re-derive
}
```

---

## Step 2 — Decrypt the ShieldedCheckpoint snapshot

`ShieldedCheckpoint.read(token)` is owner-gated. The SDK reads and decrypts
in one call:

```typescript
import { ShieldedCheckpointClient, TOKEN_REGISTRY } from "@claucondor/sdk";

const cp = new ShieldedCheckpointClient();
const privkey = MemoKeySession.get()!;

// Reads ShieldedCheckpoint via eth_call simulated as COA owner
const snapshot = await cp.readAndDecrypt(wallet, privkey, TOKEN_REGISTRY.flow.proxy);
// null → no checkpoint yet for this (owner, token) pair
// snapshot.balance   — bigint (attoFLOW / token units)
// snapshot.blinding  — bigint (Pedersen blinding scalar)
// snapshot.lastConsumedNoteIndex — bigint (cursor into EVM ShieldedInbox)
// snapshot.version   — bigint
```

Or decrypt manually if you have the raw checkpoint bytes:

```typescript
import { decryptSnapshot } from "@claucondor/sdk";

const snap = await decryptSnapshot(
  encryptedSnapshot,        // Uint8Array
  { x: ephPubkeyX, y: ephPubkeyY },
  privkey
);
// snap.balance, snap.blinding — or null on decryption failure
```

---

## Step 3 — Decrypt ShieldedInbox notes (EVM path)

```typescript
import { ShieldedInboxClient } from "@claucondor/sdk";

const inbox = new ShieldedInboxClient();
const privkey = MemoKeySession.get()!;

// Drain all notes and decrypt
const { decrypted, failed } = await inbox.drainAndDecrypt(wallet, privkey);
for (const { content, inboxIndex } of decrypted) {
  console.log(`Note[${inboxIndex}]: amount=${content.amount}, memo=${content.memo}`);
}
// failed: notes that couldn't be decrypted (wrong key or corrupt ciphertext)
```

Or decrypt a single note:

```typescript
import { decryptNote } from "@claucondor/sdk";

const content = await decryptNote(
  note.ciphertext,          // Uint8Array from ShieldedInbox
  { x: note.ephPubkeyX, y: note.ephPubkeyY },
  privkey
);
// content.amount, content.blinding, content.memo (optional)
```

---

## Step 4 — Decrypt Cadence ShieldedInbox notes (mockft path)

JanusFT stores inbox notes in the Cadence `ShieldedInbox` resource, not the EVM contract.
`getPortfolioView` handles this automatically when `cadenceAddress` is provided.

Manual access:

```typescript
import { getCadenceInboxNotes } from "@claucondor/sdk/inbox";
import { decryptNote } from "@claucondor/sdk";

const notes = await getCadenceInboxNotes(cadenceAddr, {
  flowAccessNode: "https://rest-testnet.onflow.org",
  inboxContractAddress: "0x4b6bc58bc8bf5dcc",
});

for (const note of notes) {
  const content = await decryptNote(
    note.ciphertext,
    { x: note.ephPubkeyX, y: note.ephPubkeyY },
    privkey
  );
  console.log("FT note:", content.amount, content.blinding);
}
```

---

## ECIES cipher format

The same ECIES primitive is used for both snapshots and notes:

```
Encrypt(plaintext, recipientPubkey):
  r     = randomBabyJubScalar()           ← ephemeral scalar
  R     = r * BASE8                       ← ephemeral pubkey (transmitted)
  shared = r * recipientPubkey            ← ECDH shared point
  key   = HKDF-SHA256(shared.x || shared.y)  ← 32-byte AES key
  IV    = random 12 bytes
  ciphertext = AES-256-GCM(key, IV, plaintext)
  output = IV || ciphertext || tag (16 bytes)

Decrypt(ciphertext, ephemeralPubkey, privkey):
  shared = privkey * ephemeralPubkey       ← ECDH (same shared point)
  key   = HKDF-SHA256(shared.x || shared.y)
  plaintext = AES-256-GCM-decrypt(key, IV, ciphertext)
```

The payload schema differs between snapshot and note:
- Snapshot JSON: `{ balance: string, blinding: string }`
- Note JSON: `{ amount: string, blinding: string, memo?: string }`

Both are serialized as JSON strings before AES-GCM encryption.

---

## decryptAnyNote — ambiguous schema

If you don't know whether a ciphertext is a snapshot or a note:

```typescript
import { decryptAnyNote } from "@claucondor/sdk";

const result = await decryptAnyNote(ciphertext, ephemeralPubkey, privkey);
// result.type === "snapshot" → { balance, blinding }
// result.type === "note"     → { amount, blinding, memo? }
// result === null            → decryption failed
```

---

## sessionStorage caching policy

| Material | Storage | Rationale |
|----------|---------|-----------|
| `memoPrivkey` (bigint) | sessionStorage only | Cleared on tab close; not visible cross-origin |
| `memoPublickey` | sessionStorage | Already public; safe to cache |
| Decrypted note amounts | Memory only | Never persist cleartext amounts to disk |
| Checkpoint `blinding` | Memory / encrypted IndexedDB | Equivalent to a private key — protect accordingly |

`MemoKeySession` wraps the sessionStorage pattern:

```typescript
import { MemoKeySession } from "@claucondor/sdk/session";

MemoKeySession.set(privkey);     // writes to sessionStorage
MemoKeySession.get();            // reads; returns null if expired
MemoKeySession.clear();          // logout
```

---

## Security: blinding storage

The blinding scalar is equivalent to a private key for the residual balance. Apps must:

- Never log or expose blindings in HTTP responses or analytics
- Encrypt blindings at rest (Web Crypto API in browsers, OS keychain on native)
- Wrap with a wallet-derived key so that losing app state does not lose the blinding
- The ShieldedCheckpoint slot is the canonical on-chain backup — always update it after
  each `shieldedTransfer` or `claimBatch`

---

## See also

- [recovery.md](recovery.md) — Full recovery flow: fresh slot, checkpoint + inbox combination
- [quickstart.md](quickstart.md) — Full workflow walk-through
- [v03-architecture.md](v03-architecture.md) — ShieldedCheckpoint + ShieldedInbox protocol design
