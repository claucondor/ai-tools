# Canonical Addresses

All deployed OpenJanus contracts on Flow testnet.

> These are the official testnet deployments. Mainnet addresses will be added when available.

## Primitive contracts (Flow EVM testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `BabyJub.sol` | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` | Canonical testnet deployment |
| `BabyJub.sol` (lab) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Stateless, lab/testing use |
| `ConfidentialTransferVerifier.sol` | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` | Matches `confidentialTransfer_final.zkey` |

## JanusToken + JanusFlow contracts (CURRENT)

Architecture:
- **EVM side**: `JanusToken` is a UUPS-upgradeable proxy. Owner can ship fixes as
  impl-only redeploys; the proxy address never changes.
- **Cadence side**: `JanusFlow` is a router/impl pair on the
  `openjanus-janusflow-router` account. Impl swap is gated by a 48h time-lock.

Apps always reach for these addresses. See [router-pattern.md](../../openjanus-tokens/references/router-pattern.md) for the upgrade model.

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| `JanusToken` (proxy) | Flow EVM testnet | `0x025efe7e89acdb8F315C804BE7245F348AA9c538` | UUPS proxy — stable forever |
| `JanusToken` (impl)  | Flow EVM testnet | `0x28686066D28Eb86269190Eae76eD7170c21BB7FB` | Current implementation |
| Proxy owner (COA)    | Flow EVM testnet | `0x0000000000000000000000022f6b30af48a94787` | Authorizes `upgradeToAndCall()` |
| `JanusFlow.cdc` (router) | Flow Cadence testnet | `0x5dcbeb41055ec57e` | Canonical — stable forever |
| `JanusFlowImpl.cdc` | Flow Cadence testnet | `0x5dcbeb41055ec57e` | Current impl — swappable |
| `IJanusFlowImpl.cdc` | Flow Cadence testnet | `0x5dcbeb41055ec57e` | Impl interface |
| `EncryptConsistencyVerifier.sol` | Flow EVM testnet | `0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e` | Groth16, ceremony-backed |
| `DecryptOpenVerifier.sol` | Flow EVM testnet | `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` | Groth16, ceremony-backed |
| `BabyJub.sol` (lab) | Flow EVM testnet | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Used by JanusToken |

## PrivateTip (Layer 3 — native FLOW tipping)

Router + impl pattern (mirrors JanusFlow). Custody (per-tip FlowToken vaults) lives
in the router and never moves on impl swap. `claimTip` is signer-bound via
`auth(BorrowValue) &Account` to fix the prior `self.account.address` privilege
escalation.

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| `PrivateTip.cdc` (router) | Flow Cadence testnet | `0xb9ac529c14a4c5a1` | Router + custody |
| `PrivateTipImpl.cdc` | Flow Cadence testnet | `0xb9ac529c14a4c5a1` | Initial impl |
| `IPrivateTipImpl.cdc` | Flow Cadence testnet | `0xb9ac529c14a4c5a1` | Impl interface |

## DEPRECATED — DO NOT USE

| Contract | Layer | Address | Why |
|----------|-------|---------|-----|
| `JanusToken.sol` | Flow EVM testnet | `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499` | Pre-SCALE-fix; `unwrap()` releases 1 wei instead of 1 FLOW. Locked FLOW unrecoverable. |
| `JanusToken.sol` | Flow EVM testnet | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` | Pre-ceremony zkeys (single contributor) |
| `JanusFlow.cdc` (prev router) | Flow Cadence testnet | `0xbef3c77681c15397` | 48h impl-swap time-lock blocked the SCALE-fix redeploy; superseded by `0x5dcbeb41055ec57e`. |
| `JanusFlow.cdc` (zombie v1) | Flow Cadence testnet | `0x28fef3d1d6a12800` | Legacy Pedersen, zombie — cannot be removed. |
| `PrivateTip.cdc` (monolith)  | Flow Cadence testnet | `0xd807a3992d7be612` | `claimTip` used `self.account.address` instead of signer (vuln 015). Replaced by the router/impl pair at `0xb9ac529c14a4c5a1`. |

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
| `0x7599043aea001283` | `0x000000000000000000000002b7557ee5d4a32d06` | Alice (lab) |
| `0xd807a3992d7be612` | `0x00000000000000000000000250d93efba617e0bf` | Bob |
| `0x3c601a443c81e6cd` | `0x00000000000000000000000249065458581f9bf0` | Charlie |
| `0xd32d9100e1fe983b` | `0x0000000000000000000000027b94cfc8a64971cd` | Dave |
| `0xbef3c77681c15397` | `0x0000000000000000000000022f6b30af48a94787` | openjanus-flow (proxy owner) |

## SDK constants

```typescript
import {
  JANUS_TOKEN_TESTNET,                  // { evmAddress: "0x025efe7e...", network: "testnet" }
  JANUS_FLOW_CADENCE_ADDRESS,           // "0x5dcbeb41055ec57e" (router — canonical)
  JANUS_FLOW_CADENCE_ADDRESS_PREVIOUS,  // "0xbef3c77681c15397" (deprecated)
  JANUS_FLOW_CADENCE_ADDRESS_LEGACY,    // "0x28fef3d1d6a12800" (zombie — DO NOT USE)
  JANUS_FLOW_VERSION,                   // "0.2.1-router"
  JANUS_TOKEN_EVM,                      // "0x025efe7e89acdb8F315C804BE7245F348AA9c538"
  JANUS_TOKEN_DEPRECATED_ADDRESSES,     // { preScaleFix: "0xb12E600...", preCeremony: "0xC715b36..." }
  ENCRYPT_VERIFIER_EVM,                 // "0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e"
  DECRYPT_VERIFIER_EVM,                 // "0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc"
  JANUS_BABYJUB_ADDRESS,                // "0x27139AFda7425f51F68D32e0A38b7D43BcB0f870"
} from "@openjanus/sdk/tokens";

import {
  randomBabyJubScalar,                  // Reduces mod babyjub.subOrder (~2^250), not F.p
  flowToWei, weiToFlow,                 // Whole-FLOW ↔ wei converters
  FLOW_SCALE,                           // 10n ** 18n
  assertWholeFlow,                      // Refuse to wrap non-whole-FLOW amounts
} from "@openjanus/sdk/crypto";

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
