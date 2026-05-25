# Canonical Addresses

All deployed OpenJanus contracts on Flow testnet.

> These are the official testnet deployments. Mainnet addresses will be added when available.

## Primitive contracts (Flow EVM testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `BabyJub.sol` | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` | Canonical testnet deployment |
| `BabyJub.sol` (lab) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Stateless, lab/testing use |
| `ConfidentialTransferVerifier.sol` | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` | Matches `confidentialTransfer_final.zkey` |

## JanusToken contracts (current)

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| `JanusToken.sol` | Flow EVM testnet | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` | ElGamal accumulator |
| `JanusFlow.cdc` | Flow Cadence testnet | `0x28fef3d1d6a12800` (contract: `JanusFlow`) | Deploy TX: `6f5f551f6e7af4def5cd9d7d5098b4c13daff9eaaaf0598c10feddbac0b0e7b5` |
| `EncryptConsistencyVerifier.sol` | Flow EVM testnet | `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C` | Groth16, encrypt_consistency circuit |
| `DecryptOpenVerifier.sol` | Flow EVM testnet | `0x3bB139B5404fD6b152813bC3532367AAa096638b` | Groth16, decrypt_open circuit |
| `BabyJub.sol` (lab) | Flow EVM testnet | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Used by JanusToken |

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

```typescript
import {
  JANUS_TOKEN_TESTNET,           // { evmAddress: "0xC715b...", network: "testnet" }
  JANUS_FLOW_CADENCE_ADDRESS,    // "0x28fef3d1d6a12800"
  ENCRYPT_CONSISTENCY_VERIFIER,  // "0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C"
  DECRYPT_OPEN_VERIFIER,         // "0x3bB139B5404fD6b152813bC3532367AAa096638b"
  JANUS_BABYJUB_ADDRESS,         // "0x27139AFda7425f51F68D32e0A38b7D43BcB0f870"
} from "@openjanus/sdk/tokens";

import {
  BABYJUB_CONTRACT_ADDRESS,      // BabyJub.sol canonical
  VERIFIER_ADDRESS,              // ConfidentialTransferVerifier
  PEDERSEN_CADENCE_ADDRESS,      // PedersenBabyJub.cdc
} from "@openjanus/sdk/primitives";
```

## Verifying addresses

All contracts are deployed on the public Flow testnet and can be verified at:
- Flow EVM explorer: [evm.flowscan.io](https://evm.flowscan.io)
- Cadence explorer: [flowscan.io](https://flowscan.io)
