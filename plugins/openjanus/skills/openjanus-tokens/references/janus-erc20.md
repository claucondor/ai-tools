# JanusERC20 — ADVANCED EVM-DeFi ERC20-wrapping concrete (v0.5)

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

## Deployment (testnet, v0.5)

### JanusMockUSDC (Mock USDC wrapper)

| Layer | Address |
|-------|---------|
| `JanusMockUSDC` proxy (UUPS) | `0xf2C04b1A32B815ac7Ffd87a4C312096592BBCa1e` |
| `JanusMockUSDC` impl (v0.5) | `0x10348fc1e29751B79EDAd427d1098bC83B10028D` |
| `MockUSDC` underlying | `0x3e8973dE565743Ef9748779bE377BBE050A13C22` (6 decimals) |
| `MemoKeyRegistry` | `0x05D104962ff087441f26BA11A1E1C3b9E091D663` |

SDK token ID: `sdk.token('mockusdc')`

### Shared primitives

| Contract | Address |
|----------|---------|
| `AmountDiscloseVerifier` | `0xD0ED3936530258C278f5357C1dB709ad34768352` |
| `ConfidentialTransferVerifier` | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` |
| `BabyJub` | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |


## Why MockUSDC

Flow EVM testnet does NOT have a canonical USDC contract. To give apps a
stable 6-decimal underlying address to develop against, the v0.5 deployment
ships its own `MockUSDC` (permissionlessly mintable — testnet ONLY).

For mainnet: deploy a fresh `JanusERC20_Proxy` whose `initialize(...)` call
pins the real ERC20 (e.g. canonical USDC) as the underlying. The proxy is
one-instance-per-underlying — to wrap a second ERC20, deploy a second proxy.

## Solidity surface (v0.5)

```solidity
contract JanusERC20 is JanusToken {
    string  public constant VERSION  = "0.5.0";
    uint256 public constant MAX_WRAP = 18_000_000_000_000_000_000;

    address public underlying;                    // slot 47 — pinned at initialize
    mapping(address => uint256) public firstSnapshotBlock; // slot 48
    address public feeRecipient;                  // slot 49
    uint16  public feeBps;                        // slot 50
    IMemoKeyRegistry public memoRegistry;         // slot 51

    // Initialize (for new proxies only — not called on UUPS upgrade)
    function initialize(
        address babyJub,
        address transferVerifier,
        address amountDiscloseVerifier,
        address underlyingERC20,
        address owner,
        address memoRegistry
    ) external initializer;

    // v0.6.3+ SDK wrap signature (NEW selector in v0.5)
    function wrap(
        uint256 amount,                  // VISIBLE BY DESIGN — boundary leak
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof,
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY
    ) external;                          // NOT payable

    // v0.6.3+ SDK shieldedTransfer signature (NEW selector 0x6218f5d9 in v0.5)
    function shieldedTransfer(
        address to,
        uint256[6] calldata publicInputs,
        uint256[8] calldata proof,
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY,
        bytes calldata encryptedNoteTo,
        uint256 ephPubkeyToX,
        uint256 ephPubkeyToY
    ) external;

    // v0.6.3+ SDK unwrap signature (NEW selector in v0.5)
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

    // Post-upgrade admin (owner-only)
    function setMemoRegistry(address registry) external onlyOwner;
    function initFees(address recipient, uint16 bps) external onlyOwner;
    function setFeeRecipient(address newRecipient) external onlyOwner;
    function setFeeBps(uint16 newBps) external onlyOwner;

    function underlyingBalance() external view returns (uint256);
    function getMemoKeyFromRegistry(address user) external view returns (uint256 x, uint256 y);
    function computeFee(uint256 grossAmount) public view returns (uint256);
}
```

## Events emitted (v0.5)

```solidity
event WrapWithSnapshot(
    address indexed user,
    uint256 amount,
    bytes encryptedSnapshot,
    uint256 ephPubkeyX,
    uint256 ephPubkeyY
);

event ShieldedTransferWithSnapshot(
    address indexed from,
    address indexed to,
    bytes encryptedSnapshotFrom,
    uint256 ephPubkeyFromX,
    uint256 ephPubkeyFromY,
    bytes encryptedNoteTo,
    uint256 ephPubkeyToX,
    uint256 ephPubkeyToY
);

