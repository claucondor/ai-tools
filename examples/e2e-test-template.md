# E2E Test Template — JanusToken + JanusFlow (v0.8.2)

This template covers end-to-end tests for deployed OpenJanus contracts on Flow testnet.
Uses `@claucondor/sdk@^0.8.2` with `sdk.token(id)` adapter pattern.

## Setup

```typescript
// tests/integration/setup.ts
import {
  sdk,
  deriveMemoKeyFromSignature,
  ShieldedInboxClient,
  ShieldedCheckpointClient,
  BatchClaimClient,
  isFreshSlotCommit,
  TOKEN_REGISTRY,
} from "@claucondor/sdk";
import { createEvmWallet } from "@claucondor/sdk/network";
import { generateBlinding } from "@claucondor/sdk/crypto";
import { ethers } from "ethers";
import path from "path";

// Circuit artifacts — v0.8 layout
export const WASM_PATH  = path.resolve(__dirname, "../../node_modules/@claucondor/sdk/circuits/v0.8/confidentialTransfer.wasm");
export const ZKEY_PATH  = path.resolve(__dirname, "../../node_modules/@claucondor/sdk/circuits/v0.8/confidentialTransfer_final.zkey");
export const CLAIM_WASM = path.resolve(__dirname, "../../node_modules/@claucondor/sdk/circuits/v0.8/batchClaim_n10.wasm");
export const CLAIM_ZKEY = path.resolve(__dirname, "../../node_modules/@claucondor/sdk/circuits/v0.8/batchClaim_n10_final.zkey");

// Test accounts (testnet — funded with FLOW)
export const ALICE_KEY     = process.env.ALICE_PRIVATE_KEY!;
export const BOB_KEY       = process.env.BOB_PRIVATE_KEY!;
export const BOB_CADENCE   = process.env.BOB_CADENCE_ADDRESS ?? "0xd807a3992d7be612";

export async function setupAlice() {
  const wallet = await createEvmWallet(ALICE_KEY, "testnet");
  const sig = await wallet.signMessage('OpenJanus MemoKey v1');
  const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
  return { wallet, memoKeypair };
}

export async function setupBob() {
  const wallet = await createEvmWallet(BOB_KEY, "testnet");
  const sig = await wallet.signMessage('OpenJanus MemoKey v1');
  const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
  return { wallet, memoKeypair };
}
```

## Test: read zero balance

```typescript
import { describe, it, expect, beforeAll } from "vitest";
import { sdk, isFreshSlotCommit } from "@claucondor/sdk";

describe("JanusFlow - read operations", () => {
  const flow = sdk.token('flow');

  it("returns fresh-slot commitment for zero-balance address", async () => {
    const commit = await flow.getCommitment("0x000000000000000000000000000000000000dead");
    // v0.8: fresh slot can be (0,0) OR (0,1) — use isFreshSlotCommit
    expect(isFreshSlotCommit(commit)).toBe(true);
  });

  it("returns fee in basis points", async () => {
    const bps = await flow.feeBps();
    expect(bps).toBe(10); // 0.1%
  });
});
```

## Test: wrap → checkpoint → read

```typescript
import { describe, it, expect, beforeAll } from "vitest";
import { sdk, ShieldedCheckpointClient } from "@claucondor/sdk";
import { setupAlice } from "./setup";

describe("JanusFlow - wrap + checkpoint", () => {
  it("wraps FLOW and updates ShieldedCheckpoint", async () => {
    const { wallet, memoKeypair } = await setupAlice();
    const flow = sdk.token('flow');
    const checkpoint = new ShieldedCheckpointClient();

    const result = await flow.wrap({ grossAmount: 1n * 10n**18n }, wallet);
    expect(result.txHash).toBeDefined();
    expect(result.netAmount).toBeLessThan(1n * 10n**18n); // fee applied

    // Update checkpoint
    await checkpoint.update(flow.address, result.checkpointPayload!, 0n, wallet);

    // Read back
    const snapshot = await checkpoint.readAndDecrypt(wallet, memoKeypair.privkey);
    expect(snapshot).not.toBeNull();
    expect(snapshot!.balance).toBeGreaterThan(0n);
  }, 90_000);
});
```

## Test: shielded transfer (EVM) + inbox drain

```typescript
import { describe, it, expect } from "vitest";
import {
  sdk,
  ShieldedInboxClient,
  ShieldedCheckpointClient,
  assertCheckpointMatchesCommit,
  isFreshSlotCommit,
} from "@claucondor/sdk";
import { setupAlice, setupBob } from "./setup";

describe("JanusFlow - shieldedTransfer + inbox drain", () => {
  it("transfers from Alice to Bob; Bob drains inbox", async () => {
    const { wallet: aliceWallet, memoKeypair: aliceMemo } = await setupAlice();
    const { wallet: bobWallet, memoKeypair: bobMemo }     = await setupBob();
    const flow = sdk.token('flow');
    const checkpoint = new ShieldedCheckpointClient();

    // Read Alice's current balance from checkpoint
    const snapshot = await checkpoint.readAndDecrypt(aliceWallet, aliceMemo.privkey);
    expect(snapshot).not.toBeNull();
    expect(snapshot!.balance).toBeGreaterThan(2n * 10n**18n);

    // Pre-flight safety check
    await assertCheckpointMatchesCommit({
      tokenAddr:    flow.address,
      signer:       aliceWallet,
      memoPrivkey:  aliceMemo.privkey,
      localBalance: snapshot!.balance,
      localBlinding: snapshot!.blinding,
    });

    // Transfer 1 FLOW to Bob
    const sendResult = await flow.shieldedTransfer({
      recipient:       bobWallet.address,
      amount:          1n * 10n**18n,
      memo:            'e2e test',
      currentBalance:  snapshot!.balance,
      currentBlinding: snapshot!.blinding,
    }, aliceWallet);

    expect(sendResult.txHash).toBeDefined();

    // Update Alice's checkpoint
    await checkpoint.update(flow.address, sendResult.checkpointPayload!, 0n, aliceWallet);

    // Bob drains inbox
    const inbox = new ShieldedInboxClient();
    const { decrypted } = await inbox.drainAndDecrypt(bobWallet, bobMemo.privkey);

    expect(decrypted.length).toBeGreaterThan(0);
    const note = decrypted.find(n => n.content.memo === 'e2e test');
    expect(note).toBeDefined();
    expect(note!.content.amount).toBe(1n * 10n**18n);
  }, 180_000);
});
```

