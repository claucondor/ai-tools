# Installing @claucondor/sdk

## Package manager

```bash
# npm
npm install @claucondor/sdk@^0.6.5

# pnpm
pnpm add @claucondor/sdk@^0.6.5

# yarn
yarn add @claucondor/sdk@^0.6.5
```

v0.6.5 is the current production release. It introduces the generic `sdk.token(id)` adapter
API (one interface for all 4 tokens), the shared `MemoKeyRegistry`, and updated contract
addresses (v0.6.4 contracts).

Highlights:

- Generic adapter API: `sdk.token('flow' | 'wflow' | 'mockusdc' | 'mockft')`
- MemoKeyRegistry — single immutable contract; one `publishMemoKey` covers all tokens
- JanusWFLOW (Wrapped FLOW ERC20) — new adapter in v0.6.x
- Fully shielded Pedersen-commit confidential token for all 4 tokens
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
| `@claucondor/sdk` | Everything — default entry point, includes `OpenJanusSDK` class and `sdk.token(id)` |
| `@claucondor/sdk/tokens` | `JanusToken`, `JanusFlow`, `JanusFlowCadence`, `JANUS_FLOW_TESTNET`, all v0.6.4 addresses, `TX_*` / `SCRIPT_*` Cadence templates |
| `@claucondor/sdk/primitives` | `babyjub`, `pedersen`, `groth16` modules (low-level) |
| `@claucondor/sdk/crypto` | `computeCommitment`, `addCommitments`, `buildAmountDiscloseProof`, `buildShieldedTransferProof`, `generateBlinding`, `randomBabyJubScalar`, `flowToWei`, `weiToFlow`, `FLOW_SCALE`, `assertWholeFlow`, `decryptBalance`, `deriveMemoKeyFromSignature` |
| `@claucondor/sdk/network` | `createEvmWallet`, `createEvmProvider`, `configureFCL`, COA helpers |
| `@claucondor/sdk/utils` | `applyPiBSwap`, `evmProofToUint256Array`, hex helpers |
| `@claucondor/sdk/recovery` | `scanJanusFlowSnapshots`, `decryptSnapshot`, `reconstructFromSnapshots`, `readJanusFlowCommitment`, `encryptSnapshotToSelf` |

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
} from "@claucondor/sdk/tokens";

console.log(JANUS_FLOW_EVM_ADDRESS);
// 0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156

import { OpenJanusSDK } from "@claucondor/sdk";
const sdk = new OpenJanusSDK({ network: "testnet" });
const flow = sdk.token('flow');
console.log(flow.address);
// 0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156
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

- [quickstart.md](quickstart.md) — Full v0.6.5 workflow walk-through (4 tokens, generic adapter API)
- [migration-v02-to-v03.md](migration-v02-to-v03.md) — v0.2 → v0.3 rewrite recipes (historical)
- [v03-architecture.md](v03-architecture.md) — Abstract/concrete pattern + privacy properties
- [extending-the-sdk.md](extending-the-sdk.md) — Add a custom module / new circuit
- [recovery.md](recovery.md) — Cross-device state reconstruction from snapshot events
