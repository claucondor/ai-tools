# V1 vs V2 — Which Stack Should I Use?

Use this decision tree to choose between JanusToken/JanusFlow (v1) and JanusTokenV2/JanusFlowV2 (v2).

## Decision tree

```
Are you starting a new project?
├── Yes → Use v2 (ElGamal) — stronger privacy, no backward compat needed
│
└── No — Do you have an existing v1 deployment with live user slots?
    ├── Yes → Keep using v1 — no migration path for live slots
    │         (new features can be v2 if deployed in a new contract)
    │
    └── No — Are multiple senders depositing to the same recipient?
        ├── Yes → Use v2 — v1 privacy fails with multi-sender
        └── No (single sender only) → Either works; v1 simpler if < 10k amounts
```

## Quick lookup

| Scenario | Recommendation |
|----------|---------------|
| New app (tipping, donations, payroll) | v2 |
| PrivateTip (canonical v2 use case) | v2 |
| Existing app upgrade | Keep v1, add v2 contract in parallel |
| Single sender wraps, single recipient unwraps | v1 or v2 |
| Multiple senders, shared recipient | v2 mandatory |
| Amount range > 10,000 FLOW | v2 (BSGS handles it; v1 brute-force slow) |
| Amount range < 10,000 FLOW | Either (v1 brute-force still fast) |
| Need blinding-factor-free sender flow | v2 only |

## Key differences table

| Aspect | v1 (Pedersen) | v2 (ElGamal) |
|--------|--------------|-------------|
| Module | `tokens/` | `tokens-v2/` |
| Classes | `JanusToken`, `JanusFlow` | `JanusTokenV2`, `JanusFlowV2` |
| Slot format | `(x, y)` — single EC point | `(c1x, c1y, c2x, c2y)` — two EC points |
| Multi-sender privacy | **Fails** — slot reveals contributions | **Holds** — ECDH encryption |
| Keypair setup | None | `registerPubkey()` once per account |
| Sender blinding factor | Required (sender stores per-transfer) | Not needed (ephemeral randomness in proof) |
| Recipient decrypt | Brute-force (O(n)) — small amounts only | BSGS (O(sqrt(n))) — up to ~10M |
| ZK proofs | ConfidentialTransferVerifier | EncryptConsistency + DecryptOpen |
| EVM gas (verify) | ~250k | ~300k |
| Cadence CU | Near 9999 | Near 9999 |
| Deployed contract (testnet) | `0x53F49881A1132FF4F674D2c015e35D5B07Fa1F4A` | `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D` |

## Why v1 multi-sender privacy fails

In v1, the balance slot is `C = m*G + r*H` (Pedersen commitment). When Alice receives tips from Bob (10 FLOW) and Carol (25 FLOW), the slot goes:

```
initial:    C = 0*G + 0*H = identity
after Bob:  C = 10*G + rBob*H
after Carol: C = (10+25)*G + (rBob + rCarol)*H
```

Bob's commitment `10*G + rBob*H` is visible in the event log. Carol's commitment `25*G + rCarol*H` is visible too. Alice (or any observer) can compute: `C_final - C_after_bob = 25*G + rCarol*H` — a commitment to 25, which with brute-force gives Carol's exact amount.

In v2, the slot accumulates as ElGamal ciphertexts:

```
(C1, C2) += (rBob*G, 10*G + rBob*PK)
(C1, C2) += (rCarol*G, 25*G + rCarol*PK)
Slot:       (C1, C2) = ((rBob+rCarol)*G, 35*G + (rBob+rCarol)*PK)
```

Without the secret key, `C1` and `C2` reveal nothing about the split. The ephemeral randomnesses `rBob` and `rCarol` are never on-chain.

## SDK imports side-by-side

```typescript
// v1
import { JanusToken, JanusFlow, JANUS_TOKEN_TESTNET } from "@openjanus/sdk";
import { computeCommitment, generateBlinding } from "@openjanus/sdk";

// v2
import { JanusTokenV2, JanusFlowV2, JANUS_TOKEN_V2_TESTNET } from "@openjanus/sdk";
import { buildEncryptProof, buildDecryptProof, bsgsRecover } from "@openjanus/elgamal";
```

Both stacks are exported from `@openjanus/sdk`. V1 exports are unchanged (additive only).

## I want to migrate an existing v1 app to v2

There is no automatic slot migration. v1 and v2 slots are incompatible (Pedersen point vs ElGamal ciphertext). Options:

1. **Parallel deployment**: Deploy a new JanusTokenV2/JanusFlowV2 contract. Run both simultaneously. Encourage users to unwrap from v1 and re-deposit into v2.

2. **New-user-only migration**: Keep v1 for existing users. Route all new registrations to v2.

3. **Operator migration**: If you control the token (NATIVE mode), `burnXY` all v1 slots and `encryptTo` the same amounts in v2 on behalf of users (requires their authorization).

## See also

- [which-primitive.md](which-primitive.md) — Choosing the cryptographic primitive
- [../sdk/v2-quickstart.md](../sdk/v2-quickstart.md) — V2 SDK quick start
- [../contracts/janus-token-v2.md](../contracts/janus-token-v2.md) — V2 contract reference
- [../patterns/confidential-tipping-v2.md](../patterns/confidential-tipping-v2.md) — V2 tipping pattern
