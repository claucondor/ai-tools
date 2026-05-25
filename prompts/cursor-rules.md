# Cursor Rules Template — Projects Building on OpenJanus

Copy this file into your project root as `.cursorrules` and customize the bracketed sections.

---

```
You are an expert TypeScript/Cadence developer building on the OpenJanus privacy stack on the Flow blockchain.

## Stack

- @openjanus/sdk — TypeScript SDK (JanusToken, JanusFlow v1; JanusTokenV2, JanusFlowV2 v2)
- @openjanus/elgamal — ElGamal proof generation for v2 (buildEncryptProof, buildDecryptProof, BSGS)
- Flow EVM — EVM-compatible runtime on Flow
- Flow Cadence — smart contract language for cross-VM orchestration
- circomlibjs + snarkjs — ZK proof generation (Groth16 on BabyJubJub)

**Use v2 for new apps.** V2 provides multi-sender privacy: recipients cannot determine per-sender amounts from accumulated slot. Confirmed in Phase 3 e2e: 24/24 pass.

## Key patterns

### V2 (ElGamal — RECOMMENDED for new apps)

```typescript
import { JanusFlowV2 } from "@openjanus/sdk/tokens-v2";
import { buildEncryptProof, buildDecryptProof, bsgsRecover } from "@openjanus/elgamal";

const sdk = new JanusFlowV2({ network: "testnet" });
await sdk.configure(); // MUST call before any operation

// One-time: register pubkey
await sdk.registerPubkey(keypair.pk, authz);

// Sender: encrypt amount to recipient pubkey
const proof = await buildEncryptProof({ amount, randomness: generateRandomness(), recipientPubkey: pk, ... });
await sdk.wrapAndEncrypt("10.0", RECIPIENT_ADDR, proof, senderAuthz);

// Recipient: BSGS decrypt + unwrap
const ct = await sdk.getSlot(RECIPIENT_ADDR);
const total = await bsgsRecover(recoverMaskedPoint(ct, sk), { maxValue: 1_000_000n });
const decryptProof = await buildDecryptProof({ ciphertext: ct, secretKey: sk, amount: total, ... });
await sdk.decryptAndUnwrap(`${total}.0`, RECIPIENT_ADDR, decryptProof, authz);
```

### V1 (Pedersen — legacy)

```typescript
// Connecting to JanusToken (v1)
const token = new JanusToken({ evmAddress: "0x...", network: "testnet" });
await token.connect(); // read-only
// OR
await token.connectWithSigner(wallet); // with signer

// Generating and submitting a proof (v1)
const proofResult = await buildTransferProof({ oldBalance, oldBlinding, transferAmount, ... });
// proofResult.proof and proofResult.publicInputs are ready for on-chain submission
// SDK applies the pi_b Fp2 swap automatically

// JanusFlow (v1 Cadence)
const sdk = new JanusFlow({ network: "testnet" });
await sdk.configure(); // MUST call before any operation
await sdk.wrap("10.0", 10n, blinding, authz);
```

## Non-negotiable rules

1. Never log or return blinding factors in HTTP responses
2. Always set FCL limit: 9999 for JanusFlow transactions
3. Always persist blinding factors before submitting the transaction that creates the commitment
4. Never reuse blinding factors
5. Run proof generation off the main thread (Web Worker) in browser environments

## Addresses (testnet)

### V2 (RECOMMENDED)
- JanusFlowV2.cdc: 0x28fef3d1d6a12800 (contract: JanusFlowV2)
- JanusTokenV2.sol: 0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D
- EncryptConsistencyVerifier: 0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C
- DecryptOpenVerifier: 0x3bB139B5404fD6b152813bC3532367AAa096638b
- BabyJub.sol (v2): 0x27139AFda7425f51F68D32e0A38b7D43BcB0f870

### V1 (legacy)
- JanusFlow.cdc: 0x28fef3d1d6a12800 (contract: JanusFlow)
- JanusToken.sol: 0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A
- ConfidentialTransferVerifier: 0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5
- BabyJub.sol: 0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07

## Reference

See https://github.com/openjanus/ai-tools for full documentation.
```
