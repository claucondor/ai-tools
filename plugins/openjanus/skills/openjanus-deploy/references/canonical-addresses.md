# Canonical Addresses — v0.2.0

All deployed OpenJanus contracts on Flow testnet. Updated for v0.2.0
(ceremony-backed trusted setup, 2026-05-26).

> These are the official testnet deployments. Mainnet addresses will be added when available.

## JanusToken v0.2.0 contracts (current — ceremony-backed)

Trusted setup: Hermez pot14 (200+ contributors) + Flow VRF beacon
(testnet block 323555648, hash `30f1f68eed7ea6e7b4964e798ff8a0e2b77e7ca073ed80ac44d39ddc5fb395e7`).

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| `JanusToken.sol` | Flow EVM testnet | `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499` | ElGamal accumulator, v0.2.0 |
| `EncryptConsistencyVerifier.sol` | Flow EVM testnet | `0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e` | Groth16, encrypt_consistency circuit |
| `DecryptOpenVerifier.sol` | Flow EVM testnet | `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` | Groth16, decrypt_open circuit |
| `BabyJub.sol` (lab, reused) | Flow EVM testnet | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Stateless point ops — unchanged |
| `JanusFlow.cdc` | Flow Cadence testnet | `0x28fef3d1d6a12800` (contract: `JanusFlow`) | LEGACY v1 — see note below |

**JanusFlow Cadence note:** The on-chain `JanusFlow` contract at `0x28fef3d1d6a12800` is
legacy v1 (Pedersen architecture). For v0.2.0, use `JanusToken` EVM directly via COA.
Wrapper redeploy planned for v0.3.0.

## Primitive contracts (Flow EVM testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `BabyJub.sol` | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` | Canonical testnet deployment |
| `BabyJub.sol` (lab) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Stateless, lab/testing use |
| `ConfidentialTransferVerifier.sol` | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` | Matches `confidentialTransfer_final.zkey` |

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
  JANUS_TOKEN_TESTNET,           // { evmAddress: "0xb12E600fFcde967210cFD81CF9f32bBB6e68a499", network: "testnet" }
  JANUS_FLOW_CADENCE_ADDRESS,    // "0x28fef3d1d6a12800"
  ENCRYPT_CONSISTENCY_VERIFIER,  // "0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e"
  DECRYPT_OPEN_VERIFIER,         // "0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc"
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

---

## DEPRECATED — v0.1.0 addresses (2026-05-25, single-contributor lab setup)

These addresses used a lab pot14 setup with a single contributor.
They are superseded by v0.2.0 and should NOT be used in new integrations.

| Contract | DEPRECATED Address |
|----------|--------------------|
| `JanusToken.sol` | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` |
| `EncryptConsistencyVerifier.sol` | `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C` |
| `DecryptOpenVerifier.sol` | `0x3bB139B5404fD6b152813bC3532367AAa096638b` |
