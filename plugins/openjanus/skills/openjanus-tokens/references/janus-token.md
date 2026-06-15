# JanusToken — Abstract Shielded-Pool Base (v0.8)

`JanusToken` (Solidity, `packages/janus-token/contracts/solidity/JanusToken.sol` in `openjanus-contracts`) is the abstract base every OpenJanus confidential token extends. It is NOT deployed standalone — only the concrete `Janus<X>` extensions reach the chain.

## What the abstract base provides

- `mapping(address => Point) commitments` — per-account Pedersen commitment storing the cleartext-hidden residual balance.
- `totalSupplyCommitment` — homomorphic sum of all commitments (a `Point`), exposed for indexers / auditors.
- `totalLocked` — cleartext aggregate of all asset units in the shielded pool. Boundary-only visibility by design.
- `shieldedTransfer(to, publicInputs, proof, encryptedNoteTo, ephPubkeyToX, ephPubkeyToY)` — 6-arg shielded transfer. Atomically deposits an encrypted note to recipient's `ShieldedInbox`.
- `claimBatch(publicInputs, proof)` — batch-claim up to N=10 inbox notes in a single Groth16 proof.
- `usedNonces[caller][nonce]` — anti-replay nonces consumed by `wrapWithProof`.

What the abstract base DOES NOT provide:
- `wrapWithProof` / `unwrap` / `mint` / `burn` — these are asset-specific and live on the concrete `Janus<X>`.

## Deployed (v0.8)

| Concrete | EVM proxy | SDK id |
|----------|-----------|--------|
| `JanusFlow` (native FLOW) | `0xA64340C1d356835A2450306Ffd290Ed52c001Ad3` | `'flow'` |
| `JanusERC20` (MockUSDC / mUSDC) | `0xFD8F82bE1782AF1F85f4673065e94fb3F8D5387d` | `'mockusdc'` |
| `JanusFT` (Cadence FT) | `0x4b6bc58bc8bf5dcc` (Cadence) | `'mockft'` |

Verifiers and primitives (shared across all EVM concretes, pot22 ceremony):

| Contract | EVM | Used in |
|----------|-----|---------|
| `AmountDiscloseAggregateVerifier` | `0xf7B634D41259D0613345633eE1CD193A030A6329` | wrapWithProof / unwrap boundary |
| `ConfidentialTransferAggregateVerifier` | `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c` | shieldedTransfer |
| `ConfidentialClaimBatchVerifier` (N=10) | `0x66f25B8f2e7ABFA97ff6446aEAfE5c5D3b1c8d2f` | claimBatch |
| `BabyJub` (lib) | `0xD79C90b797949F0956d977989aEf82A81c860e0C` | negate() in processShieldedDebit |
| `Pedersen2Gen` (lib) | `0x5EdF7473b1007b4855127bC40fcc89eCDD7fB561` | addCommits() — homomorphic accumulation |
| `MemoKeyRegistry` (immutable) | `0x361bD4d037838A3a9c5408AE465d36077800ee6c` | one publish covers all tokens |
| `ShieldedInbox` (immutable) | `0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6` | recipient note delivery |
| `ShieldedCheckpoint` (immutable) | `0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26` | sender state recovery |

Trusted setup: Hermez pot22 + Flow VRF beacon at testnet block 325,996,533
(see `circuits/aggregate-claim-batch/ceremony/ceremony.json` for sha256 provenance).


## Storage slot layout (v0.8 — UUPS compatibility)

```
slot  0   babyJub                  address
slot  1   transferVerifier          address
slot  2   amountDiscloseVerifier    address
slot  3   commitments               mapping(address => Point)
slot  4-5 totalSupplyCommitment     Point
slot  6   totalLocked               uint256
slot  7   memoKeyPubX               mapping  (DEPRECATED — slot kept for layout stability)
slot  8   memoKeyPubY               mapping  (DEPRECATED — slot kept for layout stability)
slot  9   firstSnapshotBlock        mapping(address => uint256)
slot 10   feeRecipient + feeBps     packed
slot 11..89 __gap[79]              uint256[79]
slot 90   memoRegistry              address
slot 91   pedersen2Gen              address  (added v0.7.0)
slot 92   usedNonces                mapping(address => mapping(uint256 => bool))  (added v0.7.1)
slot 93   shieldedInbox             address  (added v0.8.0)
slot 94   batchClaimVerifier        address  (added v0.8.1, JanusFlow only — JanusERC20 uses slot 94 for `underlying`)
```


## Slot lifecycle

