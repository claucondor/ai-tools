# JanusFT — SECONDARY Cadence-first FungibleToken privacy primitive (v0.4 / v0.8 deployer)

> **SECONDARY token — pick this if your app uses Cadence FungibleTokens
> other than FLOW.** JanusFT is the Cadence-native wrapper for any
> `FungibleToken` vault. Same shielded-transfer privacy shape as JanusFlow
> (the PRIMARY token for FLOW), but routed through a pure-Cadence registry
> instead of cross-VM. v0.4 ships as a lab-grade port with STUB crypto.
>
> If your app pays in FLOW, use `JanusFlow` instead (production-grade).

`JanusFT` is a pure-Cadence wrapper for any `FungibleToken` vault on Flow.
It is the Cadence-side counterpart to `JanusERC20`. Same shielded-transfer
privacy SHAPE; ships as a lab-grade port with STUB crypto.

## Deployment (testnet, v0.8 deployer address)

| Layer | Address | Notes |
|-------|---------|-------|
| `JanusFT` canonical | `0x4b6bc58bc8bf5dcc` | Apps consume this address; feeBps=10 |
| `MockFT` underlying | `0x4b6bc58bc8bf5dcc` | Same account hosts underlying + wrapper |
| ShieldedCheckpoint (Cadence) | `0xd1a02aa46d9151bb` | Per-token checkpoint for JanusFT |

SDK token ID: `sdk.token('mockft')`


## v0.4 lab-grade limitations

**Stub crypto.** `babyAddStub(a, b)` and `babyNegateStub(c)` are NOT real
BabyJubJub point operations. They combine the two UInt256 coordinates via
a deterministic mixing function so the output is opaque to byte-level
inspection — enough to validate STRUCTURAL privacy properties (calldata,
events, storage). They are NOT homomorphic and accumulated stub state
OVERFLOWS UInt256 after a few operations.

**Opaque proofs.** `amountProofBytes` / `proofBytes` are accepted with
`length > 0` check only — no Groth16 verification on the Cadence side.

**Single-account registry.** `CommitmentRegistry` resource must live on the
signer's account (the lab spike model). Multiple distinct accounts CAN hold
commitments via `shieldedTransfer` — recipients don't need a registry resource
on their side.

