# TypeScript/Next.js SDK Integration (v0.8)

How to wire `@claucondor/sdk@^0.8` into a Next.js (App Router) or React application.

## Install

```bash
# npm
npm install @claucondor/sdk ethers @onflow/fcl

# tarball (private-tip-v1 pattern)
# package.json: "@claucondor/sdk": "file:claucondor-sdk-0.8.1-alpha.7.tgz"
npm install
```

---

## FCL configuration

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

// Or via SDK helper:
import { configureFCL } from "@claucondor/sdk/network";
configureFCL("testnet");
```

---

## Reading the shielded portfolio (server component or API route)

```typescript
// app/api/portfolio/route.ts
import { getPortfolioView, TOKEN_REGISTRY, SHIELDED_CHECKPOINT_ADDRESS, SHIELDED_INBOX_ADDRESS } from "@claucondor/sdk";
import { bigintReplacer } from "@claucondor/sdk";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const coaAddr       = searchParams.get("coa")!;
  const cadenceAddr   = searchParams.get("cadence") ?? undefined;
  const memoPrivkey   = BigInt(searchParams.get("privkey")!); // pass securely

  const portfolio = await getPortfolioView(coaAddr, {
    rpc: "https://testnet.evm.nodes.onflow.org",
    checkpointAddr: SHIELDED_CHECKPOINT_ADDRESS,
    inboxAddr:      SHIELDED_INBOX_ADDRESS,
    tokens: [
      { id: "flow",     address: TOKEN_REGISTRY.flow.proxy,     janusTokenAddr: TOKEN_REGISTRY.flow.proxy },
      { id: "mockusdc", address: TOKEN_REGISTRY.mockusdc.proxy, janusTokenAddr: TOKEN_REGISTRY.mockusdc.proxy },
    ],
    memoPrivkey,
    cadenceAddress: cadenceAddr,
  });

  // bigintReplacer converts bigint fields to strings for JSON
  return Response.json(portfolio, { replacer: bigintReplacer });
}
```

---

## MemoKey derivation in a React client component

```typescript
// components/WalletConnect.tsx
"use client";
import { useState } from "react";
import { ethers } from "ethers";
import { deriveMemoKeyFromSignature, MemoKeySession } from "@claucondor/sdk";

export function WalletConnect() {
  const [keypair, setKeypair] = useState<{ privkey: bigint } | null>(null);

  const handleConnect = async () => {
    // Try session cache first (avoids wallet popup on every navigation)
    const cached = MemoKeySession.get();
    if (cached) {
      setKeypair({ privkey: cached });
      return;
    }

    // Derive from wallet signature
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer   = await provider.getSigner();
    const sig      = await signer.signMessage("OpenJanus MemoKey v1");
    const kp       = await deriveMemoKeyFromSignature(ethers.getBytes(sig));
    MemoKeySession.set(kp.privkey);
    setKeypair({ privkey: kp.privkey });
  };

  return <button onClick={handleConnect}>Connect Wallet</button>;
}
```

---

## Generating a proof (client-side, in a Web Worker)

Proof generation takes 10-60 seconds and is CPU-intensive. Run it in a Web Worker
to keep the UI responsive:

```typescript
// workers/prove-transfer.worker.ts
import { buildShieldedTransferProof } from "@claucondor/sdk/crypto";

self.onmessage = async (event) => {
  const {
    oldBalance,
    oldBlinding,
    transferAmount,
    transferBlinding,
    newBlinding,
  } = event.data;

  const result = await buildShieldedTransferProof({
    oldBalance:       BigInt(oldBalance),
    oldBlinding:      BigInt(oldBlinding),
    transferAmount:   BigInt(transferAmount),
    transferBlinding: BigInt(transferBlinding),
    newBlinding:      BigInt(newBlinding),
    // wasmPath / zkeyPath optional — resolved from bundled circuits by default
  });

  self.postMessage({
    proof:        result.proof.map(String),
    publicInputs: result.publicInputs.map(String),
  });
};
```

```typescript
// components/TransferButton.tsx
"use client";
const worker = new Worker(
  new URL("../workers/prove-transfer.worker.ts", import.meta.url)
);

const handleTransfer = async () => {
  setStatus("Generating proof...");
  worker.postMessage({
    oldBalance:       currentBalance.toString(),
    oldBlinding:      currentBlinding.toString(),
    transferAmount:   transferAmt.toString(),
    transferBlinding: transferBlinding.toString(),
    newBlinding:      newBlinding.toString(),
  });
  worker.onmessage = async (e) => {
    setStatus("Submitting transaction...");
    // Submit via adapter (handles FCL or ethers internally)
    const { txHash, checkpointPayload } = await sdk.token("flow").shieldedTransfer({
      recipient,
      amount: transferAmt,
      memo,
      currentBalance,
      currentBlinding,
    }, ethers.signer);
    await persistCheckpoint(checkpointPayload);
    setStatus("Done!");
  };
};
```

---

## Atomic wrap + checkpoint (Next.js server action)

```typescript
// app/actions/wrap.ts
"use server";
import { cadenceTx, TOKEN_REGISTRY, buildAmountDiscloseProof, generateBlinding, encryptSnapshot, deriveMemoKeyFromSignature } from "@claucondor/sdk";

