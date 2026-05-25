# openjanus/ai-tools

AI tools and Claude Code plugin for building on the OpenJanus privacy stack on Flow.

## What is OpenJanus?

OpenJanus is a suite of privacy primitives for the Flow blockchain:

- **BabyJubJub** — elliptic curve operations on Flow EVM
- **Pedersen commitments** — hide token amounts while preserving homomorphic properties
- **Groth16 proofs** — ZK proofs for confidential transfers
- **JanusToken** — confidential ERC-20 (NATIVE or WRAPPER mode)
- **JanusFlow** — native FLOW wrapper via Cadence Cross-VM
- **@openjanus/sdk** — unified TypeScript SDK

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
npm install @openjanus/sdk
```

Quick start:

```typescript
import { JanusToken, JANUS_TOKEN_TESTNET } from "@openjanus/sdk";

const token = new JanusToken(JANUS_TOKEN_TESTNET);
await token.connect();

const commit = await token.balanceOfCommitment("0xYourAddress");
console.log(commit); // { x: 0n, y: 1n } = zero balance
```

## Documentation

| Section | Contents |
|---------|----------|
| [docs/sdk/install.md](docs/sdk/install.md) | Installation and module structure |
| [docs/sdk/basic-transfer.md](docs/sdk/basic-transfer.md) | Reading balances, generating proofs |
| [docs/sdk/advanced-usage.md](docs/sdk/advanced-usage.md) | JanusFlow wrap/transfer/unwrap |
| [docs/patterns/confidential-tipping.md](docs/patterns/confidential-tipping.md) | End-to-end tipping pattern |
| [docs/contracts/janus-token.md](docs/contracts/janus-token.md) | JanusToken interface and modes |
| [docs/contracts/janus-flow.md](docs/contracts/janus-flow.md) | JanusFlow Cadence contract |
| [docs/contracts/creating-custom-instances.md](docs/contracts/creating-custom-instances.md) | Deploy your own JanusToken |
| [docs/primitives/](docs/primitives/) | BabyJubJub, Pedersen, Groth16 reference |
| [docs/gotchas/pi-b-fp2-swap.md](docs/gotchas/pi-b-fp2-swap.md) | The most common ZK bug |
| [docs/gotchas/circuit-artifacts.md](docs/gotchas/circuit-artifacts.md) | WASM/zkey file locations |
| [docs/deployments/canonical-addresses.md](docs/deployments/canonical-addresses.md) | All testnet addresses |
| [docs/decision-trees/](docs/decision-trees/) | Which primitive / mode / privacy level |
| [examples/deploy-janus-flow.md](examples/deploy-janus-flow.md) | Deploy a WRAPPER instance |
| [examples/nextjs-integration.md](examples/nextjs-integration.md) | Next.js app example |

## Deployed contracts (testnet)

| Contract | Address |
|----------|---------|
| BabyJub.sol | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` |
| ConfidentialTransferVerifier | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` |
| JanusToken.sol (NATIVE demo) | `0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A` |
| JanusFlow.cdc (v1.1.0) | `0x28fef3d1d6a12800` |

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
