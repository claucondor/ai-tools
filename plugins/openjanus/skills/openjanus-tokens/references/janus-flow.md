# JanusFlow — PRIMARY Cadence-first FLOW privacy primitive

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

JanusFlow is the native FLOW confidential token. The v0.6.4 SDK primarily exposes it
via the EVM proxy (direct ethers.js path). The EVM implementation is swappable via
UUPS proxy. All operations use `feeBps=10` (0.1% on wrap/unwrap, free on shielded transfer).


## Deployed contract (canonical — v0.6.4)

| Layer | Address | Contract | Notes |
|-------|---------|---------|-------|
| EVM (proxy) | `0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156` | `JanusFlow` | UUPS proxy, stable — feeBps=10 |
| MemoKeyRegistry | `0x05D104962ff087441f26BA11A1E1C3b9E091D663` | immutable | shared across all 4 tokens |

SDK token ID: `sdk.token('flow')`

## Architecture — EVM UUPS proxy

**EVM UUPS proxy**: holds all Pedersen commitment state on-chain. The implementation
is swappable via `upgradeToAndCall`. The UUPS owner is the admin COA.

The UUPS pattern means a proxy upgrade never changes the proxy address — apps always
call `0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156` regardless of which impl is active.

## User-facing operations (v0.6.4)

JanusFlow operations:

1. On `wrap`: EVM deducts 0.1% fee → adds `Pedersen(netAmount, blinding)` to slot
2. On `unwrap`: EVM verifies proofs → deducts 0.1% fee → sends `netToRecipient` FLOW
3. On `shieldedTransfer`: no fee — EVM splits sender commitment into (residual, transferred)

## Admin operations

Only the EVM UUPS owner (admin COA) can upgrade the implementation.

Public views (anyone can call):
- `isPaused()` — true if paused
- `getActiveImplVersion()` — current impl version string
- `feeBps()` — current fee in basis points (default 10 = 0.1%)
- `feeRecipient()` — current fee recipient address

## CU budget notes

JanusFlow Cadence transactions call the EVM proxy via COA. The 9999 CU limit applies
to the entire Cadence transaction including cross-VM calls.

Operations near the limit:
- `wrap`: COA call includes on-chain Groth16 verify (~300k EVM gas). Most expensive operation.
- `unwrap`: COA call includes two Groth16 verifies (amount-disclose + confidential-transfer).
- `shieldedTransfer`: COA call includes one Groth16 verify.

All three operations have been tested within the 9999 CU ceiling. If you add additional
logic to these transactions (extra reads, multiple recipients), measure CU consumption carefully.

## SDK integration

The `@claucondor/sdk/tokens` module provides high-level TypeScript wrappers for all JanusFlow
operations. See [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) for the full workflow.

```typescript
import { OpenJanusSDK, deriveMemoKeyFromSignature } from "@claucondor/sdk";
import { ethers } from "ethers";

const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
const sdk = new OpenJanusSDK({ network: "testnet" });
const flow = sdk.token('flow');
// flow.address === "0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156"

await flow.connectWithSigner(wallet);

// MemoKey — publish once (covers all 4 tokens via MemoKeyRegistry)
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
await flow.publishMemoKey(memoKeypair, wallet);

// Wrap (snapshot for cross-device recovery is automatic)
await flow.wrap({ grossAmount: 10n * 10n**18n }, wallet);

// Shielded transfer
await flow.shieldedTransfer({
  recipient, amount, memo, currentBalance, currentBlinding,
}, wallet);

// Unwrap
await flow.unwrap({ claimedAmount, recipient, currentBalance, currentBlinding }, wallet);
```

## MemoKey / MemoKeyRegistry (v0.6.4)

In v0.6.4, the canonical MemoKey registry is the **immutable EVM contract**
`MemoKeyRegistry` at `0x05D104962ff087441f26BA11A1E1C3b9E091D663`. One
`publishMemoKey` call covers all 4 tokens.

```typescript
import { deriveMemoKeyFromSignature } from "@claucondor/sdk";
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
await sdk.token('flow').publishMemoKey(memoKeypair, wallet);
```

### EVM API

The JanusFlow EVM proxy exposes a symmetric registry so EVM contracts and
scanners can look up MemoKey pubkeys without a Cadence script:

```solidity
// selector 0x6370796a
function publishMemoKey(uint256 pubkeyX, uint256 pubkeyY) external;

// Read mappings (set by publishMemoKey)
function memoKeyPubX(address user) view returns (uint256);
function memoKeyPubY(address user) view returns (uint256);
```

**The privkey NEVER goes on-chain.** Only `(pubkeyX, pubkeyY)` are submitted via `publishMemoKey(x, y)` on the EVM proxy. The privkey is derived client-side via sign-derive (HKDF over wallet signature) and cached in `sessionStorage`.

### SDK integration

```typescript
import { recovery } from "@claucondor/sdk";
// Or from subpath:
import { encryptSnapshotToSelf } from "@claucondor/sdk/recovery";

// Encrypt a snapshot to the user's own pubkey (for recovery events):
const snap = await encryptSnapshotToSelf(
  { balance: newBalanceWei, blinding: newBlinding },
  myMemoKeyPubkey
);
// snap.ciphertext, snap.ephPubkey.x, snap.ephPubkey.y
// → pass to buildWrapCalldata / buildShieldedTransferCalldata / buildUnwrapCalldata
```

## See also

- [janus-token.md](janus-token.md) — The underlying EVM contract
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — Full SDK quick start
- [../../../openjanus-sdk/references/recovery.md](../../../openjanus-sdk/references/recovery.md) — Recovery module reference
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — BSGS decrypt guide
- [confidential-tipping.md](confidential-tipping.md) — Recommended pattern for new apps
