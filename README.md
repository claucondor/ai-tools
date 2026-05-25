# openjanus/ai-tools

AI tools and Claude Code plugin for building on the OpenJanus privacy stack on Flow.

## What is OpenJanus?

OpenJanus is a suite of privacy primitives for the Flow blockchain:

- **BabyJubJub** — elliptic curve operations on Flow EVM
- **Pedersen commitments** — hide token amounts (primitive layer, used by ZK circuits)
- **Groth16 proofs** — ZK proofs for confidential transfers
- **JanusTokenV2** — confidential token with ElGamal-on-BabyJub accumulation (v2)
- **JanusFlowV2** — native FLOW wrapper via Cadence Cross-VM (v2)
- **@openjanus/sdk@^0.2.0** — unified TypeScript SDK (v2 stack)

> v1 (JanusToken/JanusFlow, Pedersen-hash) was deprecated in 0.2.0 due to a privacy limitation.
> See [why-v1-was-deprecated](https://github.com/openjanus/sdk/blob/main/docs/why-v1-was-deprecated.md).
> V1 docs are preserved in git history at tag `v0.1.0-final`.

## Plugin install (Claude Code)

```
/plugin marketplace add openjanus/ai-tools
/plugin install openjanus@openjanus-ai-tools
```

This gives Claude Code five skills:

| Skill | Activates when you ask about |
|-------|------------------------------|
| `openjanus-sdk` | Installing or using `@openjanus/sdk` (v2 stack) |
| `openjanus-primitives` | BabyJubJub, Pedersen, Groth16 internals |
| `openjanus-tokens` | JanusTokenV2 / JanusFlowV2 contracts |
| `openjanus-elgamal` | ElGamal encryption/decryption, BSGS, keypair derivation |
| `openjanus-deploy` | Deploying new token instances, canonical addresses |

## Repository Layout

This repository follows the Anthropic official Agent Skills standard:

```
plugins/openjanus/skills/<skill>/
  ├── SKILL.md       ← metadata + activation triggers + core instructions
  └── references/    ← detail docs, loaded on-demand
      └── *.md
```

Each skill is a self-contained bundle. The skill resolver loads `SKILL.md` on activation
(lazy), and `references/` files load only when the skill explicitly references them.
This achieves ~33x token efficiency vs. loading all docs upfront.

References:
- https://github.com/anthropics/skills
- https://code.claude.com/docs/en/skills

## SDK install

```bash
npm install @openjanus/sdk@^0.2.0
```

Quick start (v2):

```typescript
import { JanusFlowV2, JANUS_TOKEN_V2_TESTNET } from "@openjanus/sdk/tokens-v2";
import { buildEncryptProof, bsgsRecover } from "@openjanus/elgamal";

const sdk = new JanusFlowV2({ network: "testnet" });
await sdk.configure();

// Register pubkey once per account
await sdk.registerPubkey(keypair.pk, authz);

// Encrypt and wrap FLOW
const proof = await buildEncryptProof({ amount: 10n, randomness, recipientPubkey: pk, ... });
await sdk.wrapAndEncrypt("10.0", ALICE_ADDR, proof, senderAuthz);
```

## Documentation (in `references/`)

All detail docs live inside the relevant skill's `references/` folder.

| Topic | Location |
|-------|----------|
| Installation and module structure | `plugins/openjanus/skills/openjanus-sdk/references/install.md` |
| V2 full workflow (quickstart) | `plugins/openjanus/skills/openjanus-sdk/references/quickstart.md` |
| BSGS decrypt in depth | `plugins/openjanus/skills/openjanus-sdk/references/decrypt-flow.md` |
| Extending the SDK | `plugins/openjanus/skills/openjanus-sdk/references/extending-the-sdk.md` |
| TypeScript/Next.js integration | `plugins/openjanus/skills/openjanus-sdk/references/ts-sdk-integration.md` |
| Cross-VM COA pattern | `plugins/openjanus/skills/openjanus-sdk/references/cross-vm-coa-pattern.md` |
| BabyJubJub curve reference | `plugins/openjanus/skills/openjanus-primitives/references/babyjub.md` |
| Pedersen commitments | `plugins/openjanus/skills/openjanus-primitives/references/pedersen.md` |
| Groth16 proof generation | `plugins/openjanus/skills/openjanus-primitives/references/groth16.md` |
| pi_b Fp2 swap (most common ZK bug) | `plugins/openjanus/skills/openjanus-primitives/references/pi-b-fp2-swap.md` |
| Which primitive to use | `plugins/openjanus/skills/openjanus-primitives/references/which-primitive.md` |
| JanusTokenV2 contract interface | `plugins/openjanus/skills/openjanus-tokens/references/janus-token.md` |
| JanusFlowV2 Cadence contract | `plugins/openjanus/skills/openjanus-tokens/references/janus-flow.md` |
| Deploy a custom JanusTokenV2 | `plugins/openjanus/skills/openjanus-tokens/references/creating-custom-instances.md` |
| Confidential tipping (v2) | `plugins/openjanus/skills/openjanus-tokens/references/confidential-tipping.md` |
| Funding with amount privacy | `plugins/openjanus/skills/openjanus-tokens/references/funding-with-amount-privacy.md` |
| What privacy level do you need? | `plugins/openjanus/skills/openjanus-tokens/references/privacy-level-needed.md` |
| ElGamal cryptographic architecture | `plugins/openjanus/skills/openjanus-elgamal/references/elgamal-architecture.md` |
| BabyJubJub keypair derivation (HKDF) | `plugins/openjanus/skills/openjanus-elgamal/references/keypair-derivation.md` |
| V1 vs V2 decision | `plugins/openjanus/skills/openjanus-elgamal/references/v1-vs-v2.md` |
| Canonical deployed addresses | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` |
| WASM/zkey artifact locations | `plugins/openjanus/skills/openjanus-deploy/references/circuit-artifacts.md` |
| 9999 CU ceiling | `plugins/openjanus/skills/openjanus-deploy/references/compute-units-limit.md` |
| Flow account vs COA address | `plugins/openjanus/skills/openjanus-deploy/references/flow-account-vs-coa.md` |
| Deploying a WRAPPER instance | `plugins/openjanus/skills/openjanus-deploy/references/deploying-wrapper-instance.md` |

## Deployed contracts (testnet)

### Primitives (canonical)

| Contract | Address |
|----------|---------|
| BabyJub.sol | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` |
| ConfidentialTransferVerifier | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` |

### v2 token contracts (current)

| Contract | Address |
|----------|---------|
| JanusTokenV2.sol | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` |
| JanusFlowV2.cdc | `0x28fef3d1d6a12800` (contract: `JanusFlowV2`) |
| EncryptConsistencyVerifier | `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C` |
| DecryptOpenVerifier | `0x3bB139B5404fD6b152813bC3532367AAa096638b` |

### v1 contracts (historical — DEPRECATED)

| Contract | Address | Status |
|----------|---------|--------|
| JanusToken.sol (NATIVE demo) | `0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A` | DEPRECATED |
| JanusFlow.cdc (v1.1.0) | `0x28fef3d1d6a12800` | DEPRECATED |

## Drop-in templates

- [prompts/claude-rules.md](prompts/claude-rules.md) — `CLAUDE.md` template for your project
- [prompts/cursor-rules.md](prompts/cursor-rules.md) — `.cursorrules` template
- [prompts/agent-system-prompts.md](prompts/agent-system-prompts.md) — orchestrator system prompts

## Contributing

This repository contains Markdown only — no code to build or compile. To contribute:

1. For pitfalls: grep first. `grep -ri "symptom" plugins/openjanus/skills/`
2. If an entry exists, add a one-line cross-reference instead of duplicating.
3. Reference files stay 200–300 lines — split larger topics.
4. All content must be PUBLIC-SAFE (usage docs, operational info). Audit analysis stays private.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT — OpenJanus
