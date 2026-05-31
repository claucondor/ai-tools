# Funding with Amount Privacy

This pattern describes how to build a public fundraising or crowdfunding application where individual contribution amounts are hidden from public observers, while the total raised can be verified on-chain (via the slot ciphertext) and eventually disclosed by the recipient.

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
  Many contributors: wrap(amountWei, txCommit, amountProof) — amount hides in commitment
  Each contributor sends recipient a ShieldedNote encrypted to their MemoKey pubkey:
    { amount, blinding } — required for recipient to generate unwrap proofs later
  On-chain: each wrap adds a new commitment to recipient's slot (homomorphic add)
  Off-chain: individual amounts are private

Phase 3: Close + Tally (optional)
  Recipient decrypts each ShieldedNote to recover all (amount, blinding) pairs
  Recipient sums amounts locally to compute total raised

Phase 4: Disbursement
  Recipient calls unwrap for each commitment slice (or unwraps total in one tx)
  Recipient's FlowToken.Vault receives FLOW
```

## Implementation

### Setup: recipient publishes MemoKey

```typescript
import { deriveBabyJubKeypairFromBytes } from "@openjanus/sdk/crypto";
// See janus-flow.md MemoKey section for setup_memo_key.cdc transaction template

// Derive deterministic BabyJub keypair from wallet signature
const sig = await wallet.signMessage("openjanus/memokey/v1");
const keypair = await deriveBabyJubKeypairFromBytes(new TextEncoder().encode(sig));
// keypair.privkey: store in sessionStorage only — never on-chain
// Publish keypair.pubkey via setup_memo_key.cdc
```

### Contribution period: any donor contributes

```typescript
import { JanusFlow } from "@openjanus/sdk/tokens";
import { buildAmountDiscloseProof, generateBlinding, flowToWei, encryptText } from "@openjanus/sdk/crypto";
import { JanusFlowCadence } from "@openjanus/sdk/tokens";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.connectWithSigner(donorSigner);

// Fetch recipient's MemoKey pubkey
const cadence = new JanusFlowCadence();
await cadence.configure();
const recipientPK = await cadence.getMemoPubkey(RECIPIENT_CADENCE_ADDR);

async function contribute(amountFlow: bigint, donorSigner: unknown) {
  const amountWei = flowToWei(amountFlow);
  const blinding  = generateBlinding();

  const proof = await buildAmountDiscloseProof({ amount: amountWei, blinding });
  const tx = await sdk.wrap({
    amountWei,
    txCommit:    proof.txCommit,
    amountProof: proof.proof,
  });

  // Deliver ShieldedNote to recipient (via PrivateTip or encrypted channel)
  const { ciphertext, ephemeralPubkey } = await encryptText(
    JSON.stringify({ amount: amountWei.toString(), blinding: blinding.toString() }),
    recipientPK
  );
  // Send (ciphertext, ephemeralPubkey) to recipient out-of-band

  return tx.hash;
}

// Multiple donors contribute independently
await contribute(10n, aliceSigner);
await contribute(25n, bobSigner);
await contribute(100n, carolSigner);
```

### Close: recipient decrypts notes and tallies

```typescript
import { decryptText } from "@openjanus/sdk/crypto";

// Decrypt each ShieldedNote with recipient's privkey
let total = 0n;
for (const { ciphertext, ephemeralPubkey } of receivedNotes) {
  const note = JSON.parse(await decryptText(ciphertext, ephemeralPubkey, keypair.privkey));
  total += BigInt(note.amount);
}
console.log("Total raised:", total); // 135 * 10^18 attoFLOW
```

### Disbursement: receive FLOW

```typescript
import { buildAmountDiscloseProof, buildShieldedTransferProof } from "@openjanus/sdk/crypto";

// For each contribution slice, generate proofs and unwrap
for (const { amount, blinding } of allNotes) {
  const amtProof = await buildAmountDiscloseProof({ amount: BigInt(amount), blinding: BigInt(blinding) });
  const tProof   = await buildShieldedTransferProof({ ... });
  await sdk.unwrap({
    claimedAmountWei: BigInt(amount),
    recipient: recipientEvmAddr,
    txCommit:             amtProof.txCommit,
    amountProof:          amtProof.proof,
    transferPublicInputs: tProof.publicInputs,
    transferProof:        tProof.proof,
  });
}
// Recipient's FlowToken.Vault receives FLOW (less 0.1% boundary fee per unwrap)
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
