# Groth16 Proof Primitive — @openjanus/groth16

OpenJanus uses Groth16 zero-knowledge proofs (via snarkJS) to verify confidential transfers on-chain.

## The ConfidentialTransfer circuit

The circuit proves conservation of value across a shielded transfer. It uses `@openjanus/commitment` commitments — the same `Commit(v, r) = [v]·G + [r]·H` scheme.

```
Given public:  C_old, C_tx, C_new  (commitment x/y pairs — 6 field elements)
Given private: old_value, old_blinding, transfer_value, transfer_blinding, new_blinding

Prove that:
  C_old = Commit(old_value, old_blinding)
  C_tx  = Commit(transfer_value, transfer_blinding)
  C_new = Commit(old_value - transfer_value, new_blinding)
  old_value >= transfer_value   (range check — no overdraft)
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

Passing signals in the wrong order causes `verifyProof` to return `false` silently.

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

## Off-chain proof generation

```typescript
import { prove, proveForEVM, verifyLocally } from "@openjanus/groth16";

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
// proofUint256 is ready for on-chain submission — pi_b swap is applied automatically

// Verify locally (no network, fast)
const vk = JSON.parse(fs.readFileSync("./circuits/verification_key.json", "utf8"));
const ok = await verifyLocally(vk, rawProof, publicSignals);
```

## On-chain verification

```typescript
import { verifyOnChain } from "@openjanus/groth16";

const valid = await verifyOnChain(rawProof, publicSignals, {
  rpc: "https://testnet.evm.nodes.onflow.org",
  address: "0x0085F286d89af79EC59E27CD0c5CcD1c55f42Cf5",
});
```

`verifyOnChain` automatically applies `applyPiBSwap` before calling the verifier.

## The pi_b Fp2 swap — critical

> **WARNING: silent correctness bug.** Without this swap, `verifyProof` returns `false` for every valid proof, with no error or revert.

snarkJS outputs `pi_b` in `(re, im)` order. EIP-197 expects `(im, re)`. Swapping the inner coordinate pair of each Fp2 element corrects the encoding.

```typescript
import { applyPiBSwap } from "@openjanus/groth16";

const { pA, pB, pC } = applyPiBSwap(rawSnarkProof);
// pB is now in EIP-197 order — safe to pass to verifyProof
```

Every path that submits a proof on-chain must go through `applyPiBSwap`. `proveForEVM` and `verifyOnChain` handle this automatically. Manual callers must not skip it.

Full diagnostic and explanation: [pi-b-fp2-swap.md](pi-b-fp2-swap.md).

## Circuit artifacts

See [../../../openjanus-deploy/references/circuit-artifacts.md](../../../openjanus-deploy/references/circuit-artifacts.md) for where to find the WASM and zkey files.

## Proof generation time

| Environment | Approximate time |
|-------------|-----------------|
| M1/M2 Mac (Node.js) | 8–15 seconds |
| Linux server (Node.js) | 10–30 seconds |
| Browser (WASM) | 20–60 seconds |

Run proof generation in a Web Worker in browser environments to avoid blocking the UI.

## Relationship to @openjanus/commitment

The circuit inputs — `C_old`, `C_tx`, `C_new` — are commitment points produced by `@openjanus/commitment`. The circuit uses the same G and H generator constants. Off-chain flow:

1. Compute commitments with `@openjanus/commitment` — `commit(v, r)`
2. Generate proof with `@openjanus/groth16` — `proveForEVM(inputs, { wasmPath, zkeyPath })`
3. Submit proof + public signals on-chain to `ConfidentialTransferVerifier.sol`
