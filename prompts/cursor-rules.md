# Cursor Rules Template — Projects Building on OpenJanus

Copy this file into your project root as `.cursorrules` and customize the bracketed sections.

---

```
You are an expert TypeScript/Cadence developer building on the OpenJanus privacy stack on the Flow blockchain.

## Stack

- @openjanus/sdk — TypeScript SDK (JanusToken, JanusFlow, primitives)
- @openjanus/elgamal — ElGamal proof generation (buildEncryptProof, buildDecryptProof, BSGS)
- Flow EVM — EVM-compatible runtime on Flow
- Flow Cadence — smart contract language for cross-VM orchestration
- circomlibjs + snarkjs — ZK proof generation (Groth16 on BabyJubJub)

OpenJanus provides multi-sender privacy: recipients cannot determine
per-sender amounts from accumulated slot. Confirmed in Phase 3 e2e: 24/24 pass.
Router e2e (v0.2.0-router): 25/25 pass. JanusFlow canonical: 0x5dcbeb41055ec57e.



## Key patterns

### Connecting to JanusToken
```typescript
import { JanusToken, JANUS_TOKEN_TESTNET } from "@openjanus/sdk/tokens";
const token = new JanusToken(JANUS_TOKEN_TESTNET);
await token.connect(); // read-only
// OR
await token.connectWithSigner(wallet); // with signer
```

### JanusFlow (Cadence — full lifecycle)

```typescript
import { JanusFlow } from "@openjanus/sdk/tokens";
import { buildEncryptProof, buildDecryptProof, bsgsRecover } from "@openjanus/elgamal";

const sdk = new JanusFlow({ network: "testnet" });
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
2. Always set FCL limit: 9999 for JanusFlow transactions
3. Always call `registerPubkey` for a recipient before the first `confidentialTransfer`
4. Always call `sdk.isPaused()` before write operations — surface error to user if true
5. Run proof generation off the main thread (Web Worker) in browser environments
6. Never import from 0x28fef3d1d6a12800.JanusFlow — that is the zombie/deprecated address
7. Use `JANUS_FLOW_CADENCE_ADDRESS` constant from SDK — never hardcode the address

## Addresses (testnet) — v0.2.0-router

- JanusFlow.cdc (router): 0x5dcbeb41055ec57e (contract: JanusFlow) — CANONICAL
- JanusFlowImpl.cdc: 0x5dcbeb41055ec57e (contract: JanusFlowImpl) — current impl
- JanusToken.sol: 0x025efe7e89acdb8F315C804BE7245F348AA9c538
- EncryptConsistencyVerifier: 0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e
- DecryptOpenVerifier: 0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc
- BabyJub.sol: 0x27139AFda7425f51F68D32e0A38b7D43BcB0f870

DEPRECATED (zombie, DO NOT USE): 0x28fef3d1d6a12800.JanusFlow

## Reference

See https://github.com/openjanus/ai-tools for full documentation.
```
