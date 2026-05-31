# JanusToken — Abstract Shielded-Pool Base (v0.3)

`JanusToken` (Solidity, `src/JanusToken.sol` in `openjanus-contracts`) is the
abstract base every OpenJanus confidential token extends. It is NOT deployed
standalone — only the concrete `Janus<X>` extensions (`JanusFlow` for native
FLOW, future `JanusUSDC` for ERC-20, etc.) reach the chain.

## What the abstract base provides

- A `mapping(address => Point) commitments` — per-account Pedersen commitment
  storing the cleartext-hidden residual balance.
- `totalSupplyCommitment()` — homomorphic sum of all commitments, exposed as
  a view for indexers / auditors.
- `totalLocked()` — cleartext aggregate of all asset units in the shielded pool.
  Boundary-only visibility (by design).
- `shieldedTransfer(to, publicInputs, proof)` — the fully shielded transfer
  primitive. Hides the amount on all five privacy channels (msg.value,
  calldata, storage, events, commitment-bruteforce).

What the abstract base DOES NOT provide:

- `wrap` / `unwrap` / `mint` / `burn` — these are asset-specific and live on
  the concrete `Janus<X>`.

## Deployed (v0.3)

| Concrete | EVM proxy | Cadence façade |
|----------|-----------|----------------|
| `JanusFlow` (native FLOW) | `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078` | `0x5dcbeb41055ec57e` |

Verifiers (shared across all concretes):

| Verifier | EVM | Used in |
|----------|-----|---------|
| `AmountDiscloseVerifier` | `0xD0ED3936530258C278f5357C1dB709ad34768352` | wrap / unwrap boundary |
| `ConfidentialTransferVerifier` | `0x84852aF72D2EF2A0A937e8Dae0BFA482E707E39B` | shieldedTransfer |
| `BabyJub.sol` (library) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` | curve ops |

Trusted setup: Hermez pot14 + Flow VRF beacon
(see `circuits/v0.3/CEREMONY-RECORD.json` in the SDK for sha256 provenance).

DEPRECATED v0.2 (DO NOT USE — `0x025efe7e89acdb8F315C804BE7245F348AA9c538` leaks
amount on every shielded transfer via `msg.value`, `transferUnits`, the public
`locked` mapping, and `Wrapped` / `Unwrapped` events).

## Slot lifecycle

```
1. (Concrete) wrap(txCommit, amountProof, encryptedSnapshot, ephPubkeyX, ephPubkeyY) payable
   → deducts fee from msg.value → netAmount = msg.value * (10000 - feeBps) / 10000
   → adds Pedersen(netAmount, blinding) to commitments[msg.sender]
   → totalLocked += netAmount                   (boundary leak by design)
   → emits Wrapped(sender, netAmount)            (net, not gross)
   → emits WrapWithSnapshot(sender, netAmount, encryptedBlob, …)

2. shieldedTransfer(to, publicInputs, proof, encryptedSnapshot, ephPubkeyX, ephPubkeyY)
   → NOT payable (msg.value == 0)
   → splits commitments[msg.sender] into (residual, transferred)
   → adds transferred-commit to commitments[to]
   → totalLocked unchanged
   → emits ConfidentialTransfer(from, to)        (no amount)
   → emits ShieldedTransferWithSnapshot(from, to, encryptedBlob, …)

3. (Concrete) unwrap(claimedAmount, recipient, txCommit, amountProof,
                     transferPublicInputs, transferProof, encryptedSnapshot, ephPubkeyX, ephPubkeyY)
   → NOT payable (msg.value == 0)
   → checks amountProof binds txCommit to `claimedAmount`
   → checks transferProof reduces commitments[msg.sender] by txCommit
   → totalLocked -= claimedAmount               (boundary leak by design)
   → sends netToRecipient = claimedAmount - fee to recipient via internal transfer
   → emits Unwrapped(sender, recipient, netToRecipient)
   → emits UnwrapWithSnapshot(sender, claimedAmount, encryptedBlob, …)
   NOTE: unwrap amount is inherently public — the internal FLOW transfer is visible
   on any block explorer regardless of events.
```

## Solidity ABI (abstract base, selected)

```solidity
struct Point {
    uint256 x;
    uint256 y;
}

