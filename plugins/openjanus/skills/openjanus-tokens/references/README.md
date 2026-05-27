# Contracts

Reference documentation for the JanusToken abstract base + the three v0.4
concrete confidential tokens.

OpenJanus is **Cadence-first**. The recommended primitives are JanusFlow
(native FLOW, the PRIMARY token for most apps) and JanusFT (any Cadence
FungibleToken). JanusERC20 is additive and advanced — only use it for
EVM-DeFi integrations that need to wrap native ERC20s.

## Primary Cadence-first stack (start here)

| File | Contents |
|------|----------|
| [janus-flow.md](janus-flow.md) | **PRIMARY** — JanusFlow concrete (native FLOW EVM v0.3) with Cadence router. The recommended primitive for tips / payroll / donations denominated in FLOW. |
| [janus-ft.md](janus-ft.md) | **SECONDARY** — JanusFT concrete (Cadence FungibleToken wrapper v0.4). Use for non-FLOW Cadence FT integrations. Lab-grade in v0.4 (stub crypto); production lands in v0.5. |

## Abstract base + custom instances

| File | Contents |
|------|----------|
| [janus-token.md](janus-token.md) | JanusToken Solidity abstract base — interface, modes, events, encoding |
| [creating-custom-instances.md](creating-custom-instances.md) | How to deploy a custom Janus&lt;X&gt; for your own ERC-20 |

## Advanced (EVM-DeFi only)

| File | Contents |
|------|----------|
| [janus-erc20.md](janus-erc20.md) | **ADVANCED** — JanusERC20 concrete (ERC20-wrapping EVM v0.4), MockUSDC underlying, approve-and-pull wrap pattern. Only use for Flow EVM apps that already speak ERC20. |

For deployed addresses, see [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md).
