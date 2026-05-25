# Creating Custom JanusToken Instances

You can deploy your own JanusToken instance to add confidential transfers to any existing ERC-20, or to mint a new privacy-native token.

## When to create a custom instance

- You have an existing ERC-20 (e.g., a game token, stablecoin, DAO token) and want to add confidential transfers → **WRAPPER mode**
- You want to issue a new privacy-first token with no ERC-20 heritage → **NATIVE mode**
- You want to run your own verifier with a custom circuit → **custom WRAPPER mode**

## Reuse the canonical primitives

For most use cases, you can reuse the already-deployed `BabyJub.sol` and `ConfidentialTransferVerifier.sol`:

| Contract | Testnet address |
|----------|----------------|
| `BabyJub.sol` | `0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07` |
| `ConfidentialTransferVerifier.sol` | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` |

The verifier is circuit-specific: it only works with proofs generated from `confidentialTransfer_final.zkey`. If you use the same circuit (which most apps should), reuse it.

## WRAPPER mode — adding privacy to an ERC-20

### 1. Deploy JanusToken in WRAPPER mode

```solidity
// Solidity constructor call (Hardhat / Foundry)
JanusToken token = new JanusToken(
    0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5, // verifier
    0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07, // BabyJub.sol
    true,    // wrapperMode = true
    0xYourExistingERC20Address
);
```

### 2. Point the SDK at your instance

```typescript
import { JanusToken } from "@openjanus/sdk/tokens";

const token = new JanusToken({
  evmAddress: "0xYourJanusTokenAddress",
  network: "testnet", // or "mainnet"
});
await token.connect();
```

### 3. Users approve before wrapping

```typescript
// Standard ERC-20 approve first
const erc20 = new ethers.Contract(underlyingAddress, ERC20_ABI, signer);
await erc20.approve(YOUR_JANUS_TOKEN_ADDRESS, amount);

// Then wrap
const blinding = generateBlinding();
const { receipt, commit } = await token.mint(aliceAddress, amountBigint, blinding);
```

Wait — in WRAPPER mode, there is no `mint()`. Use:

```typescript
import { computeCommitment } from "@openjanus/sdk/crypto";

const commitment = await computeCommitment(amountBigint, blinding);
const tx = await token.wrap(amountBigint, commitment);
```

## NATIVE mode — new privacy token

```solidity
JanusToken token = new JanusToken(
    0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5, // verifier
    0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07, // BabyJub.sol
    false,       // wrapperMode = false
    address(0)   // underlying = address(0) for NATIVE
);
```

In NATIVE mode, only the owner can call `mintXY` and `burnXY`. Typical pattern: the owner is a protocol contract that gates minting on some off-chain proof of identity or payment.

## Registering with the SDK

After deploying, update your app's config:

```typescript
// config.ts
export const MY_TOKEN_TESTNET = {
  evmAddress: "0xYourDeployedAddress",
  network: "testnet" as const,
};

// usage
import { JanusToken } from "@openjanus/sdk/tokens";
import { MY_TOKEN_TESTNET } from "./config";

const token = new JanusToken(MY_TOKEN_TESTNET);
await token.connect();
```

## Custom circuit (advanced)

If you modify the ConfidentialTransfer circuit (e.g., to add more constraints), you must:

1. Regenerate the trusted setup to produce a new `.zkey`
2. Export a new `ConfidentialTransferVerifier.sol` via `snarkjs zkey export solidityverifier`
3. Deploy the new verifier
4. Deploy your JanusToken pointing at the new verifier
5. Update WASM/zkey paths in all callers

Do not mix a new `.zkey` with the old `ConfidentialTransferVerifier.sol` — the verification will always fail.

## Next steps

- [../deployments/canonical-addresses.md](../deployments/canonical-addresses.md) — all testnet addresses
- [../../examples/deploy-janus-flow.md](../../examples/deploy-janus-flow.md) — step-by-step deploy walkthrough
