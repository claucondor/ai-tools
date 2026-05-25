# Basic Transfer — Reading Balances and Generating Proofs

This guide covers the two most common operations: reading a confidential balance and generating a ZK transfer proof. All code runs against the testnet deployment.

## Reading a JanusToken balance

```typescript
import { JanusToken, JANUS_TOKEN_TESTNET } from "@openjanus/sdk/tokens";

const token = new JanusToken(JANUS_TOKEN_TESTNET);
await token.connect(); // read-only provider

const commit = await token.balanceOfCommitment("0xAliceEVMAddress");
// identity (0, 1) means zero balance
if (commit.x === 0n && commit.y === 1n) {
  console.log("Alice has zero balance");
} else {
  console.log("Alice has a non-zero commitment:", commit);
}
```

`JANUS_TOKEN_TESTNET` is shorthand for `{ evmAddress: "0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A", network: "testnet" }`.

## Computing a Pedersen commitment

```typescript
import { computeCommitment } from "@openjanus/sdk/crypto";
import { generateBlinding } from "@openjanus/sdk/crypto";

// Generate a 128-bit random blinding factor — STORE THIS
const blinding = generateBlinding();

// Commit to 10 FLOW (as uint64)
const commitment = await computeCommitment(10n, blinding);
console.log(commitment);
// { x: <bigint>, y: <bigint> }

// WARNING: if you lose `blinding`, you cannot prove ownership or unwrap
```

`generateBlinding()` returns a cryptographically random 128-bit `bigint`. Always persist it alongside the commitment in your app's database.

## Minting a commitment (NATIVE mode, owner only)

```typescript
import { JanusToken, JANUS_TOKEN_TESTNET } from "@openjanus/sdk/tokens";
import { createEvmWallet } from "@openjanus/sdk/network";

const wallet = await createEvmWallet(process.env.PRIVATE_KEY!, "testnet");
const token = new JanusToken(JANUS_TOKEN_TESTNET);
await token.connectWithSigner(wallet);

const blinding = generateBlinding();
const { receipt, commit } = await token.mint("0xAliceAddress", 10n, blinding);
console.log("Minted at tx:", receipt.hash);
// Store: { address: "0xAlice", commitment: commit, blinding }
```

## Generating a transfer proof

```typescript
import { buildTransferProof, generateBlinding } from "@openjanus/sdk/crypto";

// You need the circuit artifacts — see docs/gotchas/circuit-artifacts.md
const WASM_PATH = "./circuits/confidentialTransfer.wasm";
const ZKEY_PATH = "./circuits/confidentialTransfer_final.zkey";
const VK_PATH   = "./circuits/verification_key.json"; // optional local check

const proofResult = await buildTransferProof({
  oldBalance:       10n,
  oldBlinding:      aliceStoredBlinding,  // the blinding used at mint time
  transferAmount:   3n,
  transferBlinding: generateBlinding(),   // fresh random
  newBlinding:      generateBlinding(),   // fresh random
  wasmPath: WASM_PATH,
  zkeyPath: ZKEY_PATH,
  vkPath:   VK_PATH,
});

console.log(proofResult.locallyVerified); // true if vkPath was provided
// proofResult.proof            — uint256[8], ready for on-chain submission
// proofResult.publicInputs     — uint256[6], the six commitment coordinates
// proofResult.commitments      — { oldCommit, transferCommit, newCommit }
```

## Executing a confidential transfer (NATIVE mode)

```typescript
import { JanusToken, JANUS_TOKEN_TESTNET } from "@openjanus/sdk/tokens";
import { createEvmWallet } from "@openjanus/sdk/network";
import { buildTransferProof, generateBlinding } from "@openjanus/sdk/crypto";

const wallet = await createEvmWallet(process.env.ALICE_KEY!, "testnet");
const token = new JanusToken(JANUS_TOKEN_TESTNET);
await token.connectWithSigner(wallet);

const { receipt, proofResult } = await token.proveAndTransfer(
  "0xBobEVMAddress",
  {
    oldBalance:       10n,
    oldBlinding:      aliceBlinding,
    transferAmount:   3n,
    transferBlinding: generateBlinding(),
    newBlinding:      generateBlinding(),
    wasmPath: WASM_PATH,
    zkeyPath: ZKEY_PATH,
  }
);

console.log("Transfer TX:", receipt.hash);
// Update Alice's stored commitment to proofResult.commitments.newCommit
// and new blinding (the newBlinding you passed in)
```

## Common Pitfalls

**Not calling `.connect()` first.** Every method throws `"JanusToken: not connected"` if you skip this.

**Generating proof takes 10-60 seconds.** Groth16 proof generation with snarkJS is CPU-intensive. Run it off the main thread (Web Worker or Node worker_threads) in production.

**transferAmount > oldBalance.** `buildTransferProof` validates this and throws `RangeError` before wasting time on circuit computation.

## Next steps

- [advanced-usage.md](advanced-usage.md) — JanusFlow (Cadence native FLOW) wrap/transfer/unwrap
- [../patterns/confidential-tipping.md](../patterns/confidential-tipping.md) — End-to-end tipping pattern
- [../gotchas/circuit-artifacts.md](../gotchas/circuit-artifacts.md) — Where to find WASM and zkey files
