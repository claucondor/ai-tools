# JanusERC20 — ADVANCED EVM-DeFi ERC20-wrapping concrete (v0.8)

> **Advanced — for ERC20-native DeFi integrations on Flow EVM.** Most apps
> should **not** use this. OpenJanus is Cadence-first: if you're tipping in
> FLOW, use `JanusFlow`. If you're paying out in a Cadence FungibleToken,
> use `JanusFT`. Only reach for `JanusERC20` when your app already speaks
> ERC20 (e.g. you're integrating with a stablecoin) and you want shielded
> amounts on a pure-EVM workflow.
>
> Cross-VM wrap from Cadence is not available — JanusERC20 is
> consumed only from EVM-side callers (ethers / web3 / a Solidity caller
> contract).

`JanusERC20` is the second concrete subclass of the `JanusToken` abstract base.
It wraps an arbitrary ERC20 underlying instead of native FLOW. Shielded-transfer
privacy is identical to `JanusFlow`; the only difference is the wrap/unwrap
boundary surface.

> **v0.8 changes from v0.5:**
> - 9-arg `shieldedTransfer` removed — inherited 6-arg from base (senderSnapshot dropped).
> - `ShieldedInbox` integration — push-model, see warning below.
> - `claimBatch()` available (on JanusERC20 directly, not the base, to avoid slot collision).
> - `adminBatchResetSlots()` inherited.
> - VERSION = "0.8.1".

## Deployment (testnet, v0.8)

### JanusERC20 — Mock USDC (mUSDC) wrapper

| Layer | Address | Notes |
|-------|---------|-------|
| `JanusERC20` proxy (UUPS) | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` | v0.8.1 impl |
| `MockUSDC` (mUSDC) underlying | `0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524` | 6 decimals, mintable testnet only |
| `MemoKeyRegistry` | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` | shared |
| `ShieldedInbox` | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` | per-user mailbox |
| `ShieldedCheckpoint` | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` | per-user per-token state |

SDK token ID: `sdk.token('mockusdc')`

### Shared primitives

| Contract | Address |
|----------|---------|
| `AmountDiscloseAggregateVerifier` | `0xf7B634D41259D0613345633eE1CD193A030A6329` |
| `ConfidentialTransferAggregateVerifier` | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` |
| `ConfidentialClaimBatchVerifier` (N=10) | `0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f` |
| `BabyJub` | `0xD79C90b797949F0956d977989aEf82A81c860e0C` |
| `Pedersen2Gen` | `0x5EdF7473b1007b4855127bC40fcc89eCDD7fB561` |


## Why MockUSDC (mUSDC)

Flow EVM testnet does NOT have a canonical USDC contract. To give apps a
stable 6-decimal underlying address to develop against, the v0.8 deployment
ships its own `MockUSDC` (permissionlessly mintable — testnet ONLY).

For mainnet: deploy a fresh `JanusERC20_Proxy` whose `initialize(...)` call
pins the real ERC20 (e.g. canonical USDC) as the underlying. One proxy per
underlying — to wrap a second ERC20, deploy a second proxy.


## Solidity surface (v0.8)

```solidity
contract JanusERC20 is JanusToken {
    string  public constant VERSION  = "0.8.1";
    uint256 public constant MAX_WRAP = 18_000_000_000_000_000_000;

    // Storage after JanusToken base (slot 93 = shieldedInbox):
    //   slot 94: underlying (address) — pinned at initialize, IMMUTABLE after
    //   slot 95: batchClaimVerifier (address) — JanusERC20-specific (avoids slot 94 collision with base)

    address public underlying;

    function initialize(
        address _babyJub,
        address _transferVerifier,
        address _amountDiscloseVerifier,
        address _owner,
        address _memoRegistry,
        address _pedersen2Gen,
        address _inboxAddress,
        address _batchClaimVerifier,
        address _underlying           // ERC20 underlying — IMMUTABLE after init
    ) external initializer;

    // NOT payable — ERC20 pull via transferFrom
    // Requires: ERC20.approve(proxy, amount) first
    function wrapWithProof(
        uint256 nonce,
        uint256 amount,                  // VISIBLE BY DESIGN — boundary leak
        uint256[2] calldata commit,
        uint256[2] calldata pA,
        uint256[2][2] calldata pB,
        uint256[2] calldata pC,
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY
    ) external;

    // 6-arg shieldedTransfer (inherited from base, v0.8)
    // function shieldedTransfer(address to, uint256[6] calldata publicInputs,
    //   uint256[8] calldata proof, bytes calldata encryptedNoteTo,
    //   uint256 ephPubkeyToX, uint256 ephPubkeyToY) external;

    function unwrap(
        uint256 claimedAmount,
        address payable recipient,
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof,
        uint256[6] calldata transferPublicInputs,
        uint256[8] calldata transferProof,
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY
    ) external;

    // Batch drain N=10 inbox notes — JanusERC20-specific override (slot 95)
    function claimBatch(
        uint256[6] calldata publicInputs,
        uint256[8] calldata proof
    ) external;

    // Owner-only admin
    function setBatchClaimVerifier(address _verifier) external onlyOwner;
    function setMemoRegistry(address registry) external onlyOwner;
    function initFees(address recipient, uint16 bps) external onlyOwner;
    function setFeeRecipient(address newRecipient) external onlyOwner;
    function setFeeBps(uint16 newBps) external onlyOwner;

    // Views
    function underlyingBalance() external view returns (uint256);
    function getMemoKeyFromRegistry(address user) external view returns (uint256 x, uint256 y);
    function computeFee(uint256 grossAmount) public view returns (uint256);
}
```


## Wrap pattern (two-step — approve then pull)

```text
caller            MockUSDC (mUSDC)         JanusERC20 proxy (v0.8)
  |                   |                         |
  |--approve(proxy, amount)--------------------> emits Approval
  |
  |--wrapWithProof(nonce, amount, commit, pA, pB, pC, snapshot, ephX, ephY)-->
  |                   | transferFrom(caller, proxy, amount)
  |                   |<---------emits Transfer(caller, proxy, amount)  ← LEAKS amount
  |                   |                         | verifyAmountDisclose
  |                   |                         | accumulate commit → commitments[caller]
  |                   |                         | totalLocked += net
  |                                             | emits WrapWithSnapshot(caller, net, ...)
```

The underlying `Transfer(caller, proxy, amount)` event leaks the amount. This is intentional — matches JanusFlow `msg.value` boundary leak.


## ShieldedInbox push-model warning

`shieldedTransfer` atomically pushes a note to `ShieldedInbox`. If the recipient's inbox is full (`MAX_INBOX_NOTES = 10000`), the call **reverts**. Recipients must drain via `claimBatch()`. Warn users in your UI if the recipient inbox is nearly full.


## TypeScript usage (via @claucondor/sdk, v0.8)

```typescript
import { OpenJanusSDK } from "@claucondor/sdk";
import { ethers } from "ethers";

const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const sdk = new OpenJanusSDK({ network: "testnet" });

// JanusERC20 (mUSDC)
const usdc = sdk.token('mockusdc');
await usdc.connectWithSigner(wallet);

// 1. Approve the underlying (MockUSDC / mUSDC)
const MOCK_USDC = "0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524";
const mockUsdc = new ethers.Contract(MOCK_USDC, ["function approve(address,uint256) returns(bool)"], wallet);
const amount = 1_000_000n; // 1 mUSDC at 6 decimals
await (await mockUsdc.approve(usdc.address, amount)).wait();

// 2. WrapWithProof (nonce + proof generated by SDK)
await usdc.wrapWithProof({ grossAmount: amount }, wallet);

// 3. Shielded transfer — note atomically deposited to recipient's ShieldedInbox
await usdc.shieldedTransfer({ recipient, amount: xferAmount, currentBalance, currentBlinding,
  recipientMemoKeyPubkey }, wallet);

// 4. Claim batch inbox notes
await usdc.claimBatch({ inboxNotes }, wallet);

// 5. Read state
const totalLocked = await usdc.totalLocked();
const myCommit = await usdc.balanceOfCommitment(wallet.address);
```


## v0.8 slot notes

- `underlying` at slot 94 (JanusERC20-specific — base uses slot 94 for `batchClaimVerifier`, so ERC20 overrides this slot).
- `batchClaimVerifier` at slot 95 (consuming one slot from `__gapERC20`; gap reduced from 50 to 49).
- Storage layout is compatible with the v0.7 JanusERC20 proxy (no breaking upgrade).


## v0.8 limitations

- One JanusERC20 instance per underlying — `underlying` is immutable after `initialize()`. To wrap a second ERC20, deploy a second proxy.
- Per-call wrap cap is `MAX_WRAP = 18_000_000_000_000_000_000` raw units (~18M for 6-decimal tokens). Split larger amounts across multiple wraps.
- No Cadence router for JanusERC20 — apps must call directly via ethers.js + a Flow EVM signer (or write their own COA-based Cadence transaction).
