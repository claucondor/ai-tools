# JanusERC20 — ADVANCED EVM-DeFi ERC20-wrapping concrete (v0.4)

> **Advanced — for ERC20-native DeFi integrations on Flow EVM.** Most apps
> should **not** use this. OpenJanus is Cadence-first: if you're tipping in
> FLOW, use `JanusFlow`. If you're paying out in a Cadence FungibleToken,
> use `JanusFT`. Only reach for `JanusERC20` when your app already speaks
> ERC20 (e.g. you're integrating with a stablecoin) and you want shielded
> amounts on a pure-EVM workflow.
>
> Cross-VM wrap from Cadence (via a Cadence router similar to JanusFlow's)
> is **not** shipped in v0.4 — it lands in v0.5. Today JanusERC20 is
> consumed only from EVM-side callers (ethers / web3 / a Solidity caller
> contract).

`JanusERC20` is the second concrete subclass of the `JanusToken` abstract base.
It wraps an arbitrary ERC20 underlying instead of native FLOW. Shielded-transfer
privacy is identical to `JanusFlow`; the only difference is the wrap/unwrap
boundary surface.

## Deployment (testnet, v0.6.4)

### JanusMockUSDC (Mock USDC wrapper)

| Layer | Address |
|-------|---------|
| `JanusMockUSDC` proxy (UUPS) | `0xd45FDa099Cf67eD842eA379865AB08E18D62BAf3` |
| `MockUSDC` underlying | `0x8405E8831737aE72204c271581b7d4fAD9f622bE` (6 decimals) |

SDK token ID: `sdk.token('mockusdc')`

### JanusWFLOW (Wrapped FLOW ERC20 wrapper)

| Layer | Address |
|-------|---------|
| `JanusWFLOW` proxy (UUPS) | `0x00129E94d5340bd19d0b4ed9CDf718BB6e0A9400` |
| `WFLOW9` underlying | `0xe7BbEAcC04A589e4B70922b2796Bb4F8e6e4873C` |

SDK token ID: `sdk.token('wflow')`

### Shared primitives

| Contract | Address |
|----------|---------|
| `AmountDiscloseVerifier` | `0xD0ED3936530258C278f5357C1dB709ad34768352` |
| `ConfidentialTransferVerifier` | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` |
| `BabyJub` | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |

> **Address changes from v0.5.x:** Old JanusERC20 proxy `0xf2C04b1A32B815ac7Ffd87a4C312096592BBCa1e`
> and old MockUSDC `0x3e8973dE565743Ef9748779bE377BBE050A13C22` are deprecated.
> Use v0.6.4 addresses above.

## Why MockUSDC

Flow EVM testnet does NOT have a canonical USDC contract. To give apps a
stable 6-decimal underlying address to develop against, the v0.4 deployment
ships its own `MockUSDC` (permissionlessly mintable — testnet ONLY).

For mainnet: deploy a fresh `JanusERC20Proxy` whose `initialize(...)` call
pins the real ERC20 (e.g. canonical USDC) as the underlying. The proxy is
one-instance-per-underlying — to wrap a second ERC20, deploy a second proxy.

## Solidity surface

```solidity
contract JanusERC20 is JanusToken {
    uint256 public constant MAX_WRAP = 18_000_000_000_000_000_000; // 2^64-ish raw units
    address public underlying;                                    // pinned at initialize

    function initialize(
        address babyJub,
        address transferVerifier,
        address amountDiscloseVerifier,
        address underlyingERC20,
        address owner
    ) external initializer;

    function wrap(
        uint256 amount,                  // VISIBLE BY DESIGN — boundary
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof
    ) external;                          // NOT payable

    function unwrap(
        uint256 claimedAmount,
        address payable recipient,
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof,
        uint256[6] calldata transferPublicInputs,
        uint256[8] calldata transferProof
    ) external;

    function underlyingBalance() external view returns (uint256);
}
```

## Wrap pattern (two-step — approve then pull)

```text
caller            MockUSDC                JanusERC20 proxy
  |                  |                          |
  |--approve(proxy,amount)----------------------> emits Approval(caller, proxy, amount)
  |
  |--wrap(amount, txCommit, amountProof)-------->
  |                  | transferFrom(caller, proxy, amount)
  |                  |<------------------------- emits Transfer(caller, proxy, amount)
  |                  |                          | verifyAmountDisclose(amount, txCommit, proof)
  |                  |                          | _acceptShieldedCredit(caller, txCommit)
  |                  |                          | totalLocked += amount
  |                                              | emits Wrapped(caller, amount)
```

Both the underlying `Transfer(caller, proxy, amount)` event AND the
`Wrapped(caller, amount)` event LEAK the amount. This is intentional —
matches the JanusFlow `msg.value` boundary leak.

## Shielded transfer

Identical to JanusFlow.shieldedTransfer — inherited unchanged from the
abstract base. Amount HIDDEN on calldata, events (`ConfidentialTransfer(from,to)`
carries no amount), and storage (commitments are opaque Pedersen points).
NO ERC20 events on the underlying.

## Unwrap

Mirror of `wrap` — calls `IERC20(underlying).transfer(recipient, claimedAmount)`.
The standard `Transfer(proxy, recipient, claimedAmount)` event on the
underlying LEAKS the amount + recipient at the boundary. The `Unwrapped`
event on JanusERC20 itself also LEAKS the amount.

Verified end-to-end on testnet (see
`packages/janus-erc20/deployments/smoke-janus-erc20-v0.4.json`):

- Alice mints 100 mUSDC → approves proxy → wraps → totalLocked +100M
- Alice shielded-transfers 30 mUSDC to Bob → NO cleartext in calldata, NO
  amount in event, NO ERC20 events from underlying, totalLocked unchanged
- Bob unwraps 30 mUSDC → totalLocked -30M, Bob's underlying balance += 30M

## TypeScript usage (via @claucondor/sdk@0.6.5)

```typescript
import { OpenJanusSDK } from "@claucondor/sdk";
import { ethers } from "ethers";

const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const sdk = new OpenJanusSDK({ network: "testnet" });

// JanusMockUSDC
const usdc = sdk.token('mockusdc');
await usdc.connectWithSigner(wallet);

// 1. Approve the underlying (MockUSDC at 0x8405E8831737aE72204c271581b7d4fAD9f622bE)
const MOCK_USDC = "0x8405E8831737aE72204c271581b7d4fAD9f622bE";
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

// JanusWFLOW — same pattern
const wflow = sdk.token('wflow');
await wflow.connectWithSigner(wallet);
const WFLOW9 = "0xe7BbEAcC04A589e4B70922b2796Bb4F8e6e4873C";
const wflow9 = new ethers.Contract(WFLOW9, ["function approve(address,uint256) returns(bool)"], wallet);
await (await wflow9.approve(wflow.address, 5n * 10n**18n)).wait();
await wflow.wrap({ grossAmount: 5n * 10n**18n }, wallet);
```

## v0.4 limitations

- One JanusERC20 instance per underlying (proxy storage pins `underlying`
  immutably after initialize). To wrap multiple ERC20s, deploy multiple proxies.
- Per-call wrap cap is `MAX_WRAP = 2^64 - 1` raw token units (~18.4M for
  6-decimal tokens). Matches the Num2Bits range proof in the
  `confidential_transfer` circuit.
- No Cadence router for JanusERC20 yet — apps must call directly via
  ethers.js + a Flow EVM signer (or write their own COA-based Cadence tx).
  The Cadence router for JanusERC20 is on the v0.5 roadmap.
