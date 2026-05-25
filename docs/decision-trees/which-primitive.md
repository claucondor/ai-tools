# Which Primitive Should I Use?

Use this decision tree to choose the right OpenJanus primitive for your use case.

## Decision tree

```
Are you hiding token amounts?
├── Yes → Use Pedersen commitments (via @openjanus/sdk/crypto)
│         ├── Need to prove knowledge of the committed value? → Also use Groth16
│         └── Just hiding amounts, no on-chain proof needed? → Pedersen only
│
├── No — Are you doing elliptic curve math on BabyJubJub?
│   ├── Point addition, negation, curve checks? → Use BabyJubJub primitive
│   └── Key pairs, signatures? → BabyJubJub is not the right curve for signatures
│                                (use ECDSA on secp256k1 or P-256 via Cadence Crypto API)
│
└── No — Are you verifying a ZK proof on-chain?
    └── Yes → Groth16 + ConfidentialTransferVerifier
              (or deploy a custom verifier for your circuit)
```

## Quick lookup

| I want to... | Use |
|-------------|-----|
| Commit to an amount so observers can't read it | Pedersen |
| Prove "my balance is sufficient" without revealing it | Groth16 + circuit |
| Add two commitments homomorphically | Pedersen (`addCommitmentsLocal`) |
| Check if a commitment is zero | `isIdentityCommitment(c)` |
| Verify a ZK proof in Solidity | `ConfidentialTransferVerifier.sol` |
| Verify a ZK proof from Cadence (no state change) | `EVM.dryCall` to verifier |
| Do BabyJubJub point math in TypeScript | `@openjanus/sdk/primitives` babyjub |
| Do BabyJubJub point math on-chain | `BabyJub.sol` |
| Generate a transfer proof | `buildTransferProof` |

## When to use the SDK vs primitives directly

| Situation | Recommendation |
|-----------|---------------|
| Building an app | Use `@openjanus/sdk` — facade handles encoding, pi_b swap, error handling |
| Building a new circuit | Use primitives directly — you need raw access to constraint inputs |
| Building another contract on top of JanusToken | Use the Solidity interface directly |
| Writing Cadence integration tests | Use primitives for data setup, SDK for high-level operations |

## I just need the deployed addresses

See [../deployments/canonical-addresses.md](../deployments/canonical-addresses.md).
