# JanusToken — Confidential ERC-20 Standard

JanusToken is an ERC-20-style Solidity contract that stores balances as Pedersen commitments instead of plaintext integers. It is inspired by the ERC-7984 confidential token standard.

## Modes

JanusToken operates in one of two modes, selected at deployment time and immutable thereafter:

### NATIVE mode

- The contract manages its own supply.
- The owner calls `mintXY(to, cx, cy)` to credit a commitment to an address.
- No underlying ERC-20 is involved.
- Use case: new privacy tokens, issuing grants with hidden amounts.

### WRAPPER mode

- The contract wraps an existing ERC-20.
- Users call `wrap(amount, commitment)` after approving the JanusToken contract for `amount` of the underlying token.
- The underlying tokens are locked in the JanusToken contract.
- Users call `unwrap(from, amount, commitment)` to exit.
- Use case: adding privacy to an existing ERC-20 (e.g., USDC, WFLOW).

## Interface

### View functions

```solidity
// Read the current commitment for an address
function balanceOfCommitment(address) external view returns (tuple(uint256 x, uint256 y));

// Same, but returns x and y as two separate uint256 values
function balanceOfCommitmentXY(address) external view returns (uint256 x, uint256 y);

// Total supply as a commitment (homomorphic sum of all commitments)
function totalSupplyCommitment() external view returns (tuple(uint256 x, uint256 y));

// Mode
function isWrapperMode() external view returns (bool);
function underlying() external view returns (address); // address(0) in NATIVE mode

// Dependency addresses
function verifier() external view returns (address);
function babyJub() external view returns (address);
function owner() external view returns (address);
```

### State-changing functions

```solidity
// NATIVE mode only — owner mints a commitment to a recipient
function mintXY(address to, uint256 cx, uint256 cy) external;

// NATIVE mode only — owner burns a commitment from an address
function burnXY(address from, uint256 cx, uint256 cy) external;

// WRAPPER mode only — wrap underlying tokens into a commitment
// Caller must have approved this contract for `amount` of underlying
function wrap(uint256 amount, tuple(uint256 x, uint256 y) amountCommitment) external;

// WRAPPER mode only — exit back to underlying (owner/bridge only)
function unwrap(address from, uint256 amount, tuple(uint256 x, uint256 y) amountCommitment) external;

// All modes — transfer commitments with ZK proof
function confidentialTransfer(
    address to,
    uint256[6] calldata publicInputs,
    uint256[8] calldata proof
) external;
```

### Events

```solidity
event ConfidentialMint(address indexed to, uint256 new_commit_x, uint256 new_commit_y);
event ConfidentialTransfer(address indexed from, address indexed to);
event ConfidentialBurn(address indexed from, uint256 new_commit_x, uint256 new_commit_y);
event Wrap(address indexed account, uint256 amount, uint256 commit_x, uint256 commit_y);
event Unwrap(address indexed account, uint256 amount, uint256 new_commit_x, uint256 new_commit_y);
```

## Constructor (deployment)

```solidity
constructor(
    address _verifier,  // ConfidentialTransferVerifier address
    address _babyJub,   // BabyJub.sol address
    bool    _wrapperMode,
    address _underlying // address(0) for NATIVE mode
)
```

See [canonical-addresses.md](../deployments/canonical-addresses.md) for the testnet verifier and BabyJub addresses to pass at deploy time.

## publicInputs encoding

The `confidentialTransfer` function takes a `uint256[6]` array in this order:

```
[0] old_commit.x
[1] old_commit.y
[2] transfer_commit.x
[3] transfer_commit.y
[4] new_commit.x
[5] new_commit.y
```

This matches the public signal declaration order in the ConfidentialTransfer circuit.

## proof encoding

The `uint256[8]` proof is a flattened Groth16 proof in EIP-197 format:

```
[0] pA.x
[1] pA.y
[2] pB[0][0]  ← Fp2 component (im-first, per EIP-197)
[3] pB[0][1]
[4] pB[1][0]
[5] pB[1][1]
[6] pC.x
[7] pC.y
```

The pi_b Fp2 swap must be applied before encoding. `@openjanus/sdk` handles this automatically via `applyPiBSwap`. See [../gotchas/pi-b-fp2-swap.md](../gotchas/pi-b-fp2-swap.md).

## Extending JanusToken

To create a custom JanusToken instance:

1. Deploy `BabyJub.sol` and `ConfidentialTransferVerifier.sol` (or reuse the canonical addresses).
2. Deploy `JanusToken.sol` with your chosen mode and underlying address.
3. If WRAPPER mode: configure `wrap` authorization in your app.
4. Register the EVM address in your app's config or `@openjanus/sdk` options.

See [creating-custom-instances.md](creating-custom-instances.md) for a complete walkthrough.
