# Canonical Addresses

All deployed OpenJanus contracts on Flow testnet.

> These are the official testnet deployments. Mainnet addresses will be added when available.

## Primitive contracts (Flow EVM testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `BabyJub.sol` | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` | Canonical testnet deployment |
| `BabyJub.sol` (lab) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Stateless, lab/testing use |
| `ConfidentialTransferVerifier.sol` | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` | Matches `confidentialTransfer_final.zkey` |

## v2 token contracts (current — RECOMMENDED)

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| `JanusTokenV2.sol` | Flow EVM testnet | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` | ElGamal accumulator (v2) |
| `JanusFlowV2.cdc` | Flow Cadence testnet | `0x28fef3d1d6a12800` (contract: `JanusFlowV2`) | Deploy TX: `6f5f551f6e7af4def5cd9d7d5098b4c13daff9eaaaf0598c10feddbac0b0e7b5` |
| `EncryptConsistencyVerifier.sol` | Flow EVM testnet | `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C` | v2 ZK verifier |
| `DecryptOpenVerifier.sol` | Flow EVM testnet | `0x3bB139B5404fD6b152813bC3532367AAa096638b` | v2 ZK verifier |
| `BabyJub.sol` (v2/lab) | Flow EVM testnet | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Used by v2 stack |

## v1 token contracts (Historical — DEPRECATED)

> **These contracts are deprecated as of v0.2.0.** Do not use for new development.
> See [why-v1-was-deprecated](https://github.com/openjanus/sdk/blob/main/docs/why-v1-was-deprecated.md).

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| `JanusToken.sol` (NATIVE demo) | Flow EVM testnet | `0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A` | **DEPRECATED** — Pedersen-hash, privacy limitation |
| `JanusFlow.cdc` (v1.1.0) | Flow Cadence testnet | `0x28fef3d1d6a12800` (contract: `JanusFlow`) | **DEPRECATED** — Pedersen-hash, privacy limitation |

## Primitive contracts (Flow Cadence testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `PedersenBabyJub.cdc` | `0x28fef3d1d6a12800` | Same account as JanusFlowV2 |

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

### v2 addresses (current)

```typescript
import {
  JANUS_TOKEN_V2_TESTNET,           // { evmAddress: "0xC715b...", network: "testnet" }
  JANUS_FLOW_V2_CADENCE_ADDRESS,    // "0x28fef3d1d6a12800"
  ENCRYPT_CONSISTENCY_VERIFIER,     // "0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C"
  DECRYPT_OPEN_VERIFIER,            // "0x3bB139B5404fD6b152813bC3532367AAa096638b"
  JANUS_V2_BABYJUB_ADDRESS,         // "0x27139AFda7425f51F68D32e0A38b7D43BcB0f870"
} from "@openjanus/sdk/tokens-v2";

import {
  BABYJUB_CONTRACT_ADDRESS,         // BabyJub.sol canonical
  VERIFIER_ADDRESS,                 // ConfidentialTransferVerifier
  PEDERSEN_CADENCE_ADDRESS,         // PedersenBabyJub.cdc
} from "@openjanus/sdk/primitives";
```

> v1 constants (`JANUS_TOKEN_TESTNET`, `JANUS_FLOW_CADENCE_ADDRESS`, `@openjanus/sdk/tokens`)
> were removed in `@openjanus/sdk@0.2.0`. Access via `git checkout v0.1.0-final` if needed.

## Verifying addresses

All contracts are deployed on the public Flow testnet and can be verified at:
- Flow EVM explorer: [evm.flowscan.io](https://evm.flowscan.io)
- Cadence explorer: [flowscan.io](https://flowscan.io)