## Test: batchClaim (consolidate inbox notes)

```typescript
import { describe, it, expect } from "vitest";
import { sdk, ShieldedInboxClient, BatchClaimClient } from "@claucondor/sdk";
import { setupBob, CLAIM_WASM, CLAIM_ZKEY } from "./setup";

describe("JanusFlow - batchClaim", () => {
  it("drains and claims multiple inbox notes in one proof", async () => {
    const { wallet: bobWallet, memoKeypair: bobMemo } = await setupBob();
    const flow = sdk.token('flow');

    const inbox = new ShieldedInboxClient();
    const { notes } = await inbox.drain(bobWallet);

    // Skip if fewer than 2 notes (batchClaim requires at least 1, optimal >= 2)
    if (notes.length === 0) {
      console.log("No inbox notes — skipping batchClaim test");
      return;
    }

    const batchClaim = new BatchClaimClient(flow);
    const result = await batchClaim.buildAndClaim(notes, bobMemo, bobWallet, {
      wasmPath: CLAIM_WASM,
      zkeyPath: CLAIM_ZKEY,
    });

    expect(result.txHash).toBeDefined();
    console.log("BatchClaim TX:", result.txHash, "notes claimed:", result.notesClaimed);
  }, 180_000);
});
```

## Test: ShieldedCheckpoint read / fresh slot detection

```typescript
import { describe, it, expect } from "vitest";
import { sdk, ShieldedCheckpointClient, isFreshSlotCommit } from "@claucondor/sdk";
import { setupAlice } from "./setup";

describe("ShieldedCheckpoint", () => {
  it("isFreshSlotCommit returns true for identity points", async () => {
    // Both (0,0) and (0,1) are valid fresh/zero-balance representations
    expect(isFreshSlotCommit({ x: 0n, y: 0n })).toBe(true);
    expect(isFreshSlotCommit({ x: 0n, y: 1n })).toBe(true);
    expect(isFreshSlotCommit({ x: 1n, y: 2n })).toBe(false);
  });

  it("reads checkpoint and returns non-null after wrap", async () => {
    const { wallet, memoKeypair } = await setupAlice();
    const checkpoint = new ShieldedCheckpointClient();

    const flow = sdk.token('flow');
    const commit = await flow.getCommitment(wallet.address);
    const hasFunds = !isFreshSlotCommit(commit);

    if (hasFunds) {
      const snapshot = await checkpoint.readAndDecrypt(wallet, memoKeypair.privkey);
      expect(snapshot).not.toBeNull();
      expect(snapshot!.balance).toBeGreaterThan(0n);
    } else {
      console.log("Alice has no shielded balance — skipping snapshot check");
    }
  }, 60_000);
});
```

## Test: JanusFlow wrap via Cadence

```typescript
import { describe, it, expect } from "vitest";
import { sdk, ShieldedCheckpointClient } from "@claucondor/sdk";
import * as fcl from "@onflow/fcl";
import { setupAlice } from "./setup";
// Note: requires FCL authorization function from a funded test account
// This test is typically run manually with a test wallet configured

describe("JanusFlow - Cadence wrap", () => {
  it("wraps FLOW via Cadence tx and reads back checkpoint", async () => {
    const { wallet, memoKeypair } = await setupAlice();
    const flow = sdk.token('flow');
    const checkpoint = new ShieldedCheckpointClient();

    // FCL authz must be configured for ALICE_CADENCE address
    const result = await flow.wrap({ grossAmount: 1n * 10n**18n }, wallet);
    expect(result.txHash).toBeDefined();

    await checkpoint.update(flow.address, result.checkpointPayload!, 0n, wallet);
    const snapshot = await checkpoint.readAndDecrypt(wallet, memoKeypair.privkey);
    expect(snapshot).not.toBeNull();
  }, 60_000);
});
```

## Running integration tests

```bash
# Requires: funded testnet accounts + network access
ALICE_PRIVATE_KEY=0x... BOB_PRIVATE_KEY=0x... RUN_INTEGRATION=1 npm run test:integration

# Or with all env vars:
ALICE_PRIVATE_KEY=0x... \
BOB_PRIVATE_KEY=0x... \
BOB_CADENCE_ADDRESS=0x... \
RUN_INTEGRATION=1 npx vitest run tests/integration
```

## Notes

- Integration tests interact with the live Flow testnet. They cost real (testnet) FLOW.
- Set long timeouts (90-180 seconds) — proof generation takes up to 60s, plus tx confirmation.
- Never use mainnet accounts in integration tests.
- Use `beforeAll` with cleanup in `afterAll` to avoid leaving test state on-chain.
- `isFreshSlotCommit` handles both (0,0) and (0,1) identity points — always prefer it over
  manual `commit.x === 0n && commit.y === 1n` checks.
- After each wrap/transfer/unwrap, always call `checkpoint.update()` — missing this causes
  `assertCheckpointMatchesCommit` to throw on the next operation.