```
1. wrapWithProof(nonce, commit, pA, pB, pC, encryptedSnapshot, ephPubkeyX, ephPubkeyY) payable
   → checks usedNonces[msg.sender][nonce] == false → marks used
   → deducts fee from msg.value → net = msg.value * (10000 - feeBps) / 10000
   → verifies AmountDiscloseAggregate proof: [net, commitX, commitY, nonce]
   → adds Pedersen(net, blinding) to commitments[msg.sender] via pedersen2Gen.addCommits
   → totalLocked += net                           (boundary leak by design)
   → emits Wrapped(sender, net)
   → emits WrapWithSnapshot(sender, net, encryptedBlob, ephX, ephY)

2. shieldedTransfer(to, publicInputs, proof, encryptedNoteTo, ephPubkeyToX, ephPubkeyToY)
   → NOT payable (msg.value == 0)
   → verifies ConfidentialTransferAggregate proof against publicInputs[0..5]
   → sets commitments[msg.sender] = (C_new_x, C_new_y)   (sender post-transfer residual)
   → accumulates (C_tx_x, C_tx_y) into commitments[to] via pedersen2Gen.addCommits
   → totalLocked unchanged
   → if shieldedInbox set: ShieldedInbox.deposit(to, encryptedNoteTo, ephX, ephY)
     REVERTS if inbox full (MAX_INBOX_NOTES = 10000) — push-model warning
   → emits ConfidentialTransfer(from, to)   (no amount)
   → emits ShieldedTransferNote(from, to, encryptedNoteTo, ephX, ephY)

3. claimBatch(publicInputs, proof)
   → verifies ConfidentialClaimBatch proof against [C_old_x, C_old_y, C_new_x, C_new_y, C_consumed_x, C_consumed_y]
   → verifies C_old matches commitments[msg.sender]
   → sets commitments[msg.sender] = (C_new_x, C_new_y)
   → emits BatchClaimed(user, C_new_x, C_new_y)

4. unwrap(claimedAmount, recipient, txCommit, amountProof, transferPublicInputs, transferProof,
          encryptedSnapshot, ephPubkeyX, ephPubkeyY)
   → NOT payable
   → verifies AmountDiscloseAggregate proof: [claimedAmount, txCommit[0], txCommit[1], 0]
   → verifies ConfidentialTransferAggregate proof for the debit slice
   → totalLocked -= claimedAmount             (boundary leak by design)
   → sends netToRecipient = claimedAmount - fee to recipient via internal transfer
   → emits Unwrapped(sender, recipient, netToRecipient)
   → emits UnwrapWithSnapshot(sender, claimedAmount, encryptedBlob, ephX, ephY)
```


## Solidity ABI (abstract base, selected — v0.8)

```solidity
struct Point {
    uint256 x;
    uint256 y;
}

abstract contract JanusToken {
    mapping(address => Point) public commitments;
    mapping(address => mapping(uint256 => bool)) public usedNonces;

    function balanceOfCommitment(address account) external view returns (Point memory);
    function balanceOfCommitmentXY(address account) external view returns (uint256 x, uint256 y);
    function totalSupplyCommitment() external view returns (Point memory);
    function totalLocked() external view returns (uint256);

    // 6-arg shieldedTransfer (v0.8)
    function shieldedTransfer(
        address to,
        uint256[6] calldata publicInputs,   // [C_old_x, C_old_y, C_tx_x, C_tx_y, C_new_x, C_new_y]
        uint256[8] calldata proof,
        bytes calldata encryptedNoteTo,
        uint256 ephPubkeyToX,
        uint256 ephPubkeyToY
    ) external;

    // Batch drain N=10 inbox notes
    function claimBatch(
        uint256[6] calldata publicInputs,   // [C_old_x, C_old_y, C_new_x, C_new_y, C_consumed_x, C_consumed_y]
        uint256[8] calldata proof
    ) external;

    event ConfidentialTransfer(address indexed from, address indexed to);
    event ShieldedTransferNote(address indexed from, address indexed to,
        bytes encryptedNoteTo, uint256 ephPubkeyToX, uint256 ephPubkeyToY);
    event BatchClaimed(address indexed user, uint256 newCommitX, uint256 newCommitY);
}
```

## Concrete `JanusFlow` ABI additions (v0.8)

