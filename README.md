# openjanus/ai-tools

AI tools and Claude Code plugin for building on the OpenJanus privacy stack on Flow.

## What is OpenJanus?

OpenJanus is a suite of privacy primitives for the Flow blockchain:

- **BabyJubJub** — elliptic curve operations on Flow EVM
- **Pedersen commitments** — hide token amounts (primitive layer, used by ZK circuits)
- **Groth16 proofs** — ZK proofs for confidential transfers
- **JanusToken** — confidential token with ElGamal-on-BabyJub accumulation
- **JanusFlow** — native FLOW wrapper via Cadence Cross-VM
- **@openjanus/sdk** — unified TypeScript SDK

## Plugin install (Claude Code)

```
/plugin marketplace add openjanus/ai-tools
/plugin install openjanus@openjanus-ai-tools
```

This gives Claude Code five skills:

| Skill | Activates when you ask about |
|-------|------------------------------|
| `openjanus-sdk` | Installing or using `@openjanus/sdk` |
| `openjanus-primitives` | BabyJubJub, Pedersen, Groth16 internals |
| `openjanus-tokens` | JanusToken / JanusFlow contracts |
| `openjanus-elgamal` | ElGamal encryption/decryption, BSGS, keypair derivation |
| `openjanus-deploy` | Deploying new token instances, canonical addresses |

## Repository Layout

This repository follows the Anthropic official Agent Skills standard:

```
plugins/openjanus/skills/<skill>/
  +-- SKILL.md       <- metadata + activation triggers + core instructions
  +-- references/    <- detail docs, loaded on-demand
      +-- *.md
```

Each skill is a self-contained bundle. The skill resolver loads `SKILL.md` on activation
(lazy), and `references/` files load only when the skill explicitly references them.
This achieves ~33x token efficiency vs. loading all docs upfront.

## SDK install

```bash
npm install @openjanus/sdk
```

Quick start:

```typescript
import { JanusFlow, JANUS_TOKEN_TESTNET } from "@openjanus/sdk/tokens";
import { buildEncryptProof, bsgsRecover } from "@openjanus/elgamal";

const sdk = new JanusFlow({ network: "testnet" });
await sdk.configure();

// Register pubkey once per account
await sdk.registerPubkey(keypair.pk, authz);

// Encrypt and wrap FLOW
const proof = await buildEncryptProof({ amount: 10n, randomness, recipientPubkey: pk });
await sdk.wrapAndEncrypt("10.0", ALICE_ADDR, proof, senderAuthz);
```

## Documentation (in `references/`)

All detail docs live inside the relevant skill's `references/` folder.

| Topic | Location |
|-------|----------|
| Installation and module structure | `plugins/openjanus/skills/openjanus-sdk/references/install.md` |
| Full workflow quickstart | `plugins/openjanus/skills/openjanus-sdk/references/quickstart.md` |
| BSGS decrypt in depth | `plugins/openjanus/skills/openjanus-sdk/references/decrypt-flow.md` |
| Extending the SDK | `plugins/openjanus/skills/openjanus-sdk/references/extending-the-sdk.md` |
| TypeScript/Next.js integration | `plugins/openjanus/skills/openjanus-sdk/references/ts-sdk-integration.md` |
| Cross-VM COA pattern | `plugins/openjanus/skills/openjanus-sdk/references/cross-vm-coa-pattern.md` |
| BabyJubJub curve reference | `plugins/openjanus/skills/openjanus-primitives/references/babyjub.md` |
| Pedersen commitments | `plugins/openjanus/skills/openjanus-primitives/references/pedersen.md` |
| Groth16 proof generation | `plugins/openjanus/skills/openjanus-primitives/references/groth16.md` |
| pi_b Fp2 swap (most common ZK bug) | `plugins/openjanus/skills/openjanus-primitives/references/pi-b-fp2-swap.md` |
| Which primitive to use | `plugins/openjanus/skills/openjanus-primitives/references/which-primitive.md` |
| JanusToken contract interface | `plugins/openjanus/skills/openjanus-tokens/references/janus-token.md` |
| JanusFlow Cadence contract | `plugins/openjanus/skills/openjanus-tokens/references/janus-flow.md` |
| Deploy a custom JanusToken | `plugins/openjanus/skills/openjanus-tokens/references/creating-custom-instances.md` |
| Confidential tipping | `plugins/openjanus/skills/openjanus-tokens/references/confidential-tipping.md` |
| Funding with amount privacy | `plugins/openjanus/skills/openjanus-tokens/references/funding-with-amount-privacy.md` |
| ElGamal architecture | `plugins/openjanus/skills/openjanus-elgamal/references/elgamal-architecture.md` |
| Keypair derivation | `plugins/openjanus/skills/openjanus-elgamal/references/keypair-derivation.md` |
| Canonical deployed addresses | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` |
| Circuit artifacts | `plugins/openjanus/skills/openjanus-deploy/references/circuit-artifacts.md` |

## License

MIT
