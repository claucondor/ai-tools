# Which Primitive Should I Use?

Use this decision tree to choose the right OpenJanus primitive for your use case.

## Decision tree

```
Are you hiding token amounts?
├── Yes — Do multiple senders deposit to the same recipient?
│   ├── Yes → Use ElGamal-on-BabyJubJub (current stack, RECOMMENDED)
│   │         JanusToken + JanusFlow in @openjanus/sdk/tokens
│   │         ├── Need to prove encryption is correct? → EncryptConsistencyVerifier
│   │         └── Need to prove decryption is correct? → DecryptOpenVerifier
│   │
│   └── No (single sender) → Pedersen commitments (v1 stack, simpler)
│         computeCommitment in @openjanus/sdk/crypto
│         ├── Need on-chain proof? → Also use Groth16 + ConfidentialTransferVerifier
│         └── No proof needed? → Pedersen only
│
├── No — Are you doing elliptic curve math on BabyJubJub?
│   ├── Point addition, negation, curve checks? → Use BabyJubJub primitive
│   └── Key pairs, signatures? → BabyJubJub is not the right curve for signatures
│                                (use ECDSA on secp256k1 or P-256 via Cadence Crypto API)
│
└── No — Are you verifying a ZK proof on-chain?
    └── Yes → Groth16 + appropriate verifier:
              v1 transfers → ConfidentialTransferVerifier
              encrypt   → EncryptConsistencyVerifier
              decrypt   → DecryptOpenVerifier
              (or deploy a custom verifier for your circuit)
```

## Quick lookup

| I want to... | Use |
|-------------|-----|
| **multi-sender encrypt to recipient pubkey** | ElGamal (JanusToken, `@openjanus/sdk/tokens`) |
| **prove ciphertext encrypts m to PK correctly** | EncryptConsistencyVerifier + `buildEncryptProof` |
| **prove decryption is correct** | DecryptOpenVerifier + `buildDecryptProof` |
| **recover plaintext from accumulated slot** | BSGS solver (`bsgsRecover`) |
| **register pubkey for receiving** | `registerPubkey` on JanusToken/JanusFlow |
| v1: Commit to an amount so observers can't read it | Pedersen |
| v1: Prove "my balance is sufficient" without revealing it | Groth16 + circuit |
| Add two commitments homomorphically (v1) | Pedersen (`addCommitmentsLocal`) |
| Add two ciphertexts homomorphically | ElGamal point addition (automatic in contract) |
| Check if a commitment is zero (v1) | `isIdentityCommitment(c)` |
| Check if a ciphertext slot is empty | `c1 == (0,1) && c2 == (0,1)` |
| Verify a v1 ZK proof in Solidity | `ConfidentialTransferVerifier.sol` |
| Verify a encrypt proof in Solidity | `EncryptConsistencyVerifier.sol` |
| Verify a decrypt proof in Solidity | `DecryptOpenVerifier.sol` |
| Verify a ZK proof from Cadence (no state change) | `EVM.dryCall` to verifier |
| Do BabyJubJub point math in TypeScript | `@openjanus/sdk/primitives` babyjub |
| Do BabyJubJub point math on-chain | `BabyJub.sol` |
| Generate a v1 transfer proof | `buildTransferProof` |
| Generate a encrypt proof | `buildEncryptProof` (from `@openjanus/elgamal`) |

## When to use the SDK vs primitives directly

| Situation | Recommendation |
|-----------|---------------|
| Building an app | Use `@openjanus/sdk` — facade handles encoding, pi_b swap, error handling |
| Building a new circuit | Use primitives directly — you need raw access to constraint inputs |
| Building another contract on top of JanusToken | Use the Solidity interface directly |
| Writing Cadence integration tests | Use primitives for data setup, SDK for high-level operations |

## I just need the deployed addresses

See [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md).