```solidity
contract JanusFlow is JanusToken {
    uint256 public constant MAX_WRAP = type(uint128).max;
    string  public constant VERSION  = "0.8.1";

    // payable — msg.value is GROSS; proof must bind to NET (post-fee)
    // nonce: anti-replay, must be fresh per caller
    function wrapWithProof(
        uint256 nonce,
        uint256[2] calldata commit,         // Pedersen commitment [x, y]
        uint256[2] calldata pA,             // Groth16 pA
        uint256[2][2] calldata pB,          // Groth16 pB
        uint256[2] calldata pC,             // Groth16 pC
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY
    ) external payable;

    // NOT payable
    function unwrap(
        uint256 claimedAmount,
        address payable recipient,
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof,
        uint256[6] calldata transferPublicInputs,
        uint256[8] calldata transferProof,
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY
    ) external;

    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, address indexed recipient, uint256 amount);
    event WrapWithSnapshot(address indexed user, uint256 amount,
        bytes encryptedSnapshot, uint256 ephPubkeyX, uint256 ephPubkeyY);
    event UnwrapWithSnapshot(address indexed user, address indexed recipient, uint256 amount,
        bytes encryptedSnapshot, uint256 ephPubkeyX, uint256 ephPubkeyY);
}
```

## Public-inputs layout

### `AmountDiscloseAggregateVerifier` public inputs (uint256[4])

```
[amount, commitX, commitY, nonce]
```

Proves `Commit(amount, blinding) = (commitX, commitY)` with a fresh `nonce` to prevent replay. The `nonce` is 0 for the unwrap path (the transfer proof already provides replay protection via C_old state machine).

### `ConfidentialTransferAggregateVerifier` public inputs (uint256[6])

```
[C_old_x, C_old_y, C_tx_x, C_tx_y, C_new_x, C_new_y]
```

- `C_old` — sender's current on-chain commitment (must match `commitments[msg.sender]`).
- `C_tx` — commitment for the transferred amount (credited to recipient).
- `C_new` — sender's post-transfer residual commitment.
- The circuit proves `C_old = C_new + C_tx` (homomorphic, no amounts revealed).

### `ConfidentialClaimBatchVerifier` public inputs (uint256[6])

```
[C_old_x, C_old_y, C_new_x, C_new_y, C_consumed_x, C_consumed_y]
```

- `C_old` — user's current on-chain commitment (must match `commitments[msg.sender]`).
- `C_consumed` — sum of N inbox note commitments (private witnesses known by user only).
- `C_new` — user's post-claim commitment = `C_old + C_consumed`.

## Common pitfalls

**P1 — Wrong fixed-array length in interfaces.**
The Solidity ABI uses `uint256[N]` (fixed-length). Calling with `uint256[] calldata` produces a different selector and silently reverts. Always copy the ABI verbatim.

**P2 — Nonce collision in wrapWithProof.**
Each `nonce` is stored in `usedNonces[msg.sender]` after consumption. Re-using a nonce reverts. Use a fresh random uint256 per wrap call, or a counter. The SDK generates nonces automatically.

**P3 — shieldedTransfer reverts when recipient inbox is full.**
`MAX_INBOX_NOTES = 10000`. If the recipient has not drained their inbox, `shieldedTransfer` reverts. Recipients must call `claimBatch()` to drain. Build this warning into your UI.

**P4 — Bypassing `MAX_WRAP` (JanusFlow only).**
`MAX_WRAP = type(uint128).max` (~3.4 × 10^38 attoFLOW). Practically unlimited for native FLOW at current prices. `JanusERC20.MAX_WRAP = 18e18` raw units — split large amounts if needed.

**P5 — Trying to read a cleartext balance from `commitments[user]`.**
The mapping returns an opaque `Point`. Cleartext balance recovery requires the locally-held blinding. See `../../openjanus-sdk/references/decrypt-flow.md`.

**P6 — claimBatch trust model (v0.8 testnet).**
The on-chain verifier does NOT cross-check `C_consumed` against a registry of deposited notes. A prover could claim amounts they never received. Mainnet will add a `NoteCommitmentTracker`. For v0.8 testnet this is acceptable — the C_old state machine prevents double-spending of the same proof.

## See also

- [janus-flow.md](janus-flow.md) — JanusFlow concrete + Cadence templates
- [janus-erc20.md](janus-erc20.md) — JanusERC20 concrete + ERC20 wrap pattern
- [creating-custom-instances.md](creating-custom-instances.md) — Build a new Janus&lt;X&gt;
- [../../openjanus-sdk/references/quickstart.md](../../openjanus-sdk/references/quickstart.md) — TypeScript SDK quick start
- [../../openjanus-deploy/references/canonical-addresses.md](../../openjanus-deploy/references/canonical-addresses.md) — All deployed addresses
