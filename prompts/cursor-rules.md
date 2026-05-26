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
per-sender amounts from accumulated slot. Confirmed in v0.2.0 e2e: 27/27 pass.



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
4. Run proof generation off the main thread (Web Worker) in browser environments
5. Do not use `@openjanus/sdk/tokens` (v1, removed in 0.1.0) — use `@openjanus/sdk/tokens`

## Addresses (testnet) — v0.2.0 (ceremony-backed, 2026-05-26)

- JanusFlow.cdc: 0x28fef3d1d6a12800 (contract: JanusFlow, LEGACY v1)
- JanusToken.sol: 0xb12E600fFcde967210cFD81CF9f32bBB6e68a499
- EncryptConsistencyVerifier: 0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e
- DecryptOpenVerifier: 0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc
- BabyJub.sol: 0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07

## Reference

See https://github.com/openjanus/ai-tools for full documentation.
```
