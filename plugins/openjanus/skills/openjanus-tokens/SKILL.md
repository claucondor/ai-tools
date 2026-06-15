---
name: openjanus-tokens
description: |
  Cadence-first guide to the v0.8 Janus token stack. 3 tokens: JanusFlow (native FLOW, EVM proxy 0xA64340C1d356835A2450306Ffd290Ed52c001Ad3), JanusERC20 (Mock USDC / mUSDC, 0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d), JanusFT (Cadence FT, 0x4b6bc58bc8bf5dcc). All at feeBps=10 (0.1%). Per-token ShieldedCheckpoint for sender state. Shared ShieldedInbox for recipients (push-model: inbox full reverts shieldedTransfer). claimBatch(N=10) to drain inbox in one proof. Covers the shielded-pool primitives (commitments, totalSupplyCommitment, totalLocked, 6-arg shieldedTransfer), AmountDiscloseAggregateVerifier + ConfidentialTransferAggregateVerifier + ConfidentialClaimBatchVerifier circuit trio (pot22 ceremony), public-inputs layout, and how to scaffold a new Janus<X> concrete.
  TRIGGER when: JanusFlow, JanusFT, JanusERC20, JanusMockUSDC, JanusToken abstract base, Cadence privacy on Flow, "tip in FLOW privately", "private payroll Flow", "donations with hidden amounts", "shielded transfer FLOW", "Cadence FT wrapper", shielded pool, commitments mapping, totalSupplyCommitment, totalLocked, shieldedTransfer, AmountDiscloseVerifier, ConfidentialTransferVerifier, "wrap FLOW into privacy", "Pedersen commitment slot", "v0.8 contract", "v0.8 ABI", "shielded transfer public inputs", "wrap unwrap boundary", "totalLocked auditability", "fully shielded transfer", "privacy validation matrix", "multi-token", "Janus<X> pattern", "extend JanusToken", "create a JanusUSDC", "wrap an ERC20", "MockUSDC", "mUSDC", "deploy my own privacy token", "confidential ERC-20", "abstract concrete tokens", "wrapWithProof", "claimBatch", "ShieldedInbox", "ShieldedCheckpoint", "inbox full reverts", "push model inbox", "batch claim inbox", "N=10 notes", "pot22", "nonce anti-replay", "6-arg shieldedTransfer", "9-arg shieldedTransfer removed".
  DO NOT TRIGGER when: using the SDK to call these contracts in TypeScript (use openjanus-sdk), asking about low-level cryptography (use openjanus-primitives), deploying to testnet/mainnet (use openjanus-deploy).
---

# Janus Tokens — Cadence-first privacy primitives (v0.8)

OpenJanus is **Cadence-first**. Most apps want **JanusFlow** (native FLOW)
or **JanusFT** (any Cadence FungibleToken). **JanusERC20** is additive and
advanced — only use it for Flow EVM apps that already speak ERC20.

`JanusToken` (Solidity abstract base) defines the shielded-pool primitives
shared by every OpenJanus confidential token. Each `Janus<X>` concrete
extends it with asset-specific entry points (`wrapWithProof` / `unwrap` for native
FLOW, `transferFrom`-style wrappers for an ERC-20, etc.).


## Pick-the-right-token (v0.8)

| Use case | Token | SDK id | Notes |
|----------|-------|--------|-------|
| Tip / pay / donate in native FLOW | **`JanusFlow` (PRIMARY)** | `'flow'` | Production. EVM proxy at `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3`. |
| Privacy for Mock USDC (ERC20 stablecoin) | `JanusERC20` | `'mockusdc'` | Approve MockUSDC first; EVM proxy at `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d`. |
| Privacy for a Cadence FungibleToken | **`JanusFT`** | `'mockft'` | Cadence at `0x4b6bc58bc8bf5dcc`; FCL path. |
| Building a new shielded asset (your own ERC-20) | `JanusToken` abstract base | — | Extend with your own `Janus<X>` concrete — see `references/creating-custom-instances.md`. |

> **Removed in v0.8**: `JanusWFLOW` (wrapped FLOW ERC20 wrapper). Use `JanusERC20` for any ERC20 wrapping needs.


## Concrete tokens shipped (v0.8)

