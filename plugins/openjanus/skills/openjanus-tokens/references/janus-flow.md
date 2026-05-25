# JanusFlowV2 — Cadence Cross-VM FLOW Wrapper (ElGamal)

JanusFlowV2 is the Cadence-native FLOW wrapper for the v2 ElGamal stack. Like JanusFlow v1, it executes cross-VM Cadence → EVM transactions via COA. Unlike v1, it encrypts to recipient pubkeys instead of computing Pedersen commitments, enabling multi-sender privacy.

## Deployed contract

| Layer | Address | Contract |
|-------|---------|---------|
| Cadence | `0x28fef3d1d6a12800` | `JanusFlowV2` |
| EVM (underlying) | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` | `JanusTokenV2` |

## Architecture

JanusFlowV2 is a Cadence contract that:

1. Accepts native FLOW from a user's `FlowToken.Vault`
2. Holds the FLOW in a Cadence vault under the contract's COA
3. Calls `JanusTokenV2.encryptTo()` via the COA to record the encrypted amount on-chain
4. On unwrap: verifies the decrypt-open proof on-chain, releases FLOW from the vault

The cross-VM pattern is identical to JanusFlow v1 — Cadence orchestrates EVM via COA. The crypto layer is different (ElGamal instead of Pedersen).

## Cadence transaction templates

### Register pubkey (one-time setup)

```cadence
import JanusFlowV2 from 0x28fef3d1d6a12800

transaction(pkx: UInt256, pky: UInt256) {
    prepare(signer: auth(BorrowValue) &Account) {}
    execute {
        JanusFlowV2.registerPubkey(pkx: pkx, pky: pky)
    }
}
```

### Wrap FLOW + encrypt to recipient

```cadence
import JanusFlowV2 from 0x28fef3d1d6a12800
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
        JanusFlowV2.wrapAndEncrypt(
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
import JanusFlowV2 from 0x28fef3d1d6a12800

access(all) fun main(user: Address): {String: UInt256} {
    return JanusFlowV2.getSlot(user: user)
    // Returns: { "c1x": ..., "c1y": ..., "c2x": ..., "c2y": ... }
}
```

### Decrypt and unwrap

```cadence
import JanusFlowV2 from 0x28fef3d1d6a12800
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
        let vault <- JanusFlowV2.decryptAndUnwrap(
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

JanusFlowV2 Cadence transactions call `JanusTokenV2` on Flow EVM via COA. The 9999 CU limit applies to the entire Cadence transaction including cross-VM calls.

Operations near the limit:
- `wrapAndEncrypt`: COA call to `encryptTo` includes on-chain Groth16 verify (~300k EVM gas). This is the most expensive operation.
- `decryptAndUnwrap`: COA call to `decryptAndUnwrap` includes on-chain Groth16 verify.

Both operations have been tested within the 9999 CU ceiling in Phase 3 e2e (24/24 pass). If you add additional logic to these transactions (extra reads, multiple recipients), measure CU consumption carefully.

## Comparison to JanusFlow v1

| | JanusFlow (v1) | JanusFlowV2 |
|--|----------------|-------------|
| Cadence address | `0x28fef3d1d6a12800` | `0x28fef3d1d6a12800` |
| Contract name | `JanusFlow` | `JanusFlowV2` |
| EVM contract | `JanusToken` | `JanusTokenV2` |
| Wrap args | `(amount, commitX, commitY)` | `(amount, recipient, c1, c2, proof, pubInputs)` |
| Recipient pubkey setup | Not needed | `registerPubkey` once |
| Multi-sender | Privacy fails | Privacy holds |
| Unwrap | `(amount, commitX, commitY, recipient)` | `(amount, to, proof, pubInputs)` |

## SDK integration

The `@openjanus/sdk/tokens-v2` module provides high-level TypeScript wrappers for all JanusFlowV2 operations. See [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md).

```typescript
import { JanusFlowV2 } from "@openjanus/sdk/tokens-v2";

const sdk = new JanusFlowV2({ network: "testnet" });
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
