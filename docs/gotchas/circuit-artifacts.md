# Circuit Artifacts — WASM, zkey, and vkey Locations

## What are circuit artifacts?

The ConfidentialTransfer circuit produces three artifact files at setup time:

| File | Purpose | Size |
|------|---------|------|
| `confidentialTransfer.wasm` | WebAssembly witness calculator | ~1-2 MB |
| `confidentialTransfer_final.zkey` | Proving key (Groth16 trusted setup) | ~20-40 MB |
| `verification_key.json` | Verification key (for local and on-chain verification) | ~2-4 KB |

## Where they live in the monorepo

```
cadence-crypto-lab/
└── modules/
    └── zk/
        └── confidential-transfer-circuit/
            ├── circuit/
            │   └── confidentialTransfer.wasm
            └── setup/
                ├── confidentialTransfer_final.zkey
                └── verification_key.json
```

If you are working within the `cadence-crypto-lab` repository, use these paths:

```typescript
const WASM_PATH = "/absolute/path/to/cadence-crypto-lab/modules/zk/confidential-transfer-circuit/circuit/confidentialTransfer.wasm";
const ZKEY_PATH = "/absolute/path/to/cadence-crypto-lab/modules/zk/confidential-transfer-circuit/setup/confidentialTransfer_final.zkey";
const VK_PATH   = "/absolute/path/to/cadence-crypto-lab/modules/zk/confidential-transfer-circuit/setup/verification_key.json";
```

## Serving artifacts in a browser app

The `.wasm` and `.zkey` files must be accessible via HTTP in browser environments. Recommended approach:

1. Place them in `public/circuits/` in your Next.js project.
2. Reference them by URL:

```typescript
const WASM_PATH = "/circuits/confidentialTransfer.wasm";
const ZKEY_PATH = "/circuits/confidentialTransfer_final.zkey";
```

**Do not bundle them with webpack** — the zkey file is too large (20-40 MB). Serve from `public/` so they are fetched separately and cached by the browser.

## CDN hosting

For production apps, host the artifacts on a CDN:

```typescript
const CDN = "https://artifacts.yourdomain.com/circuits/v1";
const WASM_PATH = `${CDN}/confidentialTransfer.wasm`;
const ZKEY_PATH = `${CDN}/confidentialTransfer_final.zkey`;
```

Cache with a long TTL (e.g., 1 year) — artifacts never change for a given circuit version. If you regenerate the circuit (new trusted setup), bump the version path.

## Verifying artifact integrity

The zkey file corresponds to a specific trusted setup ceremony. Do not mix zkeys between different circuit versions or different ceremonies. If `proveForEVM` produces proofs that fail `verifyOnChain`, the most common cause (after the pi_b swap) is a zkey/WASM mismatch.

## Common Pitfalls

**Relative paths in Node.js tests.** snarkJS resolves paths relative to the current working directory. Use `path.resolve(__dirname, "../../...")` in test files to get absolute paths.

**Missing `.wasm` in `public/` directory.** Next.js only serves files in `public/`. Moving the WASM to a different location will cause `fetch` to return 404.

**Large zkey causes build timeouts.** Never import the zkey as a module — always use a URL/path string.
