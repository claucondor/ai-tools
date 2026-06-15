# Installing @claucondor/sdk

## Package name and version

The SDK is published as `@claucondor/sdk`. Current production version: **v0.8.1-alpha.7**.

## Install paths

### Path A — npm (canonical)

When the package is available in the npm registry:

```bash
npm install @claucondor/sdk

# pnpm
pnpm add @claucondor/sdk

# yarn
yarn add @claucondor/sdk
```

### Path B — tarball file: ref (private-tip-v1 pattern)

Downstream apps that consume the SDK before it is published to the public registry commit
the tarball to their repo and reference it with a `file:` prefix:

```json
// package.json
{
  "dependencies": {
    "@claucondor/sdk": "file:claucondor-sdk-0.8.1-alpha.7.tgz",
    "@openjanus/commitment": "file:openjanus-commitment-0.1.0.tgz"
  }
}
```

```bash
# Install from the file: ref
npm install
```

The tarball is produced with `npm pack` from the SDK repo after `npm run build`.
Bump the version identifier in the filename + package.json when the SDK ships a new tarball.

> Do not run `npm publish` iteratively. Build locally, pack to tarball, test downstream
> against the tarball, then publish only when browser-tested and operator-approved.

---

## v0.8 highlights

- Generic `sdk.token('flow' | 'mockusdc' | 'mockft')` — one interface for all 3 tokens.
- `ShieldedCheckpoint` + `ShieldedInbox` — replaces v0.7 event-scan recovery.
- `BatchClaimClient` — consolidate up to 50 inbox notes via Groth16 proof.
- `getPortfolioView` — multi-token portfolio snapshot with checkpoint health detection.
- `safeBuild*` guards — pre-flight commitment coherence checks.
- Atomic `cadenceTx.*` templates — wrap+checkpoint in one Cadence tx.
- `MemoKeySession` — sessionStorage-backed BabyJub privkey cache.
- Bundled Groth16 artifacts in `circuits/` (ConfidentialTransfer, AmountDisclose, ConfidentialClaimBatch).
- ESM + CJS dual build; Node.js 18+.

---

## Peer dependencies

All required dependencies are bundled (`ethers@^6`, `@onflow/fcl`, `@onflow/types`,
`circomlibjs`, `snarkjs`, `@noble/hashes`). No separate install needed unless
you need version pinning:

```bash
npm install @claucondor/sdk ethers@^6
```

---

## Node version

Requires Node.js 18 or later. The SDK uses ESM (`"type": "module"` in package.json).

For CommonJS consumers (webpack, Next.js pages router), the `exports` map handles it
automatically — import from `@claucondor/sdk` works in both ESM and CJS.

---

## Module exports map

```
@claucondor/sdk            — main barrel (sdk singleton, all adapters, helpers)
@claucondor/sdk/adapters   — JanusFlowAdapter, JanusERC20Adapter, JanusFTAdapter
@claucondor/sdk/batchClaim — BatchClaimClient, buildBatchClaimProof
@claucondor/sdk/checkpoint — ShieldedCheckpointClient
@claucondor/sdk/inbox      — ShieldedInboxClient, getCadenceInboxNotes
@claucondor/sdk/cadence    — cadenceTx.*, installInbox, installCheckpoint, etc.
@claucondor/sdk/session    — MemoKeySession, SentMemoStore
@claucondor/sdk/orchestration — orchestrateWrap, orchestrateShieldedTransfer, orchestrateUnwrap
@claucondor/sdk/network    — createEvmProvider, createEvmWallet, configureFCL, COA helpers
@claucondor/sdk/crypto     — proof builders, ECIES, commitment helpers
@claucondor/sdk/primitives — computeCommitment, addCommitmentsLocal
@claucondor/sdk/utils      — applyPiBSwap, rawToUFix64, cadenceAddrToEvmToken, isFreshSlotCommit
@claucondor/sdk/proof/batch-claim — buildBatchClaimProof (direct access)
```

Import from fine-grained subpaths to reduce bundle size in browser apps.

---

## TypeScript

Full type definitions are included. No `@types/` package needed.

```json
// tsconfig.json — recommended for ESM + Flow SDK
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true
  }
}
```

---

## Verifying the install

```typescript
import { TOKEN_REGISTRY, SHIELDED_CHECKPOINT_ADDRESS } from "@claucondor/sdk";

console.log(TOKEN_REGISTRY.flow.proxy);
// 0xA64340C1d356835A2450306Ffd290Ed52c001Ad3

console.log(SHIELDED_CHECKPOINT_ADDRESS);
// 0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26

import { sdk } from "@claucondor/sdk";
const flow = sdk.token('flow');
console.log(flow);  // JanusFlowAdapter instance — no error means install succeeded
```

---

## Bundled circuit artifacts

The SDK ships Groth16 artifacts in `circuits/`:

```
node_modules/@claucondor/sdk/circuits/
├── amount_disclose/
│   ├── amount_disclose.wasm
│   ├── amount_disclose_final.zkey
│   └── amount_disclose_vkey.json
├── confidential_transfer/
│   ├── confidential_transfer.wasm
│   ├── confidential_transfer_final.zkey
│   └── confidential_transfer_vkey.json
└── batch_claim/
    ├── batch_claim.wasm
    ├── batch_claim_final.zkey
    └── batch_claim_vkey.json
```

The proof builders (`buildAmountDiscloseProof`, `buildShieldedTransferProof`,
`buildBatchClaimProof`) resolve artifact paths automatically from `import.meta.url`.

---

## Next steps

- [quickstart.md](quickstart.md) — Full v0.8 workflow walk-through (3 tokens, MemoKey, portfolio, batch claim)
- [migration-to-v08.md](migration-to-v08.md) — v0.7 → v0.8 migration recipes
- [v03-architecture.md](v03-architecture.md) — v0.8.x architecture + module map
- [extending-the-sdk.md](extending-the-sdk.md) — Add a custom module / new circuit
- [recovery.md](recovery.md) — State recovery from ShieldedCheckpoint
