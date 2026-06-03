# Canonical Addresses — v0.6.4 contracts / v0.6.5 SDK

All deployed OpenJanus contracts on **Flow testnet** (chainId 545 EVM + Flow Cadence testnet).

> **Status — testnet only.** These addresses are the canonical testnet deployments for
> contracts v0.6.4 + SDK v0.6.5. Mainnet addresses will be added when available.

---

## Address table (single source of truth)

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| JanusFlow proxy | EVM | `0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156` | UUPS proxy — stable forever |
| JanusWFLOW proxy | EVM | `0x00129E94d5340bd19d0b4ed9CDf718BB6e0A9400` | UUPS proxy |
| JanusMockUSDC proxy | EVM | `0xd45FDa099Cf67eD842eA379865AB08E18D62BAf3` | UUPS proxy |
| JanusFT | Cadence | `0x7599043aea001283` | Canonical Cadence FT wrapper |
| MemoKeyRegistry (immutable) | EVM | `0x05D104962ff087441f26BA11A1E1C3b9E091D663` | One publish covers all 4 tokens |
| WFLOW9 (underlying for JanusWFLOW) | EVM | `0xe7BbEAcC04A589e4B70922b2796Bb4F8e6e4873C` | Wrapped FLOW ERC20 |
| MockUSDC (underlying for JanusMockUSDC) | EVM | `0x8405E8831737aE72204c271581b7d4fAD9f622bE` | 6 decimals, mintable testnet only |
| MockFT (underlying for JanusFT) | Cadence | `0x7599043aea001283` | Cadence FungibleToken |
| BabyJub | EVM | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Reused across versions |
| ConfidentialTransferVerifier | EVM | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` | Groth16, pot18 ceremony |
| AmountDiscloseVerifier | EVM | `0xD0ED3936530258C278f5357C1dB709ad34768352` | Groth16, pot18 ceremony |

All 3 EVM Janus tokens + JanusFT Cadence operate at `feeBps=10` (0.1% on wrap + unwrap,
free on shielded transfers).

---

## Token inventory (v0.6.4)

### JanusFlow — native FLOW (PRIMARY, Cadence-first)

| Layer | Address | Notes |
|-------|---------|-------|
| JanusFlow EVM proxy | `0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156` | UUPS proxy, stable forever |
| MemoKeyRegistry | `0x05D104962ff087441f26BA11A1E1C3b9E091D663` | Immutable; one publish covers all 4 tokens |

The Cadence router for JanusFlow calls the EVM proxy via COA. Most Cadence-first apps
consume the EVM proxy address through the SDK — no Cadence address needed for JanusFlow
in v0.6.x.

### JanusWFLOW — Wrapped FLOW ERC20

| Layer | Address | Notes |
|-------|---------|-------|
| JanusWFLOW proxy | `0x00129E94d5340bd19d0b4ed9CDf718BB6e0A9400` | UUPS proxy |
| WFLOW9 underlying | `0xe7BbEAcC04A589e4B70922b2796Bb4F8e6e4873C` | Standard WFLOW ERC20 |

Wrap pattern: approve WFLOW9 → `sdk.token('wflow').wrap(...)`.

### JanusMockUSDC — Mock USDC ERC20

| Layer | Address | Notes |
|-------|---------|-------|
| JanusMockUSDC proxy | `0xd45FDa099Cf67eD842eA379865AB08E18D62BAf3` | UUPS proxy |
| MockUSDC underlying | `0x8405E8831737aE72204c271581b7d4fAD9f622bE` | 6 decimals, mintable testnet only |

Wrap pattern: approve MockUSDC → `sdk.token('mockusdc').wrap(...)`.

### JanusFT — Cadence FungibleToken

| Layer | Address | Notes |
|-------|---------|-------|
| JanusFT Cadence | `0x7599043aea001283` | Canonical Cadence FT wrapper |
| MockFT underlying | `0x7599043aea001283` | Same account hosts underlying + wrapper |

Use `sdk.token('mockft')` to interact via the SDK.

### Shared primitives

| Contract | Address | Notes |
|----------|---------|-------|
| ConfidentialTransferVerifier | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` | Groth16, shared by all EVM tokens |
| AmountDiscloseVerifier | `0xD0ED3936530258C278f5357C1dB709ad34768352` | Groth16, shared by all EVM tokens |
| BabyJub | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Reused across versions |

---

## SDK token IDs

The v0.6.5 SDK exposes a generic adapter interface. Use `sdk.token(id)` with the
following IDs:

| SDK token ID | Contract | Underlying |
|-------------|----------|-----------|
| `'flow'` | JanusFlow proxy | Native FLOW |
| `'wflow'` | JanusWFLOW proxy | WFLOW9 ERC20 |
| `'mockusdc'` | JanusMockUSDC proxy | MockUSDC ERC20 |
| `'mockft'` | JanusFT Cadence | MockFT Cadence FT |

---

## MemoKeyRegistry

The `MemoKeyRegistry` at `0x05D104962ff087441f26BA11A1E1C3b9E091D663` is an
**immutable** contract. Publishing a MemoKey once registers it for all 4 tokens —
no per-token re-publish needed.

```typescript
import { deriveMemoKeyFromSignature } from "@claucondor/sdk";
import { ethers } from "ethers";

const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));

// One publish covers all 4 tokens:
await sdk.token('flow').publishMemoKey(memoKeypair, wallet);
```

---

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

---

## Verifying addresses

All EVM contracts are deployed on the public Flow testnet and can be verified at:

- Flow EVM explorer: [evm.flowscan.io](https://evm.flowscan.io)
- Cadence explorer: [flowscan.io](https://flowscan.io)
