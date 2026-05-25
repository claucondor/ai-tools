# TypeScript/Next.js SDK Integration

How to wire `@openjanus/sdk` into a Next.js (or React) application.

## Install

```bash
npm install @openjanus/sdk @onflow/fcl
```

## FCL wallet connection

```typescript
// lib/fcl-config.ts
import * as fcl from "@onflow/fcl";

fcl.config({
  "app.detail.title": "My App",
  "app.detail.icon": "/icon.png",
  "flow.network": "testnet",
  "accessNode.api": "https://rest-testnet.onflow.org",
  "discovery.wallet": "https://fcl-discovery.onflow.org/testnet/authn",
});
```

## Reading a balance (server component or API route)

```typescript
// app/api/balance/route.ts
import { JanusFlow } from "@openjanus/sdk/tokens";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const userAddress = searchParams.get("address")!;

  const sdk = new JanusFlow({ network: "testnet" });
  await sdk.configure();

  const commit = await sdk.getCommitment(userAddress);
  const isZero = commit.x === 0n && commit.y === 1n;

  return Response.json({
    hasBalance: !isZero,
    // Do not return commitment coordinates to the client unless needed
  });
}
```

Note: do not serialize `bigint` values directly — JSON does not support them. Convert with `.toString()`:

```typescript
return Response.json({
  commitX: commit.x.toString(),
  commitY: commit.y.toString(),
});
```

## Generating a proof (client-side, in a Web Worker)

Proof generation takes 10-60 seconds and is CPU-intensive. Run it in a Web Worker to keep the UI responsive:

```typescript
// workers/prove.worker.ts
import { buildTransferProof, generateBlinding } from "@openjanus/sdk/crypto";

self.onmessage = async (event) => {
  const { oldBalance, oldBlinding, transferAmount, wasmUrl, zkeyUrl } = event.data;

  const proofResult = await buildTransferProof({
    oldBalance: BigInt(oldBalance),
    oldBlinding: BigInt(oldBlinding),
    transferAmount: BigInt(transferAmount),
    transferBlinding: generateBlinding(),
    newBlinding: generateBlinding(),
    wasmPath: wasmUrl,
    zkeyPath: zkeyUrl,
  });

  self.postMessage({
    proof: proofResult.proof.map((v) => v.toString()),
    publicInputs: proofResult.publicInputs.map((v) => v.toString()),
    // Also pass newBlinding so the client can store it
  });
};
```

```typescript
// components/TipButton.tsx
const worker = new Worker(new URL("../workers/prove.worker.ts", import.meta.url));

const handleTip = async () => {
  setStatus("Generating proof...");
  worker.postMessage({ oldBalance: "100", oldBlinding: storedBlinding.toString(), ... });
  worker.onmessage = async (e) => {
    setStatus("Submitting...");
    // Submit via FCL mutation
  };
};
```

## Submitting a transaction via FCL

```typescript
import * as fcl from "@onflow/fcl";
import { TX_CONFIDENTIAL_TRANSFER } from "@openjanus/sdk/tokens";

const txId = await fcl.mutate({
  cadence: TX_CONFIDENTIAL_TRANSFER,
  args: (arg, t) => [
    arg(recipientAddress, t.Address),
    arg(publicInputs[0].toString(), t.UInt256),
    arg(publicInputs[1].toString(), t.UInt256),
    arg(publicInputs[2].toString(), t.UInt256),
    arg(publicInputs[3].toString(), t.UInt256),
    arg(publicInputs[4].toString(), t.UInt256),
    arg(publicInputs[5].toString(), t.UInt256),
    arg(proof.map(String), t.Array(t.UInt256)),
  ],
  proposer: fcl.authz,
  payer: fcl.authz,
  authorizations: [fcl.authz],
  limit: 9999,
});

await fcl.tx(txId).onceSealed();
```

## State persistence

Blinding factors and commitments must survive page refreshes. Options:

- **localStorage** — simple, but not secure (visible to other JS on the page)
- **IndexedDB with encryption** — better; encrypt the blinding with the user's wallet-derived key
- **Server-side encrypted store** — best for production; tie to user session

Never expose blinding factors to the server in plaintext.

## Next steps

- [../../../../../examples/nextjs-integration.md](../../../../../examples/nextjs-integration.md) — Full Next.js example with wallet connection
- [../../../openjanus-deploy/references/circuit-artifacts.md](../../../openjanus-deploy/references/circuit-artifacts.md) — Serving WASM/zkey from CDN
