# Extending @claucondor/sdk (v0.8)

The v0.8 SDK is designed to grow additively via the adapter pattern.
Adding a new module, a new `Janus<X>` concrete token, or a new circuit
requires no changes to existing modules.

## Module layout (v0.8)

```
src/
  adapters/       JanusTokenAdapter interface + JanusFlowAdapter, JanusERC20Adapter, JanusFTAdapter
  orchestration/  orchestrateWrap, orchestrateShieldedTransfer, orchestrateUnwrap
  crypto/         ECIES, note-schema, checkpoint-schema, memokey, proof builders
  proof/          Groth16 wrappers + pi_b swap (buildAmountDiscloseProof, etc.)
  network/        EVM/Cadence clients, TOKEN_REGISTRY, contract addresses
  inbox/          ShieldedInboxClient, getCadenceInboxNotes
  checkpoint/     ShieldedCheckpointClient
  cadence/        Cadence transaction templates (atomic wrap+checkpoint, install, etc.)
  batchClaim/     BatchClaimClient, buildBatchClaimProof
  portfolio/      getPortfolioView
  safety/         safeBuild* guards, isOpSafeNow, assertCheckpointMatchesCommit
  session/        MemoKeySession, SentMemoStore
  identity/       resolveRecipient
  utils/          pi_b swap, ufix64, evm-helpers, fresh-slot
  primitives/     computeCommitment, addCommitmentsLocal, subCommitmentsLocal
  types/          shared TypeScript types
```

## Adding a top-level module

1. Create `src/<module-name>/index.ts` with your exports.
2. Add an entry to the `exports` map in `package.json`:
   ```json
   "./<module-name>": {
     "import": "./dist/<module-name>/index.js",
     "require": "./dist/<module-name>/index.cjs",
     "types": "./dist/<module-name>/index.d.ts"
   }
   ```
3. Add the directory to `tsup.config.ts` entry points.
4. Re-run `npm run build`.
5. Import via `@claucondor/sdk/<module-name>`.

## Adding a new concrete `Janus<X>` token (adapter pattern)

All adapters implement `JanusTokenAdapter` (in `src/adapters/JanusTokenAdapter.ts`).
To add a new concrete token (e.g., `JanusUSDC` over a real USDC ERC20):

### 1. Add the token to TOKEN_REGISTRY

```typescript
// src/network/contracts.ts
export const TOKEN_REGISTRY = {
  // ... existing tokens ...
  usdc: {
    variant: "erc20",
    proxy: "0xYourJanusERC20ProxyAddress",
    underlying: "0xYourUSDCTokenAddress",
    decimals: 6,
  } satisfies ERC20TokenEntry,
} as const;
```

### 2. Create the adapter

```typescript
// src/adapters/janus-usdc.ts
import { JanusERC20Adapter } from "./janus-erc20";

// If behavior matches JanusERC20 exactly, just extend it:
export class JanusUSDCAdapter extends JanusERC20Adapter {
  constructor(id: TokenId, entry: ERC20TokenEntry) {
    super(id, entry);
  }
  // Override methods only if token-specific behavior differs
}
```

### 3. Wire into buildAdapter

```typescript
// src/index.ts — buildAdapter()
function buildAdapter(id: TokenId): JanusTokenAdapter {
  const entry = TOKEN_REGISTRY[id];
  switch (entry.variant) {
    case "native": return new JanusFlowAdapter(id, entry);
    case "erc20":  return new JanusERC20Adapter(id, entry);
    // Add your variant here if you add a new variant type
    case "cadence-ft": return new JanusFTAdapter(id, entry);
  }
}
```

### 4. Add to getPortfolioView token list

When using `getPortfolioView`, pass the new token explicitly:

```typescript
await getPortfolioView(coaAddr, {
  // ...
  tokens: [
    { id: 'flow',     address: TOKEN_REGISTRY.flow.proxy,     janusTokenAddr: TOKEN_REGISTRY.flow.proxy },
    { id: 'usdc',     address: TOKEN_REGISTRY.usdc.proxy,     janusTokenAddr: TOKEN_REGISTRY.usdc.proxy },
  ],
  memoPrivkey,
});
```

