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

**IMPORTANT:** The old address `0x28fef3d1d6a12800.JanusFlow` is a zombie (legacy v1
Pedersen). Do not import from it.

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

## DEPRECATED — DO NOT USE

- `0x28fef3d1d6a12800.JanusFlow` — legacy v1 Pedersen contract. Zombie, cannot be removed.
- `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078` — v0.5.x JanusFlow proxy (OLD; do not use)
- `0x5dcbeb41055ec57e` — v0.5.x JanusFlow Cadence router (OLD architecture; v0.6.4 uses EVM proxy directly)

## Cadence transaction templates (legacy cross-VM path, v0.5.x)

### Wrap FLOW (v0.5.4 — with snapshot)

```cadence
import JanusFlow from 0x5dcbeb41055ec57e
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

transaction(
    amount:       UFix64,
    txCommitX:    UInt256,
    txCommitY:    UInt256,
    amountProof:  [UInt256],
    encSnapshot:  [UInt8],
    ephPubkeyX:   UInt256,
    ephPubkeyY:   UInt256
) {
    let vault: @FlowToken.Vault

    prepare(signer: auth(BorrowValue) &Account) {
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("No FlowToken.Vault in signer storage")
        self.vault <- flowVault.withdraw(amount: amount) as! @FlowToken.Vault
    }

    execute {
        JanusFlow.wrap(
            vault:        <-self.vault,
            txCommitX:    txCommitX,
            txCommitY:    txCommitY,
            amountProof:  amountProof,
            encSnapshot:  encSnapshot,
            ephPubkeyX:   ephPubkeyX,
            ephPubkeyY:   ephPubkeyY
        )
    }
}
```

### Read commitment (Cadence script)

```cadence
import JanusFlow from 0x5dcbeb41055ec57e

access(all) fun main(user: Address): {String: UInt256} {
    return JanusFlow.getCommitment(user: user)
    // Returns: { "x": ..., "y": ... }  — opaque Pedersen point
}
```

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

**Historical (v0.5.x):** `JanusFlow.MemoKey` was a Cadence resource at
`0x5dcbeb41055ec57e` with storage path `/storage/openjanusMemoKey`. That
Cadence MemoKey pattern is superseded by `MemoKeyRegistry` in v0.6.x.

### Cadence API

```cadence
import JanusFlow from 0x5dcbeb41055ec57e

// Resource type
resource MemoKey: MemoKeyPublic { ... }

// Public interface (readable by any account)
resource interface MemoKeyPublic {
    fun pubkeyX(): UInt256
    fun pubkeyY(): UInt256
}

// Factory
fun createMemoKey(pubkeyX: UInt256, pubkeyY: UInt256): @MemoKey

// Canonical storage paths
fun memoKeyStoragePath(): StoragePath   // /storage/openjanusMemoKey
fun memoKeyPublicPath(): PublicPath     // /public/openjanusMemoKey

// Lookup from any address
fun getMemoPubkey(owner: Address): {String: UInt256}?
// Returns { "x": UInt256, "y": UInt256 } or nil if not set up.
```

### EVM API (v0.5.2 additions)

The JanusFlow EVM proxy exposes a symmetric registry so EVM contracts and
scanners can look up MemoKey pubkeys without a Cadence script:

```solidity
// selector 0x6370796a
function publishMemoKey(uint256 pubkeyX, uint256 pubkeyY) external;

// Read mappings (set by publishMemoKey)
function memoKeyPubX(address user) view returns (uint256);
function memoKeyPubY(address user) view returns (uint256);
```

### Setup transaction (v0.5.2)

The `setup_memo_key.cdc` transaction atomically:
1. Creates a `JanusFlow.MemoKey` resource on the Cadence side (idempotent).
2. Calls `JanusFlow.publishMemoKey(pubkeyX, pubkeyY)` on the EVM proxy via COA.

**The privkey NEVER goes on-chain.** Only `(pubkeyX, pubkeyY)` are submitted.
The privkey is derived client-side via sign-derive (HKDF over wallet signature)
and cached in `sessionStorage`.

```cadence
import JanusFlow from 0x5dcbeb41055ec57e
import EVM from 0x8c5303eaa26202d6

// Parameters: pubkeyX UInt256, pubkeyY UInt256
transaction(pubkeyX: UInt256, pubkeyY: UInt256) {
    prepare(signer: auth(...) &Account) {
        // 1. Cadence: create JanusFlow.MemoKey if missing
        if signer.storage.borrow<&JanusFlow.MemoKey>(
                from: JanusFlow.memoKeyStoragePath()) == nil {
            let key <- JanusFlow.createMemoKey(pubkeyX: pubkeyX, pubkeyY: pubkeyY)
            signer.storage.save(<-key, to: JanusFlow.memoKeyStoragePath())
            let cap = signer.capabilities.storage.issue<&{JanusFlow.MemoKeyPublic}>(
                JanusFlow.memoKeyStoragePath())
            signer.capabilities.publish(cap, at: JanusFlow.memoKeyPublicPath())
        }
        // 2. EVM: call publishMemoKey(uint256,uint256) selector 0x6370796a
        // ... (ABI encode pubkeyX, pubkeyY and call via COA)
    }
}
```

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

- [router-pattern.md](router-pattern.md) — Router pattern details, security implications
- [janus-token.md](janus-token.md) — The underlying EVM contract
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — Full v0.5.4 SDK quick start
- [../../../openjanus-sdk/references/recovery.md](../../../openjanus-sdk/references/recovery.md) — Recovery module reference
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — BSGS decrypt guide
- [confidential-tipping.md](confidential-tipping.md) — Recommended pattern for new apps
