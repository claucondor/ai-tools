# JanusFlow — PRIMARY Cadence-first FLOW privacy primitive (v0.8)

> **PRIMARY token — use this for Cadence-first apps.** JanusFlow is the
> recommended OpenJanus primitive for most apps: tipping, payroll, donations,
> any FLOW-denominated privacy use case. Cadence users sign normal Cadence
> transactions; the cross-VM EVM call is the implementation detail they
> never see.
>
> Companion (also Cadence-first): `JanusFT` — same shape but wraps any
> Cadence `FungibleToken` vault (use for non-FLOW Cadence tokens).
>
> Advanced (EVM-DeFi only): `JanusERC20` — wraps a native ERC20 underlying.
> Only use if you are building on Flow EVM and need to wrap native ERC20s.

JanusFlow is the native FLOW confidential token. The v0.8 SDK exposes it via the EVM proxy
(ethers.js + COA path). The EVM implementation is swappable via UUPS proxy.
All operations use `feeBps=10` (0.1% on wrap/unwrap, free on shielded transfer).

> **v0.8 changes from v0.6.x:**
> - `wrap()` renamed to `wrapWithProof()` — now includes a caller-chosen `nonce` for anti-replay.
> - `shieldedTransfer` is 6-arg — sender snapshot removed; senders update `ShieldedCheckpoint` separately.
> - `ShieldedInbox` integration — each `shieldedTransfer` atomically deposits an encrypted note to the recipient's inbox. **PUSH-MODEL WARNING:** if inbox is full, `shieldedTransfer` reverts.
> - `claimBatch(publicInputs, proof)` — drain up to N=10 inbox notes in one Groth16 proof.


## Deployed contract (canonical — v0.8)

| Layer | Address | Contract | Notes |
|-------|---------|---------|-------|
| EVM (proxy) | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` | `JanusFlow` | UUPS proxy, v0.8.1 impl — feeBps=10 |
| ShieldedInbox | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` | immutable | per-user mailbox, atomically receives notes |
| ShieldedCheckpoint | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` | immutable | per-user per-token sender state |
| MemoKeyRegistry | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` | immutable | shared across all tokens |

Legacy v0.7.1 proxy (still serves PrivateTip demo): `0x9A83732417947Ef9b7AEa64bF807a345267c2FdA` — do NOT use for new work.

SDK token ID: `sdk.token('flow')`

## Architecture — EVM UUPS proxy

**EVM UUPS proxy**: holds all Pedersen commitment state on-chain. The implementation
is swappable via `upgradeToAndCall`. The UUPS owner is the admin COA
(`0x0000000000000000000000020885d7ad3582356a`).

The UUPS pattern means a proxy upgrade never changes the proxy address — apps always
call `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` regardless of which impl is active.

## User-facing operations (v0.8)

1. **wrapWithProof**: payable — gross FLOW → nonce check → AmountDisclose proof → fee deduction → `Pedersen(net, blinding)` added to commitment slot. Anti-replay via `usedNonces[caller][nonce]`.
2. **shieldedTransfer**: not payable — splits sender commitment into `(C_new_sender, C_tx)`, accumulates `C_tx` into recipient commitment via `Pedersen2Gen.addCommits`. Atomically deposits encrypted note to `ShieldedInbox`. **REVERTS if inbox full.**
3. **claimBatch**: not payable — batch-accumulates N=10 inbox notes into caller's commitment with one Groth16 proof. Caller must know `(amount_i, blinding_i)` for each note (from inbox ciphertexts).
4. **unwrap**: not payable — verifies amount-disclose + transfer proof, deducts fee, sends FLOW to recipient.

After a `shieldedTransfer`, the **sender** should call `ShieldedCheckpoint.update(token, encryptedSnapshot, ...)` in a separate transaction to persist their new state for cross-device recovery.

## ShieldedInbox push-model warning

`ShieldedInbox.MAX_INBOX_NOTES = 10000`. If a recipient has 10000 unread notes, any `shieldedTransfer` to them **reverts**. Your UI should:
1. Track the recipient's inbox note count before sending.
2. Warn if the inbox is nearly full.
3. Guide recipients to call `claimBatch()` to drain their inbox.

## Admin operations

Only the EVM UUPS owner (admin COA) can upgrade the implementation.

Public views (anyone can call):
- `isPaused()` — true if paused
- `feeBps()` — current fee in basis points (default 10 = 0.1%)
- `feeRecipient()` — current fee recipient address
- `balanceOfCommitment(address)` — opaque Point (requires blinding to decode)
- `totalLocked()` — cleartext pool aggregate
- `usedNonces(address, uint256)` — true if nonce has been consumed

