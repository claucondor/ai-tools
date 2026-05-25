# JanusFlow — Cadence-Native FLOW Wrapper

JanusFlow is a Cadence contract (v1.1.0) that wraps native FLOW tokens into Pedersen commitments stored on Flow EVM. It orchestrates all operations via Cross-VM calls from Cadence into EVM.

## Deployed contract

| Field | Value |
|-------|-------|
| Cadence address | `0x28fef3d1d6a12800` |
| Contract name | `JanusFlow` |
| Version | `1.1.0` |
| Deploy TX | `9828ed5075d05579765c6aeb4ff3514beb925a70529ccaf12d2a686ff5aa4171` |

## Architecture

```
User Cadence account
  ├── FlowToken.Vault  ← locked by wrap()
  └── COA              ← EVM address controlled by this account
         └── JanusToken EVM slot (commitment stored here)

JanusFlow (Cadence)
  ├── wrap()           → locks FLOW, mints EVM commitment via COA
  ├── confidentialTransfer() → verifies ZK proof via EVM.dryCall, updates commitments
  └── unwrap()         → verifies commitment, releases FLOW from vault
```

## v1.1.0 key changes from v1.0

- **Per-user COA slot**: commitments are keyed by each user's COA address, not a single shared address
- **Homomorphic `mintXY`**: delta arithmetic — adds to existing commitment rather than replacing it
- **`babyNeg()` via `EVM.dryCall`**: point negation is computed via a dry EVM call to BabyJub.sol
- **ZK proof via `EVM.dryCall`**: verifyProof is called as a dry call to avoid `msg.sender` issues

## Public interface (Cadence)

### wrap

```cadence
access(all) fun wrap(
    vault: @FlowToken.Vault,
    commitX: UInt256,
    commitY: UInt256
)
```

Locks FLOW from the vault. Records the commitment in the sender's JanusToken EVM slot (keyed by their COA address).

### confidentialTransfer

```cadence
access(all) fun confidentialTransfer(
    recipient: Address,
    oldCommit:  {String: UInt256},
    txCommit:   {String: UInt256},
    newCommit:  {String: UInt256},
    proof: [UInt256]
)
```

Verifies the Groth16 proof on-chain via `EVM.dryCall` to `ConfidentialTransferVerifier`, then updates sender and recipient EVM slots.

### unwrap

```cadence
access(all) fun unwrap(
    amount: UFix64,
    commitX: UInt256,
    commitY: UInt256
): @FlowToken.Vault
```

Verifies the commitment matches the stored slot, then releases the vault.

### getCommitment

```cadence
access(all) fun getCommitment(user: Address): {String: UInt256}
```

Returns `{"x": UInt256, "y": UInt256}` — the commitment stored in the user's EVM slot.

## Cadence transaction strings

The SDK exports the exact Cadence transaction strings:

```typescript
import {
  TX_WRAP,
  TX_CONFIDENTIAL_TRANSFER,
  TX_UNWRAP,
  SCRIPT_GET_COMMITMENT,
  JANUS_FLOW_CADENCE_ADDRESS,
} from "@openjanus/sdk/tokens";
```

These can be used with the Flow CLI for scripted deploys and testing.

## EVM dependencies

JanusFlow calls these EVM contracts at runtime:

| Contract | Address |
|----------|---------|
| `JanusToken.sol` (NATIVE demo) | `0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A` |
| `BabyJub.sol` | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` |
| `ConfidentialTransferVerifier.sol` | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` |

## flow.json registration

To use JanusFlow in a Flow project, add the import alias to `flow.json`:

```json
{
  "contracts": {
    "JanusFlow": {
      "source": "./cadence/contracts/JanusFlow.cdc",
      "aliases": {
        "testnet": "0x28fef3d1d6a12800"
      }
    }
  }
}
```

Or import directly in Cadence using the deployed address:

```cadence
import JanusFlow from 0x28fef3d1d6a12800
```

## Common Pitfalls

**COA required**: users must have a COA on their Cadence account before calling `wrap()`. If no COA exists, the EVM write fails. See [../gotchas/flow-account-vs-coa.md](../gotchas/flow-account-vs-coa.md).

**Compute unit ceiling**: the Cross-VM proof verification is the most expensive operation. The 9999 CU ceiling on testnet is tight. See [../gotchas/compute-units-limit.md](../gotchas/compute-units-limit.md).

**Amount mismatch at unwrap**: the `amount` parameter to `unwrap()` must exactly match the plaintext value committed to in the commitment slot. JanusFlow verifies this by computing the commitment locally and comparing.
