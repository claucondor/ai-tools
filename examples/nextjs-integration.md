# Next.js Integration Example (v0.8.2)

A complete example of integrating OpenJanus into a Next.js 14 (App Router) application
using `@claucondor/sdk@^0.8.2`.

## Project setup

```bash
npx create-next-app@latest my-privacy-app --typescript --tailwind --app
cd my-privacy-app

# Install from tarball (current pattern until npm publish)
cp /path/to/claucondor-sdk-0.8.2.tgz .
npm install file:claucondor-sdk-0.8.2.tgz @onflow/fcl
```

## FCL configuration

```typescript
// lib/fcl-config.ts
"use client";
import * as fcl from "@onflow/fcl";

export function configureFCL() {
  fcl.config({
    "app.detail.title": "My Privacy App",
    "app.detail.icon": "https://my-app.com/icon.png",
    "flow.network": "testnet",
    "accessNode.api": "https://rest-testnet.onflow.org",
    "discovery.wallet": "https://fcl-discovery.onflow.org/testnet/authn",
  });
}
```

## Reading a commitment (Server Action)

```typescript
// app/actions/getBalance.ts
"use server";
import { sdk, isFreshSlotCommit } from "@claucondor/sdk";

export async function getBalance(evmAddress: string) {
  const flow = sdk.token('flow');
  const commit = await flow.getCommitment(evmAddress);
  const hasBalance = !isFreshSlotCommit(commit);

  return {
    hasBalance,
    // Convert bigint for JSON serialization
    commitX: commit.x.toString(),
    commitY: commit.y.toString(),
  };
}
```

## Portfolio view — multi-token drift detection

```typescript
// app/actions/getPortfolio.ts
"use server";
import { getPortfolioView, ShieldedCheckpointClient } from "@claucondor/sdk";
import { ethers } from "ethers";

export async function getPortfolio(walletAddress: string, memoPrivkey: bigint) {
  const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
  const wallet = new ethers.Wallet(process.env.DUMMY_KEY!, provider);

  // Returns per-token view: on-chain commitment vs checkpoint balance
  const portfolio = await getPortfolioView({
    evmAddress: walletAddress,
    memoPrivkey,
    signer: wallet,
  });

  // portfolio.tokens: TokenPortfolioView[] — each has tokenId, hasBalance, driftDetected
  return portfolio.tokens.map(t => ({
    tokenId:       t.tokenId,
    hasBalance:    t.hasBalance,
    driftDetected: t.driftDetected, // true if checkpoint out of sync with on-chain
    commitX:       t.commitment.x.toString(),
    commitY:       t.commitment.y.toString(),
  }));
}
```

## Proof generation Web Worker

```typescript
// workers/prove.ts (bundled by Next.js)
import {
  buildShieldedTransferProof,
  generateBlinding,
} from "@claucondor/sdk";

self.onmessage = async (event: MessageEvent) => {
  const { currentBalance, currentBlinding, transferAmount } = event.data;

  try {
    const proofResult = await buildShieldedTransferProof({
      oldAmount:        BigInt(currentBalance),
      oldBlinding:      BigInt(currentBlinding),
      transferAmount:   BigInt(transferAmount),
      transferBlinding: generateBlinding(),
      newBlinding:      generateBlinding(),
      wasmPath: "/circuits/confidentialTransfer.wasm",
      zkeyPath: "/circuits/confidentialTransfer_final.zkey",
    });

    self.postMessage({
      ok: true,
      proof:           proofResult.proof.map(String),
      publicInputs:    proofResult.publicInputs.map(String),
      newBalance:      proofResult.newSenderAmount.toString(),
      newBlinding:     proofResult.newSenderBlinding.toString(),
      newCommitX:      proofResult.newSenderCommit.x.toString(),
      newCommitY:      proofResult.newSenderCommit.y.toString(),
    });
  } catch (err) {
    self.postMessage({ ok: false, error: String(err) });
  }
};
```

## Tip button component

```typescript
// components/TipButton.tsx
"use client";
import { useState } from "react";
import * as fcl from "@onflow/fcl";
import { sdk, ShieldedCheckpointClient, isFreshSlotCommit } from "@claucondor/sdk";

interface TipButtonProps {
  recipient:          string; // EVM or Cadence address (SDK resolves)
  storedOldBalance:   string;
  storedOldBlinding:  string;
  memoPrivkey:        bigint;
  onSuccess: (newBalance: string, newBlinding: string) => void;
}

export function TipButton({
  recipient,
  storedOldBalance,
  storedOldBlinding,
  memoPrivkey,
  onSuccess,
}: TipButtonProps) {
  const [status, setStatus] = useState<"idle" | "proving" | "submitting" | "done">("idle");

  const handleTip = async () => {
    setStatus("proving");

    const worker = new Worker(new URL("../workers/prove.ts", import.meta.url));

    worker.postMessage({
      currentBalance:  storedOldBalance,
      currentBlinding: storedOldBlinding,
      transferAmount:  (5n * 10n**18n).toString(), // 5 FLOW
    });

    worker.onmessage = async (e) => {
      if (!e.data.ok) {
        console.error("Proof failed:", e.data.error);
        setStatus("idle");
        return;
      }

      const { newBalance, newBlinding } = e.data;
      setStatus("submitting");

      try {
        // Use sdk.token adapter for the full orchestration
        // (proof + encrypt + tx in one call)
        const { ethers } = await import("ethers");
        const provider = new ethers.BrowserProvider(window.ethereum);
        const signer = await provider.getSigner();

        const flow = sdk.token('flow');
        const sendResult = await flow.shieldedTransfer({
          recipient,
          amount:          5n * 10n**18n,
          memo:            'tip',
          currentBalance:  BigInt(storedOldBalance),
          currentBlinding: BigInt(storedOldBlinding),
        }, signer as any);

        // Update sender checkpoint
        const checkpoint = new ShieldedCheckpointClient();
        await checkpoint.update(flow.address, sendResult.checkpointPayload!, 0n, signer as any);

        setStatus("done");
        onSuccess(sendResult.newBalance!.toString(), sendResult.newBlinding!.toString());
      } catch (err) {
        console.error("Transaction failed:", err);
        setStatus("idle");
      }
    };
  };

  return (
    <button onClick={handleTip} disabled={status !== "idle"}>
      {status === "idle"       && "Send Tip (5 FLOW, private)"}
      {status === "proving"    && "Generating proof..."}
      {status === "submitting" && "Submitting..."}
      {status === "done"       && "Tip sent!"}
    </button>
  );
}
```

