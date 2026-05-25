# Installing @openjanus/sdk

## Package manager

```bash
# npm
npm install @openjanus/sdk

# pnpm
pnpm add @openjanus/sdk

# yarn
yarn add @openjanus/sdk
```

## Peer dependencies

All required dependencies are bundled (ethers, @onflow/fcl, circomlibjs, snarkjs). You do not need to install them separately unless you are doing advanced version pinning.

If you need a specific ethers version:

```bash
npm install @openjanus/sdk ethers@^6
```

## Node version

Requires Node.js 18 or later. The SDK uses ES modules (`"type": "module"` in package.json), so your project must support ESM.

For CommonJS projects (webpack, Next.js pages router), import via the CJS bundle:

```typescript
// This works — the exports map handles CJS automatically
const { JanusToken } = require("@openjanus/sdk");
```

## Module exports map

`@openjanus/sdk` exposes fine-grained entry points:

| Import | Contents |
|--------|----------|
| `@openjanus/sdk` | Everything — default entry point |
| `@openjanus/sdk/tokens` | `JanusToken`, `JanusFlow`, `JANUS_TOKEN_TESTNET` |
| `@openjanus/sdk/primitives` | `babyjub`, `pedersen`, `groth16` modules |
| `@openjanus/sdk/crypto` | `computeCommitment`, `buildTransferProof`, `generateBlinding` |
| `@openjanus/sdk/network` | `createEvmWallet`, `createEvmProvider`, `configureFCL`, COA helpers |
| `@openjanus/sdk/utils` | `applyPiBSwap`, `evmProofToUint256Array`, hex helpers |

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
import { JANUS_TOKEN_TESTNET } from "@openjanus/sdk/tokens";
import { FLOW_TESTNET_ACCESS_NODE } from "@openjanus/sdk/primitives";

console.log(JANUS_TOKEN_TESTNET.evmAddress);
// 0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A
console.log(FLOW_TESTNET_ACCESS_NODE);
// https://rest-testnet.onflow.org
```

If these print without error, your install is working.

## Next steps

- [basic-transfer.md](basic-transfer.md) — Read balances and generate your first proof
- [advanced-usage.md](advanced-usage.md) — JanusFlow wrap/transfer/unwrap
- [extending-the-sdk.md](extending-the-sdk.md) — Add a custom module
