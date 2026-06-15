# Deploy a JanusToken WRAPPER Instance — Step-by-Step

This walkthrough deploys a JanusToken instance in WRAPPER mode for an existing ERC-20 token on Flow EVM testnet. By the end, users of your ERC-20 can wrap tokens into confidential commitments and execute hidden-amount transfers.

## Prerequisites

- Flow CLI installed
- Node.js 18+
- Hardhat or Foundry configured for Flow EVM
- A deployed ERC-20 at a known address
- A funded Flow EVM testnet account (for gas)
- `@claucondor/sdk@^0.8.2` installed

## Step 1: Get the canonical primitive addresses

From [../plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md](../plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md):

```
BabyJub.sol:                    0xD79C90b797949F0956d977989aEf82A81c860e0C
AmountDiscloseVerifier:         0xf7B634D41259D0613345633eE1CD193A030A6329
ConfidentialTransferVerifier:   0x38e69fE7Ba7c2C586d64DFFc14742641A675666c
ShieldedInbox (EVM):            0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6
ShieldedCheckpoint (EVM):       0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26
MemoKeyRegistry:                0x361bD4d037838A3a9c5408AE465d36077800ee6c
```

These are already deployed. You do not need to redeploy them unless you are using a custom circuit.

## Step 2: Deploy JanusToken in WRAPPER mode

### Hardhat

Create `scripts/deploy-janus-token.ts`:

```typescript
import { ethers } from "hardhat";

async function main() {
  const VERIFIER    = "0x38e69fE7Ba7c2C586d64DFFc14742641A675666c"; // ConfidentialTransferVerifier
  const BABYJUB     = "0xD79C90b797949F0956d977989aEf82A81c860e0C";
  const MEMO_REG    = "0x361bD4d037838A3a9c5408AE465d36077800ee6c"; // MemoKeyRegistry
  const INBOX       = "0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6"; // ShieldedInbox
  const MY_ERC20    = "0xYourERC20Address";

  // v0.8 JanusToken constructor: (verifier, babyJub, memoRegistry, inbox, isWrapper, underlying)
  const JanusToken = await ethers.getContractFactory("JanusToken");
  const token = await JanusToken.deploy(VERIFIER, BABYJUB, MEMO_REG, INBOX, true, MY_ERC20);
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
    0x38e69fE7Ba7c2C586d64DFFc14742641A675666c \
    0xD79C90b797949F0956d977989aEf82A81c860e0C \
    0x361bD4d037838A3a9c5408AE465d36077800ee6c \
    0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6 \
    true \
    0xYourERC20Address \
  --rpc-url https://testnet.evm.nodes.onflow.org \
  --private-key $PRIVATE_KEY
```

Note the deployed address from the output.

## Step 3: Verify the deployment

```typescript
import { sdk } from "@claucondor/sdk";

// Register your custom token in a local registry and use the adapter pattern
// For a quick verification, use ethers directly:
import { ethers } from "ethers";
const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const abi = [
  "function isWrapperMode() view returns (bool)",
  "function underlying() view returns (address)",
  "function getCommitment(address) view returns (uint256, uint256)",
];
const contract = new ethers.Contract("0xYourDeployedJanusTokenAddress", abi, provider);

console.log("Wrapper mode:", await contract.isWrapperMode());  // true
console.log("Underlying:", await contract.underlying());        // your ERC-20
const [cx, cy] = await contract.getCommitment("0x000000000000000000000000000000000000dead");
console.log("Zero-balance slot:", cx === 0n, cy === 1n);       // true, true (identity point)
```

## Step 4: Test the wrap flow

```typescript
import { sdk, generateBlinding, ShieldedCheckpointClient } from "@claucondor/sdk";
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://testnet.evm.nodes.onflow.org");
const wallet = new ethers.Wallet(process.env.TEST_KEY!, provider);

// Approve first (ERC20 WRAPPER mode)
const erc20 = new ethers.Contract(MY_ERC20, ["function approve(address,uint256) returns (bool)"], wallet);
await erc20.approve(MY_JANUS_TOKEN, 100n * 10n**6n);  // e.g. 100 USDC (6 decimals)

// Use sdk.token() for canonical tokens, or instantiate a custom adapter for your token.
// For the canonical flow token adapter as reference:
const flow = sdk.token('flow');

// For your custom token, use the adapter interface directly after instantiation.
// wrap() submits the proof and tx in one call:
// const result = await myCustomAdapter.wrap({ grossAmount: 100n * 10n**6n }, wallet);
// console.log("Wrap TX:", result.txHash);

// Update ShieldedCheckpoint after wrap
const checkpoint = new ShieldedCheckpointClient();
// await checkpoint.update(MY_JANUS_TOKEN, result.checkpointPayload!, 0n, wallet);
```

