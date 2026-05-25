# Extending @openjanus/sdk

The SDK is designed to grow additively. Adding a new module (e.g., HekateMixer, stealth addresses) requires no changes to existing modules.

## Adding a module

1. Create `src/<module-name>/index.ts` with your exports.
2. Add an entry to the `exports` map in `package.json`:
   ```json
   "./mixer": {
     "import": "./dist/mixer/index.js",
     "require": "./dist/mixer/index.cjs",
     "types": "./dist/mixer/index.d.ts"
   }
   ```
3. Add the directory to `tsup.config.ts` entry points.
4. Re-run `npm run build`.
5. Import via `@openjanus/sdk/mixer`.

## Reusing primitives

All primitives are available as internal imports:

```typescript
// From within your module src file:
import { computeCommitment } from "../primitives/pedersen";
import { proveForEVM } from "../primitives/groth16";
import { applyPiBSwap } from "../utils/pi-b-swap";
import { NETWORK_CONFIG } from "../network/flow-client";
```

## Adding a new circuit

If your module uses a different circuit:

1. Generate the `.wasm`, `.zkey`, and `verification_key.json` via `circom` + `snarkjs`.
2. Place artifacts alongside the circuit source (not in `dist/`).
3. Export the artifact paths as constants so callers can reference them by package path.
4. Write a `prove<YourCircuit>ForEVM` function that calls `proveForEVM` and applies `applyPiBSwap`.

Always apply `applyPiBSwap` before submitting to any Flow EVM verifier. See [../../../openjanus-primitives/references/pi-b-fp2-swap.md](../../../openjanus-primitives/references/pi-b-fp2-swap.md).

## Unit testing your module

The SDK uses `vitest`. Add your tests under `tests/unit/<module-name>/`:

```typescript
import { describe, it, expect } from "vitest";
import { myFunction } from "../../src/my-module/index";

describe("my-module", () => {
  it("does the thing", async () => {
    const result = await myFunction(42n, 0n);
    expect(result).toBeDefined();
  });
});
```

Run with: `npm run test:unit`

Integration tests that require Flow testnet go under `tests/integration/` and are gated by `RUN_INTEGRATION=1`.

## Contributing upstream

The `openjanus/sdk` repository accepts PRs for new modules. Open an issue first to align on the module interface before building.
