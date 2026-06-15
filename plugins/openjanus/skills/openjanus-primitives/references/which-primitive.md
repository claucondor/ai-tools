# Which Primitive Should I Use?

Use this decision tree to choose the right OpenJanus primitive for your use case.

## Decision tree

```
Are you hiding token amounts on-chain (JanusFlow / shielded balances)?
├── Yes → Use @openjanus/commitment + @openjanus/groth16 (CURRENT STACK, v0.2.0)
│         commit(v, r) off-chain → accumulate addCommits() on-chain
│         ├── Wrap / unwrap boundary proof? → AmountDiscloseVerifier + buildAmountDiscloseProof
│         └── Shielded transfer proof? → ConfidentialTransferVerifier + buildShieldedTransferProof
│
├── Are you encrypting a memo / recovery snapshot? (ECIES layer)
│   └── Yes → ElGamal-on-BabyJub — see openjanus-elgamal skill
│             (historic/lab — not used in v0.8.2 production stack)
│
├── Are you doing elliptic curve math on BabyJubJub?
│   ├── Point addition, negation, on-chain checks? → @openjanus/babyjub
│   └── Key pairs, signatures? → BabyJubJub is not the right curve for signatures
│                                (use ECDSA on secp256k1 or P-256 via Cadence Crypto API)
│
├── Are you verifying a ZK proof on-chain?
│   └── Yes → @openjanus/groth16 + appropriate verifier:
│             wrap/unwrap → AmountDiscloseVerifier
│             transfer    → ConfidentialTransferVerifier
│             (or deploy a custom verifier for your circuit)
│
└── Are you building a UTXO note model?
    └── Yes → @openjanus/utxo (deferred to v2+ — scaffold only, not production)
```

## Package status table

| Use case | Package | Status |
|----------|---------|--------|
| Amount-privacy: commit to token amount | `@openjanus/commitment` | **production (v0.2.0)** |
| Homomorphic accumulation of commitments | `@openjanus/commitment` | **production (v0.2.0)** |
| Groth16 proof generation + EVM encoding | `@openjanus/groth16` | **production** |
| BabyJubJub point ops (TypeScript + on-chain) | `@openjanus/babyjub` | **production** |
| ElGamal-style encrypted state | `@openjanus/elgamal` | experimental/lab (not used in v0.8.2) |
| UTXO note model | `@openjanus/utxo` | experimental, deferred to v2+ |
| circomlib windowed Pedersen hash | `@openjanus/pedersen` | **deprecated** → use commitment |

## Quick lookup

| I want to... | Use |
|-------------|-----|
| **Commit to an amount (hiding it on-chain)** | `@openjanus/commitment` — `commit(v, r)` |
| **Add two commitments homomorphically** | `@openjanus/commitment` — `addCommits(c1, c2)` |
| **Subtract commitments (transfer balance)** | `@openjanus/commitment` — `subCommits(c1, c2)` |
| **Check if a commitment is zero** | `@openjanus/commitment` — `isIdentity(c)` |
| **Wrap / unwrap FLOW with hidden amount** | JanusFlow + `buildAmountDiscloseProof` |
| **Shielded transfer (amount hidden end-to-end)** | JanusFlow + `buildShieldedTransferProof` |
| **Generate a Groth16 proof off-chain** | `@openjanus/groth16` — `prove`, `proveForEVM` |
| **Verify a Groth16 proof on-chain (Solidity)** | `AmountDiscloseVerifier.sol` / `ConfidentialTransferVerifier.sol` |
| **Verify a ZK proof from Cadence (no state change)** | `EVM.dryCall` to verifier |
| **BabyJubJub point math in TypeScript** | `@openjanus/babyjub` — `babyAddOnChain`, `negatePoint` |
| **BabyJubJub point math on-chain** | `BabyJub.sol` via `@openjanus/babyjub` |
| **Encrypt a memo to a recipient** | `@openjanus/elgamal` (lab — not in production path) |
| **UTXO notes** | `@openjanus/utxo` (deferred v2+) |
| Old Pedersen hash (circomlib windowed) | `@openjanus/pedersen` (**deprecated** — migrate to commitment) |

## Why commitment instead of pedersen?

`@openjanus/pedersen` uses the circomlib windowed hash-to-point function. This is a collision-resistant hash, but it is **not** additively homomorphic: `Pedersen(a, r1) + Pedersen(b, r2) ≠ Pedersen(a+b, r1+r2)`.

`@openjanus/commitment` uses the classical 2-generator Pedersen scheme: `Commit(v, r) = [v]·G + [r]·H`. This is homomorphic, which means the on-chain accumulator contract can add commitment points directly without knowing the underlying amounts. This is the property that makes shielded balance accumulation feasible.

## When to use the SDK vs primitives directly

| Situation | Recommendation |
|-----------|---------------|
| Building an app on JanusFlow | Use the SDK facade — it handles encoding, pi_b swap, error handling |
| Building a new circuit | Use primitives directly — you need raw constraint inputs |
| Building another contract on top of JanusToken | Use the Solidity interface directly |
| Writing Cadence integration tests | Use primitives for data setup, SDK for high-level operations |

## I just need the deployed addresses

See [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md).
