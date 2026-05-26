# JanusFlow — Cadence Cross-VM FLOW Wrapper (ElGamal)

> **IMPORTANT — v0.2.0 status:** The on-chain `JanusFlow` Cadence contract at
> `0x28fef3d1d6a12800` is currently **legacy v1 (Pedersen commitment architecture)**
> from an earlier sprint. Flow protocol requires FlowServiceAccount authorization to
> remove a Cadence contract, which was not available during the v0.2.0 sprint.
>
> For v0.2.0, **use JanusToken EVM directly via COA** — the 27/27 e2e test validates
> this path. The Cadence wrapper patterns below describe the intended architecture;
> the underlying EVM address has been updated to `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499`.
>
> A wrapper redeploy under a compatible name is planned for **v0.3.0**.

JanusFlow is the Cadence-native FLOW wrapper for the ElGamal stack. It executes
cross-VM Cadence → EVM transactions via COA. It encrypts to recipient pubkeys instead
of computing Pedersen commitments, enabling multi-sender privacy.

## Deployed contract

| Layer | Address | Contract | Status |
|-------|---------|---------|--------|
| Cadence | `0x28fef3d1d6a12800` | `JanusFlow` | LEGACY v1 (Pedersen) — deferred redeploy |
| EVM (underlying) | `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499` | `JanusToken` | v0.2.0 ceremony-backed |

## Architecture

JanusFlow is a Cadence contract that:

1. Accepts native FLOW from a user's `FlowToken.Vault`
2. Holds the FLOW in a Cadence vault under the contract's COA
3. Calls `JanusToken.encryptTo()` via the COA to record the encrypted amount on-chain
4. On unwrap: verifies the decrypt-open proof on-chain, releases FLOW from the vault

The cross-VM pattern is identical to JanusFlow v1 — Cadence orchestrates EVM via COA. The crypto layer is different (ElGamal instead of Pedersen).

## Cadence transaction templates

### Register pubkey (one-time setup)

```cadence
import JanusFlow from 0x28fef3d1d6a12800

transaction(pkx: UInt256, pky: UInt256) {
    prepare(signer: auth(BorrowValue) &Account) {}
    execute {
        JanusFlow.registerPubkey(pkx: pkx, pky: pky)
    }
}
```

### Wrap FLOW + encrypt to recipient

```cadence
import JanusFlow from 0x28fef3d1d6a12800
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
import JanusFlow from 0x28fef3d1d6a12800

access(all) fun main(user: Address): {String: UInt256} {
    return JanusFlow.getSlot(user: user)
    // Returns: { "c1x": ..., "c1y": ..., "c2x": ..., "c2y": ... }
}
```

### Decrypt and unwrap

```cadence
import JanusFlow from 0x28fef3d1d6a12800
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

Both operations have been tested within the 9999 CU ceiling in Phase 3 e2e (24/24 pass). If you add additional logic to these transactions (extra reads, multiple recipients), measure CU consumption carefully.

## Comparison to JanusFlow v1

| | JanusFlow (v1) | JanusFlow |
|--|----------------|-------------|
| Cadence address | `0x28fef3d1d6a12800` | `0x28fef3d1d6a12800` |
| Contract name | `JanusFlow` | `JanusFlow` |
| EVM contract | `JanusToken` | `JanusToken` |
| Wrap args | `(amount, commitX, commitY)` | `(amount, recipient, c1, c2, proof, pubInputs)` |
| Recipient pubkey setup | Not needed | `registerPubkey` once |
| Multi-sender | Privacy fails | Privacy holds |
| Unwrap | `(amount, commitX, commitY, recipient)` | `(amount, to, proof, pubInputs)` |

## SDK integration

The `@openjanus/sdk/tokens` module provides high-level TypeScript wrappers for all JanusFlow operations. See [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md).

```typescript
import { JanusFlow } from "@openjanus/sdk/tokens";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.configure();

// One-time setup
await sdk.registerPubkey(alicePK, aliceAuthz);

// Wrap + encrypt
const { txId } = await sdk.wrapAndEncrypt("10.0", ALICE_CADENCE_ADDR, proofResult, senderAuthz);

// Decrypt + unwrap
await sdk.decryptAndUnwrap("42.0", ALICE_CADENCE_ADDR, decryptResult, aliceAuthz);
```

## See also

- [janus-token.md](janus-token.md) — The underlying EVM contract
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — Full v2 SDK quick start
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — BSGS decrypt guide
- [confidential-tipping.md](confidential-tipping.md) — Recommended pattern for new apps
