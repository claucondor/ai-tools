# Cursor Rules Template — Projects Building on the Janus Privacy Stack (v0.3)

Copy this file into your project root as `.cursorrules` and customize the
bracketed sections.

---

```
You are an expert TypeScript/Cadence developer building on the Janus v0.3
privacy stack on the Flow blockchain.

## Stack (v0.3)

- @claucondor/sdk@^0.5.4 — TypeScript SDK with abstract `JanusToken` base +
  `Janus<X>` concretes (currently `JanusFlow` for native FLOW)
- @claucondor/primitives — Pedersen commitments on BabyJubJub, blinding
  generation, proof builders (buildAmountDiscloseProof,
  buildShieldedTransferProof)
- Flow EVM — UUPS proxy hosts the JanusFlow concrete (proxy 0x09A3DCa…,
  impl 0x4F09149…, v0.5.4-fees); shielded-pool storage lives here
- Flow Cadence — JanusFlow router at 0x5dcbeb41055ec57e provides a cross-VM
  façade that forwards to the EVM proxy
- circomlibjs + snarkjs — ZK proof generation (Groth16 on BabyJubJub) for the
  two v0.3 circuits

Janus v0.3 provides FULL amount privacy on `shieldedTransfer`: amount is
hidden on msg.value, calldata, storage, events, and against commitment
bruteforce (128-bit blinding). Wrap / unwrap leak amount at the boundary BY
DESIGN so the FLOW custody pool can be audited.

## Key patterns

### Connecting to a Janus<X> concrete

```typescript
import {
  JanusFlow,
  JANUS_FLOW_EVM_TESTNET,
  JANUS_FLOW_CADENCE_TESTNET,
} from "@claucondor/sdk/tokens";

const token = new JanusFlow({
  evmAddress: JANUS_FLOW_EVM_TESTNET,
  cadenceAddress: JANUS_FLOW_CADENCE_TESTNET,
});
await token.connect();                      // read-only
// OR
await token.connectWithSigner(wallet);      // with signer
```

### JanusFlow (full v0.3 lifecycle)

```typescript
import {
  JanusFlow,
  generateBlinding,
} from "@claucondor/sdk";
import {
  buildAmountDiscloseProof,
  buildShieldedTransferProof,
} from "@claucondor/sdk/proof";

const token = new JanusFlow({ network: "testnet" });
await token.connectWithSigner(signer);

// === WRAP (boundary, amount visible by design) ===
const wrapBlinding = generateBlinding();
const wrapProof = await buildAmountDiscloseProof({
  amount:    amountWei,
  blinding:  wrapBlinding,
});
await token.wrap({
  amountWei,
  txCommit:    wrapProof.commit,
  amountProof: wrapProof.proof,
});
// Persist (amountWei, wrapBlinding) — this is the decryption key locally.

// === SHIELDED TRANSFER (fully hidden) ===
const transferBlinding = generateBlinding();
const newBlinding      = generateBlinding();
const xferProof = await buildShieldedTransferProof({
  oldAmount,       oldBlinding,
  transferAmount,  transferBlinding,
  newBlinding,
});
await token.shieldedTransfer({
  to:           recipientAddr,
  publicInputs: xferProof.publicInputs,
  proof:        xferProof.proof,
});
// Deliver (transferAmount, transferBlinding) to recipient OUT-OF-BAND.

// === UNWRAP (boundary, amount visible by design) ===
await token.unwrap({
  claimedAmountWei,
  recipient,
  txCommit,            // commitment for the slice being released
  amountProof,         // AmountDiscloseVerifier proof
  transferPublicInputs,
  transferProof,       // ConfidentialTransferVerifier proof
});
```

## Non-negotiable rules (v0.3)

1. Never log or return blinding factors in HTTP responses. The blinding IS
   the decryption material.
2. Always set FCL `limit: 9999` for JanusFlow Cadence transactions.
3. Always call `token.connect()` or `token.connectWithSigner()` before any
   operation.
4. Run proof generation off the main thread (Web Worker) in browser apps.
5. Never import from any deprecated address (see list below).
6. Use the canonical SDK address constants — never hardcode.
7. Deliver `(transferAmount, transferBlinding)` to recipients via a secure
   out-of-band channel. On-chain state alone does not let them recover the
   amount.
8. Use `generateBlinding()` for every new blinding factor — never hardcode
   or reuse.

## Addresses (testnet) — v0.5.4

- JanusFlow EVM proxy:           0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078
- JanusFlow EVM impl (v0.5.4-fees): 0x4F0914911C2f2beb7bFf6d060F3136bbd8c57943
- JanusFlow Cadence router:      0x5dcbeb41055ec57e
- AmountDiscloseVerifier:        0x9c83b2b1EFFD3bd375b9Bee93Cb618005D6A2Dc4
- ConfidentialTransferVerifier:  0x48f791D2a4992F448Cc36F12e5500b6553e969b3
- BabyJub.sol (lab):             0x27139AFda7425f51F68D32e0A38b7D43BcB0f870
- Owner (admin COA):             0x0000000000000000000000022f6b30af48a94787

DEPRECATED (DO NOT USE):
- 0x025efe7e89acdb8F315C804BE7245F348AA9c538 (v0.2 EVM JanusToken — leaks amounts)
- 0xbef3c77681c15397 (v0.2 Cadence router)
- 0x28fef3d1d6a12800.JanusFlow (v1 zombie, Pedersen-hash, unremovable)

## Migration from v0.2

If your codebase still references `registerPubkey`, `buildEncryptProof`,
`buildDecryptProof`, `wrapAndEncrypt`, `decryptAndUnwrap`, or `bsgsRecover`,
those are v0.2 ElGamal APIs and have been removed. See
`openjanus-sdk/references/migration-v02-to-v03.md` for the rewrite recipes.

## Reference

See https://github.com/claucondor/ai-tools for full v0.3 documentation.
```
