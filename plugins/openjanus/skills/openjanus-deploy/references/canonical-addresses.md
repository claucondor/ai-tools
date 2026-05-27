# Canonical Addresses

All deployed OpenJanus contracts on Flow testnet, grouped by **Cadence-first
recommended stack** vs **advanced EVM-DeFi only**.

> These are the official testnet deployments. Mainnet addresses will be added when available.

## Primary Cadence-first stack (recommended for most apps)

The recommended privacy primitives. Cadence users sign normal Cadence
transactions; cross-VM EVM is implementation detail. Use these for tips /
payroll / donations / any FLOW- or Cadence-FT-denominated app.

### JanusFlow — PRIMARY native-FLOW privacy (v0.3, production)

| Layer | Address | Notes |
|-------|---------|-------|
| JanusFlow Cadence router | `0x5dcbeb41055ec57e` | **PRIMARY** — the address most apps consume |
| JanusFlow EVM proxy | `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078` | UUPS proxy (implementation detail of the Cadence router) |
| JanusFlow EVM impl | `0x9321dF5884021D7E19Ad0EB5F582f8E2A70236eC` | upgradeable via UUPS |
| Owner (admin COA) | `0x0000000000000000000000022f6b30af48a94787` | openjanus-flow COA, controls UUPS upgrade |

v0.3 uses a fully shielded Pedersen-commit scheme. Per-account storage is an
opaque BabyJubJub point. The only cleartext amounts on-chain are at the
wrap / unwrap boundary (intentional, auditable pool aggregate via
`totalLocked()`).

### JanusFT — SECONDARY Cadence FungibleToken wrapper (v0.4, lab-grade)

| Address | Notes |
|---------|-------|
| `0xbef3c77681c15397` | **Canonical** JanusFT contract (openjanus-flow account) |
| `0x3c601a443c81e6cd` | Smoke-test mirror (charlie account) — byte-identical contract, repeatable structural tests via `Admin.resetCommitmentsForTestingOnly` |
| Default underlying | `A.7e60df042a9c0868.FlowToken.Vault` — configurable via Admin |

**v0.4 is lab-grade Cadence.** `babyAddStub` / `babyNegateStub` are NOT
cryptographically valid BabyJubJub point ops — placeholders so the lab can
validate **structural** privacy (calldata, events, storage). Opaque proofs
are accepted (length > 0). Cross-VM crypto + Groth16 verification land in v0.5.

NOTE: `0xbef3c77681c15397` now serves TWO purposes:
- It hosts the canonical JanusFT v0.4 contract.
- It is ALSO the legacy v0.2 JanusFlow Cadence router address (DEPRECATED —
  superseded by v0.3 router at `0x5dcbeb41055ec57e`).
Both contracts coexist on the same Cadence account — the address is NOT
deprecated, only the JanusFlow contract at that address is. Apps consuming
JanusFT can safely use this address.

### Shared primitives (reused across all tokens, v0.3)

