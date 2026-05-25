# Funding with Amount Privacy

This pattern describes how to build a public fundraising or crowdfunding application where individual contribution amounts are hidden from public observers, while the total raised can be verified on-chain (via the slot ciphertext) and eventually disclosed by the recipient.

## Use cases

- **Anonymous donations**: Donors contribute to a cause without revealing how much they gave
- **Quadratic funding rounds**: Individual contributions are private until the round closes
- **Payroll**: An employer distributes salaries to employees; amounts are confidential between employer and each employee
- **Bounties with private payouts**: Multiple sponsors fund a bounty independently without coordinating

This pattern builds on [confidential-tipping-v2.md](confidential-tipping-v2.md) but focuses on the fundraising lifecycle (contribution period → reveal → disbursement).

## Architecture

```
Phase 1: Setup
  Recipient registers BabyJubJub pubkey

Phase 2: Contribution Period  
  Many contributors: wrapAndEncrypt(amount, recipientPubkey, proof)
  On-chain: slot accumulates homomorphically
  Off-chain: amounts are private

Phase 3: Close + Reveal (optional)
  Recipient decrypts total with BSGS
  Recipient publishes total (optionally with proof)
  
Phase 4: Disbursement
  Recipient calls decryptAndUnwrap to receive accumulated FLOW
```

## Implementation

### Setup: recipient registers pubkey

```typescript
import { JanusFlow } from "@openjanus/sdk/tokens";
import { deriveBabyJubKeypair } from "@openjanus/elgamal";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.configure();

// Recipient generates and stores keypair
const recipientKeypair = deriveBabyJubKeypair(recipientFlowKey);
// store recipientKeypair.sk securely

await sdk.registerPubkey(recipientKeypair.pk, recipientAuthz);
// PK is now public — contributors can encrypt to it
```

### Contribution period: any donor contributes

```typescript
import { buildEncryptProof, generateRandomness } from "@openjanus/elgamal";

async function contribute(
  amount: bigint,      // in smallest FLOW units
  amountUFix: string,  // e.g. "25.0"
  donorAuthz: unknown
) {
  const recipientPK = await sdk.getPubkey(RECIPIENT_CADENCE_ADDR);

  const proof = await buildEncryptProof({
    amount,
    randomness: generateRandomness(),
    recipientPubkey: recipientPK,
    wasmPath: ENCRYPT_WASM_PATH,
    zkeyPath: ENCRYPT_ZKEY_PATH,
  });

  const { txId } = await sdk.wrapAndEncrypt(
    amountUFix,
    RECIPIENT_CADENCE_ADDR,
    proof,
    donorAuthz
  );

  // txId visible on-chain: transfer happened, amount hidden
  return txId;
}

// Multiple donors contribute independently
await contribute(10n, "10.0", aliceAuthz);
await contribute(25n, "25.0", bobAuthz);
await contribute(100n, "100.0", carolAuthz);
```

### Close: recipient reads and decrypts total

```typescript
import { bsgsRecover, recoverMaskedPoint } from "@openjanus/elgamal";

const ciphertext = await sdk.getSlot(RECIPIENT_CADENCE_ADDR);
const M = await recoverMaskedPoint(ciphertext, recipientKeypair.sk);

// Set maxValue to the theoretical maximum (total supply * donors)
const total = await bsgsRecover(M, { maxValue: 1_000_000n });
console.log("Total raised:", total); // 135n FLOW
```

### Reveal: publish total (optional)

The recipient can publish the total without on-chain proof:

```typescript
// Off-chain announcement
console.log(`Fundraiser complete. Total raised: ${total} FLOW`);
```

Or with a ZK proof (using the decrypt-open proof):

```typescript
const decryptResult = await buildDecryptProof({
  ciphertext,
  secretKey: recipientKeypair.sk,
  amount: total,
  wasmPath: DECRYPT_WASM_PATH,
  zkeyPath: DECRYPT_ZKEY_PATH,
});
// Publish decryptResult.proof on-chain or via a public announcement
// Anyone can verify the proof with DecryptOpenVerifier at 0x3bB139B5404fD6b152813bC3532367AAa096638b
```

### Disbursement: receive FLOW

```typescript
await sdk.decryptAndUnwrap(`${total}.0`, RECIPIENT_CADENCE_ADDR, decryptResult, recipientAuthz);
// Recipient's FlowToken.Vault receives `total` FLOW
```

## Privacy guarantees

| Observable on-chain | Not observable |
|--------------------|---------------|
| Recipient's registered pubkey | Any individual contribution amount |
| Contribution event: `wrapAndEncrypt` called | Who contributed how much |
| Accumulated slot ciphertext (2 points) | Total raised (until recipient reveals) |
| `decryptAndUnwrap` amount (when called) | Which donors contributed (if same-address donors is the concern, note sender address IS visible) |

**Important:** The sender's Cadence address is visible on-chain. Only amounts are hidden. For sender address privacy, combine with a stealth address pattern (roadmap item L9).

## Funding with a cap

If the fundraiser has a hard cap (e.g., 1000 FLOW), you can enforce it in the Cadence contract:

```cadence
// In a custom JanusFlow wrapper
if JanusFlow.getSlotTotal(recipient: RECIPIENT) >= cap {
    panic("Fundraiser cap reached")
}
JanusFlow.wrapAndEncrypt(...)
```

Note: "slot total" is not directly readable without decryption. To enforce a cap without revealing the running total, use a separate counter commitment (advanced pattern, not in scope here).

## CU and gas costs at scale

For a fundraiser with 100 donors:
- Each `wrapAndEncrypt` Cadence TX: ~9000 CU, ~300k EVM gas
- All 100 contributions: 100 transactions (parallel, no ordering required)
- Final `decryptAndUnwrap`: 1 transaction, ~9000 CU

BSGS for total up to 1M: ~10ms. For amounts in millions of FLOW, increase `maxValue` and precompute the table.

## See also

- [confidential-tipping.md](confidential-tipping.md) — Per-person tip use case
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — SDK setup
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — BSGS decryption guide
- [../../../openjanus-elgamal/references/v1-vs-v2.md](../../../openjanus-elgamal/references/v1-vs-v2.md) — Why v2 for this use case
