# JanusFlow — Cadence Cross-VM FLOW Wrapper (ElGamal, router/impl pattern)

JanusFlow is the Cadence-native FLOW wrapper for the ElGamal stack. It executes
cross-VM Cadence → EVM transactions via COA. As of v0.2.0-router, it uses a
router/impl pattern: the canonical address is stable forever, while the implementation
logic is swappable via a 48h time-locked capability swap.

**IMPORTANT:** The old address `0x28fef3d1d6a12800.JanusFlow` is a zombie (legacy v1
Pedersen). Do not import from it. Use `0x5dcbeb41055ec57e.JanusFlow` everywhere.

## Deployed contract (canonical — router pattern)

| Layer | Address | Contract | Notes |
|-------|---------|---------|-------|
| Cadence (router) | `0x5dcbeb41055ec57e` | `JanusFlow` | Canonical forever |
| Cadence (impl) | `0x5dcbeb41055ec57e` | `JanusFlowImpl` | Current impl — swappable |
| Cadence (interface) | `0x5dcbeb41055ec57e` | `IJanusFlowImpl` | All impls must conform |
| EVM (underlying) | `0x025efe7e89acdb8F315C804BE7245F348AA9c538` | `JanusToken` | Unchanged |

Router e2e: 25/25 PASS (2026-05-26). Deployment record: `circuits/setup/deployments-router.json`.

## Architecture — Router/Impl pattern

JanusFlow uses a router/facade + swappable-impl design:

**Router (`JanusFlow`)**: holds all state — FLOW vault, commitments map, pubkeys map.
Exposes the full public API. Never migrated. Users always import from this address.

**Impl (`JanusFlowImpl`)**: pure logic — validates proofs, computes slot updates, returns
results. No state. Disposable. Current impl: v0.1.0 (ElGamal-on-BabyJubjub).

**Interface (`IJanusFlowImpl`)**: the contract interface all future impls must conform to.
Decouples router from impl details.

The FLOW vault + all user state stays in the router forever. On impl swap, no funds move.

## User-facing operations

JanusFlow is a Cadence contract that:

1. Accepts native FLOW from a user's `FlowToken.Vault`
2. Holds the FLOW in a Cadence vault inside the router contract
3. Calls `JanusToken.encryptTo()` via the COA to record the encrypted amount on-chain
4. On unwrap: verifies the decrypt-open proof on-chain, releases FLOW from the vault

The cross-VM pattern is the same as before — Cadence orchestrates EVM via COA.

## Admin operations (router v0.2.0-router)

Only the holder of `AdminResource` at `/storage/janusFlowAdmin` on the router account can:

| Operation | Description |
|-----------|-------------|
| `pause()` | Emergency stop — all writes revert; reads still work |
| `unpause()` | Resume normal operation |
| `proposeImplSwap(newImplCap)` | Start 48h time-lock for impl upgrade |
| `finalizeImplSwap()` | Complete upgrade after time-lock expires |
| `cancelImplSwap()` | Abort a pending upgrade proposal |

Public views (anyone can call):
- `isPaused()` — true if paused
- `getActiveImplVersion()` — version string of current impl (e.g. "0.1.0")

## Upgrade flow (48h time-lock)

1. Admin calls `proposeImplSwap(newImplCapability)`. Time-lock starts.
2. 48h window: app developers review the new impl, test, or raise concerns.
3. Admin calls `finalizeImplSwap()`. Capability is swapped. Apps are transparent.
4. If admin cancels before finalize: `cancelImplSwap()` resets pending state.

Apps that import `JanusFlow from 0x5dcbeb41055ec57e` never need code changes
across impl upgrades — only the internal logic changes.

## DEPRECATED — DO NOT USE

`0x28fef3d1d6a12800.JanusFlow` — legacy v1 Pedersen contract. Flow's protocol restriction
prevents removal without service account authorization. It is a zombie. All apps must
import from `0x5dcbeb41055ec57e` instead.

## Cadence transaction templates

### Register pubkey (one-time setup)

```cadence
import JanusFlow from 0x5dcbeb41055ec57e

transaction(pkx: UInt256, pky: UInt256) {
    prepare(signer: auth(BorrowValue) &Account) {}
    execute {
        JanusFlow.registerPubkey(pkx: pkx, pky: pky)
    }
}
```

