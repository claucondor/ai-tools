# E2E Test Template — JanusToken + JanusFlow

This template covers end-to-end tests for deployed OpenJanus contracts on Flow testnet.

## Setup

```typescript
// tests/integration/setup.ts
import { JanusToken, JanusFlow, JANUS_TOKEN_TESTNET } from "@claucondor/sdk/tokens";
import { createEvmWallet } from "@claucondor/sdk/network";
import { generateBlinding } from "@claucondor/sdk/crypto";
import path from "path";

// Circuit artifacts
export const WASM_PATH = path.resolve(__dirname, "../../circuits/confidentialTransfer.wasm");
export const ZKEY_PATH = path.resolve(__dirname, "../../circuits/confidentialTransfer_final.zkey");
export const VK_PATH   = path.resolve(__dirname, "../../circuits/verification_key.json");

// Test accounts (testnet — funded with FLOW)
export const ALICE_KEY = process.env.ALICE_PRIVATE_KEY!;
export const BOB_CADENCE = "0xd807a3992d7be612";

export async function setupEVM() {
  const aliceWallet = await createEvmWallet(ALICE_KEY, "testnet");
  const token = new JanusToken(JANUS_TOKEN_TESTNET);
  await token.connectWithSigner(aliceWallet);
  return { aliceWallet, token };
}

export async function setupCadence() {
  const sdk = new JanusFlow({ network: "testnet" });
  await sdk.configure();
  return { sdk };
}
```

## Test: read zero balance

```typescript
import { describe, it, expect, beforeAll } from "vitest";
import { JanusToken, JANUS_TOKEN_TESTNET } from "@claucondor/sdk/tokens";

describe("JanusToken - read operations", () => {
  let token: JanusToken;

  beforeAll(async () => {
    token = new JanusToken(JANUS_TOKEN_TESTNET);
    await token.connect();
  });

  it("returns identity commitment for zero-balance address", async () => {
    const commit = await token.balanceOfCommitment("0x000000000000000000000000000000000000dead");
    expect(commit.x).toBe(0n);
    expect(commit.y).toBe(1n);
  });

  it("isWrapperMode returns false for NATIVE demo", async () => {
    const isWrapper = await token.isWrapperMode();
    expect(isWrapper).toBe(false);
  });
});
```

## Test: mint → verify commitment

```typescript
import { computeCommitment, generateBlinding } from "@claucondor/sdk/crypto";
import { setupEVM } from "./setup";

describe("JanusToken - mint (NATIVE mode)", () => {
  it("mints a commitment and reads it back", async () => {
    const { aliceWallet, token } = await setupEVM();
    const blinding = generateBlinding();

    const { receipt, commit } = await token.mint(aliceWallet.address, 5n, blinding);
    expect(receipt).toBeDefined();

    const stored = await token.balanceOfCommitment(aliceWallet.address);
    expect(stored.x).toBe(commit.x);
    expect(stored.y).toBe(commit.y);
  }, 60_000); // mint may take a few seconds on testnet
```

## Test: confidential transfer (EVM)

```typescript
import { buildTransferProof, generateBlinding } from "@claucondor/sdk/crypto";
import { setupEVM, WASM_PATH, ZKEY_PATH, VK_PATH } from "./setup";

describe("JanusToken - confidentialTransfer", () => {
  it("transfers 3 units from alice to bob (EVM COA)", async () => {
    const { aliceWallet, token } = await setupEVM();
    const BOB_EVM = "0x00000000000000000000000250d93efba617e0bf";

    // Mint to Alice first
    const aliceBlinding = generateBlinding();
    await token.mint(aliceWallet.address, 10n, aliceBlinding);

    // Transfer 3 to Bob
    const { receipt, proofResult } = await token.proveAndTransfer(BOB_EVM, {
      oldBalance: 10n,
      oldBlinding: aliceBlinding,
      transferAmount: 3n,
      transferBlinding: generateBlinding(),
      newBlinding: generateBlinding(),
      wasmPath: WASM_PATH,
      zkeyPath: ZKEY_PATH,
      vkPath: VK_PATH,
    });

    expect(receipt).toBeDefined();
    expect(proofResult.locallyVerified).toBe(true);

    // Bob should have a non-identity commitment
    const bobCommit = await token.balanceOfCommitment(BOB_EVM);
    const isZero = bobCommit.x === 0n && bobCommit.y === 1n;
    expect(isZero).toBe(false);
  }, 120_000); // proof generation can take up to 60s
});
```

## Test: JanusFlow wrap (Cadence)

```typescript
import { setupCadence } from "./setup";
import { generateBlinding } from "@claucondor/sdk/crypto";
// Note: requires FCL authorization function from a funded test account
// This test is typically run manually with a test wallet configured

describe("JanusFlow - wrap", () => {
  it("wraps FLOW and reads back commitment via Cadence", async () => {
    const { sdk } = await setupCadence();
    const ALICE_CADENCE = "0xYourTestCadenceAddress";
    const blinding = generateBlinding();

    const { txId, commitment } = await sdk.wrap("1.0", 1n, blinding, aliceAuthz);
    expect(txId).toBeDefined();

    const stored = await sdk.getCommitment(ALICE_CADENCE);
    expect(stored.x).toBe(commitment.x);
    expect(stored.y).toBe(commitment.y);
  }, 60_000);
});
```

## Running integration tests

```bash
# Requires: funded testnet accounts + network access
RUN_INTEGRATION=1 npm run test:integration

# Or with environment variables:
ALICE_PRIVATE_KEY=0x... RUN_INTEGRATION=1 npx vitest run tests/integration
```

## Notes

- Integration tests interact with the live Flow testnet. They cost real (testnet) FLOW.
- Set long timeouts (60-120 seconds) for proof generation tests.
- Never use mainnet accounts in integration tests.
- Use `beforeAll` with cleanup in `afterAll` to avoid leaving test state on-chain.
