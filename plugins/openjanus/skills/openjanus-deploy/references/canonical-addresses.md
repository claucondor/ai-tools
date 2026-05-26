# Canonical Addresses

All deployed OpenJanus contracts on Flow testnet.

> These are the official testnet deployments. Mainnet addresses will be added when available.

## Primitive contracts (Flow EVM testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `BabyJub.sol` | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` | Canonical testnet deployment |
| `BabyJub.sol` (lab) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Stateless, lab/testing use |
| `ConfidentialTransferVerifier.sol` | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` | Matches `confidentialTransfer_final.zkey` |

## JanusToken + JanusFlow contracts (current — v0.2.0-router)

Router pattern: `JanusFlow` at `0xbef3c77681c15397` is stable forever. Impl upgrades
happen via 48h time-locked capability swap. Apps always import from this address.
See [router-pattern.md](router-pattern.md) for details.

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| `JanusFlow.cdc` (router) | Flow Cadence testnet | `0xbef3c77681c15397` | Canonical — stable forever |
| `JanusFlowImpl.cdc` | Flow Cadence testnet | `0xbef3c77681c15397` | Current impl — swappable |
| `IJanusFlowImpl.cdc` | Flow Cadence testnet | `0xbef3c77681c15397` | Impl interface |
| `JanusToken.sol` | Flow EVM testnet | `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499` | ElGamal accumulator |
| `EncryptConsistencyVerifier.sol` | Flow EVM testnet | `0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e` | Groth16, ceremony-backed |
| `DecryptOpenVerifier.sol` | Flow EVM testnet | `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` | Groth16, ceremony-backed |
| `BabyJub.sol` (lab) | Flow EVM testnet | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Used by JanusToken |

## DEPRECATED — DO NOT USE

| Contract | Layer | Address | Why |
|----------|-------|---------|-----|
| `JanusFlow.cdc` (zombie v1) | Flow Cadence testnet | `0x28fef3d1d6a12800` | Legacy Pedersen, zombie — cannot be removed. All apps must use `0xbef3c77681c15397` |

## Primitive contracts (Flow Cadence testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `PedersenBabyJub.cdc` | `0x28fef3d1d6a12800` | Legacy primitives account |

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
| `0x28fef3d1d6a12800` | `0x0000000000000000000000027eb18dc34b9966fd` | openjanus legacy deployer |
| `0xbef3c77681c15397` | `0x0000000000000000000000022f6b30af48a94787` | openjanus router account (canonical) |

## SDK constants

```typescript
import {
  JANUS_TOKEN_TESTNET,                // { evmAddress: "0xb12E600f...", network: "testnet" }
  JANUS_FLOW_CADENCE_ADDRESS,         // "0xbef3c77681c15397" (router — canonical)
  JANUS_FLOW_CADENCE_ADDRESS_LEGACY,  // "0x28fef3d1d6a12800" (zombie — DO NOT USE)
  JANUS_FLOW_VERSION,                 // "0.2.0-router"
  JANUS_TOKEN_EVM,                    // "0xb12E600fFcde967210cFD81CF9f32bBB6e68a499"
  ENCRYPT_VERIFIER_EVM,               // "0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e"
  DECRYPT_VERIFIER_EVM,               // "0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc"
  JANUS_BABYJUB_ADDRESS,              // "0x27139AFda7425f51F68D32e0A38b7D43BcB0f870"
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
