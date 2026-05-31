# Installing @claucondor/sdk

## Package manager

```bash
# npm
npm install @claucondor/sdk@^0.5.4

# pnpm
pnpm add @claucondor/sdk@^0.5.4

# yarn
yarn add @claucondor/sdk@^0.5.4
```

v0.5.4 is the current production release. It introduces boundary fees (0.1% on wrap + unwrap),
snapshot events for cross-device recovery, and the generic `JanusFlow.MemoKey` registry.

Highlights:

- Fully shielded Pedersen-commit confidential token (`JanusFlow` for native FLOW)
- Bundled Groth16 artifacts in `circuits/v0.3/` (Hermez pot18 + Flow VRF beacon at block 324,226,714)
- Generic proof helpers: `buildAmountDiscloseProof`, `buildShieldedTransferProof`
- Generic Pedersen helpers: `computeCommitment`, `generateBlinding`, `randomBabyJubScalar`
- Recovery module: `@claucondor/sdk/recovery` for cross-device state reconstruction

## Peer dependencies

All required dependencies are bundled (ethers v6, `@onflow/fcl`, `@onflow/types`,
`circomlibjs`, `snarkjs`). You do not need to install them separately unless you
are doing advanced version pinning.

If you need a specific ethers version:

```bash
npm install @claucondor/sdk ethers@^6
```

## Node version

Requires Node.js 18 or later. The SDK uses ES modules (`"type": "module"` in
package.json), so your project must support ESM.

For CommonJS projects (webpack, Next.js pages router), import via the CJS bundle
— the `exports` map handles it automatically:

```typescript
const { JanusFlow } = require("@claucondor/sdk");
```

## Module exports map

`@claucondor/sdk` exposes fine-grained entry points (same names as v0.2; the
contents are refreshed for v0.3):

| Import | Contents |
|--------|----------|
| `@claucondor/sdk` | Everything — default entry point |
| `@claucondor/sdk/tokens` | `JanusToken`, `JanusFlow`, `JanusFlowCadence`, `JANUS_FLOW_TESTNET`, all v0.3 addresses, `TX_*` / `SCRIPT_*` Cadence templates |
| `@claucondor/sdk/primitives` | `babyjub`, `pedersen`, `groth16` modules (low-level) |
| `@claucondor/sdk/crypto` | `computeCommitment`, `addCommitments`, `buildAmountDiscloseProof`, `buildShieldedTransferProof`, `generateBlinding`, `randomBabyJubScalar`, `flowToWei`, `weiToFlow`, `FLOW_SCALE`, `assertWholeFlow`, `decryptBalance` |
| `@claucondor/sdk/network` | `createEvmWallet`, `createEvmProvider`, `configureFCL`, COA helpers |
| `@claucondor/sdk/utils` | `applyPiBSwap`, `evmProofToUint256Array`, hex helpers |

Import from the fine-grained path to reduce bundle size in browser apps.

## TypeScript

The SDK ships full type definitions. No `@types/` package is needed.

```json
// tsconfig.json — recommended settings for ESM + Flow SDK
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true
  }
}
```

## Verifying the install

```typescript
import {
  JANUS_FLOW_EVM_ADDRESS,
  JANUS_FLOW_VERSION,
} from "@claucondor/sdk/tokens";

console.log(JANUS_FLOW_EVM_ADDRESS);
// 0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078
console.log(JANUS_FLOW_VERSION);
// 0.3.0
```

If these print without error, your install is working.

## Bundled circuit artifacts

The v0.3 SDK ships the production Groth16 artifacts in `circuits/v0.3/`:

```
node_modules/@claucondor/sdk/circuits/v0.3/
├── amount_disclose.wasm
├── amount_disclose_final.zkey
├── amount_disclose_vkey.json
├── confidential_transfer.wasm
├── confidential_transfer_final.zkey
├── confidential_transfer_vkey.json
├── AmountDiscloseVerifier.sol          # for reference / on-chain verification
├── ConfidentialTransferVerifier.sol    # for reference / on-chain verification
└── CEREMONY-RECORD.json                # full sha256 provenance chain
```

The old `circuits/build/`, `circuits/setup/`, `circuits/source/` (v0.2 ElGamal artifacts)
are removed. The npm tarball no longer carries the dead weight.

## Next steps

- [quickstart.md](quickstart.md) — Full v0.5.4 workflow walk-through
- [migration-v02-to-v03.md](migration-v02-to-v03.md) — v0.2 → v0.3 rewrite recipes
- [v03-architecture.md](v03-architecture.md) — Abstract/concrete pattern + privacy properties
- [extending-the-sdk.md](extending-the-sdk.md) — Add a custom module / new circuit
- [recovery.md](recovery.md) — Cross-device state reconstruction from snapshot events
