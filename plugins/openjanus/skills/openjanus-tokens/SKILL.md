---
name: openjanus-tokens
description: |
  Cadence-first guide to the v0.4 multi-token Janus stack. PRIMARY token: JanusFlow (native FLOW, Cadence-router façade at 0x5dcbeb41055ec57e, recommended for tips / payroll / donations). SECONDARY: JanusFT (Cadence FungibleToken wrapper, lab-grade in v0.4 with stub crypto). ADVANCED / EVM-DeFi only: JanusERC20 (ERC20 wrapper on EVM, MockUSDC underlying on testnet). Plus the shared JanusToken abstract base. Covers the shielded-pool primitives (commitments, totalSupplyCommitment, totalLocked, shieldedTransfer), the v0.3 AmountDiscloseVerifier + ConfidentialTransferVerifier circuit pair (reused by all EVM tokens), public-inputs layout, empirically-validated privacy property tables, and how to scaffold a new Janus&lt;X&gt; concrete.
  TRIGGER when: JanusFlow, JanusFT, JanusToken abstract base, JanusERC20, Cadence privacy on Flow, "tip in FLOW privately", "private payroll Flow", "donations with hidden amounts", "shielded transfer FLOW", "Cadence FT wrapper", shielded pool, commitments mapping, totalSupplyCommitment, totalLocked, shieldedTransfer, AmountDiscloseVerifier, ConfidentialTransferVerifier, "wrap FLOW into privacy", "Pedersen commitment slot", "v0.3 contract", "v0.3 ABI", "shielded transfer public inputs", "wrap unwrap boundary", "totalLocked auditability", "fully shielded transfer", "privacy validation matrix", "multi-token", "Janus&lt;X&gt; pattern", "extend JanusToken", "create a JanusUSDC", "wrap an ERC20", "MockUSDC", "deploy my own privacy token", "confidential ERC-20", "abstract concrete tokens", "v0.4 contract", "v0.4 ABI".
  DO NOT TRIGGER when: using the SDK to call these contracts in TypeScript (use openjanus-sdk), asking about low-level cryptography (use openjanus-primitives), deploying to testnet/mainnet (use openjanus-deploy), or asking about deprecated v0.2 ElGamal contracts (content is in migration docs at openjanus-sdk/references/migration-v02-to-v03.md).
---

# Janus Tokens — Cadence-first privacy primitives (v0.4)

OpenJanus is **Cadence-first**. Most apps want **JanusFlow** (native FLOW)
or **JanusFT** (any Cadence FungibleToken). **JanusERC20** is additive and
advanced — only use it for Flow EVM apps that already speak ERC20.

`JanusToken` (Solidity abstract base) defines the shielded-pool primitives
shared by every OpenJanus confidential token. Each `Janus<X>` concrete
extends it with asset-specific entry points (`wrap` / `unwrap` for native
FLOW, `transferFrom`-style wrappers for an ERC-20, etc.).

> **v0.2 (ElGamal+SCALE) is deprecated.** It leaked the transferred amount on
> `msg.value`, calldata `transferUnits`, the public `locked` mapping, and the
> `Wrapped` / `Unwrapped` events. v0.3 moves all of that to a Pedersen-commit
> scheme where the shielded-transfer path leaks nothing about the amount on any
> channel. See [../openjanus-sdk/references/migration-v02-to-v03.md](../openjanus-sdk/references/migration-v02-to-v03.md)
> for the rewrite recipes.

## Pick-the-right-token (v0.4)

| Use case | Token | Notes |
|----------|-------|-------|
| Tip / pay / donate in FLOW (Cadence-native) | **`JanusFlow` (PRIMARY)** | Production. Cadence router at `0x5dcbeb41055ec57e` hides cross-VM from users. |
| Tip / pay / donate in a Cadence FungibleToken other than FLOW | **`JanusFT` (SECONDARY)** | Lab-grade in v0.4 (stub crypto); production lands in v0.5. |
| Shielded amounts on a pure-EVM DeFi workflow with ERC20 underlying | `JanusERC20` (ADVANCED) | Only when you already speak ERC20 on Flow EVM. |
| Building a new shielded asset (your own ERC-20) | `JanusToken` abstract base | Extend with your own `Janus<X>` concrete — see `references/creating-custom-instances.md`. |

## Concrete tokens shipped (v0.4)

