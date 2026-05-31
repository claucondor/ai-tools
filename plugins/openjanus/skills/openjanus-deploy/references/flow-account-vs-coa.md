# Flow Account vs COA — Which Address to Use?

## Two address spaces on Flow

Flow has two distinct address spaces that are easy to confuse:

| Type | Example | Used for |
|------|---------|----------|
| Cadence address | `0xd807a3992d7be612` | FCL transactions, Cadence contracts, JanusFlow API |
| EVM (COA) address | `0x00000000000000000000000250d93efba617e0bf` | JanusToken EVM slot, ethers.js, ERC-20 calls |

A COA (Cadence Owned Account) is an EVM address that is **derived from and controlled by** a Cadence account. The same user has both.

## When to use which

| Operation | Address type | Example |
|-----------|-------------|---------|
| FCL transaction `arg(addr, t.Address)` | Cadence address | `"0xd807a3992d7be612"` |
| `JanusFlow.getCommitment(user:)` | Cadence address | `"0xd807a3992d7be612"` |
| `JanusToken.balanceOfCommitment(address)` | EVM/COA address | `"0x000...0250d93efba617e0bf"` |
| ethers.js contract call `balanceOf(...)` | EVM/COA address | |
| `confidentialTransfer(recipient:)` in Cadence | Cadence address | |

## JanusFlow stores commitments by COA, not Cadence address

JanusFlow's `wrap()` writes to the JanusToken EVM slot keyed by the caller's **COA address**. When reading via `JanusToken.balanceOfCommitment`, you must use the COA address:

```typescript
// Via JanusFlow (Cadence) — use Cadence address
const commit = await sdk.getCommitment("0xd807a3992d7be612");

// Via JanusToken (EVM) — use COA address
const commit = await token.balanceOfCommitment("0x00000000000000000000000250d93efba617e0bf");
```

Both return the same commitment — JanusFlow internally resolves the COA.

## Looking up a COA address

```typescript
import { getCOAAddressOnChain, getKnownCOA } from "@claucondor/sdk/network";

// Known test accounts (fast, no network call)
const coa = getKnownCOA("0xd807a3992d7be612");
// "0x00000000000000000000000250d93efba617e0bf"

// Arbitrary account (requires testnet query)
const coa = await getCOAAddressOnChain("0xd807a3992d7be612", "testnet");
// "0x00000000000000000000000250d93efba617e0bf" or null if no COA
```

## What if a user has no COA?

If a user's Cadence account has no COA, `wrap()` will fail. The user must create a COA first by calling `EVM.createCadenceOwnedAccount()` in a Cadence transaction:

```cadence
import EVM from 0x8c5303eaa26202d6

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        if signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm) == nil {
            let coa <- EVM.createCadenceOwnedAccount()
            signer.storage.save(<-coa, to: /storage/evm)
        }
    }
}
```

In practice, most wallet apps create a COA automatically when the user first interacts with Flow EVM.
