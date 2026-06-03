# Cursor Rules Template — Projects Building on the Janus Privacy Stack (v0.3)

Copy this file into your project root as `.cursorrules` and customize the
bracketed sections.

---

```
You are an expert TypeScript/Cadence developer building on the Janus v0.3
privacy stack on the Flow blockchain.

## Stack (v0.3)

- @claucondor/sdk@^0.6.5 — TypeScript SDK with generic `sdk.token(id)` adapter
  (4 tokens: 'flow'/'wflow'/'mockusdc'/'mockft') + abstract `JanusToken` base
- MemoKeyRegistry (0x05D104962ff087441f26BA11A1E1C3b9E091D663) — immutable;
  one publishMemoKey covers all 4 tokens
- Flow EVM — UUPS proxies for JanusFlow (0x2458ae2d…), JanusWFLOW (0x00129E94…),
  JanusMockUSDC (0xd45FDa09…); feeBps=10 (0.1%) on all
- Flow Cadence — JanusFT at 0x7599043aea001283
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
5. Always import addresses from the canonical SDK constants — never hardcode addresses.
6. Use the canonical SDK address constants — never hardcode.
7. Deliver `(transferAmount, transferBlinding)` to recipients via a secure
   out-of-band channel. On-chain state alone does not let them recover the
   amount.
8. Use `generateBlinding()` for every new blinding factor — never hardcode
   or reuse.

## Addresses (testnet) — v0.6.4 contracts

- JanusFlow EVM proxy:           0x2458ae2d26797c2ffa3B4f6612Bdc4aDf22b7156
- JanusWFLOW EVM proxy:         0x00129E94d5340bd19d0b4ed9CDf718BB6e0A9400
- JanusMockUSDC EVM proxy:      0xd45FDa099Cf67eD842eA379865AB08E18D62BAf3
- JanusFT Cadence:               0x7599043aea001283
- MemoKeyRegistry (immutable):  0x05D104962ff087441f26BA11A1E1C3b9E091D663
- WFLOW9 underlying:             0xe7BbEAcC04A589e4B70922b2796Bb4F8e6e4873C
- MockUSDC underlying:           0x8405E8831737aE72204c271581b7d4fAD9f622bE
- AmountDiscloseVerifier:       0xD0ED3936530258C278f5357C1dB709ad34768352
- ConfidentialTransferVerifier: 0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B
- BabyJub.sol:                   0x27139AFda7425f51F68D32e0A38b7D43BcB0f870


## Reference

See https://github.com/claucondor/ai-tools for full v0.3 documentation.
```
