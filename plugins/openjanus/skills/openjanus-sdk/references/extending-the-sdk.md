# Extending @openjanus/sdk

The v0.3 SDK is designed to grow additively. Adding a new module (e.g., a
HekateMixer, stealth addresses, or a new `Janus<X>` concrete token over an
ERC-20) requires no changes to existing modules.

## Module layout (v0.3)

```
src/
  types/          Shared TypeScript types (no runtime code)
  utils/          Pure utilities (hex, pi_b swap, evmProofToUint256Array)
  primitives/     Low-level crypto (BabyJub, Pedersen, Groth16)
  network/        Flow client + COA management + EVM wallet/provider helpers
  crypto/         High-level crypto operations (commitments, v0.3 proof builders)
  tokens/         JanusToken abstract base + JanusFlow concrete + Cadence helper
```

## Adding a top-level module

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

## Adding a new concrete `Janus<X>` token

`JanusToken` (in `src/tokens/janus-token.ts`) is the abstract base. To add a new
concrete confidential token (e.g. `JanusUSDC` over an ERC-20):

1. Create `src/tokens/janus-usdc.ts`.
2. Extend `JanusToken` and add token-specific methods (e.g. `wrap` that pulls
   ERC-20 via `transferFrom` instead of taking `msg.value`).
3. Re-export from `src/tokens/index.ts`.
4. Add a `JANUS_USDC_TESTNET` constant carrying the deployed EVM address,
   network, and any extra ABI fragments for the token-specific entry points.

The abstract base already provides `connect`, `connectWithSigner`,
`balanceOfCommitment`, `totalSupplyCommitment`, `totalLocked`, and
`shieldedTransfer`. Concrete tokens only need to implement `wrap` and `unwrap`
(or `mint` / `burn` for non-wrap-style tokens).

## Reusing primitives

All primitives are available as internal imports:

```typescript
// From within your module src file:
import { computeCommitment } from "../crypto/commitment";
import { buildAmountDiscloseProof } from "../crypto/amount-disclose";
import { buildShieldedTransferProof } from "../crypto/shielded-transfer";
import { proveForEVM } from "../primitives/groth16";
import { applyPiBSwap } from "../utils/pi-b-swap";
import { JanusToken } from "../tokens/janus-token";
```

## Adding a new circuit

If your module uses a different circuit:

1. Generate the `.wasm`, `.zkey`, and `verification_key.json` via `circom` + `snarkjs`.
2. Place artifacts under `circuits/<module-name>/` (parallel to `circuits/v0.3/`).
3. Add the new directory to the `files` array in `package.json` so it ships
   with the npm tarball.
4. Export the artifact paths as constants so callers can reference them
   by package path.
5. Write a `prove<YourCircuit>ForEVM` function that calls `proveForEVM` and
   applies `applyPiBSwap` before returning.

Always apply `applyPiBSwap` before submitting to any Flow EVM verifier. See
[../../../openjanus-primitives/references/pi-b-fp2-swap.md](../../../openjanus-primitives/references/pi-b-fp2-swap.md).

## Trusted-setup discipline

Do not ship a new circuit without recording the ceremony provenance in a
`CEREMONY-RECORD.json` next to the artifacts (same shape as `circuits/v0.3/`).
At minimum: the `.ptau` file hash, the `.zkey` file hash, contributor list,
and the entropy source (Flow VRF beacon block height is the OpenJanus standard).

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

Integration tests that require Flow testnet go under `tests/integration/` and
are gated by `RUN_INTEGRATION=1`.

## Contributing upstream

The `openjanus/sdk` repository accepts PRs for new modules. Open an issue first
to align on the module interface before building. New `Janus<X>` concretes must
follow the abstract-base contract documented in
[v03-architecture.md](v03-architecture.md).
