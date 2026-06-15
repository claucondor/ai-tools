# Contracts (v0.8)

Reference documentation for the JanusToken abstract base + the three v0.8 concrete confidential tokens.

OpenJanus is **Cadence-first**. The recommended primitives are JanusFlow
(native FLOW, the PRIMARY token for most apps) and JanusFT (any Cadence
FungibleToken). JanusERC20 is additive and advanced — only use it for
EVM-DeFi integrations that need to wrap native ERC20s.

> **v0.8 key additions:** ShieldedInbox push-model (atomically delivers notes on shieldedTransfer),
> ShieldedCheckpoint for sender state recovery, claimBatch(N=10) for batch inbox drain.

## Primary Cadence-first stack (start here)

| File | Contents |
|------|----------|
| [janus-flow.md](janus-flow.md) | **PRIMARY** — JanusFlow concrete (native FLOW EVM v0.8) with wrapWithProof, 6-arg shieldedTransfer, ShieldedInbox integration, claimBatch. The recommended primitive for tips / payroll / donations denominated in FLOW. |
| [janus-ft.md](janus-ft.md) | **SECONDARY** — JanusFT concrete (Cadence FungibleToken wrapper). Use for non-FLOW Cadence FT integrations. Lab-grade with stub crypto. |

## Abstract base + custom instances

| File | Contents |
|------|----------|
| [janus-token.md](janus-token.md) | JanusToken Solidity abstract base — v0.8 slot layout, 6-arg shieldedTransfer, claimBatch, public inputs format |
| [creating-custom-instances.md](creating-custom-instances.md) | How to deploy a custom Janus&lt;X&gt; for your own ERC-20 with 8-arg constructor + ShieldedInbox/Checkpoint |

## Advanced (EVM-DeFi only)

| File | Contents |
|------|----------|
| [janus-erc20.md](janus-erc20.md) | **ADVANCED** — JanusERC20 concrete (ERC20-wrapping EVM v0.8), MockUSDC (mUSDC) underlying, approve-and-pull wrap pattern, claimBatch. Only use for Flow EVM apps that already speak ERC20. |

For deployed addresses, see [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md).