**Unwrap broken on stub crypto.** The unwrap path requires
`babyAddStub(totalSupplyCommitment, babyNegateStub(txCommit))` which
deterministically overflows. The smoke test intentionally skips unwrap
(matches the lab spike's `multi-user-stress-ft.json#steps.unwrap`).

Real soundness + real unwrap require cross-VM COA calls to the EVM
`BabyJub.sol` + `ConfidentialTransferVerifier` (planned enhancement).

## Cadence surface

```cadence
access(all) contract JanusFT {
    access(all) struct Commitment {
        access(all) let x: UInt256
        access(all) let y: UInt256
    }

    access(all) var totalLocked: UFix64
    access(all) var totalSupplyCommitment: Commitment
    access(all) var underlyingVaultTypeIdentifier: String

    access(all) resource interface CommitmentRegistryPublic {
        access(all) fun balanceOfCommitment(account: Address): Commitment
        access(all) view fun getTotalLocked(): UFix64
    }

    access(all) resource CommitmentRegistry: CommitmentRegistryPublic {
        access(all) fun wrap(account: Address, amount: UFix64, depositVault: @{FungibleToken.Vault},
                              txCommit: Commitment, amountProofBytes: [UInt8])
        access(all) fun shieldedTransfer(fromAccount: Address, toAccount: Address,
                                          publicInputs: [UInt256; 6], proofBytes: [UInt8])
        access(all) fun unwrap(account: Address, claimedAmount: UFix64, recipient: Address,
                                txCommit: Commitment, amountProofBytes: [UInt8],
                                transferPublicInputs: [UInt256; 6], transferProofBytes: [UInt8]
                              ): @{FungibleToken.Vault}
    }

    access(all) resource Admin {
        access(all) fun setUnderlyingVaultType(typeIdentifier: String)
        access(all) fun resetCommitmentsForTestingOnly()  // testing only
    }

    access(all) event Wrapped(account: Address, amount: UFix64)
    access(all) event Unwrapped(account: Address, recipient: Address, amount: UFix64)
    access(all) event ShieldedTransferred(
        fromCommitX: UInt256, fromCommitY: UInt256,
        toCommitX:   UInt256, toCommitY:   UInt256,
    )

    access(all) fun createRegistry(vault: @{FungibleToken.Vault}): @CommitmentRegistry
    access(all) fun createAdmin(): @Admin
}
```

## SDK usage (v0.8)

The preferred path is `sdk.token('mockft')` which wraps the FCL transactions automatically:

```typescript
import { OpenJanusSDK } from "@claucondor/sdk";

const sdk = new OpenJanusSDK({ network: "testnet" });
const ft = sdk.token('mockft');
await ft.configure(); // sets up FCL

// Wrap (FCL transaction — requires wallet auth)
await ft.wrap({ grossAmount: 2_00000000n /* 2.0 UFix64 raw */ });

// Shielded transfer — no cleartext amount in tx args
await ft.shieldedTransfer({
  recipient: "0xd807a3992d7be612",
  amount, currentBalance, currentBlinding,
});

// Unwrap
await ft.unwrap({ claimedAmount, recipient, currentBalance, currentBlinding });
```

## Low-level FCL templates (via @claucondor/sdk string templates)

```typescript
import {
  TX_FT_SETUP_REGISTRY,
  TX_FT_WRAP,
  TX_FT_SHIELDED_TRANSFER,
  TX_FT_UNWRAP,
  SCRIPT_FT_GET_TOTAL_LOCKED,
  SCRIPT_FT_GET_COMMITMENT,
  buildJanusFTTx,            // re-target to a custom address
} from "@claucondor/sdk";

import * as fcl from "@onflow/fcl";

// 1. Setup registry (one-time per signer)
const txId = await fcl.mutate({ cadence: TX_FT_SETUP_REGISTRY });

// 2. Wrap 2.0 FT (canonical address 0x4b6bc58bc8bf5dcc)
const wrapTx = await fcl.mutate({
  cadence: TX_FT_WRAP,
  args: (arg, t) => [
    arg("0x4b6bc58bc8bf5dcc", t.Address),                // registryAddr
    arg("2.00000000",         t.UFix64),                 // amount (boundary leak)
    arg(commit.x.toString(),  t.UInt256),                // Pedersen.x
    arg(commit.y.toString(),  t.UInt256),                // Pedersen.y
    arg(opaqueProofBytes,     t.Array(t.UInt8)),         // proof bytes
  ],
});

// 3. Shielded transfer — NO cleartext amount in tx args!
const xferTx = await fcl.mutate({
  cadence: TX_FT_SHIELDED_TRANSFER,
  args: (arg, t) => [
    arg("0xd807a3992d7be612", t.Address),
    arg(publicInputs.map(v => arg(v.toString(), t.UInt256)), t.Array(t.UInt256)),
    arg(opaqueProofBytes, t.Array(t.UInt8)),
  ],
});
```

## Empirical privacy validation (smoke 2026-05-27, deployer 0x7599043aea001283 → migrated to 0x4b6bc58bc8bf5dcc)

From `packages/janus-ft/deployments/smoke-janus-ft-v0.4.json`:

| Channel | wrap | shieldedTransfer | unwrap |
|---------|------|------------------|--------|
| Cadence args | `amount: UFix64` LEAK | NO amount arg (HIDE) | `claimedAmount: UFix64` LEAK |
| Contract events | `Wrapped(account, amount)` LEAK | `ShieldedTransferred(4×UInt256)` no amount (HIDE) | `Unwrapped(account, recipient, amount)` LEAK |
| FungibleToken events | `FlowToken.TokensWithdrawn/Deposited` LEAK | ONLY fee-related events; shielded amount NEVER in any FT event (HIDE) | `FlowToken.TokensWithdrawn/Deposited` LEAK |
| `totalLocked` | += amount (LEAK aggregate) | UNCHANGED (HIDE) | -= amount (LEAK aggregate) |

Wrap + shielded transfer empirically PASS. Unwrap intentionally skipped
(stub crypto overflow).

