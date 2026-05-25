# Cursor Rules Template — Projects Building on OpenJanus

Copy this file into your project root as `.cursorrules` and customize the bracketed sections.

---

```
You are an expert TypeScript/Cadence developer building on the OpenJanus privacy stack on the Flow blockchain.

## Stack

- @openjanus/sdk@^0.2.0 — TypeScript SDK (JanusTokenV2, JanusFlowV2, primitives)
- @openjanus/elgamal — ElGamal proof generation for v2 (buildEncryptProof, buildDecryptProof, BSGS)
- Flow EVM — EVM-compatible runtime on Flow
- Flow Cadence — smart contract language for cross-VM orchestration
- circomlibjs + snarkjs — ZK proof generation (Groth16 on BabyJubJub)

**Use v2 for new apps.** V2 provides multi-sender privacy: recipients cannot determine
per-sender amounts from accumulated slot. Confirmed in Phase 3 e2e: 24/24 pass.

> v1 (JanusToken/JanusFlow, Pedersen-hash) is deprecated as of 0.2.0.
> Do not use @openjanus/sdk/tokens (removed) — use @openjanus/sdk/tokens-v2.

## Key patterns

### Connecting to JanusTokenV2
```typescript
import { JanusTokenV2, JANUS_TOKEN_V2_TESTNET } from "@openjanus/sdk/tokens-v2";
const token = new JanusTokenV2(JANUS_TOKEN_V2_TESTNET);
await token.connect(); // read-only
// OR
await token.connectWithSigner(wallet); // with signer
```

### JanusFlowV2 (Cadence — full lifecycle)

```typescript
import { JanusFlowV2 } from "@openjanus/sdk/tokens-v2";
import { buildEncryptProof, buildDecryptProof, bsgsRecover } from "@openjanus/elgamal";

const sdk = new JanusFlowV2({ network: "testnet" });
await sdk.configure(); // MUST call before any operation

// One-time: register pubkey (recipient must do this before receiving)
await sdk.registerPubkey(keypair.pk, authz);

// Sender: encrypt amount to recipient pubkey and wrap FLOW
const proof = await buildEncryptProof({ amount, randomness, recipientPubkey: pk, ... });
await sdk.wrapAndEncrypt("10.0", RECIPIENT_ADDR, proof, senderAuthz);

// Recipient: BSGS decrypt accumulated total + unwrap
const ct = await sdk.getSlot(RECIPIENT_ADDR);
const total = await bsgsRecover(recoverMaskedPoint(ct, sk), { maxValue: 1_000_000n });
const decryptProof = await buildDecryptProof({ ciphertext: ct, secretKey: sk, amount: total, ... });
await sdk.decryptAndUnwrap(`${total}.0`, RECIPIENT_ADDR, decryptProof, authz);
```

## Non-negotiable rules

1. Never log or return private keys or secret decryption material in HTTP responses
2. Always set FCL limit: 9999 for JanusFlowV2 transactions
3. Always call `registerPubkey` for a recipient before the first `confidentialTransfer`
4. Run proof generation off the main thread (Web Worker) in browser environments
5. Do not use `@openjanus/sdk/tokens` (v1, removed in 0.2.0) — use `@openjanus/sdk/tokens-v2`

## Addresses (testnet)

- JanusFlowV2.cdc: 0x28fef3d1d6a12800 (contract: JanusFlowV2)
- JanusTokenV2.sol: 0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D
- EncryptConsistencyVerifier: 0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C
- DecryptOpenVerifier: 0x3bB139B5404fD6b152813bC3532367AAa096638b
- BabyJub.sol: 0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07

## Reference

See https://github.com/openjanus/ai-tools for full documentation.
```
