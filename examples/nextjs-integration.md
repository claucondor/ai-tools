# Next.js Integration Example

A complete example of integrating OpenJanus into a Next.js 14 (App Router) application.

## Project setup

```bash
npx create-next-app@latest my-privacy-app --typescript --tailwind --app
cd my-privacy-app
npm install @openjanus/sdk @onflow/fcl
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
import { JanusFlow } from "@openjanus/sdk/tokens";

export async function getBalance(cadenceAddress: string) {
  const sdk = new JanusFlow({ network: "testnet" });
  await sdk.configure();

  const commit = await sdk.getCommitment(cadenceAddress);
  const hasBalance = !(commit.x === 0n && commit.y === 1n);

  return {
    hasBalance,
    // Convert bigint for JSON serialization
    commitX: commit.x.toString(),
    commitY: commit.y.toString(),
  };
}
```

## Proof generation Web Worker

```typescript
// public/workers/prove.worker.js
// Note: must be in /public to be served correctly; use importScripts for modules
importScripts("https://cdn.jsdelivr.net/npm/snarkjs@0.7.6/build/snarkjs.min.js");

self.onmessage = async (event) => {
  const { oldBalance, oldBlinding, transferAmount, wasmUrl, zkeyUrl } = event.data;

  // Use snarkjs directly in worker
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    {
      old_value: oldBalance,
      old_blinding: oldBlinding,
      transfer_value: transferAmount,
      // ...other inputs
    },
    wasmUrl,
    zkeyUrl
  );

  self.postMessage({ proof, publicSignals });
};
```

For ESM workers with the full SDK, use a bundler-aware approach:

```typescript
// workers/prove.ts (bundled by Next.js)
import { buildTransferProof, generateBlinding } from "@openjanus/sdk/crypto";

self.onmessage = async (event: MessageEvent) => {
  const { oldBalance, oldBlinding, transferAmount } = event.data;

  try {
    const proofResult = await buildTransferProof({
      oldBalance: BigInt(oldBalance),
      oldBlinding: BigInt(oldBlinding),
      transferAmount: BigInt(transferAmount),
      transferBlinding: generateBlinding(),
      newBlinding: generateBlinding(),
      wasmPath: "/circuits/confidentialTransfer.wasm",
      zkeyPath: "/circuits/confidentialTransfer_final.zkey",
    });

    self.postMessage({
      ok: true,
      proof: proofResult.proof.map(String),
      publicInputs: proofResult.publicInputs.map(String),
      newCommitX: proofResult.commitments.newCommit.x.toString(),
      newCommitY: proofResult.commitments.newCommit.y.toString(),
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
import { TX_CONFIDENTIAL_TRANSFER } from "@openjanus/sdk/tokens";

interface TipButtonProps {
  recipient: string; // Cadence address
  storedOldBalance: string;
  storedOldBlinding: string;
  onSuccess: (newBlinding: string, newCommitX: string, newCommitY: string) => void;
}

export function TipButton({ recipient, storedOldBalance, storedOldBlinding, onSuccess }: TipButtonProps) {
  const [status, setStatus] = useState<"idle" | "proving" | "submitting" | "done">("idle");

  const handleTip = async () => {
    setStatus("proving");

    const worker = new Worker(new URL("../workers/prove.ts", import.meta.url));

    worker.postMessage({
      oldBalance: storedOldBalance,
      oldBlinding: storedOldBlinding,
      transferAmount: "5", // fixed tip amount for demo
    });

    worker.onmessage = async (e) => {
      if (!e.data.ok) {
        console.error("Proof failed:", e.data.error);
        setStatus("idle");
        return;
      }

      const { proof, publicInputs, newCommitX, newCommitY } = e.data;
      // newBlinding is not returned here — the worker should also send it
      // or derive it deterministically from a key

      setStatus("submitting");
      try {
        const txId = await fcl.mutate({
          cadence: TX_CONFIDENTIAL_TRANSFER,
          args: (arg, t) => [
            arg(recipient, t.Address),
            arg(publicInputs[0], t.UInt256),
            arg(publicInputs[1], t.UInt256),
            arg(publicInputs[2], t.UInt256),
            arg(publicInputs[3], t.UInt256),
            arg(publicInputs[4], t.UInt256),
            arg(publicInputs[5], t.UInt256),
            arg(proof, t.Array(t.UInt256)),
          ],
          proposer: fcl.authz,
          payer: fcl.authz,
          authorizations: [fcl.authz],
          limit: 9999,
        });

        await fcl.tx(txId).onceSealed();
        setStatus("done");
        onSuccess("newBlinding", newCommitX, newCommitY);
      } catch (err) {
        console.error("Transaction failed:", err);
        setStatus("idle");
      }
    };
  };

  return (
    <button onClick={handleTip} disabled={status !== "idle"}>
      {status === "idle" && "Send Tip (5 FLOW, private)"}
      {status === "proving" && "Generating proof..."}
      {status === "submitting" && "Submitting..."}
      {status === "done" && "Tip sent!"}
    </button>
  );
}
```

## Serving circuit artifacts

Place files in `public/circuits/`:

```
public/
└── circuits/
    ├── confidentialTransfer.wasm   (~1-2 MB)
    └── confidentialTransfer_final.zkey  (~20-40 MB)
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
  balance: string;       // plaintext amount as string
  blinding: string;      // 128-bit random as string
  commitX: string;
  commitY: string;
}

const KEY = "openjanus_commitment";

export function saveCommitment(state: CommitmentState) {
  // In production: encrypt with a wallet-derived key before storing
  localStorage.setItem(KEY, JSON.stringify(state));
}

export function loadCommitment(): CommitmentState | null {
  const raw = localStorage.getItem(KEY);
  return raw ? JSON.parse(raw) : null;
}
```

**Warning**: `localStorage` is not secure against XSS. In production, encrypt blinding factors with a key derived from the user's wallet signature.

## Next steps

- [../docs/gotchas/circuit-artifacts.md](../docs/gotchas/circuit-artifacts.md) — CDN hosting for large artifacts
- [../docs/patterns/ts-sdk-integration.md](../docs/patterns/ts-sdk-integration.md) — Detailed integration patterns