abstract contract JanusToken {
    mapping(address => Point) public commitments;

    function balanceOfCommitment(address account) external view returns (Point memory);
    function totalSupplyCommitment() external view returns (Point memory);
    function totalLocked() external view returns (uint256);

    function shieldedTransfer(
        address to,
        uint256[6] calldata publicInputs,
        uint256[8] calldata proof
    ) external;

    event ConfidentialTransfer(address indexed from, address indexed to);
}
```

## Concrete `JanusFlow` ABI additions (v0.5.4-fees)

```solidity
contract JanusFlow is JanusToken {
    uint256 public constant MAX_WRAP_ATTOFLOW = 18_000_000_000_000_000_000;

    // payable — msg.value is GROSS; proof must bind to NET (post-fee)
    function wrap(
        uint256[2] calldata txCommit,
        uint256[8] calldata amountProof,
        bytes calldata encryptedSnapshot,
        uint256 ephPubkeyX,
        uint256 ephPubkeyY
    ) external payable;

    // NOT payable — unwrap is non-payable; recipient receives via internal transfer
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

    // Legacy events (amount = NET post-fee for Wrapped; netToRecipient for Unwrapped)
    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, address indexed recipient, uint256 amount);
    // Snapshot events (carry encrypted state blob for recovery)
    event WrapWithSnapshot(address indexed user, uint256 netAmount, bytes encryptedSnapshot, uint256 ephPubkeyX, uint256 ephPubkeyY);
    event UnwrapWithSnapshot(address indexed user, uint256 claimedAmount, bytes encryptedSnapshot, uint256 ephPubkeyX, uint256 ephPubkeyY);
    event ShieldedTransferWithSnapshot(address indexed from, address indexed to, bytes encryptedSnapshot, uint256 ephPubkeyX, uint256 ephPubkeyY);
}
```

## Public-inputs layout

### `AmountDiscloseVerifier` public inputs (uint256[3])

```
[txCommitX, txCommitY, amount]
```

Where `(txCommitX, txCommitY) = Pedersen(amount, blinding)` for the public
scalar `amount` (in attoFLOW). Used at the wrap / unwrap boundary so the
contract can be confident the committed value matches the cleartext amount it
is moving across the boundary.

### `ConfidentialTransferVerifier` public inputs (uint256[6])

```
[oldCommitX, oldCommitY, newSenderCommitX, newSenderCommitY,
 transferCommitX, transferCommitY]
```

Six BabyJubJub point coordinates. Proves the sender's old commitment was
correctly split into a residual (`newSenderCommit`) and a transferred-commit
without revealing any of the underlying amounts.

## Common pitfalls

**P1 — Wrong fixed-array length in interfaces (vuln/013, still applies).**
The Solidity ABI uses `uint256[N]` (fixed-length). Calling with `uint256[]
calldata` produces a different selector and silently reverts. Always copy the
ABI verbatim.

**P2 — Calling `shieldedTransfer` to an address with no commitments slot.**
v0.3 allocates the recipient slot lazily on first receive; no pre-registration
is required (unlike v0.2). But the recipient still needs to know
`(transferAmount, transferBlinding)` out-of-band to ever spend the new commit.

**P3 — Trying to read a balance from `commitments[user]`.**
The mapping returns an opaque Point. Cleartext balance recovery requires the
locally-held blinding. See `../../openjanus-sdk/references/decrypt-flow.md`.

**P4 — Bypassing `MAX_WRAP_ATTOFLOW` (JanusFlow only).**
Testnet caps wraps at 18 FLOW per call. Bigger amounts revert. Split into
multiple wraps if needed.

## Technical characteristics (v0.3 JanusFlow concrete)

| Aspect | v0.3 JanusFlow |
|--------|----------------|
| Commitment type | `Point` (BabyJubJub) — Pedersen of `(amount, blinding)` |
| Per-user storage | one `Point` |
| On-chain pubkey registration | **none** (removed in v0.3) |
| Decryption key | local-only `(amount, blinding)` pair |
| Multi-sender privacy | Yes, on `shieldedTransfer`; OOB delivery required |
| Boundary visibility | `wrap` + `unwrap` leak amount by design |
| ZK proofs | AmountDiscloseVerifier + ConfidentialTransferVerifier |
| Upgrade model | UUPS proxy (admin COA = `0x0000…2f6b30af48a94787`) |

## See also

- [janus-flow.md](janus-flow.md) — JanusFlow concrete + Cadence templates
- [creating-custom-instances.md](creating-custom-instances.md) — Build a new Janus&lt;X&gt;
- [../../openjanus-sdk/references/v03-architecture.md](../../openjanus-sdk/references/v03-architecture.md) — Abstract / concrete pattern + privacy validation
- [../../openjanus-sdk/references/quickstart.md](../../openjanus-sdk/references/quickstart.md) — TypeScript SDK quick start
- [../../openjanus-deploy/references/canonical-addresses.md](../../openjanus-deploy/references/canonical-addresses.md) — All deployed addresses