| Contract | Address | Notes |
|----------|---------|-------|
| AmountDiscloseVerifier | `0xD0ED3936530258C278f5357C1dB709ad34768352` | Groth16, v0.3 production ceremony |
| ConfidentialTransferVerifier | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` | Groth16, v0.3 production ceremony |
| BabyJub library | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | reused across versions |

## Advanced EVM-DeFi (use only for ERC20-native workflows)

> Most apps should **not** use these. Reach for `JanusERC20` only when your
> app is on Flow EVM and already speaks ERC20 (e.g. integrating with a
> stablecoin). For Cadence-first apps, use `JanusFlow` or `JanusFT` above.

### JanusERC20 — ERC20-wrapping confidential token (v0.4)

| Layer | Address | Notes |
|-------|---------|-------|
| JanusERC20 EVM proxy | `0xf2C04b1A32B815ac7Ffd87a4C312096592BBCa1e` | UUPS proxy, pinned to MockUSDC underlying |
| JanusERC20 EVM impl | `0x7FE0B05ED77E0540519B6f10DD4b4521e867590D` | upgradeable via UUPS |
| MockUSDC (underlying) | `0x3e8973dE565743Ef9748779bE377BBE050A13C22` | 6 decimals, **permissionlessly mintable — testnet only** |
| Owner (admin COA) | `0x0000000000000000000000022f6b30af48a94787` | openjanus-flow COA, controls UUPS upgrade |

Wrap pattern: caller calls `MockUSDC.approve(proxy, amount)` then
`proxy.wrap(amount, txCommit, amountProof)`. Standard ERC20 `Transfer` event
fires on the underlying at wrap/unwrap boundary BY DESIGN. shieldedTransfer
hides amount on calldata + events + storage (no underlying ERC20 events).

Flow EVM testnet does NOT have a canonical USDC. MockUSDC is a placeholder
so apps can develop against a stable 6-decimal token address. For mainnet,
deploy a fresh `JanusERC20Proxy` pinned to your real ERC20.

Cross-VM wrap from Cadence (via a Cadence router similar to JanusFlow's) is
**not** shipped in v0.4 — it lands in v0.5. Today JanusERC20 is consumed
only from EVM-side callers (ethers / web3 / a Solidity caller contract).

Trusted setup: Hermez pot14 (200+ contributors) + Flow VRF beacon.
See `circuits/v0.3/CEREMONY-RECORD.json` in `@openjanus/sdk` for full
sha256 provenance.

Privacy validated empirically against the canonical question set
(see `cadence-crypto-lab/docs/privacy-validation/`):

- `wrap` LEAKS amount at boundary (intentional, msg.value)
- `shieldedTransfer` HIDES amount on all 5 channels (calldata, storage, events, msg.value, commitment-bruteforce)
- `unwrap` LEAKS amount at boundary (intentional, `claimedAmount` param)
- `totalLocked()` LEAKS aggregate pool size (intentional, auditability)

## DEPRECATED — DO NOT USE

| Address | Version | Reason |
|---------|---------|--------|
| `0x025efe7e89acdb8F315C804BE7245F348AA9c538` | v0.2 JanusToken EVM | LEAKS_AMOUNTS_BY_DESIGN. ElGamal+SCALE pattern leaked amounts via `msg.value` at wrap, `transferUnits` calldata param, and the public `locked()` mapping. Vuln 014 (audits-kb). |
| `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499` | v0.2 JanusToken EVM (pre-vuln-014-fix) | LEAKS_AMOUNTS_BY_DESIGN plus the vuln 014 SCALE unit mismatch (unwrap released 1 wei instead of 1 FLOW; locked FLOW unrecoverable). |
| `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` | v0.1 JanusToken EVM | Pre-ceremony zkeys (single contributor); superseded by ceremony-backed v0.2 then v0.3. |
| `0xbef3c77681c15397` (JanusFlow contract only) | v0.2 JanusFlow Cadence router | Old router for the v0.2 EVM JanusToken; superseded by v0.3 router at `0x5dcbeb41055ec57e`. NOTE: this address ALSO hosts the canonical JanusFT v0.4 contract — only the JanusFlow Cadence contract at this address is deprecated. |
| `0x28fef3d1d6a12800` | v1 JanusFlow Cadence zombie | Pedersen-hash (not 2-gen EC). Flow protocol prevents contract removal — this address is permanently squatted. |
| `0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e` | v0.2 EncryptConsistencyVerifier | ElGamal-only verifier, replaced by AmountDiscloseVerifier in v0.3. |
| `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` | v0.2 DecryptOpenVerifier | ElGamal-only verifier, replaced by ConfidentialTransferVerifier in v0.3. |

## Primitive contracts (Flow Cadence testnet)

| Contract | Address | Notes |
|----------|---------|-------|
| `PedersenBabyJub.cdc` | `0x28fef3d1d6a12800` | Legacy primitives account (v1, do not consume new code from here) |

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
| `0xbef3c77681c15397` | `0x0000000000000000000000022f6b30af48a94787` | openjanus-flow (admin COA, v0.3 UUPS owner) |

## SDK constants (v0.4)

```typescript
// From @openjanus/sdk/tokens (or the root entry point)
import {
  // Token classes
  JanusFlow,                          // concrete native-FLOW (v0.3)
  JanusERC20,                         // concrete ERC20 wrapper (v0.4)
  JanusToken,                         // abstract base
  JanusFlowCadence,                   // Cadence router read-only helper (v0.3)
  JanusFTCadence,                     // Cadence-side FT wrapper helper (v0.4)

  // JanusFlow (v0.3) — unchanged
  JANUS_FLOW_TESTNET,
  JANUS_FLOW_EVM_ADDRESS,             // "0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078"
  JANUS_FLOW_EVM_IMPL_ADDRESS,        // "0x9321dF5884021D7E19Ad0EB5F582f8E2A70236eC"
  JANUS_FLOW_CADENCE_ADDRESS,         // "0x5dcbeb41055ec57e"
  JANUS_FLOW_CONTRACT_NAME,           // "JanusFlow"
  JANUS_FLOW_VERSION,                 // "0.3.0"
  JANUS_FLOW_MAX_WRAP_ATTOFLOW,       // 18_000_000_000_000_000_000n
  JANUS_FLOW_EVM_ADDRESS_DEPRECATED_V02,
  JANUS_FLOW_CADENCE_ADDRESS_PREVIOUS,
  JANUS_FLOW_CADENCE_ADDRESS_LEGACY,

  // JanusERC20 (v0.4) — NEW
  JANUS_ERC20_TESTNET,
  JANUS_ERC20_EVM_ADDRESS,            // "0xf2C04b1A32B815ac7Ffd87a4C312096592BBCa1e"
  JANUS_ERC20_EVM_IMPL_ADDRESS,       // "0x7FE0B05ED77E0540519B6f10DD4b4521e867590D"
  JANUS_ERC20_MOCK_USDC_ADDRESS,      // "0x3e8973dE565743Ef9748779bE377BBE050A13C22"
  JANUS_ERC20_VERSION,                // "0.4.0"
  JANUS_ERC20_MAX_WRAP_RAW,           // 18_000_000_000_000_000_000n
  JANUS_ERC20_EXTRA_ABI,
  ERC20_MINIMAL_ABI,                  // approve / transferFrom / balanceOf / mint (test)

  // JanusFT (v0.4) — NEW
  JANUS_FT_CADENCE_ADDRESS,           // "0xbef3c77681c15397"
  JANUS_FT_CONTRACT_NAME,             // "JanusFT"
  JANUS_FT_VERSION,                   // "0.4.0"
  JANUS_FT_DEFAULT_UNDERLYING_TYPE,   // "A.7e60df042a9c0868.FlowToken.Vault"
  JANUS_FT_SMOKE_MIRROR_ADDRESS,      // "0x3c601a443c81e6cd"
  TX_FT_SETUP_REGISTRY, TX_FT_WRAP, TX_FT_SHIELDED_TRANSFER, TX_FT_UNWRAP,
  SCRIPT_FT_GET_TOTAL_LOCKED, SCRIPT_FT_GET_COMMITMENT, SCRIPT_FT_GET_UNDERLYING_TYPE,
  buildJanusFTTx,                     // helper to retarget templates to a non-canonical address

  // Shared primitives (REUSED across all three tokens)
  AMOUNT_DISCLOSE_VERIFIER,           // "0xD0ED3936530258C278f5357C1dB709ad34768352"
  CONFIDENTIAL_TRANSFER_VERIFIER,     // "0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B"
  JANUS_BABYJUB_ADDRESS,              // "0x27139AFda7425f51F68D32e0A38b7D43BcB0f870"
  JANUS_TOKEN_OWNER_EVM,              // "0x0000000000000000000000022f6b30af48a94787"
  JANUS_TOKEN_DEPRECATED_ADDRESSES,

  // JanusFlow Cadence templates (v0.3)
  TX_WRAP, TX_SHIELDED_TRANSFER, TX_UNWRAP,
  TX_ADMIN_PAUSE, TX_ADMIN_UNPAUSE,
  SCRIPT_GET_TOTAL_LOCKED, SCRIPT_GET_ACTIVE_IMPL_VERSION,
  SCRIPT_IS_PAUSED, SCRIPT_GET_EVM_TARGET,
} from "@openjanus/sdk/tokens";

import {
  computeCommitment,                  // Pedersen on BabyJubJub
  addCommitments,
  negateCommitment,
  identityCommitment,
  isIdentityCommitment,
  generateBlinding,                   // 128-bit random blinding
  decryptBalance,                     // exhaustive search over a value range
  buildAmountDiscloseProof,           // v0.3 wrap / unwrap boundary proof
  buildShieldedTransferProof,         // v0.3 fully shielded transfer proof
  randomBabyJubScalar,                // mod babyjub.subOrder (~2^250)
  flowToWei,
  weiToFlow,
  assertWholeFlow,
  FLOW_SCALE,                         // 10n ** 18n
  FLOW_DECIMALS,                      // 18
} from "@openjanus/sdk/crypto";
```

## Verifying addresses

All contracts are deployed on the public Flow testnet and can be verified at:

- Flow EVM explorer: [evm.flowscan.io](https://evm.flowscan.io)
- Cadence explorer: [flowscan.io](https://flowscan.io)
