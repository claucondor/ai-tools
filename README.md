# openjanus/ai-tools

AI agent skills and documentation for building on the Janus privacy stack on Flow.

## What is the Janus privacy stack?

> **Status — testnet only.** The Janus privacy stack is deployed on Flow EVM testnet for
> demonstration. Not recommended for production use until third-party audit
> completes (audit pending). Privacy, not anonymity: sender/recipient addresses
> stay public on-chain — only the amount is hidden.

The Janus privacy stack is a suite of privacy primitives for the Flow blockchain.
`@claucondor/sdk@^0.8.2` gives you:

- **BabyJubJub** — elliptic curve operations on Flow EVM
- **Pedersen commitments** — hide token amounts behind 128-bit random blindings (`@openjanus/commitment`)
- **Groth16 proofs** — ZK proofs for confidential wrap/transfer/unwrap (and batchClaim N=10)
- **ShieldedNote** — protocol-level encrypted payload that carries `(amount, blinding, memo)` to recipients end-to-end
- **ShieldedInbox** — per-user on-chain mailbox; recipients drain instead of scanning events (`0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6`)
- **ShieldedCheckpoint** — per-user, per-token encrypted sender state store for balance recovery (`0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26`)
- **BatchClaim** — consolidate up to N=10 inbox notes in a single ZK proof
- **Sign-derive** — deterministic BabyJub keypair from a wallet signature (HKDF-SHA256); same key on any device, no seed phrase
- **MemoKeyRegistry** (v0.8) — shared registry at `0x361bD4d037838A3a9c5408AE465d36077800ee6c`; one `publishMemoKey` covers all tokens; privkey never on-chain
- **Generic adapter API** — `sdk.token('flow' | 'mockusdc' | 'mockft')` — one interface for all tokens
- **JanusFlow** — native FLOW confidential token (EVM proxy at `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3`)
- **JanusERC20** — ERC20 privacy wrapper (MockUSDC proxy at `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d`)
- **JanusFT** — Cadence FungibleToken privacy (at Cadence address `0x4b6bc58bc8bf5dcc`)
- **getPortfolioView** — multi-token drift detector; compares on-chain commitments vs local checkpoint
- **Safety guards** — `assertCheckpointMatchesCommit`, `isOpSafeNow`, `safeBuild*` pre-flight checks

## Plugin install

```
/plugin marketplace add openjanus/ai-tools
/plugin install openjanus@openjanus-ai-tools
```

This gives your agent five skills:

| Skill | Activates when you ask about |
|---|---|
| `openjanus-sdk` | Installing or using `@claucondor/sdk`, `sdk.token(id)`, ShieldedInbox, ShieldedCheckpoint, batchClaim |
| `openjanus-primitives` | BabyJubJub, Pedersen, Groth16, `@openjanus/commitment` internals |
| `openjanus-tokens` | JanusFlow / JanusERC20 / JanusFT contracts |
| `openjanus-elgamal` | ECIES + AES-GCM encryption, BabyJub keypair derivation (sign-derive), ShieldedNote payload encryption |
| `openjanus-deploy` | Deploying new token instances, canonical v0.8.2 addresses |

## Repository Layout

This repository follows the agent skills standard:

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
# Install from tarball (recommended until npm publish)
npm install file:claucondor-sdk-0.8.2.tgz
# Or from npm (when available)
npm install @claucondor/sdk@^0.8.2
```

```typescript
import { sdk, deriveMemoKeyFromSignature, ShieldedInboxClient, ShieldedCheckpointClient } from "@claucondor/sdk";
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// 1. Derive memokey from wallet signature (deterministic, no seed phrase)
const sig = await wallet.signMessage('OpenJanus MemoKey v1');
const memoKeypair = await deriveMemoKeyFromSignature(ethers.getBytes(sig));

// 2. Publish memokey once (covers all tokens via MemoKeyRegistry)
const flow = sdk.token('flow');
await flow.publishMemoKey(memoKeypair, wallet);

// 3. Wrap, send, unwrap — same API across all tokens
const mockusdc = sdk.token('mockusdc'); // ERC20 (needs approve first)
const ft       = sdk.token('mockft');  // Cadence FT

await flow.wrap({ grossAmount: 5n * 10n**18n }, wallet);
// Returns: { txHash, netAmount, commitment, blinding, checkpointPayload }

// 4. Read sender checkpoint (balance recovery)
const checkpoint = new ShieldedCheckpointClient();
const snapshot = await checkpoint.readAndDecrypt(wallet, memoKeypair.privkey);

// 5. Shielded transfer (6-arg calldata in v0.8; push-model: updates receiver slot on-chain)
const result = await flow.shieldedTransfer({
  recipient: BOB_EVM_ADDR,
  amount: 2n * 10n**18n,
  memo: 'payment',
  currentBalance: snapshot!.balance,
  currentBlinding: snapshot!.blinding,
}, wallet);

// 6. Update sender checkpoint after transfer
await checkpoint.update(flow.address, result.checkpointPayload!, 0n, wallet);

// 7. Recipient drains inbox
const inbox = new ShieldedInboxClient();
const { decrypted } = await inbox.drainAndDecrypt(bobWallet, bobMemoKeypair.privkey);
for (const { content } of decrypted) {
  console.log('Received:', content.amount, 'memo:', content.memo);
}
```

For the full shielded-transfer and unwrap walkthrough, see
[`@claucondor/sdk`](https://github.com/claucondor/sdk) or the
[PrivateTip demo](https://privatetip.vercel.app) and its `/learn`
page for an animated, visual explanation of the underlying primitives.

## Documentation (in `references/`)

All detail docs live inside the relevant skill's `references/` folder.

| Topic | Location |
|---|---|
| Installation and module structure | `plugins/openjanus/skills/openjanus-sdk/references/install.md` |
| Full workflow quickstart | `plugins/openjanus/skills/openjanus-sdk/references/quickstart.md` |
| **ShieldedInbox recovery** | `plugins/openjanus/skills/openjanus-sdk/references/inbox.md` |
| **ShieldedCheckpoint (sender state)** | `plugins/openjanus/skills/openjanus-sdk/references/checkpoint.md` |
| **BatchClaim** | `plugins/openjanus/skills/openjanus-sdk/references/batch-claim.md` |
| Architecture overview | `plugins/openjanus/skills/openjanus-sdk/references/v08-architecture.md` |
| Extending the SDK | `plugins/openjanus/skills/openjanus-sdk/references/extending-the-sdk.md` |
| TypeScript/Next.js integration | `plugins/openjanus/skills/openjanus-sdk/references/ts-sdk-integration.md` |
| Cross-VM COA pattern | `plugins/openjanus/skills/openjanus-sdk/references/cross-vm-coa-pattern.md` |
| BabyJubJub curve reference | `plugins/openjanus/skills/openjanus-primitives/references/babyjub.md` |
| Pedersen commitments (`@openjanus/commitment`) | `plugins/openjanus/skills/openjanus-primitives/references/pedersen.md` |
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