| Contract | Layer | SDK id | Address | Status |
|----------|-------|--------|---------|--------|
| `JanusFlow` (concrete, Solidity) | Flow EVM | `'flow'` | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` | production |
| `JanusERC20` (concrete, Solidity) | Flow EVM | `'mockusdc'` | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` | production (testnet) |
| `JanusFT` (concrete, Cadence) | Cadence | `'mockft'` | `0x4b6bc58bc8bf5dcc` | production |
| `JanusToken` (abstract, Solidity) | Flow EVM | — | not deployed standalone | stable |
| `MockUSDC` (mUSDC underlying) | Flow EVM | — | `0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524` | 6 decimals, testnet only |
| `MockFT` (underlying for JanusFT) | Cadence | — | `0x4b6bc58bc8bf5dcc` | Cadence FT underlying |
| `MemoKeyRegistry` (immutable) | EVM | — | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` | shared; one publish covers all |
| `ShieldedInbox` (immutable) | EVM | — | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` | per-user mailbox |
| `ShieldedCheckpoint` (immutable) | EVM | — | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` | per-user per-token state |


## Core concepts

**Pedersen commitment slot** — Each user's residual balance is stored as
a single BabyJubJub point: `Commit(v, r) = [v]·G + [r]·H`. The point is
opaque; observers cannot derive the cleartext amount without the blinding.

**Homomorphic accumulation** — `shieldedTransfer` updates the sender's and
recipient's commitments simultaneously, conserving total value. The
`totalSupplyCommitment()` (sum of all commitments) is also a Pedersen point.
The `Pedersen2Gen` library performs all `addCommits()` on-chain.

**Boundary aggregate (`totalLocked`)** — A cleartext `uint256` aggregate
of all tokens currently held in the shielded pool. Visible by design so external
observers can audit the pool size. Per-user balances stay hidden.

**Three Groth16 circuits (pot22 ceremony)** —
- `AmountDiscloseAggregateVerifier` — wrap / unwrap boundary. Proves `Commit(amount, blinding) = (commitX, commitY)` with anti-replay nonce. Public inputs: `[amount, commitX, commitY, nonce]`.
- `ConfidentialTransferAggregateVerifier` — `shieldedTransfer`. Proves a sender's commitment was correctly split into `(C_new_sender, C_tx)` without revealing any amounts. Public inputs: `[C_old_x, C_old_y, C_tx_x, C_tx_y, C_new_x, C_new_y]`.
- `ConfidentialClaimBatchVerifier` (N=10) — `claimBatch`. Proves draining N=10 inbox notes in one proof. Public inputs: `[C_old_x, C_old_y, C_new_x, C_new_y, C_consumed_x, C_consumed_y]`.

**ShieldedInbox (push-model)** — On every `shieldedTransfer`, the contract
atomically deposits an encrypted note to the recipient's `ShieldedInbox`. If the
inbox is full (`MAX_INBOX_NOTES = 10000`), the `shieldedTransfer` **reverts**.
Recipients must drain their inbox via `claimBatch()`. **Always warn users in the UI.**

**ShieldedCheckpoint** — Per-user, per-token encrypted state store. Senders update
this after each transfer via a separate composable call. The ShieldedInbox push
model keeps the checkpoint update off the critical transfer path.


## Deployed addresses (testnet) — v0.8

See [`canonical-addresses.md`](../openjanus-deploy/references/canonical-addresses.md) for the
full address table. Summary:

### EVM tokens

| Contract | Address | Notes |
|----------|---------|-------|
| `JanusFlow` (EVM proxy) | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` | UUPS proxy, feeBps=10 |
| `JanusERC20` (EVM proxy) | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` | UUPS proxy, feeBps=10 |
| `MockUSDC` (mUSDC underlying) | `0xd49Ff950279841aaEcf642E85C3a0bBc1FB4B524` | 6 decimals, mintable |

### Cadence token

| Contract | Address | Notes |
|----------|---------|-------|
| `JanusFT` (Cadence) | `0x4b6bc58bc8bf5dcc` | Canonical Cadence FT wrapper, feeBps=10 |
| `MockFT` (underlying) | `0x4b6bc58bc8bf5dcc` | Same account |

### Shared primitives

| Contract | Address | Notes |
|----------|---------|-------|
| `MemoKeyRegistry` (immutable) | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` | one publish covers all tokens |
| `ShieldedInbox` (immutable) | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` | push-model recipient mailbox |
| `ShieldedCheckpoint` (immutable) | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` | per-user per-token sender state |
| `AmountDiscloseAggregateVerifier` | `0xf7B634D41259D0613345633eE1CD193A030A6329` | Groth16, pot22 ceremony |
| `ConfidentialTransferAggregateVerifier` | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` | Groth16, pot22 ceremony |
| `ConfidentialClaimBatchVerifier` (N=10) | `0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f` | Groth16, pot22, batch drain |
| `BabyJub.sol` | `0xD79C90b797949F0956d977989aEf82A81c860e0C` | Reused across versions |
| `Pedersen2Gen` | `0x5EdF7473b1007b4855127bC40fcc89eCDD7fB561` | 2-gen Pedersen accumulator |


## References (loaded on-demand)

When relevant, read these files for detail. Order reflects recommended adoption (Cadence-first stack first, advanced last).

- `references/README.md` — Contracts overview: file map and quick lookup
- `references/janus-flow.md` — **PRIMARY** — JanusFlow concrete (native FLOW EVM v0.8) with wrapWithProof, 6-arg shieldedTransfer, claimBatch, ShieldedInbox push-model.
- `references/janus-ft.md` — **SECONDARY** (v0.4, lab-grade) — JanusFT Cadence FungibleToken wrapper, stub-crypto limitations, registry resource model
- `references/janus-token.md` — Solidity abstract base interface, slot lifecycle, public inputs format, claimBatch trust model
- `references/creating-custom-instances.md` — Deploy a custom Janus&lt;X&gt; concrete for your ERC-20 with all 8 constructor args
- `references/confidential-tipping.md` — Multi-sender tipping pattern using ShieldedInbox delivery + claimBatch accumulation
- `references/funding-with-amount-privacy.md` — Public fundraising with hidden contribution amounts
- `references/privacy-level-needed.md` — Decision tree: amount-only privacy (v1) vs UTXO/stealth (v2+ roadmap)
- `references/janus-erc20.md` — **ADVANCED** (v0.8) — JanusERC20 ERC20-wrapping concrete, MockUSDC (mUSDC) underlying, approve-and-pull wrap pattern. Only for EVM-DeFi apps that already speak ERC20.


## Cross-skill references (load when context indicates)

- `../openjanus-sdk/references/quickstart.md` — SDK-level v0.8 quick start
- `../openjanus-deploy/references/canonical-addresses.md` — All testnet addresses
- `../openjanus-sdk/references/decrypt-flow.md` — Recovering a balance from `(commit, blinding)`


## Examples

**JanusToken abstract base ABI (Solidity, brief — v0.8):**

```solidity
abstract contract JanusToken {
    mapping(address => Point) public commitments;
    mapping(address => mapping(uint256 => bool)) public usedNonces;

    function totalSupplyCommitment() external view returns (Point memory);
    function totalLocked() external view returns (uint256);

    // 6-arg shieldedTransfer — deposits note to ShieldedInbox atomically
    function shieldedTransfer(
        address to,
        uint256[6] calldata publicInputs,  // [C_old_x, C_old_y, C_tx_x, C_tx_y, C_new_x, C_new_y]
        uint256[8] calldata proof,
        bytes calldata encryptedNoteTo,
        uint256 ephPubkeyToX,
        uint256 ephPubkeyToY
    ) external;

    // Drain N=10 inbox notes in one Groth16 proof
    function claimBatch(
        uint256[6] calldata publicInputs,  // [C_old_x, C_old_y, C_new_x, C_new_y, C_consumed_x, C_consumed_y]
        uint256[8] calldata proof
    ) external;
}
```

**JanusFlow concrete — wrapWithProof (v0.8):**

```solidity
contract JanusFlow is JanusToken {
    // payable — gross amount; proof binds to NET (post-fee); nonce for anti-replay
    function wrapWithProof(
        uint256 nonce,
        uint256[2] calldata commit,
        uint256[2] calldata pA,
        uint256[2][2] calldata pB,
        uint256[2] calldata pC,
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY
    ) external payable;

    // NOT payable
    function unwrap(
        uint256 claimedAmount,
        address payable recipient,
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof,
        uint256[6] calldata transferPublicInputs,
        uint256[8] calldata transferProof,
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY
    ) external;
}
```


## Common gotchas

**P1 — ShieldedInbox push-model: inbox full reverts shieldedTransfer.**
If a recipient has 10000 unread inbox notes, any `shieldedTransfer` to them reverts.
Recipients must drain via `claimBatch()`. Build this warning into your UI and track inbox depth.

**P2 — Nonce must be fresh per wrapWithProof call.**
`usedNonces[caller][nonce]` is written after each wrap. Re-using a nonce reverts.
Generate a random uint256 per wrap, or use a counter. The SDK handles this automatically.

**P3 — Persisting `(amount, blinding)` is the app's responsibility.**
Recipients receive `(amount_i, blinding_i)` in the encrypted note from their ShieldedInbox.
They must decrypt and persist these pairs to later run `claimBatch()` or `unwrap()`.
Losing the blinding loses access to that commitment forever.

**P4 — Fixed-array verifier interface mismatch.**
snarkjs generates verifiers with `uint[N]` (fixed arrays). Your interface must
match exactly — `uint256[6]` not `uint256[] calldata`. Selector mismatch causes silent revert.

**P5 — Boundary amount visibility surprises users.**
`wrapWithProof` leaks the gross amount via `msg.value` and the net (post-fee) amount via
`Wrapped` + `WrapWithSnapshot` events. `unwrap` is non-payable; the amount leaks via
`claimedAmount` in calldata, `Unwrapped` + `UnwrapWithSnapshot` events, and — unavoidably —
the native FLOW internal transfer (visible on any block explorer).
This is amount privacy on shielded transfers, transparency at boundaries — by design.

**P6 — claimBatch trust model (v0.8 testnet only).**
The verifier does NOT cross-check `C_consumed` against a registry of deposited inbox notes.
Mainnet will add a `NoteCommitmentTracker`. For testnet, the C_old state machine prevents
double-spending of the same batch proof.


## Companion skills

- **`openjanus-sdk`** — TypeScript SDK wrapping these contracts
- **`openjanus-deploy`** — deploy a new Janus&lt;X&gt; concrete or verifier
- **`openjanus-primitives`** — the cryptographic layer the contracts depend on
- **`flow-crossvm`** — Cross-VM patterns for Cadence orchestrating EVM calls