## Reusing orchestration primitives

All proof-building and transaction logic lives in `src/orchestration/`. Adapters
call orchestrate functions; they do NOT build proofs themselves:

```typescript
// From within your adapter:
import { orchestrateWrap } from "../orchestration/wrap";
import { orchestrateShieldedTransfer } from "../orchestration/shielded-transfer";
import { orchestrateUnwrap } from "../orchestration/unwrap";

// From your module (external):
import { orchestrateWrap } from "@claucondor/sdk/orchestration";
```

Internal crypto imports (for building custom proofs):

```typescript
import { computeCommitment } from "../primitives/pedersen";
import { buildAmountDiscloseProof } from "../crypto/amount-disclose";
import { buildShieldedTransferProof } from "../crypto/shielded-transfer";
import { applyPiBSwap } from "../utils/pi-b-swap";
import { encryptNote, decryptNote } from "../crypto/note-schema";
import { encryptSnapshot, decryptSnapshot } from "../crypto/checkpoint-schema";
```

## Reusing ShieldedCheckpoint + ShieldedInbox in a new adapter

Any new adapter that produces state changes should update the ShieldedCheckpoint:

```typescript
import { ShieldedCheckpointClient } from "../checkpoint/ShieldedCheckpointClient";
import { encryptSnapshot } from "../crypto/checkpoint-schema";

// After successful wrap/transfer:
const cp = new ShieldedCheckpointClient();
await cp.update(tokenProxyAddr, checkpointPayload, lastConsumedNoteIndex, signer);
```

For reading inbox notes:

```typescript
import { ShieldedInboxClient } from "../inbox/ShieldedInboxClient";

const inbox = new ShieldedInboxClient();
const { decrypted } = await inbox.drainAndDecrypt(signer, memoPrivkey);
```

## Adding a new circuit

If your module uses a different circuit:

1. Generate `.wasm`, `.zkey`, and `verification_key.json` via `circom` + `snarkjs`.
2. Place artifacts under `circuits/<module-name>/` (parallel to existing circuit directories).
3. Add the new directory to the `files` array in `package.json`.
4. Export artifact paths as constants so callers can reference them by package path.
5. Write a proof builder function that calls `proveForEVM` and applies `applyPiBSwap`:

```typescript
import { applyPiBSwap } from "../utils/pi-b-swap";

export async function buildMyCircuitProof(inputs: MyInputs): Promise<MyProof> {
  const { proof, publicSignals } = await groth16.fullProve(
    circomInputs,
    wasmPath,
    zkeyPath,
  );
  const swapped = applyPiBSwap(proof);
  return { proof: swapped, publicInputs: publicSignals };
}
```

Always apply `applyPiBSwap` before submitting to any Flow EVM verifier. Without it,
`verifyProof` returns `false` silently.

## Trusted-setup discipline

Do not ship a new circuit without:
- A `CEREMONY-RECORD.json` next to the artifacts (same shape as existing circuits)
- The `.ptau` file hash, `.zkey` file hash, contributor list
- The entropy source (Flow VRF beacon block height is the OpenJanus standard)

## Unit testing your module

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

Run: `npm run test:unit`

Integration tests requiring Flow testnet: `tests/integration/` gated by `RUN_INTEGRATION=1`.

## Safety guard integration

New adapters that build proofs should integrate the safety guards:

```typescript
import { assertCheckpointMatchesCommit } from "../safety/assertCheckpointMatchesCommit";

// In your wrap/send/unwrap method:
await assertCheckpointMatchesCommit({
  janusTokenAddr,
  owner: signerAddr,
  checkpointAddr: SHIELDED_CHECKPOINT_ADDRESS,
  memoPrivkey,
  rpc: FLOW_EVM_RPC,
});
// Throws CheckpointDivergenceError if checkpoint doesn't match on-chain commitment
// After throwing, the caller should re-read portfolio and not build the proof
```

## See also

- [v03-architecture.md](v03-architecture.md) — Full v0.8.x module map + protocol flow
- [quickstart.md](quickstart.md) — SDK usage from an app perspective
- `../openjanus-tokens/references/janus-token.md` — JanusToken Solidity abstract base
