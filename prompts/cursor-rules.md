# Cursor Rules Template — Projects Building on the Janus Privacy Stack (v0.8.2)

Copy this file into your project root as `.cursorrules` and customize the
bracketed sections.

---

```
You are an expert TypeScript/Cadence developer building on the Janus v0.8.2
privacy stack on the Flow blockchain.

## Stack (v0.8.2)

- @claucondor/sdk@^0.8.2 — TypeScript SDK with generic `sdk.token(id)` adapter
  (3 tokens: 'flow'/'mockusdc'/'mockft') + adapter interface JanusTokenAdapter
- @openjanus/commitment — Pedersen commitment primitives (replaces @openjanus/pedersen)
- MemoKeyRegistry (0x361bD4d037838A3a9c5408AE465d36077800ee6c) — immutable;
  one publishMemoKey covers all 3 tokens
- ShieldedInbox (0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6) — per-user on-chain mailbox;
  recipients call drain() instead of scanning events; immutable
- ShieldedCheckpoint (0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26) — per-user, per-token
  encrypted sender state store; multi-token (token address as first arg on all write/read)
- Flow EVM — UUPS proxies for JanusFlow (0xA64340C1d3...), JanusERC20 (0xFD8F82bE17...);
  feeBps=10 (0.1%) on all
- Flow Cadence — JanusFT at 0x4b6bc58bc8bf5dcc
- circomlibjs + snarkjs — ZK proof generation (Groth16 on BabyJubJub) for the
  three v0.8 circuits (amount_disclose, confidential_transfer, batch_claim_n10)

Janus v0.8.2 provides FULL amount privacy on `shieldedTransfer`: amount is
hidden on msg.value, calldata, storage, events, and against commitment
bruteforce (128-bit blinding). Wrap / unwrap leak amount at the boundary BY
DESIGN so the FLOW custody pool can be audited.

v0.8 is push-model: shieldedTransfer writes the receiver's on-chain commitment
slot directly. Always implement 3-layer defense:
  1. assertCheckpointMatchesCommit before building proof
  2. isOpSafeNow gate before submitting
  3. checkpoint.update() after tx sealed

## Key patterns

### Getting a token adapter

```typescript
import { sdk } from "@claucondor/sdk";

const flow     = sdk.token('flow');     // native FLOW
const mockusdc = sdk.token('mockusdc'); // ERC20 (requires approve before wrap)
const mockft   = sdk.token('mockft');   // Cadence FT
```

### Full v0.8.2 lifecycle (JanusFlow)

```typescript
import {
  sdk,
  deriveMemoKeyFromSignature,
  ShieldedInboxClient,
  ShieldedCheckpointClient,
  assertCheckpointMatchesCommit,
  generateBlinding,
  TOKEN_REGISTRY,
} from "@claucondor/sdk";
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
const flow = sdk.token('flow');

// 1. MemoKey setup (once per wallet)
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
await flow.publishMemoKey(memoKeypair, wallet);

// === WRAP (boundary, amount visible by design) ===
const wrapResult = await flow.wrap({ grossAmount: 5n * 10n**18n }, wallet);
// Returns: { txHash, netAmount, commitment, blinding, checkpointPayload }

// Persist checkpointPayload to ShieldedCheckpoint
const checkpoint = new ShieldedCheckpointClient();
await checkpoint.update(flow.address, wrapResult.checkpointPayload!, 0n, wallet);

// === SHIELDED TRANSFER (fully hidden) ===
// Read current balance from checkpoint
const snapshot = await checkpoint.readAndDecrypt(wallet, memoKeypair.privkey);

// Pre-flight safety check
await assertCheckpointMatchesCommit({
  tokenAddr: flow.address,
  signer: wallet,
  memoPrivkey: memoKeypair.privkey,
  localBalance: snapshot!.balance,
  localBlinding: snapshot!.blinding,
});

const sendResult = await flow.shieldedTransfer({
  recipient:       recipientEVMAddr,  // EVM or Cadence addr (SDK resolves)
  amount:          2n * 10n**18n,
  memo:            'payment',
  currentBalance:  snapshot!.balance,
  currentBlinding: snapshot!.blinding,
}, wallet);

// Update sender checkpoint after transfer
await checkpoint.update(flow.address, sendResult.checkpointPayload!, 0n, wallet);

// === RECIPIENT DRAINS INBOX ===
const inbox = new ShieldedInboxClient();
const { decrypted } = await inbox.drainAndDecrypt(recipientWallet, recipientMemoPrivkey);
for (const { content } of decrypted) {
  console.log('Received:', content.amount, 'blinding:', content.blinding);
}

// === UNWRAP (boundary, amount visible by design) ===
const snapshot2 = await checkpoint.readAndDecrypt(wallet, memoKeypair.privkey);
const unwrapResult = await flow.unwrap({
  claimedAmount:   snapshot2!.balance,
  recipient:       wallet.address,
  currentBalance:  snapshot2!.balance,
  currentBlinding: snapshot2!.blinding,
}, wallet);
await checkpoint.update(flow.address, unwrapResult.checkpointPayload!, 0n, wallet);
```

### BatchClaim (consolidate inbox notes)

```typescript
import { sdk, ShieldedInboxClient, BatchClaimClient } from "@claucondor/sdk";

const inbox = new ShieldedInboxClient();
const { notes } = await inbox.drain(recipientWallet);

if (notes.length >= 2) {
  const batchClaim = new BatchClaimClient(sdk.token('flow'));
  await batchClaim.buildAndClaim(notes, memoKeypair, recipientWallet);
}
```

## Non-negotiable rules (v0.8.2)

1. Never log or return blinding factors in HTTP responses. The blinding IS
   the decryption material.
2. Always set FCL `limit: 9999` for JanusFlow Cadence transactions.
3. Use `sdk.token(id)` — do not instantiate adapters directly.
4. Run proof generation off the main thread (Web Worker) in browser apps.
5. Always import addresses from canonical SDK constants — never hardcode addresses.
6. Deliver inbox notes via ShieldedInbox on-chain — not out-of-band.
7. Always call checkpoint.update() after any shieldedTransfer or unwrap.
8. Use `generateBlinding()` for every new blinding factor — never hardcode or reuse.
9. Do not call sdk.token('wflow') — JanusWFLOW was dropped in v0.8.
10. Use isFreshSlotCommit(commit) to detect zero-balance slots — matches both (0,0) and (0,1).

## Addresses (testnet) — v0.8.2 contracts

- JanusFlow EVM proxy:              0xA64340C1d356835A2450306Ffd290Ed52c001Ad3
- JanusERC20 EVM proxy (mockusdc):  0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d
- JanusFT Cadence deployer:         0x4b6bc58bc8bf5dcc
- MemoKeyRegistry (immutable):      0x361bD4d037838A3a9c5408AE465d36077800ee6c
- ShieldedInbox (EVM, immutable):   0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6
- ShieldedCheckpoint (EVM):         0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26
- Cadence ShieldedCheckpoint:       0xd1a02aa46d9151bb
- MockUSDC underlying:              0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524
- AmountDiscloseVerifier:           0xf7B634D41259D0613345633eE1CD193A030A6329
- ConfidentialTransferVerifier:     0x38e69fE7Ba7c2C586d64DFFc14742641A675666c
- ClaimBatchVerifier N=10:          0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f
- BabyJub.sol:                      0xD79C90b797949F0956d977989aEf82A81c860e0C

## Reference

See https://github.com/openjanus/ai-tools for full v0.8.2 documentation.
PrivateTip demo: https://privatetip.vercel.app
```