| Contract | Layer | Purpose | Status |
|----------|-------|---------|--------|
| `JanusFlow` (concrete, Solidity)  | Flow EVM | **PRIMARY** native-FLOW concrete extending `JanusToken` | v0.3, production |
| `JanusFlow` (Cadence router)      | Cadence  | **PRIMARY** Cadence-first façade — most apps consume this | v0.3, production |
| `JanusFT` (concrete, Cadence)     | Cadence  | **SECONDARY** FungibleToken-wrapping concrete | v0.4, lab-grade (stub crypto) |
| `JanusToken` (abstract, Solidity) | Flow EVM | Shielded-pool primitives; NOT deployed standalone | v0.3, stable |
| `JanusERC20` (concrete, Solidity) | Flow EVM | ADVANCED — ERC20-wrapping concrete extending `JanusToken` | v0.4, production (testnet) |
| `MockUSDC` (test underlying)      | Flow EVM | Permissionlessly-mintable 6-decimal placeholder underlying for the v0.4 JanusERC20 instance | v0.4, testnet only |

## Core concepts

**Pedersen commitment slot** — Each user's residual balance is stored as a
single BabyJubJub point: `commit = amount * G + blinding * H`. The point is
opaque; observers cannot derive the cleartext amount without the blinding.

**Homomorphic accumulation** — `shieldedTransfer` updates the sender's and
recipient's commitments simultaneously, conserving total value. The
`totalSupplyCommitment()` (sum of all commitments) is also a Pedersen point.

**Boundary aggregate (`totalLocked`)** — A cleartext `uint256` aggregate
of all FLOW currently held in the shielded pool. Visible by design so external
observers can audit the pool size. Per-user balances stay hidden.

**Two Groth16 circuits** —
- `AmountDiscloseVerifier` is used at the wrap / unwrap boundary. It proves
  a commitment binds a specific public scalar amount.
- `ConfidentialTransferVerifier` is used on `shieldedTransfer`. It proves a
  sender's commitment was correctly split into a residual and a transferred
  commitment without revealing any of the amounts.

## Deployed addresses (testnet) — v0.4.0

### Primary Cadence-first stack

| Contract | Address | Notes |
|----------|---------|-------|
| `JanusFlow` (Cadence router)  | `0x5dcbeb41055ec57e` | **PRIMARY** — the address most apps consume |
| `JanusFlow` (EVM proxy)       | `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078` | UUPS proxy, stable forever (implementation detail of the router) |
| `JanusFlow` (EVM impl)        | `0x9321dF5884021D7E19Ad0EB5F582f8E2A70236eC` | swappable via UUPS |
| `JanusFT` (Cadence)           | `0xbef3c77681c15397` | **SECONDARY** Cadence FT wrapper, NEW in v0.4 (lab-grade) |
| `JanusFT` (Cadence smoke)     | `0x3c601a443c81e6cd` | Smoke-test mirror — byte-identical, resettable |

### Shared primitives (REUSED across all tokens)

| Contract | Address | Notes |
|----------|---------|-------|
| `AmountDiscloseVerifier`  | `0xD0ED3936530258C278f5357C1dB709ad34768352` | Groth16, ceremony-backed |
| `ConfidentialTransferVerifier` | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` | Groth16, ceremony-backed |
| `BabyJub.sol` (lab)       | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | Reused across versions |

### Advanced EVM-DeFi (use only for ERC20-native workflows)

| Contract | Address | Notes |
|----------|---------|-------|
| `JanusERC20` (EVM proxy)  | `0xf2C04b1A32B815ac7Ffd87a4C312096592BBCa1e` | UUPS proxy, NEW in v0.4 |
| `JanusERC20` (EVM impl)   | `0x7FE0B05ED77E0540519B6f10DD4b4521e867590D` | swappable via UUPS |
| `MockUSDC` (underlying)   | `0x3e8973dE565743Ef9748779bE377BBE050A13C22` | 6 decimals, mintable (testnet only) |

DEPRECATED (DO NOT USE):
`0x025efe7e89acdb8F315C804BE7245F348AA9c538` (v0.2 EVM JanusToken — LEAKS_AMOUNTS_BY_DESIGN),
`0xbef3c77681c15397.JanusFlow` (v0.2 Cadence router — NOTE: this is the SAME account as canonical JanusFT v0.4, but only the JanusFlow contract at this address is deprecated),
`0x28fef3d1d6a12800` (v1 Cadence zombie — Pedersen-hash, cannot be removed).

## References (loaded on-demand)

When relevant, read these files for detail. Order reflects recommended
adoption (Cadence-first stack first, advanced last).

- `references/README.md` — Contracts overview: file map and quick lookup
- `references/janus-flow.md` — **PRIMARY** — JanusFlow concrete (native FLOW EVM v0.3) with Cadence router. Start here for tips / payroll / donations in FLOW.
- `references/janus-ft.md` — **SECONDARY** (v0.4, lab-grade) — JanusFT Cadence FungibleToken wrapper, stub-crypto limitations, registry resource model, smoke mirror
- `references/janus-token.md` — Solidity abstract base interface, slot lifecycle, public inputs format
- `references/creating-custom-instances.md` — Deploy a custom Janus&lt;X&gt; concrete for your ERC-20
- `references/confidential-tipping.md` — Multi-sender tipping pattern using v0.3 fully shielded transfers
- `references/funding-with-amount-privacy.md` — Public fundraising with hidden contribution amounts
- `references/privacy-level-needed.md` — Decision tree: what OpenJanus v0.3 provides vs stealth addresses vs mixer
- `references/router-pattern.md` — Historical note on the v0.2 Cadence router/impl pattern (v0.3 uses UUPS on EVM + simple Cadence façade)
- `references/janus-erc20.md` — **ADVANCED** (v0.4) — JanusERC20 ERC20-wrapping concrete, MockUSDC underlying, approve-and-pull wrap pattern. Only for EVM-DeFi apps that already speak ERC20.

## Cross-skill references (load when context indicates)

- `../openjanus-sdk/references/v03-architecture.md` — Abstract / concrete pattern + empirical privacy validation
- `../openjanus-sdk/references/migration-v02-to-v03.md` — v0.2 ElGamal → v0.3 Pedersen rewrite recipes
- `../openjanus-deploy/references/canonical-addresses.md` — All testnet addresses
- `../openjanus-sdk/references/quickstart.md` — SDK-level v0.3 quick start
- `../openjanus-sdk/references/decrypt-flow.md` — Recovering a balance from `(commit, blinding)`

## Examples

**JanusToken abstract base ABI (Solidity, brief):**

```solidity
abstract contract JanusToken {
    mapping(address => Point) public commitments;
    function totalSupplyCommitment() external view returns (Point memory);
    function totalLocked() external view returns (uint256);

    function shieldedTransfer(
        address to,
        uint256[6] calldata publicInputs,
        uint256[8] calldata proof
    ) external;
}
```

**JanusFlow concrete (adds native-FLOW wrap / unwrap):**

```solidity
contract JanusFlow is JanusToken {
    function wrap(
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof
    ) external payable;

    function unwrap(
        uint256 claimedAmount,
        address recipient,
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof,
        uint256[6] calldata transferPublicInputs,
        uint256[8] calldata transferProof
    ) external;
}
```

**Cadence transaction (wrap via the router):**

```cadence
import JanusFlow from 0x5dcbeb41055ec57e
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

