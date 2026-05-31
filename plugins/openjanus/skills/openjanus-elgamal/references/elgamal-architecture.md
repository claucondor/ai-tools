# ElGamal-on-BabyJubJub Architecture

This document describes the cryptographic architecture of the OpenJanus ElGamal stack: how ciphertexts are structured, how they accumulate, and how the on-chain contracts enforce correctness.

## Cryptographic primitives used

| Primitive | Role |
|-----------|------|
| BabyJubJub (twisted Edwards) | Underlying elliptic curve |
| Additive ElGamal | Encryption scheme |
| Groth16 (snarkjs) | ZK proofs for encrypt-consistency and decrypt-open |
| BSGS (Baby-Step Giant-Step) | Discrete log solver for decryption |
| BN254 scalar field | Field for BabyJubJub operations |

## Ciphertext structure

A single encryption of amount `m` to public key `PK = sk * G`:

```
Encrypt(m, r, PK):
  c1 = r * G            ← ephemeral key (BabyJubJub point)
  c2 = m * G + r * PK  ← masked message (BabyJubJub point)

Ciphertext = (c1, c2) = two BabyJubJub points = four uint256 values on-chain
             (c1x, c1y, c2x, c2y)
```

`r` is ephemeral randomness generated per-encryption. It never appears on-chain.

## Homomorphic accumulation

The slot in `JanusToken` stores the **accumulated** ciphertext from all senders:

```
Initial slot: identity = ((0,1), (0,1))

After sender A encrypts m_A with randomness r_A:
  slot = (r_A*G, m_A*G + r_A*PK)

After sender B encrypts m_B with randomness r_B:
  slot += (r_B*G, m_B*G + r_B*PK)
       = ((r_A+r_B)*G, (m_A+m_B)*G + (r_A+r_B)*PK)
```

The accumulated slot decrypts to `m_A + m_B`. Individual amounts `m_A` and `m_B` are
unrecoverable from the slot without knowing all individual randomnesses, which stay off-chain.

## Slot lifecycle in JanusToken

```
1. registerPubkey(pkx, pky)   — one-time, stores PK = (pkx, pky)
2. encryptTo(recipient, ct, proof)  — accumulates ct into recipient's slot
   → requires encrypt-consistency proof
3. getSlotRaw(account)        — read (c1x, c1y, c2x, c2y)
4. decryptAndUnwrap(to, amount, proof) — empties slot, releases FLOW
   → requires decrypt-open proof
```

## ZK proof system

### Encrypt-consistency proof (EncryptConsistencyVerifier)

Proves that the submitted ciphertext `(c1, c2)` was correctly constructed with:
- `c1 = r * G` for some private `r`
- `c2 = m * G + r * PK` for the claimed public key `PK` and amount `m`

**Public inputs (uint256[6]):** `[c1x, c1y, c2x, c2y, pkx, pky]`

Without this proof, a sender could submit a garbage ciphertext that encrypts the wrong amount
or is undecryptable.

### Decrypt-open proof (DecryptOpenVerifier)

Proves that the decryption is correct:
- Claimer knows `sk` such that `PK = sk * G`
- The claimed `amount` satisfies `amount * G = C2 - sk * C1`

**Public inputs (uint256[5]):** `[c1x, c1y, c2x, c2y, amount]`

Without this proof, anyone could claim an arbitrary amount from any slot.

## IND-CPA security

The scheme is IND-CPA secure under the Decisional Diffie-Hellman (DDH) assumption on BabyJubJub.
An adversary who cannot solve DDH cannot distinguish the ciphertext of `m_0` from the
ciphertext of `m_1` given only the public key `PK`.

**Caveats:**
- Amount privacy holds; sender address is public on-chain
- Small amounts susceptible to BSGS guessing with known range (this is by design — BSGS is the
  intended decryption mechanism; adversarial BSGS with unknown range is infeasible for large maxValue)

## Comparison to v1 Pedersen scheme

| Aspect | v1 Pedersen | v2 ElGamal |
|--------|------------|------------|
| Slot type | `m*G + r*H` (single point) | `(r*G, m*G + r*PK)` (two points) |
| Recipient key | None | BabyJubJub keypair |
| Multi-sender | Privacy fails | Privacy holds |
| Accumulation | Point addition | Point addition (both components) |
| Decryption | Brute force | BSGS |
| Proof types | ConfidentialTransfer | EncryptConsistency + DecryptOpen |

## On-chain slot encoding

```solidity
// Stored per account in JanusToken
struct Slot {
    uint256 c1x;
    uint256 c1y;
    uint256 c2x;
    uint256 c2y;
}

// Identity slot (empty / zero balance)
c1x = 0, c1y = 1   ← identity point on BabyJubJub
c2x = 0, c2y = 1
```

## ShieldedNote — dual use: tip memo AND recovery snapshot

`ShieldedNote` is the ECIES payload type (BabyJubJub ECDH + AES-GCM) used for
two distinct purposes:

| Purpose | Encrypted to | Payload |
|---------|-------------|---------|
| Tip memo | **Recipient's** MemoKey pubkey | `{ amount, blinding, data: memoText }` |
| Recovery snapshot | **Sender's own** MemoKey pubkey | `{ balance, blinding }` (absolute state post-action) |

**Tip memo** lets the recipient decrypt the tip amount and blinding scalar needed
to generate the unwrap proof.

**Recovery snapshot** is encrypted to the SENDER's own pubkey
and embedded in the `*WithSnapshot` EVM events (`WrapWithSnapshot`,
`ShieldedTransferWithSnapshot`, `UnwrapWithSnapshot`). The `@claucondor/sdk/recovery`
module scans these events and decrypts with the user's MemoKey privkey to
reconstruct state on any device.

Both use the same underlying ECIES primitive (`encryptSnapshotToSelf` for
self-encryption, `encryptNote` for recipient-encryption), but carry different
payloads and serve different recovery paths.

## See also

- `keypair-derivation.md` — How to derive BabyJubJub keypairs from Flow account key material
- `sign-derive.md` — Deterministic MemoKey keypair from wallet signature
- `../openjanus-sdk/references/recovery.md` — Full recovery module reference
- `../openjanus-sdk/references/decrypt-flow.md` — BSGS decryption implementation
- `../openjanus-tokens/references/janus-token.md` — Full Solidity interface
