# Circuit Artifacts — WASM, zkey, and vkey Locations (v0.8)

## What circuits are in v0.8?

The v0.8 stack has **three circuits**:

| Circuit | Verifier contract | Purpose |
|---------|-----------------|---------|
| `ConfidentialTransferAggregate` | `ConfidentialTransferAggregateVerifier` | `shieldedTransfer` — proves sender commitment split |
| `AmountDiscloseAggregate` | `AmountDiscloseAggregateVerifier` | `wrapWithProof` / `unwrap` boundary — proves commit = Pedersen(amount, blinding, nonce) |
| `ConfidentialClaimBatch` (N=10) | `ConfidentialClaimBatchVerifier` | `claimBatch` — proves draining N=10 inbox notes in one proof |

All circuits use the **Groth16** protocol on the BN128 curve.
The `amount_disclose` and `confidential_transfer` circuits share a single trusted setup (pot22).
`batch_claim` has its own pot22 ceremony.

> **Ceremony upgrade (v0.8):** All circuits were re-ceremonialized on **pot22**
> (Hermez `powersOfTau28_hez_final_22`, 54+ contributors). Previous v0.6.x circuits
> used pot14/15. Do NOT mix old zkeys with new verifier contracts — verification will
> always fail.

---

## Artifact file locations (monorepo)

### ConfidentialTransferAggregate + AmountDiscloseAggregate

```
openjanus-contracts/
└── circuits/
    └── aggregate-ceremony/
        └── setup/
            ├── confidential_transfer_aggregate_test.zkey   # transfer proving key
            ├── verification_key.json                       # transfer vkey (6 public inputs)
            ├── amount_disclose_aggregate_test.zkey         # amount-disclose proving key
            └── amount_disclose_verification_key.json       # amount-disclose vkey (4 public inputs)
```

### ConfidentialClaimBatch (N=10)

```
openjanus-contracts/
└── circuits/
    └── aggregate-claim-batch/
        └── ceremony/
            ├── cb_n10_0000.zkey    # initial zkey (N=10)
            ├── cb_n10_0001.zkey    # contributor 1 contribution (N=10)
            ├── cb_final.zkey       # final proving key (active, ~151 MB)
            ├── cb_final_vkey.json  # batch-claim vkey (6 public inputs)
            ├── pot22.ptau          # Hermez phase 1 SRS
            └── ceremony.json       # full ceremony record + sha256 provenance
```

> `cb_final.zkey` is 151 MB — gitignored. Regenerate from the ceremony record if needed.
> `cb_n50_archive.zkey` is the deprecated N=50 version — do not use.

---

## Vkey SHA-256 hashes (v0.8 canonical)

| Vkey file | SHA-256 |
|-----------|---------|
| `verification_key.json` (ConfidentialTransfer) | `4f8544496ca2d983dd13dbb32a7efec1c668001ac4ef638116f1a1ed4dc90745` |
| `amount_disclose_verification_key.json` | `910bac96216d7df4678e5dadda02a3686854ed3f7dabc00285b8a964f9a84ae0` |
| `cb_final_vkey.json` (ClaimBatch N=10) | `7258504afedd9707fbc406855627a8a8863a2ca858025d2278bd8c05802edae3` |

---

## Public inputs layout per circuit

### AmountDiscloseAggregate (4 inputs)

```
[0] amount     — net wrap amount in attoFLOW (post-fee)
[1] commitX    — Pedersen commitment x-coordinate
[2] commitY    — Pedersen commitment y-coordinate
[3] nonce      — anti-replay nonce (caller-chosen, must be unused)
```

### ConfidentialTransferAggregate (6 inputs)

```
[0] C_old_x   — sender's current on-chain commitment x
[1] C_old_y   — sender's current on-chain commitment y
[2] C_tx_x    — transfer commitment x (credited to recipient)
[3] C_tx_y    — transfer commitment y
[4] C_new_x   — sender's post-transfer commitment x
[5] C_new_y   — sender's post-transfer commitment y
```

### ConfidentialClaimBatch (6 inputs)

```
[0] C_old_x       — user's current on-chain commitment x
[1] C_old_y       — user's current on-chain commitment y
[2] C_new_x       — user's new commitment after draining N notes
[3] C_new_y       — y of new commitment
[4] C_consumed_x  — sum of all N note commitments (public witness)
[5] C_consumed_y  — y of consumed sum
```

---

## Serving artifacts in a browser app

The `.wasm` and `.zkey` files must be accessible via HTTP in browser environments. Recommended approach:

1. Place them in `public/circuits/` in your Next.js project.
2. Reference them by URL:

```typescript
const WASM_TRANSFER_PATH  = "/circuits/confidential_transfer_aggregate.wasm";
const ZKEY_TRANSFER_PATH  = "/circuits/confidential_transfer_aggregate_final.zkey";
const WASM_DISCLOSE_PATH  = "/circuits/amount_disclose_aggregate.wasm";
const ZKEY_DISCLOSE_PATH  = "/circuits/amount_disclose_aggregate_final.zkey";
```

**Do not bundle them with webpack** — the zkey files are 20-150 MB. Serve from `public/` so they are fetched separately and cached by the browser.

## CDN hosting

For production apps, host the artifacts on a CDN with a versioned path:

```typescript
const CDN = "https://artifacts.yourdomain.com/circuits/v0.8";
const ZKEY_TRANSFER_PATH = `${CDN}/confidential_transfer_aggregate_final.zkey`;
const ZKEY_DISCLOSE_PATH = `${CDN}/amount_disclose_aggregate_final.zkey`;
const ZKEY_BATCH_PATH    = `${CDN}/cb_final.zkey`;
```

Cache with a long TTL (e.g., 1 year) — artifacts never change for a given ceremony. If you re-run a ceremony, bump the version path.

## Verifying artifact integrity

Use `sha256sum` against the hashes in the table above. Never mix a zkey from one ceremony with a verifier contract compiled for a different ceremony — Groth16 verification will silently fail.

## Common Pitfalls

**Mixing v0.6 zkeys with v0.8 verifiers.** The verifier contracts deployed at v0.8 addresses correspond exclusively to the pot22 ceremony. Proofs generated with old (pot14/15) zkeys will fail on-chain.

**Using the N=50 archived batch-claim zkey.** `cb_n50_archive.zkey` is a discarded ceremony artifact. The active verifier is N=10. Proofs from N=50 zkeys will fail against the deployed `ConfidentialClaimBatchVerifier`.

**Relative paths in Node.js tests.** snarkJS resolves paths relative to the current working directory. Use `path.resolve(__dirname, "../../...")` in test files to get absolute paths.

**Missing `.wasm` in `public/` directory.** Next.js only serves files in `public/`. Moving the WASM to a different location causes `fetch` to return 404.

**pi_b FP2 swap.** snarkJS generates proofs where `pi_b` is in the (imaginary, real) field element order per EIP-197. The deployed verifiers expect this format. The SDK handles the swap automatically; if you call the verifier directly, pre-swap before passing `pB`.
