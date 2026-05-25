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
> See [why-v1-was-deprecated](https://github.com/openjanus/sdk/blob/main/docs/why-v1-was-deprecated.md)
> and [docs/_archive/](docs/_archive/) for v1 documentation.

## Plugin install (Claude Code)

```
/plugin marketplace add openjanus/ai-tools
/plugin install openjanus@openjanus-ai-tools
```

This gives Claude Code four skills:

| Skill | Activates when you ask about |
|-------|------------------------------|
| `openjanus-sdk` | Installing or using `@openjanus/sdk` |
| `openjanus-primitives` | BabyJubJub, Pedersen, Groth16 internals |
| `openjanus-tokens` | JanusToken / JanusFlow contracts |
| `openjanus-deploy` | Deploying new token instances |

## SDK install

```bash
npm install @openjanus/sdk@^0.2.0
```

Quick start (v2):

```typescript
import { JanusTokenV2, JANUS_TOKEN_V2_TESTNET } from "@openjanus/sdk/tokens-v2";

const token = new JanusTokenV2(JANUS_TOKEN_V2_TESTNET);
await token.connect();

const ct = await token.getBalanceCiphertext("0xYourAddress");
// Identity ciphertext means zero balance
const hasPk = await token.hasPubkey("0xYourAddress");
```

## Documentation

| Section | Contents |
|---------|----------|
| [docs/sdk/install.md](docs/sdk/install.md) | Installation and module structure |
| [docs/sdk/extending-the-sdk.md](docs/sdk/extending-the-sdk.md) | Adding new modules |
| [docs/patterns/cross-vm-coa-pattern.md](docs/patterns/cross-vm-coa-pattern.md) | Cross-VM COA pattern |
| [docs/patterns/ts-sdk-integration.md](docs/patterns/ts-sdk-integration.md) | TypeScript SDK integration |
| [docs/contracts/README.md](docs/contracts/README.md) | Contract overview |
| [docs/contracts/creating-custom-instances.md](docs/contracts/creating-custom-instances.md) | Deploy your own JanusTokenV2 |
| [docs/primitives/](docs/primitives/) | BabyJubJub, Pedersen, Groth16 reference |
| [docs/gotchas/pi-b-fp2-swap.md](docs/gotchas/pi-b-fp2-swap.md) | The most common ZK bug |
| [docs/gotchas/circuit-artifacts.md](docs/gotchas/circuit-artifacts.md) | WASM/zkey file locations |
| [docs/deployments/canonical-addresses.md](docs/deployments/canonical-addresses.md) | All testnet addresses (v1 historical, v2 current) |
| [docs/decision-trees/which-primitive.md](docs/decision-trees/which-primitive.md) | Which primitive to use |
| [docs/decision-trees/privacy-level-needed.md](docs/decision-trees/privacy-level-needed.md) | What privacy level do you need? |
| [examples/deploy-janus-flow.md](examples/deploy-janus-flow.md) | Deploy a v2 instance |
| [examples/nextjs-integration.md](examples/nextjs-integration.md) | Next.js app example |
| [docs/_archive/](docs/_archive/) | v1 docs (Pedersen-hash, deprecated) |

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

1. For pitfalls: grep first. `grep -ri "symptom" docs/ plugins/`
2. If an entry exists, add a one-line cross-reference instead of duplicating.
3. Reference files stay 200–300 lines — split larger topics.
4. All content must be PUBLIC-SAFE (usage docs, operational info). Audit analysis stays private.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT — OpenJanus