## CU budget notes

JanusFlow Cadence transactions call the EVM proxy via COA. The 9999 CU limit applies to the entire Cadence transaction including cross-VM calls.

Operations near the limit:
- `wrapWithProof`: COA call includes AmountDisclose Groth16 verify + nonce check.
- `shieldedTransfer`: COA call includes ConfidentialTransfer Groth16 verify + ShieldedInbox deposit.
- `claimBatch`: ClaimBatch Groth16 verify (N=10).
- `unwrap`: two Groth16 verifies (amount-disclose + confidential-transfer).

All four have been tested within the 9999 CU ceiling. Do not add extra EVM calls to these transactions.

## SDK integration (v0.8)

```typescript
import { OpenJanusSDK, deriveMemoKeyFromSignature } from "@claucondor/sdk";
import { ethers } from "ethers";

const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
const sdk = new OpenJanusSDK({ network: "testnet" });
const flow = sdk.token('flow');
// flow.address === "0xA64340C1d356835A2450306Ffd290Ed52c001Ad3"

await flow.connectWithSigner(wallet);

// MemoKey — publish once (covers all tokens via MemoKeyRegistry)
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
await flow.publishMemoKey(memoKeypair, wallet);

// Wrap (nonce + proof generated automatically by SDK)
await flow.wrapWithProof({ grossAmount: 10n * 10n**18n }, wallet);

// Shielded transfer — encrypted note deposited to recipient's ShieldedInbox automatically
await flow.shieldedTransfer({
  recipient, amount, currentBalance, currentBlinding,
  recipientMemoKeyPubkey,  // fetched from MemoKeyRegistry
}, wallet);

// After a transfer: update sender checkpoint (separate tx)
await sdk.checkpoint.update({
  token: flow.address,
  newBalance, newBlinding,
}, wallet);

// Drain inbox notes (claimBatch)
await flow.claimBatch({ inboxNotes }, wallet);

// Unwrap
await flow.unwrap({ claimedAmount, recipient, currentBalance, currentBlinding }, wallet);
```

## MemoKey / MemoKeyRegistry (v0.8)

The canonical MemoKey registry is the **immutable EVM contract** `MemoKeyRegistry`
at `0x361bD4d037838A3a9c5408AE465d36077800ee6c`. One `publishMemoKey` call covers all tokens.

```typescript
import { deriveMemoKeyFromSignature } from "@claucondor/sdk";
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
await sdk.token('flow').publishMemoKey(memoKeypair, wallet);
```

## wrapWithProof ABI (EVM direct)

```solidity
// payable — msg.value is GROSS; proof must bind to NET (post-fee)
function wrapWithProof(
    uint256 nonce,              // Anti-replay. Must be unused for msg.sender.
    uint256[2] calldata commit, // [commitX, commitY] — Pedersen commitment
    uint256[2] calldata pA,     // Groth16 proof element A
    uint256[2][2] calldata pB,  // Groth16 proof element B (FP2, snarkjs convention)
    uint256[2] calldata pC,     // Groth16 proof element C
    bytes calldata encryptedSnapshot,
    uint256 ephPubkeyX,
    uint256 ephPubkeyY
) external payable;
```

Public input layout verified by `AmountDiscloseAggregateVerifier`:
```
[amount (net), commitX, commitY, nonce]
```

## shieldedTransfer ABI (EVM direct, v0.8 — 6 args)

```solidity
function shieldedTransfer(
    address to,
    uint256[6] calldata publicInputs,  // [C_old_x, C_old_y, C_tx_x, C_tx_y, C_new_x, C_new_y]
    uint256[8] calldata proof,
    bytes calldata encryptedNoteTo,    // ECIES-encrypted note for recipient
    uint256 ephPubkeyToX,
    uint256 ephPubkeyToY
) external;
```

## claimBatch ABI (EVM direct, v0.8)

```solidity
function claimBatch(
    uint256[6] calldata publicInputs,  // [C_old_x, C_old_y, C_new_x, C_new_y, C_consumed_x, C_consumed_y]
    uint256[8] calldata proof
) external;
```

## See also

- [janus-token.md](janus-token.md) — The underlying EVM contract (slot layout, full ABI)
- [confidential-tipping.md](confidential-tipping.md) — Recommended pattern for new apps
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — Full SDK quick start
- [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md) — All testnet addresses
