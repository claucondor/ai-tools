# Confidential Tipping Pattern

This pattern describes how to build a tip-sending feature where the transfer amount is hidden from public observers. This is the same pattern used by PrivateTip.

## What is confidential tipping?

A "tip" is a small payment from one user to another. In a normal ERC-20 transfer, the amount is visible on-chain. With the confidential tipping pattern, only the sender and recipient know the amount — the chain only records that *some* transfer happened.

## How it works

1. The sender wraps their FLOW balance into a Pedersen commitment (once, at deposit time).
2. To tip, the sender generates a ZK proof proving they have enough balance to cover the tip, without revealing how much.
3. The proof is submitted on-chain. The sender's commitment updates, and the recipient receives a new commitment representing the tip amount.
4. The recipient can later unwrap their accumulated tips to real FLOW.

## Step-by-step

### Step 1: Sender wraps FLOW (deposit)

```typescript
import { JanusFlow } from "@openjanus/sdk/tokens";
import { generateBlinding } from "@openjanus/sdk/crypto";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.configure();

// Alice wraps 100 FLOW
const aliceBlinding = generateBlinding(); // STORE THIS
const { txId, commitment: aliceCommit } = await sdk.wrap(
  "100.0",
  100n,
  aliceBlinding,
  aliceAuthz
);
// Persist: { commitment: aliceCommit, blinding: aliceBlinding }
```

### Step 2: Sender generates a tip proof

```typescript
import { buildTransferProof, generateBlinding } from "@openjanus/sdk/crypto";

const tipBlinding = generateBlinding();
const aliceNewBlinding = generateBlinding();

const proofResult = await buildTransferProof({
  oldBalance:       100n,
  oldBlinding:      aliceBlinding,
  transferAmount:   5n,     // tip amount — hidden from observers
  transferBlinding: tipBlinding,
  newBlinding:      aliceNewBlinding,
  wasmPath: WASM_PATH,
  zkeyPath: ZKEY_PATH,
  vkPath:   VK_PATH,        // recommended: verify locally before submitting
});

// proofResult.locallyVerified should be true before proceeding
```

### Step 3: Execute the confidential transfer

```typescript
const { txId: tipTx } = await sdk.confidentialTransfer(
  BOB_CADENCE_ADDRESS,  // recipient
  {
    oldBalance:       100n,
    oldBlinding:      aliceBlinding,
    transferAmount:   5n,
    transferBlinding: tipBlinding,
    newBlinding:      aliceNewBlinding,
    wasmPath: WASM_PATH,
    zkeyPath: ZKEY_PATH,
  },
  aliceAuthz
);

// Update Alice's stored state:
// commitment = proofResult.commitments.newCommit
// blinding   = aliceNewBlinding
// balance    = 95n
```

### Step 4: Recipient reads their tip

```typescript
const bobCommit = await sdk.getCommitment(BOB_CADENCE_ADDRESS);
// bobCommit is now a commitment to 5n (the tip)
// Bob needs the tipBlinding to unwrap — sender must communicate it out-of-band
```

### Step 5: Recipient unwraps (when ready to cash out)

```typescript
const { txId: unwrapTx } = await sdk.unwrap(
  "5.0",
  5n,
  tipBlinding,       // the blinding factor Bob received from Alice
  BOB_CADENCE_ADDRESS,
  bobAuthz
);
```

## Out-of-band blinding factor delivery

The blinding factor for the tip commitment (`tipBlinding`) is private data that the sender must share with the recipient. Options:

- **Encrypted message in the transaction memo** — encrypt with the recipient's public key, include as event data
- **Off-chain channel** — DM, email, app notification
- **Stealth address pattern** — the sender derives a blinding factor the recipient can independently compute

This is an active area of development. See [../decision-trees/privacy-level-needed.md](../decision-trees/privacy-level-needed.md) for when each approach is appropriate.

## State the app must persist

| Data | Owner | Why |
|------|-------|-----|
| `blinding` | Sender | Required to prove old commitment in next transfer |
| `commitment` (current) | Sender | Old commitment input for next proof |
| `balance` (known amount) | Sender | Circuit requires the plaintext value |
| Received `blinding` | Recipient | Required to unwrap |

## Privacy properties

- **Amount hidden**: observers see `confidentialTransfer(from, to)` but not the amount
- **Sender balance hidden**: the commitment reveals nothing about the total balance
- **Recipient visible**: the recipient address is visible on-chain

This version provides **amount privacy only**. Sender and recipient addresses remain public. For stronger privacy, see the decision tree.

## Gas and CU notes

- Proof generation: ~10-60 seconds (CPU-bound, do it client-side or in a worker)
- Cadence transaction CU: approaches the 9999 CU ceiling due to Cross-VM proof verification
- EVM gas for `verifyProof`: ~250,000-300,000 gas on Flow EVM

## Next steps

- [ts-sdk-integration.md](ts-sdk-integration.md) — Integrate into a Next.js app
- [../gotchas/compute-units-limit.md](../gotchas/compute-units-limit.md) — CU limit management
- [../decision-trees/privacy-level-needed.md](../decision-trees/privacy-level-needed.md) — Choose the right privacy level