## BatchClaim CTA — consolidate incoming notes

When a recipient has unread inbox notes, show a "Claim All" button to consolidate them in one ZK proof.

```typescript
// components/ClaimInboxButton.tsx
"use client";
import { useState } from "react";
import { ShieldedInboxClient, BatchClaimClient, sdk } from "@claucondor/sdk";

interface ClaimInboxButtonProps {
  memoPrivkey: bigint;
  onClaimed:   (noteCount: number) => void;
}

export function ClaimInboxButton({ memoPrivkey, onClaimed }: ClaimInboxButtonProps) {
  const [status, setStatus] = useState<"idle" | "draining" | "claiming" | "done">("idle");
  const [noteCount, setNoteCount] = useState(0);

  const handleClaim = async () => {
    setStatus("draining");

    const { ethers } = await import("ethers");
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();

    const inbox = new ShieldedInboxClient();
    const { notes } = await inbox.drain(signer as any);
    setNoteCount(notes.length);

    if (notes.length === 0) {
      setStatus("idle");
      return;
    }

    setStatus("claiming");
    const flow = sdk.token('flow');
    const batchClaim = new BatchClaimClient(flow);

    // Reconstruct memoKeypair from stored privkey (pubkey derived on-chain lookup)
    const memoKeypair = { privkey: memoPrivkey, pubkey: { x: 0n, y: 0n } }; // SDK resolves pubkey

    const result = await batchClaim.buildAndClaim(notes, memoKeypair, signer as any);
    setStatus("done");
    onClaimed(result.notesClaimed);
  };

  return (
    <button onClick={handleClaim} disabled={status !== "idle"}>
      {status === "idle"      && `Claim Inbox${noteCount > 0 ? ` (${noteCount} notes)` : ""}`}
      {status === "draining"  && "Checking inbox..."}
      {status === "claiming"  && "Generating batch proof..."}
      {status === "done"      && "Claimed!"}
    </button>
  );
}
```

## Serving circuit artifacts

Place files in `public/circuits/`:

```
public/
└── circuits/
    ├── confidentialTransfer.wasm        (~1-2 MB)
    ├── confidentialTransfer_final.zkey  (~20-40 MB)
    ├── batchClaim_n10.wasm              (~2-3 MB)
    └── batchClaim_n10_final.zkey        (~40-80 MB, pot22)
```

Add to `next.config.js` to prevent webpack from bundling them:

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  webpack: (config) => {
    config.externals = [...(config.externals || []), { snarkjs: "snarkjs" }];
    return config;
  },
};
module.exports = nextConfig;
```

## State management

Use a simple store for commitment state:

```typescript
// lib/commitment-store.ts
interface CommitmentState {
  balance:  string; // plaintext amount as string (bigint)
  blinding: string; // 128-bit random as string (bigint)
  commitX:  string;
  commitY:  string;
}

const KEY = "openjanus_commitment_v082";

export function saveCommitment(state: CommitmentState) {
  // In production: encrypt with a wallet-derived key before storing
  localStorage.setItem(KEY, JSON.stringify(state));
}

export function loadCommitment(): CommitmentState | null {
  const raw = localStorage.getItem(KEY);
  return raw ? JSON.parse(raw) : null;
}
```

**Warning**: `localStorage` is not secure against XSS. In production, encrypt blinding factors
with a key derived from the user's wallet signature. The SDK's `MemoKeySession` (sessionStorage)
provides a scoped BabyJub privkey cache — use it to minimize key exposure.

## Push-model warning

v0.8 shieldedTransfer is push-model: it writes the receiver's commitment slot on-chain directly.
Implement 3-layer defense in your UI:

1. **Before proof build**: call `assertCheckpointMatchesCommit` — throws if local state is stale
2. **Before submit**: call `isOpSafeNow` — returns soft safety result without throwing
3. **After tx sealed**: call `checkpoint.update()` — persist new sender state to ShieldedCheckpoint

Skipping step 3 will cause divergence on the next operation.

## Next steps

- [../plugins/openjanus/skills/openjanus-sdk/references/inbox.md](../plugins/openjanus/skills/openjanus-sdk/references/inbox.md) — ShieldedInbox drain patterns
- [../plugins/openjanus/skills/openjanus-sdk/references/checkpoint.md](../plugins/openjanus/skills/openjanus-sdk/references/checkpoint.md) — ShieldedCheckpoint sender state
- [../plugins/openjanus/skills/openjanus-sdk/references/batch-claim.md](../plugins/openjanus/skills/openjanus-sdk/references/batch-claim.md) — batchClaim N=10 details
- [../plugins/openjanus/skills/openjanus-sdk/references/ts-sdk-integration.md](../plugins/openjanus/skills/openjanus-sdk/references/ts-sdk-integration.md) — detailed integration patterns