export async function wrapAction(amountUFix64: string, memoPrivkeyStr: string) {
  // Build proof
  const blinding = await generateBlinding();
  const grossAmount = parseUFix64ToWei(amountUFix64);
  const proof = await buildAmountDiscloseProof({ amount: grossAmount, blinding });

  // Encrypt snapshot
  const memoPrivkey = BigInt(memoPrivkeyStr);
  const { encryptedSnapshot, ephPubkeyX, ephPubkeyY } = await encryptSnapshot(
    { balance: netAmount(grossAmount), blinding },
    derivedPubkey // from published MemoKeyRegistry
  );

  // Return Cadence tx template + args to frontend for FCL signing
  return {
    cadence: cadenceTx.wrapFlowAtomic(TOKEN_REGISTRY.flow.proxy),
    args: [amountUFix64, proof.txCommit.x.toString(), /* ... */],
  };
}
```

---

## Batch claim in a Next.js API route

```typescript
// app/api/batch-claim/route.ts
import { BatchClaimClient, TOKEN_REGISTRY, generateBlinding } from "@claucondor/sdk";
import { ethers } from "ethers";

export async function POST(req: Request) {
  const { pendingNotes, oldBalance, oldBlinding, signerKey } = await req.json();

  const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
  const wallet   = new ethers.Wallet(signerKey, provider);
  const client   = new BatchClaimClient(wallet, TOKEN_REGISTRY.flow.proxy);

  const newBlinding = await generateBlinding();
  const { tx, newBalance, newCommit } = await client.buildAndClaim({
    oldBalance:     BigInt(oldBalance),
    oldBlinding:    BigInt(oldBlinding),
    newBlinding,
    notesToConsume: pendingNotes.map((n: { amount: string; blinding: string }) => ({
      amount:  BigInt(n.amount),
      blinding: BigInt(n.blinding),
    })),
  });

  return Response.json({
    txHash:     tx.hash,
    newBalance: newBalance.toString(),
    newCommit:  { x: newCommit.x.toString(), y: newCommit.y.toString() },
    newBlinding: newBlinding.toString(),
  });
}
```

---

## Submitting via FCL (Cadence path)

```typescript
import * as fcl from "@onflow/fcl";
import { cadenceTx, TOKEN_REGISTRY } from "@claucondor/sdk";

const txTemplate = cadenceTx.combinedShieldedTransferWithCheckpoint(TOKEN_REGISTRY.flow.proxy);

const txId = await fcl.mutate({
  cadence: txTemplate,
  args: (arg, t) => [
    arg(recipientEvmAddress, t.String),
    arg(publicInputs.map(String), t.Array(t.UInt256)),
    arg(proof.map(String), t.Array(t.UInt256)),
    arg(recipientCiphertextHex, t.String),
    arg(recipientEphX.toString(), t.UInt256),
    arg(recipientEphY.toString(), t.UInt256),
    // checkpoint args:
    arg(senderCiphertextHex, t.String),
    arg(senderEphX.toString(), t.UInt256),
    arg(senderEphY.toString(), t.UInt256),
    arg(lastConsumedNoteIndex.toString(), t.UInt64),
  ],
  proposer: fcl.authz,
  payer: fcl.authz,
  authorizations: [fcl.authz],
  limit: 9999,
});

await fcl.tx(txId).onceSealed();
```

---

## State persistence — v0.8 contract

v0.8 uses `ShieldedCheckpoint` as the canonical on-chain state store.
App responsibilities:

1. After every `wrap`, `shieldedTransfer`, `claimBatch`: call `ShieldedCheckpointClient.update()`.
2. On session start: call `ShieldedCheckpointClient.readAndDecrypt()` to restore state.
3. On session end (logout): call `MemoKeySession.clear()`.
4. Cache only the `memoPrivkey` in sessionStorage — never checkpoint blinding to localStorage.

```typescript
// Client-side state contract
import { MemoKeySession } from "@claucondor/sdk/session";

// Login: derive + cache
MemoKeySession.set(keypair.privkey);

// Each operation: update checkpoint on-chain (ShieldedCheckpointClient.update)

// Logout: clear cached privkey
MemoKeySession.clear();
```

---

## SentMemoStore — sender-side mirror

Track memos you've sent (for your own records — the chain doesn't store them):

```typescript
import { SentMemoStore, saveSentMemo, findSentMemo } from "@claucondor/sdk/session";

// After sending a shielded transfer:
saveSentMemo({
  txHash,
  recipient,
  amount: transferAmount.toString(),
  memo: "payment",
  timestamp: Date.now(),
});

// Find a sent memo by tx hash:
const sent = findSentMemo(txHash);
```

---

## Next steps

- [quickstart.md](quickstart.md) — Full v0.8 workflow
- [decrypt-flow.md](decrypt-flow.md) — Note and snapshot decryption
- [recovery.md](recovery.md) — Cross-device state recovery
- [migration-to-v08.md](migration-to-v08.md) — v0.7 → v0.8 migration recipes