event UnwrapWithSnapshot(
    address indexed user,
    address indexed recipient,
    uint256 amount,
    bytes encryptedSnapshot,
    uint256 ephPubkeyX,
    uint256 ephPubkeyY
);
```

## Wrap pattern (two-step — approve then pull)

```text
caller            MockUSDC                JanusERC20 proxy (v0.5)
  |                  |                          |
  |--approve(proxy,amount)----------------------> emits Approval(caller, proxy, amount)
  |
  |--wrap(amount, txCommit, proof, snapshot, ephX, ephY)-------->
  |                  | transferFrom(caller, proxy, amount)
  |                  |<------------------------- emits Transfer(caller, proxy, amount)
  |                  |                          | _calcFee, _wrap, verifyAmountDisclose
  |                  |                          | _acceptShieldedCredit(caller, txCommit)
  |                  |                          | totalLocked += net
  |                                              | emits WrapWithSnapshot(caller, net, ...)
```

Both the underlying `Transfer(caller, proxy, amount)` event AND the
`WrapWithSnapshot(caller, net, ...)` event LEAK the amount. This is intentional —
matches the JanusFlow `msg.value` boundary leak.

## Shielded transfer (v0.5)

Identical semantics to JanusFlow.shieldedTransfer — amount HIDDEN on calldata,
events (`ConfidentialTransfer(from,to)` carries no amount), and storage
(commitments are opaque Pedersen points). NO ERC20 events on the underlying.

The v0.5 override adds `encryptedSnapshot` + `encryptedNoteTo` args for
on-chain snapshot storage (SDK recovery path). Emits `ShieldedTransferWithSnapshot`.

## Selector quick reference

| Function | Selector |
|----------|----------|
| `wrap(uint256,uint256[2],uint256[8],bytes,uint256,uint256)` | v0.5 NEW |
| `shieldedTransfer(address,uint256[6],uint256[8],bytes,uint256,uint256,bytes,uint256,uint256)` | `0x6218f5d9` |
| `unwrap(uint256,address,uint256[2],uint256[8],uint256[6],uint256[8],bytes,uint256,uint256)` | v0.5 NEW |
| `firstSnapshotBlock(address)` | v0.5 NEW |
| `feeBps()` | v0.5 NEW |
| `memoRegistry()` | v0.5 NEW |

The legacy 3-arg `shieldedTransfer(address,uint256[6],uint256[8])` (selector `0x5764e916`) and
legacy 3-arg `wrap(uint256,uint256[2],uint256[8])` remain accessible via inherited
JanusToken v0.3 — no breaking change for legacy callers.

## TypeScript usage (via @claucondor/sdk)

```typescript
import { OpenJanusSDK } from "@claucondor/sdk";
import { ethers } from "ethers";

const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const sdk = new OpenJanusSDK({ network: "testnet" });

// JanusMockUSDC
const usdc = sdk.token('mockusdc');
await usdc.connectWithSigner(wallet);

// 1. Approve the underlying (MockUSDC)
const MOCK_USDC = "0x3e8973dE565743Ef9748779bE377BBE050A13C22";
const mockUsdc = new ethers.Contract(MOCK_USDC, ["function approve(address,uint256) returns(bool)"], wallet);
const amount = 1_000_000n; // 1 mUSDC at 6 decimals
await (await mockUsdc.approve(usdc.address, amount)).wait();

// 2. Wrap
await usdc.wrap({ grossAmount: amount }, wallet);

// 3. Shielded transfer
await usdc.shieldedTransfer({ recipient, amount: xferAmount, currentBalance, currentBlinding }, wallet);

// 4. Read state
const totalLocked = await usdc.totalLocked();
const myCommit = await usdc.balanceOfCommitment(wallet.address);
```

## v0.5 upgrade summary

v0.5 is a UUPS upgrade of the v0.4 proxy. Storage layout is compatible:
- `underlying` stays at slot 47 (unchanged)
- `firstSnapshotBlock`, `feeRecipient`, `feeBps`, `memoRegistry` added at slots 48-51
  (previously zero gap slots — safe to consume)

Post-upgrade, `setMemoRegistry(0x05D104962ff087441f26BA11A1E1C3b9E091D663)` was
called to wire in the shared registry.

## v0.5 limitations

- One JanusERC20 instance per underlying (proxy storage pins `underlying`
  immutably after initialize). To wrap multiple ERC20s, deploy multiple proxies.
- Per-call wrap cap is `MAX_WRAP = 18_000_000_000_000_000_000` raw units
  (~18M for 6-decimal tokens). Matches the Num2Bits range proof boundary.
- No Cadence router for JanusERC20 — apps must call directly via
  ethers.js + a Flow EVM signer (or write their own COA-based Cadence tx).
