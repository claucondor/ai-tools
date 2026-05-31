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

## Deployment (testnet, 2026-05-27)

| Layer | Address |
|-------|---------|
| `JanusERC20` proxy (UUPS) | `0xf2C04b1A32B815ac7Ffd87a4C312096592BBCa1e` |
| `JanusERC20` impl | `0x7FE0B05ED77E0540519B6f10DD4b4521e867590D` |
| `MockUSDC` underlying | `0x3e8973dE565743Ef9748779bE377BBE050A13C22` (6 decimals) |
| Owner (admin COA) | `0x0000000000000000000000022f6b30af48a94787` |

Reused from v0.3 — `AmountDiscloseVerifier`, `ConfidentialTransferVerifier`,
`BabyJub` (see canonical-addresses for the addresses).

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

## TypeScript usage (via @openjanus/sdk@0.5.4)

```typescript
import {
  JanusERC20,
  JANUS_ERC20_MOCK_USDC_ADDRESS,
  ERC20_MINIMAL_ABI,
} from "@openjanus/sdk";
import { buildAmountDiscloseProof, generateBlinding } from "@openjanus/sdk/crypto";
import { ethers } from "ethers";

const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const usdc = new JanusERC20();
await usdc.connectWithSigner(wallet);

// 1. Approve the underlying
const mUsdc = new ethers.Contract(JANUS_ERC20_MOCK_USDC_ADDRESS, ERC20_MINIMAL_ABI, wallet);
const amount = 1_000_000n; // 1 mUSDC at 6 decimals
await (await mUsdc.approve(usdc.address, amount)).wait();

// 2. Build the amount-disclose proof + wrap
const blinding = generateBlinding();
const ad = await buildAmountDiscloseProof({ amount, blinding });
await usdc.wrap({
  amountRaw: amount,
  txCommit: [ad.commitX, ad.commitY],
  amountProof: ad.proof,
});

// 3. Read state
const totalLocked = await usdc.totalLocked();
const myCommit = await usdc.balanceOfCommitment(wallet.address);
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
