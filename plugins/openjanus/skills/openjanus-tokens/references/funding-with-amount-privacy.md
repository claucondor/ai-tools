# Funding with Amount Privacy (v0.8)

This pattern describes how to build a public fundraising or crowdfunding application where individual contribution amounts are hidden from public observers, while the total raised can be verified on-chain (via the slot ciphertext) and eventually disclosed by the recipient.

> **v0.8 note:** Contributions are delivered via `shieldedTransfer` → `ShieldedInbox`. Recipients accumulate notes via `claimBatch()` instead of holding each commitment separately. See the push-model warning below.

## Use cases

- **Anonymous donations**: Donors contribute to a cause without revealing how much they gave
- **Quadratic funding rounds**: Individual contributions are private until the round closes
- **Payroll**: An employer distributes salaries to employees; amounts are confidential between employer and each employee
- **Bounties with private payouts**: Multiple sponsors fund a bounty independently without coordinating

This pattern builds on [confidential-tipping.md](confidential-tipping.md) but focuses on the fundraising lifecycle (contribution period → reveal → disbursement).

## Architecture

```
Phase 1: Setup
  Recipient sets up a JanusFlow.MemoKey (BabyJubJub pubkey published on-chain)

Phase 2: Contribution Period
  Many contributors:
    1. wrapWithProof(nonce, commit, pA, pB, pC, snapshot, ephX, ephY) — amount hides in commitment
    2. shieldedTransfer(recipient, publicInputs, proof, encryptedNoteTo, ephX, ephY)
       → ShieldedInbox delivers note to recipient automatically
  On-chain: each shieldedTransfer accumulates into recipient's commitment via homomorphic add
  Off-chain: individual amounts are private
  PUSH-MODEL WARNING: if recipient inbox fills (10000 notes), shieldedTransfer reverts

Phase 3: Close + Tally
  Recipient reads ShieldedInbox for all deposited notes
  Recipient decrypts each note with MemoKey privkey → recovers (amount_i, blinding_i)
  Recipient calls claimBatch(publicInputs, proof) to accumulate all notes into one commitment slot
  (If > N=10 notes, multiple claimBatch calls are needed)

Phase 4: Disbursement
  Recipient calls unwrap on their accumulated commitment slot
  Recipient's FlowToken.Vault receives FLOW
```

## Implementation

### Setup: recipient publishes MemoKey

```typescript
import { deriveBabyJubKeypairFromBytes } from "@claucondor/sdk/crypto";
// See janus-flow.md MemoKey section for setup_memo_key.cdc transaction template

// Derive deterministic BabyJub keypair from wallet signature
const sig = await wallet.signMessage("openjanus/memokey/v1");
const keypair = await deriveBabyJubKeypairFromBytes(new TextEncoder().encode(sig));
// keypair.privkey: store in sessionStorage only — never on-chain
// Publish keypair.pubkey via setup_memo_key.cdc
```

### Contribution period: any donor contributes

```typescript
import { JanusFlow } from "@claucondor/sdk/tokens";
import { buildAmountDiscloseProof, generateBlinding, flowToWei, encryptText } from "@claucondor/sdk/crypto";
import { JanusFlowCadence } from "@claucondor/sdk/tokens";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.connectWithSigner(donorSigner);

// Fetch recipient's MemoKey pubkey
const cadence = new JanusFlowCadence();
await cadence.configure();
const recipientPK = await cadence.getMemoPubkey(RECIPIENT_CADENCE_ADDR);

async function contribute(amountFlow: bigint, donorSigner: ethers.Signer) {
  const amountWei = flowToWei(amountFlow);

  // 1. Wrap donor's own commitment
  await sdk.wrapWithProof({ grossAmount: amountWei }, donorSigner);

  // 2. ShieldedTransfer to recipient — note delivered via ShieldedInbox automatically
  await sdk.shieldedTransfer({
    recipient: RECIPIENT_COA_ADDRESS,
    amount: amountWei,
    currentBalance: donorBalance,
    currentBlinding: donorBlinding,
    recipientMemoKeyPubkey: recipientPK,
  }, donorSigner);
  // No out-of-band delivery needed — ShieldedInbox handles it
}

// Multiple donors contribute independently
await contribute(10n, aliceSigner);
await contribute(25n, bobSigner);
await contribute(100n, carolSigner);
```

### Close: recipient reads inbox and claimBatch

```typescript
import { OpenJanusSDK } from "@claucondor/sdk";
const sdk = new OpenJanusSDK({ network: "testnet" });
const flow = sdk.token('flow');

// Read inbox notes
const inboxNotes = await sdk.inbox.drain(RECIPIENT_COA_ADDRESS);
const decryptedNotes = await Promise.all(
  inboxNotes.map(note => sdk.inbox.decryptNote(note, keypair.privkey))
);
// Each: { amount: bigint, blinding: bigint }

const total = decryptedNotes.reduce((sum, n) => sum + n.amount, 0n);
console.log("Total raised:", total); // 135 * 10^18 attoFLOW

// Accumulate all notes into recipient's commitment slot (up to N=10 per call)
await flow.claimBatch({ inboxNotes: decryptedNotes }, recipientSigner);
```

### Disbursement: receive FLOW

```typescript
// Unwrap the accumulated commitment
await flow.unwrap({
  claimedAmount: total,
  recipient: recipientEvmAddr,
  currentBalance: total,
  currentBlinding: accumulatedBlinding,
}, recipientSigner);
// Recipient's FlowToken.Vault receives FLOW (less 0.1% boundary fee)
```

## Privacy guarantees

| Observable on-chain | Not observable |
|--------------------|---------------|
| Sender address (EVM `msg.sender`) | Any individual contribution amount |
| `wrap` boundary: `msg.value` and `Wrapped` event | Total raised (until recipient tallies and reveals) |
| Recipient's MemoKey pubkey | Contents of ShieldedNotes (end-to-end encrypted) |
| `unwrap` amount at disbursement boundary | Which donors contributed how much |

**Important:** The sender's EVM address is visible on-chain. Only amounts are hidden. For sender address privacy, combine with a stealth address pattern (future roadmap).

## Funding with a cap

If the fundraiser has a hard cap (e.g., 1000 FLOW), enforce it in a Cadence wrapper
by tracking `totalLocked()` on the EVM proxy (which leaks the aggregate by design):

```cadence
let locked = JanusFlow.getTotalLocked()   // cleartext aggregate — OK to check
if locked >= cap { panic("Fundraiser cap reached") }
JanusFlow.wrap(...)
```

## CU and gas costs at scale

For a fundraiser with 100 donors:
- Each `wrap` Cadence TX: ~9000 CU, ~300k EVM gas
- All 100 contributions: 100 transactions (parallel, no ordering required)
- Each `unwrap` at disbursement: ~9000 CU, two Groth16 verifies

## See also

- [confidential-tipping.md](confidential-tipping.md) — Per-person tip use case
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — SDK setup
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — Balance recovery from commitment
- [../../../openjanus-elgamal/references/elgamal-architecture.md](../../../openjanus-elgamal/references/elgamal-architecture.md) — ECIES ShieldedNote architecture
