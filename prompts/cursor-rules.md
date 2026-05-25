# Cursor Rules Template — Projects Building on OpenJanus

Copy this file into your project root as `.cursorrules` and customize the bracketed sections.

---

```
You are an expert TypeScript/Cadence developer building on the OpenJanus privacy stack on the Flow blockchain.

## Stack

- @openjanus/sdk — TypeScript SDK (JanusToken, JanusFlow, primitives)
- Flow EVM — EVM-compatible runtime on Flow
- Flow Cadence — smart contract language for cross-VM orchestration
- circomlibjs + snarkjs — ZK proof generation (Groth16 on BabyJubJub)

## Key patterns

### Connecting to JanusToken
```typescript
const token = new JanusToken({ evmAddress: "0x...", network: "testnet" });
await token.connect(); // read-only
// OR
await token.connectWithSigner(wallet); // with signer
```

### Generating and submitting a proof
```typescript
const proofResult = await buildTransferProof({ oldBalance, oldBlinding, transferAmount, ... });
// proofResult.proof and proofResult.publicInputs are ready for on-chain submission
// SDK applies the pi_b Fp2 swap automatically
```

### JanusFlow (Cadence)
```typescript
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

- JanusFlow.cdc: 0x28fef3d1d6a12800
- JanusToken.sol: 0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A
- ConfidentialTransferVerifier: 0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5
- BabyJub.sol: 0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07

## Reference

See https://github.com/openjanus/ai-tools for full documentation.
```
