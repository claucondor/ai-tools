# Canonical Addresses

All deployed OpenJanus contracts on Flow testnet.

> These are the official testnet deployments. Mainnet addresses will be added when available.

## Primitive contracts (Flow EVM testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `BabyJub.sol` | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` | Canonical testnet deployment |
| `BabyJub.sol` (lab) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Stateless, lab/testing use |
| `ConfidentialTransferVerifier.sol` | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` | Matches `confidentialTransfer_final.zkey` |

## Token contracts

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| `JanusToken.sol` (NATIVE demo) | Flow EVM testnet | `0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A` | NATIVE mode, demo instance |
| `JanusFlow.cdc` (v1.1.0) | Flow Cadence testnet | `0x28fef3d1d6a12800` (contract: `JanusFlow`) | Deploy TX: `9828ed5075d05579765c6aeb4ff3514beb925a70529ccaf12d2a686ff5aa4171` |

## Primitive contracts (Flow Cadence testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `PedersenBabyJub.cdc` | `0x28fef3d1d6a12800` | Same account as JanusFlow |

## Network endpoints

| Network | Flow EVM RPC | Flow REST API |
|---------|-------------|---------------|
| Testnet | `https://testnet.evm.nodes.onflow.org` | `https://rest-testnet.onflow.org` |
| Mainnet | `https://mainnet.evm.nodes.onflow.org` | `https://rest-mainnet.onflow.org` |

## Chain IDs

| Network | EVM Chain ID |
|---------|-------------|
| Testnet | 545 |
| Mainnet | 747 |

## Known test COA mappings (testnet)

| Cadence address | COA (EVM) address | Label |
|----------------|-----------------|-------|
| `0xd807a3992d7be612` | `0x00000000000000000000000250d93efba617e0bf` | Bob |
| `0x3c601a443c81e6cd` | `0x00000000000000000000000249065458581f9bf0` | Charlie |
| `0xd32d9100e1fe983b` | `0x0000000000000000000000027b94cfc8a64971cd` | Dave |
| `0x28fef3d1d6a12800` | `0x0000000000000000000000027eb18dc34b9966fd` | openjanus deployer |

## SDK constants

All addresses above are exported as named constants from `@openjanus/sdk`:

```typescript
import {
  BABYJUB_CONTRACT_ADDRESS,       // BabyJub.sol
  VERIFIER_ADDRESS,               // ConfidentialTransferVerifier
  PEDERSEN_CADENCE_ADDRESS,       // PedersenBabyJub.cdc
  JANUS_FLOW_CADENCE_ADDRESS,     // JanusFlow.cdc
} from "@openjanus/sdk/primitives";

import { JANUS_TOKEN_TESTNET } from "@openjanus/sdk/tokens";
// { evmAddress: "0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A", network: "testnet" }
```

## Verifying addresses

All contracts are deployed on the public Flow testnet and can be verified at:
- Flow EVM explorer: [evm.flowscan.io](https://evm.flowscan.io)
- Cadence explorer: [flowscan.io](https://flowscan.io)