## Step 5: Test a confidential transfer

```typescript
import {
  sdk,
  ShieldedInboxClient,
  ShieldedCheckpointClient,
  assertCheckpointMatchesCommit,
} from "@claucondor/sdk";

const checkpoint = new ShieldedCheckpointClient();
const flow = sdk.token('flow');  // replace with your adapter

// Read current sender state
const snapshot = await checkpoint.readAndDecrypt(wallet, memoKeypair.privkey);

// Pre-flight safety check (throws if checkpoint is out of sync)
await assertCheckpointMatchesCommit({
  tokenAddr: flow.address,
  signer: wallet,
  memoPrivkey: memoKeypair.privkey,
  localBalance: snapshot!.balance,
  localBlinding: snapshot!.blinding,
});

// Transfer
const sendResult = await flow.shieldedTransfer({
  recipient:       "0xBobEVMAddress",
  amount:          25n * 10n**18n,
  memo:            'test tip',
  currentBalance:  snapshot!.balance,
  currentBlinding: snapshot!.blinding,
}, wallet);

console.log("Transfer TX:", sendResult.txHash);

// Update sender checkpoint
await checkpoint.update(flow.address, sendResult.checkpointPayload!, 0n, wallet);

// Recipient drains inbox
const inbox = new ShieldedInboxClient();
const { decrypted } = await inbox.drainAndDecrypt(bobWallet, bobMemoPrivkey);
console.log("Bob received:", decrypted[0]?.content.amount);
```

## Step 6: Register in your SDK config

```typescript
// config/openjanus.ts
export const MY_TOKEN_ADDR = "0xYourDeployedJanusTokenAddress";
export const NETWORK = "testnet" as const;
```

## Step 7: Add to flow.json (if building a Cadence wrapper)

If you want to build a Cadence contract that interacts with your JanusToken instance (similar to JanusFlow), add the EVM address as a constant in your Cadence contract:

```cadence
// YourWrapper.cdc
let janusTokenEVM: EVM.EVMAddress = EVM.addressFromString("0xYourDeployedJanusTokenAddress")
```

## ShieldedCheckpoint and ShieldedInbox notes

- **ShieldedCheckpoint** (`0x88C9fD443BC15d1Cd24bc724DB6928D3246b2E26`) is per-user, per-token.
  Always pass the token address as the first argument to `update()` and `read()`.
  Re-deployed 2026-06-11 to support multi-token (v0.8.2).
- **ShieldedInbox** (`0x0C787AAcbA9a116EdA4ec05Be41D8474D470bfC6`) is shared across all tokens.
  Recipients drain with `ShieldedInboxClient.drainAndDecrypt()` — no event scanning needed.
- **batchClaim** — if recipient has >= 2 notes, use `BatchClaimClient.buildAndClaim()` to
  consolidate up to N=10 notes into a single Groth16 proof (ClaimBatchVerifier pot22 ceremony).

## Troubleshooting

**"execution reverted" on wrap** — Check that the ERC-20 `approve` call went through before `wrap`.

**"computation exceeds limit"** — This can happen if you add extra operations in the same transaction as `shieldedTransfer`. Keep transfers atomic.

**verifyProof returns false** — Check that you are using the correct zkey (matching the canonical `ConfidentialTransferVerifier` address at `0x38e69fE7Ba7c2C586d64DFFc14742641A675666c`). If you redeployed the verifier with a different zkey, update the verifier address in the constructor.

**Checkpoint divergence error** — `assertCheckpointMatchesCommit` threw because the local balance/blinding does not match what's on-chain. The user likely missed a `checkpoint.update()` call after a previous transfer. Recover via `ShieldedInboxClient.drain()` + `isFreshSlotCommit()` detection.