### Wrap FLOW + encrypt to recipient

```cadence
import JanusFlow from 0x5dcbeb41055ec57e
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

transaction(
    amount: UFix64,
    recipient: Address,
    c1x: UInt256, c1y: UInt256,
    c2x: UInt256, c2y: UInt256,
    proof: [UInt256],
    pubInputs: [UInt256]
) {
    let vault: @FlowToken.Vault

    prepare(signer: auth(BorrowValue) &Account) {
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("No FlowToken.Vault in signer storage")
        self.vault <- flowVault.withdraw(amount: amount) as! @FlowToken.Vault
    }

    execute {
        JanusFlow.wrapAndEncrypt(
            vault: <-self.vault,
            recipient: recipient,
            c1x: c1x, c1y: c1y,
            c2x: c2x, c2y: c2y,
            proof: proof,
            pubInputs: pubInputs
        )
    }
}
```

### Read slot (Cadence script)

```cadence
import JanusFlow from 0x5dcbeb41055ec57e

access(all) fun main(user: Address): {String: UInt256} {
    return JanusFlow.getSlot(user: user)
    // Returns: { "c1x": ..., "c1y": ..., "c2x": ..., "c2y": ... }
}
```

### Decrypt and unwrap

```cadence
import JanusFlow from 0x5dcbeb41055ec57e
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

transaction(
    amount: UFix64,
    to: Address,
    proof: [UInt256],
    pubInputs: [UInt256]
) {
    prepare(signer: auth(BorrowValue) &Account) {}
    execute {
        let vault <- JanusFlow.decryptAndUnwrap(
            amount: amount,
            proof: proof,
            pubInputs: pubInputs
        )
        let recipientRef = getAccount(to)
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("No FlowToken.Receiver on recipient")
        recipientRef.deposit(from: <-vault)
    }
}
```

## CU budget notes

JanusFlow Cadence transactions call `JanusToken` on Flow EVM via COA. The 9999 CU limit applies to the entire Cadence transaction including cross-VM calls.

Operations near the limit:
- `wrapAndEncrypt`: COA call to `encryptTo` includes on-chain Groth16 verify (~300k EVM gas). This is the most expensive operation.
- `decryptAndUnwrap`: COA call to `decryptAndUnwrap` includes on-chain Groth16 verify.

Both operations have been tested within the 9999 CU ceiling in Phase 3 e2e (24/24 pass)
and router e2e (25/25 pass). If you add additional logic to these transactions (extra reads,
multiple recipients), measure CU consumption carefully.

## SDK integration

The `@openjanus/sdk/tokens` module provides high-level TypeScript wrappers for all JanusFlow
operations including admin methods. See [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md).

```typescript
import { JanusFlow, JANUS_FLOW_CADENCE_ADDRESS } from "@openjanus/sdk/tokens";
// JANUS_FLOW_CADENCE_ADDRESS === "0x5dcbeb41055ec57e"

const sdk = new JanusFlow({ network: "testnet" });
await sdk.configure();

// Check pause state before operations
const paused = await sdk.isPaused();

// One-time setup
await sdk.registerPubkey(alicePK, aliceAuthz);

// Wrap + encrypt
const { txId } = await sdk.wrapAndEncrypt("10.0", ALICE_CADENCE_ADDR, proofResult, senderAuthz);

// Decrypt + unwrap
await sdk.decryptAndUnwrap("42.0", ALICE_CADENCE_ADDR, decryptResult, aliceAuthz);

// Admin: pause/unpause (admin account only)
await sdk.pause(adminAuthz);
await sdk.unpause(adminAuthz);

// Admin: finalize impl swap after 48h time-lock
await sdk.finalizeImplSwap(adminAuthz);

// Check current impl version
const version = await sdk.getActiveImplVersion(); // "0.1.0"
```

## See also

- [router-pattern.md](router-pattern.md) — Router pattern details, security implications
- [janus-token.md](janus-token.md) — The underlying EVM contract
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — Full v2 SDK quick start
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — BSGS decrypt guide
- [confidential-tipping.md](confidential-tipping.md) — Recommended pattern for new apps
