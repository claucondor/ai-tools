# Confidential Tipping — JanusToken on Flow (v0.8)

Uses JanusFlow's Pedersen-commitment scheme to provide genuine multi-sender
privacy: the recipient cannot learn individual tip amounts from on-chain data.
In v0.8, the `ShieldedInbox` delivers encrypted notes atomically on-chain;
recipients accumulate notes via `claimBatch()` instead of listening to events.

> **SDK version:** `@claucondor/sdk@^0.8.1-alpha.7`
> **MemoKey:** `MemoKeyRegistry` at `0x361bD4d037838A3a9c5408AE465d36077800ee6c` — one
> `publishMemoKey` covers all tokens.
> **ShieldedInbox:** `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` — per-user recipient mailbox.
> **ShieldedCheckpoint:** `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` — sender updates after each transfer.

## What this pattern provides

- **Amount privacy:** On-chain data reveals that *some* transfer happened, not how much
- **Multi-sender privacy:** Recipient learns the total, not per-sender amounts
- **Sender independence:** Senders do not need to coordinate or share blinding factors
- **On-chain note delivery via ShieldedInbox:** Each `shieldedTransfer` atomically deposits an encrypted note to the recipient's inbox (ECIES to recipient's MemoKey pubkey). No out-of-band channel required.
- **Batch accumulation via claimBatch:** Recipients drain up to N=10 inbox notes in a single Groth16 proof, accumulating all pending tips into their commitment slot.
- **Cross-device recovery:** `ShieldedCheckpoint` lets senders persist their new state for recovery from any device.

## Push-model warning

`ShieldedInbox.MAX_INBOX_NOTES = 10000`. If a recipient has 10000 unread notes, any new `shieldedTransfer` to them **reverts**. Build inbox-depth checks into your UI and guide recipients to run `claimBatch()` before sending the 10001st tip.

## High-level flow (v0.8)

```
1. Alice sets up a JanusFlow MemoKey (BabyJubJub pubkey published on-chain) — one time
2. Bob wraps 5 FLOW → wrapWithProof(nonce, commit, pA, pB, pC, snapshot, ephX, ephY)
   (Alice's slot unchanged; wrap is SENDER's own commitment update)
3. Bob shieldedTransfer(aliceCOA, publicInputs, proof, encryptedNoteTo, ephX, ephY)
   → ShieldedInbox atomically receives note encrypted to Alice's MemoKey pubkey
   → on-chain: no amount revealed
4. Carol and Dave repeat steps 2-3 with 3 FLOW and 12 FLOW respectively
5. Alice sees 3 notes in ShieldedInbox
6. Alice decrypts each inbox note → recovers (amount_i, blinding_i) → generates claimBatch proof
   → claimBatch(publicInputs, proof) → commitment updated to sum of all 3 tips
7. Alice unwraps when ready → receives FLOW
```

## Step-by-step implementation

### 1. Alice sets up MemoKey (one time)

```typescript
import { deriveMemoKeyFromSignature } from "@claucondor/sdk";
import { ethers } from "ethers";

const sig = await wallet.signMessage("OpenJanus MemoKey v1");
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
// memoKeypair.privkey: store in sessionStorage only — never on-chain

// Publish pubkey on-chain (covers all tokens)
await sdk.token('flow').publishMemoKey(memoKeypair, aliceWallet);
```

### 2. Publisher exposes Alice's pubkey

```typescript
const { x: pubX, y: pubY } = await sdk.token('flow').getMemoKeyFromRegistry(aliceCOAAddress);
// { x: bigint, y: bigint } — safe to publish publicly
```

### 3. Bob wraps and shielded-transfers to Alice

```typescript
import { OpenJanusSDK } from "@claucondor/sdk";

const sdk = new OpenJanusSDK({ network: "testnet" });
const flow = sdk.token('flow');
await flow.connectWithSigner(bobSigner);

const tipAmountWei = 5n * 10n**18n;  // 5 FLOW

// Step A: wrap into Bob's own commitment slot
await flow.wrapWithProof({ grossAmount: tipAmountWei }, bobWallet);

// Step B: shieldedTransfer to Alice — note deposited to Alice's ShieldedInbox automatically
await flow.shieldedTransfer({
  recipient: aliceCOAAddress,
  amount: tipAmountWei,
  currentBalance: bobBalance,
  currentBlinding: bobBlinding,
  recipientMemoKeyPubkey: { x: pubX, y: pubY },
}, bobWallet);

// Step C: sender updates own ShieldedCheckpoint (separate tx)
await sdk.checkpoint.update({
  token: flow.address,
  newBalance: bobBalance - tipAmountWei,
  newBlinding: bobNewBlinding,
}, bobWallet);
```

Carol and Dave follow identical steps with amounts 3 FLOW and 12 FLOW.

### 4. Alice reads her ShieldedInbox

```typescript
import { OpenJanusSDK } from "@claucondor/sdk";
const sdk = new OpenJanusSDK({ network: "testnet" });

const inboxNotes = await sdk.inbox.drain(aliceCOAAddress);
// Returns array of { ciphertext, ephPubkeyX, ephPubkeyY }

// Decrypt each note with Alice's MemoKey privkey
const decryptedNotes = await Promise.all(
  inboxNotes.map(note => sdk.inbox.decryptNote(note, memoKeypair.privkey))
);
// Each: { amount: bigint, blinding: bigint }
```

### 5. Alice claimBatch — accumulate all pending notes at once

```typescript
// SDK generates the claimBatch proof from the inbox notes
await flow.claimBatch({ inboxNotes: decryptedNotes, currentBalance: 0n, currentBlinding: 0n }, aliceWallet);
// Alice's commitment now encodes sum of all tips (5 + 3 + 12 = 20 FLOW equiv)
```

### 6. Alice unwraps

```typescript
await flow.unwrap({
  claimedAmount: 20n * 10n**18n,
  recipient: aliceEvmAddr,
  currentBalance: aliceBalance,
  currentBlinding: aliceBlinding,
}, aliceWallet);
// Alice receives 20 FLOW minus 0.1% fee
```

## Privacy properties

| Property | JanusFlow (Pedersen + Groth16) |
|----------|-------------------------------|
| Amount hidden from observers | Yes (shieldedTransfer and commitment slot) |
| Per-sender amount hidden from recipient | Yes — each inbox note is ECIES-encrypted to recipient MemoKey |
| Sender address visible on-chain | Yes — unavoidable (EVM msg.sender) |
| Coordination required between senders | No — independent wraps + shieldedTransfer |
| Boundary visibility | `wrapWithProof` leaks msg.value (by design) |

## State the app must persist

| Data | Owner | Why |
|------|-------|-----|
| `memoKeypair.privkey` | Alice | Decrypts inbox notes; derived from wallet sig, can be re-derived |
| `(amount_i, blinding_i)` per note | Alice | Required for claimBatch or unwrap proofs |
| Sender's `(newBalance, newBlinding)` | Sender | Persisted in ShieldedCheckpoint for cross-device recovery |

## Gas and CU notes

- wrapWithProof Cadence TX: near 9999 CU, ~300k EVM gas (AmountDisclose Groth16 verify)
- shieldedTransfer Cadence TX: near 9999 CU, ~300k EVM gas (ConfidentialTransfer Groth16 + ShieldedInbox deposit)
- claimBatch (N=10): ~6000-8500 CU
- BSGS table build for 1M range: ~10ms, ~1000 entries

## See also

- [funding-with-amount-privacy.md](funding-with-amount-privacy.md) — Public fundraising use case
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — Full SDK quick start
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — BSGS decrypt guide
