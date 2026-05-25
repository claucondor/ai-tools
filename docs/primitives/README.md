# Primitives

Low-level cryptographic building blocks for OpenJanus.

| File | Contents |
|------|----------|
| [babyjub.md](babyjub.md) | BabyJubJub elliptic curve — constants, curve operations, on-chain contract |
| [pedersen.md](pedersen.md) | Pedersen commitments — packing format, homomorphic ops, on-chain contract |
| [groth16.md](groth16.md) | Groth16 proofs — circuit description, proof generation, verification, pi_b swap |

For most app development, use the SDK facade (`@openjanus/sdk/crypto`) rather than these primitives directly.
