# Groth16 Proof Primitive

OpenJanus uses Groth16 zero-knowledge proofs (via snarkJS) to verify confidential transfers on-chain.

## The ConfidentialTransfer circuit

The circuit proves:

```
Given public: C_old, C_tx, C_new (as commitment x/y pairs)
Given private: old_value, old_blinding, transfer_value, transfer_blinding, new_blinding

Prove that:
  C_old = Pedersen(old_value, old_blinding)
  C_tx  = Pedersen(transfer_value, transfer_blinding)
  C_new = Pedersen(old_value - transfer_value, new_blinding)
  old_value >= transfer_value  (range check)
```

The circuit has 6 public outputs and no private outputs visible on-chain.

## Public signal ordering

The on-chain verifier expects signals in this order (matching the circuit declaration):

```
[0] old_commit.x
[1] old_commit.y
[2] transfer_commit.x
[3] transfer_commit.y
[4] new_commit.x
[5] new_commit.y
```

## On-chain verifier

| Network | Address |
|---------|---------|
| Flow EVM testnet | `0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5` |

```solidity
function verifyProof(
    uint256[2] calldata _pA,
    uint256[2][2] calldata _pB,
    uint256[2] calldata _pC,
    uint256[6] calldata _pubSignals
) public view returns (bool);
```

## Off-chain proof generation (SDK)

```typescript
import { prove, proveForEVM, verifyLocally } from "@claucondor/sdk/primitives";

// Generate a raw snarkJS proof
const { proof, publicSignals } = await prove(circuitInput, {
  wasmPath: "./circuits/confidentialTransfer.wasm",
  zkeyPath: "./circuits/confidentialTransfer_final.zkey",
});

// Generate and EVM-encode in one call (recommended)
const { rawProof, evmProof, proofUint256, publicSignals: sigs } = await proveForEVM(
  circuitInput,
  { wasmPath, zkeyPath }
);
// proofUint256 is ready for on-chain submission

// Verify locally (no network, fast)
const vk = JSON.parse(fs.readFileSync("./circuits/verification_key.json", "utf8"));
const ok = await verifyLocally(vk, rawProof, publicSignals);
```

## On-chain verification (SDK)

```typescript
import { verifyOnChain } from "@claucondor/sdk/primitives";

const valid = await verifyOnChain(rawProof, publicSignals, {
  rpc: "https://testnet.evm.nodes.onflow.org",
  address: "0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5",
});
```

`verifyOnChain` automatically applies `applyPiBSwap` before calling the verifier.

## The pi_b Fp2 swap — critical

snarkJS outputs `pi_b` in `(re, im)` order. EIP-197 expects `(im, re)`. Without the swap, `verifyProof` returns `false` for every valid proof — silently.

```typescript
import { applyPiBSwap } from "@claucondor/sdk/utils";

const { pA, pB, pC } = applyPiBSwap(rawSnarkProof);
```

Every path that submits a proof on-chain must go through `applyPiBSwap`. `proveForEVM` and `verifyOnChain` handle this automatically. See [pi-b-fp2-swap.md](pi-b-fp2-swap.md) for the full explanation.

## Circuit artifacts

See [../../../openjanus-deploy/references/circuit-artifacts.md](../../../openjanus-deploy/references/circuit-artifacts.md) for where to find the WASM and zkey files.

## Proof generation time

| Environment | Approximate time |
|-------------|-----------------|
| M1/M2 Mac (Node.js) | 8-15 seconds |
| Linux server (Node.js) | 10-30 seconds |
| Browser (WASM) | 20-60 seconds |

Run proof generation in a Web Worker in browser environments to avoid blocking the UI.
