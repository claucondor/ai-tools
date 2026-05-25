# Deploy a JanusToken WRAPPER Instance — Step-by-Step

This walkthrough deploys a JanusToken instance in WRAPPER mode for an existing ERC-20 token on Flow EVM testnet. By the end, users of your ERC-20 can wrap tokens into confidential commitments and execute hidden-amount transfers.

## Prerequisites

- Flow CLI installed
- Node.js 18+
- Hardhat or Foundry configured for Flow EVM
- A deployed ERC-20 at a known address
- A funded Flow EVM testnet account (for gas)

## Step 1: Get the canonical primitive addresses

From [../docs/deployments/canonical-addresses.md](../docs/deployments/canonical-addresses.md):

```
BabyJub.sol:                    0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07
ConfidentialTransferVerifier:   0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5
```

These are already deployed. You do not need to redeploy them unless you are using a custom circuit.

## Step 2: Deploy JanusToken in WRAPPER mode

### Hardhat

Create `scripts/deploy-janus-token.ts`:

```typescript
import { ethers } from "hardhat";

async function main() {
  const VERIFIER = "0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5";
  const BABYJUB  = "0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07";
  const MY_ERC20 = "0xYourERC20Address";

  const JanusToken = await ethers.getContractFactory("JanusToken");
  const token = await JanusToken.deploy(VERIFIER, BABYJUB, true, MY_ERC20);
  await token.waitForDeployment();

  console.log("JanusToken deployed at:", await token.getAddress());
  console.log("isWrapperMode:", await token.isWrapperMode());
  console.log("underlying:", await token.underlying());
}

main().catch(console.error);
```

```bash
npx hardhat run scripts/deploy-janus-token.ts --network flowTestnet
```

### Foundry

```bash
forge create src/JanusToken.sol:JanusToken \
  --constructor-args \
    0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5 \
    0x2c40513b343B70f2A0B7e6Ad6F997DDa819D6f07 \
    true \
    0xYourERC20Address \
  --rpc-url https://testnet.evm.nodes.onflow.org \
  --private-key $PRIVATE_KEY
```

Note the deployed address from the output.

## Step 3: Verify the deployment

```typescript
import { JanusToken } from "@openjanus/sdk/tokens";

const token = new JanusToken({
  evmAddress: "0xYourDeployedJanusTokenAddress",
  network: "testnet",
});
await token.connect();

console.log("Wrapper mode:", await token.isWrapperMode());  // true
console.log("Underlying:", (await token._contract().underlying()));  // your ERC-20
console.log("Total supply commitment:", await token.totalSupplyCommitment());
// { x: 0n, y: 1n } — identity, no wraps yet
```

## Step 4: Test the wrap flow

```typescript
import { createEvmWallet } from "@openjanus/sdk/network";
import { computeCommitment, generateBlinding } from "@openjanus/sdk/crypto";
import { ethers } from "ethers";

const wallet = await createEvmWallet(process.env.TEST_KEY!, "testnet");
const erc20 = new ethers.Contract(MY_ERC20, ["function approve(address,uint256) returns (bool)"], wallet);
const token = new JanusToken({ evmAddress: MY_JANUS_TOKEN, network: "testnet" });
await token.connectWithSigner(wallet);

// Step 4a: approve
await erc20.approve(MY_JANUS_TOKEN, 100n);

// Step 4b: compute commitment
const blinding = generateBlinding();
const commitment = await computeCommitment(100n, blinding);

// Step 4c: wrap
// Note: JanusToken in WRAPPER mode uses wrap(), not mint()
const tx = await token.wrap(100n, commitment);
console.log("Wrap TX:", tx.transactionHash);

// Step 4d: verify
const storedCommit = await token.balanceOfCommitment(wallet.address);
console.log("Stored commitment:", storedCommit);
// Should match `commitment`
```

## Step 5: Test a confidential transfer

```typescript
const { receipt, proofResult } = await token.proveAndTransfer(
  "0xBobEVMAddress",
  {
    oldBalance: 100n,
    oldBlinding: blinding,
    transferAmount: 25n,
    transferBlinding: generateBlinding(),
    newBlinding: generateBlinding(),
    wasmPath: WASM_PATH,
    zkeyPath: ZKEY_PATH,
    vkPath: VK_PATH,
  }
);

console.log("Transfer TX:", receipt.hash);
// Verify Bob's slot now has a commitment to 25
const bobCommit = await token.balanceOfCommitment("0xBobEVMAddress");
console.log("Bob commitment:", bobCommit);
```

## Step 6: Register in your SDK config

```typescript
// config/openjanus.ts
export const MY_TOKEN = {
  evmAddress: "0xYourDeployedJanusTokenAddress",
  network: "testnet" as const,
};
```

## Step 7: Add to flow.json (if building a Cadence wrapper)

If you want to build a Cadence contract that interacts with your JanusToken instance (similar to JanusFlow), add the EVM address as a constant in your Cadence contract:

```cadence
// YourWrapper.cdc
let janusTokenEVM: EVM.EVMAddress = EVM.addressFromString("0xYourDeployedJanusTokenAddress")
```

## Troubleshooting

**"execution reverted" on wrap** — Check that the ERC-20 `approve` call went through before `wrap`.

**"computation exceeds limit"** — This can happen if you add extra operations in the same transaction as `confidentialTransfer`. Keep transfers atomic.

**verifyProof returns false** — Check that you are using the correct zkey (matching the canonical `ConfidentialTransferVerifier` address). If you redeployed the verifier with a different zkey, update the verifier address in the constructor.