transaction(
    amount:      UFix64,
    txCommitX:   UInt256,
    txCommitY:   UInt256,
    amountProof: [UInt256]
) {
    let vault: @FlowToken.Vault
    prepare(signer: auth(BorrowValue) &Account) {
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("No FlowToken.Vault in signer storage")
        self.vault <- flowVault.withdraw(amount: amount) as! @FlowToken.Vault
    }
    execute {
        JanusFlow.wrap(
            vault:       <-self.vault,
            txCommitX:   txCommitX,
            txCommitY:   txCommitY,
            amountProof: amountProof
        )
    }
}
```

## Common gotchas

**P1 — No `registerPubkey` in v0.3.**
v0.2 required recipients to register a BabyJubJub pubkey. v0.3 has no pubkey registry —
commitments are bound only to the sender's locally-held blinding. Recipients of a
`shieldedTransfer` MUST receive `(transferAmount, transferBlinding)` from the
sender via an out-of-band channel.

**P2 — Persisting `(amount, blinding)` is the app's responsibility.**
There is no on-chain decryption key. Losing the blinding for a commitment loses
access to that commitment forever.

**P3 — Fixed-array verifier interface mismatch (vuln/013, still applies).**
snarkjs generates verifiers with `uint[N]` (fixed arrays). Your interface must
match exactly — `uint256[6]` not `uint256[] calldata`. Selector mismatch causes
silent revert.

**P4 — Wrong addresses.**
The v0.2 EVM JanusToken (`0x025efe7e...`) and v0.2 Cadence router (`0xbef3c776...`)
leak amount privacy by design. Always import addresses from the SDK constants —
never hardcode.

**P5 — Boundary amount visibility surprises users.**
`wrap` leaks the gross amount via `msg.value` and the net (post-fee) amount via
`Wrapped` + `WrapWithSnapshot` events. `unwrap` is non-payable (`msg.value` is
always 0); the amount leaks via `claimedAmount` in calldata (proof public input),
`Unwrapped` + `UnwrapWithSnapshot` events, and — unavoidably — the native FLOW
internal transfer to the recipient, which is visible on any block explorer regardless
of event emission. This is amount privacy on shielded transfers, transparency at
boundaries — by design, not by accident. Document this clearly in your UI — users
who expect "fully private" need to use `shieldedTransfer` between two pool
participants and avoid the boundary.

## Companion skills

- **`openjanus-sdk`** — TypeScript SDK wrapping these contracts
- **`openjanus-deploy`** — deploy a new Janus&lt;X&gt; concrete or verifier
- **`openjanus-primitives`** — the cryptographic layer the contracts depend on
- **`flow-crossvm`** — Cross-VM patterns for Cadence orchestrating EVM calls
