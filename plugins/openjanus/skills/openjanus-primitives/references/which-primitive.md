# Which Primitive Should I Use?

Use this decision tree to choose the right OpenJanus primitive for your use case.

## Decision tree

```
Are you hiding token amounts on-chain (JanusFlow)?
├── Yes → Use Pedersen commitments + Groth16 (CURRENT STACK, RECOMMENDED)
│         JanusFlow + JanusToken in @claucondor/sdk/tokens
│         ├── Wrap / unwrap boundary proof? → AmountDiscloseVerifier + buildAmountDiscloseProof
│         └── Shielded transfer proof? → ConfidentialTransferVerifier + buildShieldedTransferProof
│
├── Are you encrypting a tip memo / recovery snapshot? (ECIES layer)
│   └── Yes → encryptText / decryptText from @claucondor/sdk/crypto
│             (BabyJubJub ECDH + AES-GCM — see openjanus-elgamal skill)
│
├── Are you doing elliptic curve math on BabyJubJub?
│   ├── Point addition, negation, curve checks? → Use BabyJubJub primitive
│   └── Key pairs, signatures? → BabyJubJub is not the right curve for signatures
│                                (use ECDSA on secp256k1 or P-256 via Cadence Crypto API)
│
└── Are you verifying a ZK proof on-chain?
    └── Yes → Groth16 + appropriate verifier:
              wrap/unwrap → AmountDiscloseVerifier (0x9c83b2b1...)
              transfer    → ConfidentialTransferVerifier (0x48f791D2...)
              (or deploy a custom verifier for your circuit)
```

> **Deprecated (v0.2):** ElGamal accumulator (`EncryptConsistencyVerifier`,
> `DecryptOpenVerifier`, `buildEncryptProof`, `buildDecryptProof`, `bsgsRecover`,
> `registerPubkey`) — replaced by Pedersen+Groth16 in v0.3. See
> `../../openjanus-sdk/references/migration-v02-to-v03.md`.

## Quick lookup

| I want to... | Use |
|-------------|-----|
| **wrap / unwrap FLOW with hidden amount** | JanusFlow + `buildAmountDiscloseProof` |
| **shielded transfer (amount hidden end-to-end)** | JanusFlow + `buildShieldedTransferProof` |
| **prove commit binds to amount** | AmountDiscloseVerifier + `buildAmountDiscloseProof` |
| **prove sender split commitment correctly** | ConfidentialTransferVerifier + `buildShieldedTransferProof` |
| **encrypt tip memo / snapshot to recipient** | `encryptText` from `@claucondor/sdk/crypto` |
| **derive BabyJub keypair (sign-derive)** | `deriveBabyJubKeypairFromBytes` from `@claucondor/sdk/crypto` |
| Commit to an amount so observers can't read it | Pedersen (`computeCommitment`) |
| Add two commitments homomorphically | Pedersen (`addCommitmentsLocal`) |
| Check if a commitment is zero | `isIdentityCommitment(c)` |
| Verify a wrap/transfer ZK proof in Solidity | `AmountDiscloseVerifier.sol` / `ConfidentialTransferVerifier.sol` |
| Verify a ZK proof from Cadence (no state change) | `EVM.dryCall` to verifier |
| Do BabyJubJub point math in TypeScript | `@claucondor/sdk/primitives` babyjub |
| Do BabyJubJub point math on-chain | `BabyJub.sol` |

## When to use the SDK vs primitives directly

| Situation | Recommendation |
|-----------|---------------|
| Building an app | Use `@claucondor/sdk` — facade handles encoding, pi_b swap, error handling |
| Building a new circuit | Use primitives directly — you need raw access to constraint inputs |
| Building another contract on top of JanusToken | Use the Solidity interface directly |
| Writing Cadence integration tests | Use primitives for data setup, SDK for high-level operations |

## I just need the deployed addresses

See [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md).
