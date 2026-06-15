# Canonical Addresses — v0.8.x contracts / v0.8.1-alpha.7 SDK

All deployed OpenJanus contracts on **Flow testnet** (EVM chainId 545 + Flow Cadence testnet).

> **Status — testnet only.** These addresses are the canonical v0.8 testnet deployments.
> Mainnet addresses will be added when available.
>
> **v0.8 clean deploy**: 2026-06-09. Admin Cadence: `0x4b6bc58bc8bf5dcc`,
> COA (EVM owner): `0x0000000000000000000000020885d7ad3582356a`.

---

## Address table (single source of truth)

| Contract | Layer | Address | Notes |
|----------|-------|---------|-------|
| JanusFlow proxy | EVM | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` | UUPS proxy — v0.8, stable |
| JanusERC20 proxy (mUSDC) | EVM | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` | UUPS proxy — v0.8 |
| MockUSDC (mUSDC) underlying | EVM | `0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524` | 6 decimals, mintable testnet only |
| JanusFT | Cadence | `0x4b6bc58bc8bf5dcc` | Canonical Cadence FT wrapper |
| MockFT (underlying for JanusFT) | Cadence | `0x4b6bc58bc8bf5dcc` | Same account hosts both |
| MemoKeyRegistry (immutable) | EVM | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` | One publish covers all tokens |
| ShieldedInbox (immutable) | EVM | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` | Per-user mailbox; no proxy |
| ShieldedCheckpoint (immutable) | EVM | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` | Per-user per-token state; no proxy |
| ShieldedCheckpoint (Cadence) | Cadence | `0xd1a02aa46d9151bb` | JanusFT checkpoint, separate faucet account |
| BabyJub | EVM | `0xD79C90b797949F0956d977989aEf82A81c860e0C` | BabyJubJub negate helper |
| Pedersen2Gen | EVM | `0x5EdF7473b1007b4855127bC40fcc89eCDD7fB561` | 2-generator Pedersen library |
| ConfidentialTransferAggregateVerifier | EVM | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` | Groth16, pot22 ceremony |
| AmountDiscloseAggregateVerifier | EVM | `0xf7B634D41259D0613345633eE1CD193A030A6329` | Groth16, pot22 ceremony |
| ConfidentialClaimBatchVerifier (N=10) | EVM | `0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f` | Groth16, pot22, N=10 batch claim |

All deployed Janus tokens operate at `feeBps=10` (0.1% on wrap + unwrap; free on shielded transfers).

---

## Token inventory (v0.8)

### JanusFlow — native FLOW (PRIMARY, Cadence-first)

| Layer | Address | Notes |
|-------|---------|-------|
| JanusFlow EVM proxy | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` | UUPS proxy, v0.8.1 impl |
| MemoKeyRegistry | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` | Immutable; one publish covers all tokens |
| ShieldedInbox | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` | Atomically receives recipient notes on shieldedTransfer |
| ShieldedCheckpoint | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` | Sender updates this separately after each transfer |

The Cadence router for JanusFlow calls the EVM proxy via COA. Most Cadence-first apps
consume the EVM proxy address through the SDK.

### JanusERC20 — ERC20 wrapper (mUSDC)

| Layer | Address | Notes |
|-------|---------|-------|
| JanusERC20 proxy | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` | UUPS proxy, v0.8.1 impl |
| MockUSDC (mUSDC) underlying | `0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524` | 6 decimals, mintable testnet only |

Wrap pattern: approve MockUSDC (mUSDC) → `sdk.token('mockusdc').wrapWithProof(...)`.

### JanusFT — Cadence FungibleToken

| Layer | Address | Notes |
|-------|---------|-------|
| JanusFT Cadence | `0x4b6bc58bc8bf5dcc` | Canonical Cadence FT wrapper |
| MockFT underlying | `0x4b6bc58bc8bf5dcc` | Same account hosts underlying + wrapper |
| ShieldedCheckpoint (Cadence) | `0xd1a02aa46d9151bb` | Per-token checkpoint for JanusFT |

Use `sdk.token('mockft')` to interact via the SDK.

### Shared primitives (v0.8)

| Contract | Address | Notes |
|----------|---------|-------|
| ConfidentialTransferAggregateVerifier | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` | Groth16, pot22, shared by all EVM tokens |
| AmountDiscloseAggregateVerifier | `0xf7B634D41259D0613345633eE1CD193A030A6329` | Groth16, pot22, shared by all EVM tokens |
| ConfidentialClaimBatchVerifier (N=10) | `0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f` | Groth16, pot22, claimBatch() |
| BabyJub | `0xD79C90b797949F0956d977989aEf82A81c860e0C` | Curve negate helper |
| Pedersen2Gen | `0x5EdF7473b1007b4855127bC40fcc89eCDD7fB561` | Homomorphic accumulation |

> **Legacy v0.7.1 JanusFlow proxy**: `0x9A83732417947Ef9b7AEa64bF807a345267c2FdA` — still live,
> serves the PrivateTip demo. Do NOT use for new deployments.

---

## SDK token IDs (v0.8)

The SDK exposes a generic adapter interface. Use `sdk.token(id)` with the following IDs:

| SDK token ID | Contract | Underlying |
|-------------|----------|-----------|
| `'flow'` | JanusFlow proxy | Native FLOW |
| `'mockusdc'` | JanusERC20 proxy | MockUSDC (mUSDC) ERC20 |
| `'mockft'` | JanusFT Cadence | MockFT Cadence FT |

> **Removed in v0.8**: `'wflow'` (JanusWFLOW) — that token type is no longer part of the stack.
> If you have a v0.6 integration using `'wflow'`, migrate to `'mockusdc'` for the ERC20 path.

---

## MemoKeyRegistry

The `MemoKeyRegistry` at `0x361bD4d037838A3a9c5408AE465d36077800ee6c` is an
**immutable** contract. Publishing a MemoKey once registers it for all tokens —
no per-token re-publish needed.

```typescript
import { deriveMemoKeyFromSignature } from "@claucondor/sdk";
import { ethers } from "ethers";

const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));

// One publish covers all tokens:
await sdk.token('flow').publishMemoKey(memoKeypair, wallet);
```

---

## ShieldedInbox and ShieldedCheckpoint (v0.8 primitives)

**ShieldedInbox** (`0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6`): per-user on-chain mailbox.
On every `shieldedTransfer`, the contract atomically deposits an encrypted note to the
recipient's inbox. If the inbox is full (`MAX_INBOX_NOTES = 10000`), `shieldedTransfer`
reverts — recipients must drain their inbox via `claimBatch()` or individual drains.

**ShieldedCheckpoint** (`0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26`): per-user, per-token
encrypted state. Senders update this separately after each transfer using
`checkpoint.update(token, encryptedSnapshot, ephX, ephY, cursorIndex)`. Read your own
checkpoint at any time for state recovery.

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

## Admin / COA mappings (testnet)

| Cadence address | COA (EVM) address | Label |
|----------------|-----------------|-------|
| `0x4b6bc58bc8bf5dcc` | `0x0000000000000000000000020885d7ad3582356a` | OpenJanus deployer / admin |

---

## Verifying addresses

All EVM contracts are deployed on the public Flow testnet and can be verified at:

- Flow EVM explorer: [evm.flowscan.io](https://evm.flowscan.io)
- Cadence explorer: [flowscan.io](https://flowscan.io)
