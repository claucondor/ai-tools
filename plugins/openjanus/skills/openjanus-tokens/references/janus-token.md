# JanusToken — ElGamal Confidential Balance Contract

JanusToken uses additive ElGamal-on-BabyJubJub for genuine multi-sender privacy: multiple senders encrypt to the same recipient pubkey independently, and ciphertexts accumulate homomorphically. The recipient decrypts the total without learning per-sender amounts.

## Deployed addresses (testnet) — v0.2.0 (2026-05-26, ceremony-backed)

Trusted setup: Hermez pot14 (200+ contributors) + Flow VRF beacon
(testnet block 323555648).

| Contract | Address |
|----------|---------|
| `JanusToken.sol` | `0xb12E600fFcde967210cFD81CF9f32bBB6e68a499` |
| `EncryptConsistencyVerifier` | `0x0C1e731036f4632CF9620bf6C6BB8204eD3a3B1e` |
| `DecryptOpenVerifier` | `0x1c248dA94aab9f4A03005E7944a8b745a6236Dbc` |
| `BabyJub.sol` (lab) | `0x27139AFda7425f51F68D32e0A38b7D43BcB0f870` |

E2E validation: 27/27 tests PASS against v0.2.0 deployment (2026-05-26).

> **Deprecated v0.1.0 addresses (single-contributor lab setup — DO NOT USE):**
> JanusToken `0xC715b3647536F671Aa25A6B6Ea1d7f5a0b9fA63D`,
> EncryptConsistencyVerifier `0x6F8Cc93dd6aA7B3ED0a3DaA75271815558ad9b5C`,
> DecryptOpenVerifier `0x3bB139B5404fD6b152813bC3532367AAa096638b`

## Core architecture

### ElGamal slot format

`slot = (C1, C2) = accumulated(r_i*G, m_i*G + r_i*PK)` — two points. The slot is the point-wise sum of all incoming ciphertexts. Only the holder of `sk` (where `PK = sk*G`) can decrypt.

### Slot lifecycle

```
1. registerPubkey(pkx, pky)     — one-time, before first receive
2. encryptTo(recipient, ct, ∏)  — sender wraps FLOW + encrypts to recipient
   OR confidentialTransfer(...)  — sender-to-sender within JanusToken
3. getSlotRaw(account)           — read accumulated (c1x, c1y, c2x, c2y)
4. decryptAndUnwrap(to, amount, ∏) — prove decryption, release FLOW
```

### Cryptographic primitives

**Encrypt-consistency proof** — a Groth16 proof that the ciphertext `(c1, c2) = (r*G, m*G + r*PK)` was constructed correctly with the claimed value `m` and recipient pubkey `PK`. Prevents the sender from encrypting garbage.

**Decrypt-open proof** — a Groth16 proof that the decryption is correct: `M = C2 - sk*C1 = m*G`. Prevents the recipient from claiming a different amount than the accumulated total.

**BSGS solver** — Baby-Step Giant-Step algorithm to solve `M = m*G` for `m` given the accumulated point `M`. Practical for amounts up to ~10 million. In `@openjanus/elgamal/bsgs`.

## Solidity interface

```solidity
interface IJanusToken {
    // One-time setup
    function registerPubkey(uint256 pkx, uint256 pky) external;
    function pubkeyOf(address account) external view returns (uint256 pkx, uint256 pky);
    function hasPubkey(address account) external view returns (bool);

    // Slot reads
    function getSlotRaw(address account)
        external view returns (uint256 c1x, uint256 c1y, uint256 c2x, uint256 c2y);

    // Encrypt + accumulate (wrap FLOW)
    function encryptTo(
        address recipient,
        uint256 c1x, uint256 c1y, uint256 c2x, uint256 c2y,
        uint256[8] calldata proof,
        uint256[6] calldata pubInputs
    ) external payable;

    // Confidential transfer (slot-to-slot)
    function confidentialTransfer(
        address recipient,
        uint256 c1x, uint256 c1y, uint256 c2x, uint256 c2y,
        uint256[8] calldata encProof,
        uint256[6] calldata encPubInputs
    ) external;

    // Decrypt and release FLOW
    function decryptAndUnwrap(
        address to,
        uint256 amount,
        uint256[8] calldata proof,
        uint256[5] calldata pubInputs
    ) external;

    // Events
    event PubkeyRegistered(address indexed account, uint256 pkx, uint256 pky);
    event SlotUpdated(address indexed account, uint256 c1x, uint256 c1y, uint256 c2x, uint256 c2y);
    event Unwrapped(address indexed account, address indexed to, uint256 amount);
}
```

## Public inputs format

### EncryptConsistencyVerifier public inputs (uint256[6])

```
[c1x, c1y, c2x, c2y, pkx, pky]
```

Where `(c1x, c1y)` = r*G, `(c2x, c2y)` = m*G + r*PK, `(pkx, pky)` = recipient PK.

### DecryptOpenVerifier public inputs (uint256[5])

```
[c1x, c1y, c2x, c2y, amount]
```

Where `(c1x,c1y)` and `(c2x,c2y)` are the accumulated slot values and `amount` is the claimed plaintext.

## Common pitfalls

**P1 — Registering pubkey with a point not on BabyJubJub.**
`registerPubkey` should validate the point is on-curve. If not, `encryptTo` will compute incorrect ciphertexts that can never be decrypted. Always derive pubkeys via `sk * G` with a valid scalar.

**P2 — Claiming wrong amount in decryptAndUnwrap.**
The DecryptOpenVerifier circuit will reject any `amount` that doesn't satisfy `amount*G = C2 - sk*C1`. Use the BSGS solver to determine the correct amount before generating the proof.

**P3 — Fixed-array verifier interface mismatch.**
snarkjs generates verifiers with `uint[N]` (fixed arrays). Your interface declaration must match exactly — `uint[6]` not `uint[] calldata`. Selector mismatch causes silent revert. See vuln/013.

**P4 — Not calling registerPubkey before first receive.**
If an account tries to call `encryptTo` targeting an account with no registered pubkey, the transaction reverts. Recipients must register their pubkey once before they can receive encrypted amounts.

## Technical characteristics

| Aspect | JanusToken |
|--------|-----------|
| Slot type | `(c1x, c1y, c2x, c2y)` ElGamal ciphertext |
| Multi-sender privacy | Yes |
| Blinding factor needed | No (randomness is ephemeral in proof) |
| Pubkey registration | Yes (one-time per recipient) |
| Decrypt mechanism | BSGS (up to ~10M) |
| ZK proofs | EncryptConsistency + DecryptOpen |

## See also

- [janus-flow.md](janus-flow.md) — Cadence cross-VM wrapper for JanusToken
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — TypeScript SDK quick start
- [../../../openjanus-sdk/references/decrypt-flow.md](../../../openjanus-sdk/references/decrypt-flow.md) — Decryption and BSGS guide
- [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md) — All deployed addresses
