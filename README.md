# claucondor/ai-tools

Claude Code plugin for building on the Janus privacy stack on Flow.

## What is the Janus privacy stack?

> **Status — testnet only.** The Janus privacy stack is deployed on Flow EVM testnet for
> demonstration. Not recommended for production use until third-party audit
> completes (audit pending). Privacy, not anonymity: sender/recipient addresses
> stay public on-chain — only the amount is hidden.

The Janus privacy stack is a suite of privacy primitives for the Flow blockchain.
`@claucondor/sdk@0.5.5` gives you:

- **BabyJubJub** — elliptic curve operations on Flow EVM
- **Pedersen commitments** — hide token amounts behind 128-bit random blindings
- **Groth16 proofs** — ZK proofs for confidential wrap/transfer/unwrap
- **ShieldedNote** — protocol-level encrypted payload that carries `(amount, blinding, memo)` to recipients end-to-end
- **Sign-derive** — deterministic BabyJub keypair from a wallet signature (HKDF-SHA256); same key on any device, no seed phrase
- **JanusFlow.MemoKey** — generic BabyJub pubkey registry (v0.5.2+); lives in JanusFlow.cdc, NOT app contracts; privkey never on-chain
- **Recovery module** — `@claucondor/sdk/recovery`: scan `*WithSnapshot` EVM events, decrypt with MemoKey privkey, reconstruct (balance, blinding) from any device
- **Boundary fee model (v0.5.4+)** — 0.1% on wrap + unwrap, free on shielded transfers; admin-configurable, MAX 1% hard cap
- **JanusFlow** — native FLOW confidential token via Cadence cross-VM
- **JanusFTCadence** — any Cadence FungibleToken vault
- **JanusERC20** — ERC20-wrapping on Flow EVM

## Plugin install (Claude Code)

```
/plugin marketplace add claucondor/ai-tools
/plugin install openjanus@claucondor-ai-tools
```

This gives Claude Code five skills:

| Skill | Activates when you ask about |
|---|---|
| `openjanus-sdk` | Installing or using `@claucondor/sdk` |
| `openjanus-primitives` | BabyJubJub, Pedersen, Groth16 internals |
| `openjanus-tokens` | JanusFlow / JanusERC20 / JanusFTCadence contracts |
| `openjanus-elgamal` | ECIES + AES-GCM encryption, BabyJub keypair derivation (sign-derive), ShieldedNote payload encryption |
| `openjanus-deploy` | Deploying new token instances, canonical addresses |

## Repository Layout

This repository follows the Anthropic official Agent Skills standard:

```
plugins/openjanus/skills/<skill>/
  +-- SKILL.md       <- metadata + activation triggers + core instructions
  +-- references/    <- detail docs, loaded on-demand
      +-- *.md
```

Each skill is a self-contained bundle. The skill resolver loads `SKILL.md` on
activation (lazy), and `references/` files load only when explicitly referenced.
This achieves ~33x token efficiency vs. loading all docs upfront.

## Quick start

```bash
npm install @claucondor/sdk@^0.5.5
```

```typescript
import {
  JanusFlow,
  buildAmountDiscloseProof,
  generateBlinding,
  flowToWei,
} from "@claucondor/sdk";
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

const flow = new JanusFlow();
await flow.connectWithSigner(wallet);

const amountWei = flowToWei(5n);
const blinding  = generateBlinding();
const proof     = await buildAmountDiscloseProof({ amount: amountWei, blinding });

await flow.wrap({
  amountWei,
  txCommit:    proof.txCommit,
  amountProof: proof.proof,
});
```

For the full shielded-transfer and unwrap walkthrough, see
[`@claucondor/sdk`](https://github.com/claucondor/sdk) or the
[PrivateTip demo](https://github.com/claucondor/private-tip) and its `/learn`
page for an animated, visual explanation of the underlying primitives.

## Documentation (in `references/`)

All detail docs live inside the relevant skill's `references/` folder.

| Topic | Location |
|---|---|
| Installation and module structure | `plugins/openjanus/skills/openjanus-sdk/references/install.md` |
| Full workflow quickstart | `plugins/openjanus/skills/openjanus-sdk/references/quickstart.md` |
| **Recovery module (v0.5.2)** | `plugins/openjanus/skills/openjanus-sdk/references/recovery.md` |
| Architecture overview | `plugins/openjanus/skills/openjanus-sdk/references/v03-architecture.md` |
| Extending the SDK | `plugins/openjanus/skills/openjanus-sdk/references/extending-the-sdk.md` |
| TypeScript/Next.js integration | `plugins/openjanus/skills/openjanus-sdk/references/ts-sdk-integration.md` |
| Cross-VM COA pattern | `plugins/openjanus/skills/openjanus-sdk/references/cross-vm-coa-pattern.md` |
| BabyJubJub curve reference | `plugins/openjanus/skills/openjanus-primitives/references/babyjub.md` |
| Pedersen commitments | `plugins/openjanus/skills/openjanus-primitives/references/pedersen.md` |
| Groth16 proof generation | `plugins/openjanus/skills/openjanus-primitives/references/groth16.md` |
| pi_b Fp2 swap (most common ZK bug) | `plugins/openjanus/skills/openjanus-primitives/references/pi-b-fp2-swap.md` |
| Which primitive to use | `plugins/openjanus/skills/openjanus-primitives/references/which-primitive.md` |
| JanusToken contract interface | `plugins/openjanus/skills/openjanus-tokens/references/janus-token.md` |
| JanusFlow Cadence + **MemoKey primitive** | `plugins/openjanus/skills/openjanus-tokens/references/janus-flow.md` |
| Deploy a custom JanusToken | `plugins/openjanus/skills/openjanus-tokens/references/creating-custom-instances.md` |
| Confidential tipping | `plugins/openjanus/skills/openjanus-tokens/references/confidential-tipping.md` |
| Funding with amount privacy | `plugins/openjanus/skills/openjanus-tokens/references/funding-with-amount-privacy.md` |
| Sign-derive: deterministic keypair from wallet sig | `plugins/openjanus/skills/openjanus-elgamal/references/sign-derive.md` |
| Keypair derivation (from Flow private key) | `plugins/openjanus/skills/openjanus-elgamal/references/keypair-derivation.md` |
| ECIES + ShieldedNote + snapshot dual-use | `plugins/openjanus/skills/openjanus-elgamal/references/elgamal-architecture.md` |
| Canonical deployed addresses | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` |
| Circuit artifacts | `plugins/openjanus/skills/openjanus-deploy/references/circuit-artifacts.md` |

## License

MIT
