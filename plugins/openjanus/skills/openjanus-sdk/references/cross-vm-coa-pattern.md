# Cross-VM COA Pattern (v0.8)

How the v0.8 OpenJanus stack uses the Cadence Owned Account (COA) to orchestrate
EVM contract calls from Cadence transactions, with attention to the MemoKey resource
and JanusFT.CommitmentRegistry patterns.

## What is a COA?

A COA (Cadence Owned Account) is an EVM address controlled by a Cadence account.
When a Cadence transaction calls `coa.call(...)`, the EVM sees `msg.sender` as the
COA address. All EVM commitment slots in JanusFlow, JanusERC20, and ShieldedCheckpoint
are keyed by the COA EVM address — not the Cadence address directly.

Flow P-256 signing keys cannot derive EOA addresses — the COA is the ONLY valid owner
for upgradeable EVM contracts on Flow.

```
Cadence account 0x4b6bc58bc8bf5dcc
    └── COA EVM addr: 0x0000000000000000000000020885d7ad3582356a
        └── commitments[0x0000...0885d7ad...] = Pedersen(balance, blinding) in JanusFlow
```

## COA lookup

```typescript
import { getCoaEvmAddress, hasCOA } from "@claucondor/sdk";

const coaAddr = await getCoaEvmAddress(myFlowCadenceAddr);
// Throws if no COA — use hasCOA(addr) for soft check

const exists = await hasCOA(myFlowCadenceAddr);
```

SDK exports `KNOWN_COAS` for the deployer COA and `getKnownCOA(cadenceAddr)` for
fast lookup of pre-mapped COA addresses without an RPC call.

## COA call patterns in Cadence templates

The v0.8 `cadenceTx.*` templates use three EVM call patterns:

### 1. `coa.call` — state-changing EVM write

Used in `wrapFlowAtomic` to call both the JanusFlow wrap and ShieldedCheckpoint.update:

```cadence
prepare(signer: auth(BorrowValue) &Account) {
  self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
    ?? panic("no COA at /storage/evm — run setup_coa first")
}

execute {
  // 1. Wrap FLOW via EVM
  let wrapResult = self.coa.call(
    to: janusFlowAddr,
    data: EVM.encodeABIWithSignature("wrap(uint256,uint256,uint256[8])", [...]),
    gasLimit: 400000,
    value: EVM.Balance(attoflow: wrapAmountAttoflow)
  )
  assert(wrapResult.status == EVM.Status.successful, message: "wrap failed")

  // 2. Checkpoint in same tx
  let cpResult = self.coa.call(
    to: checkpointAddr,
    data: EVM.encodeABIWithSignature(
      "update(address,bytes,uint256,uint256,uint64)",
      [tokenAddr, EVM.EVMBytes(value: encryptedSnapshotHex.decodeHex()), ...]
    ),
    gasLimit: 100000,
    value: EVM.Balance(attoflow: 0)
  )
  assert(cpResult.status == EVM.Status.successful, message: "checkpoint failed")
}
```

**Critical:** always check `callResult.status == EVM.Status.successful`. A Cadence
transaction succeeds even if the inner EVM call reverts — the failure is silent.

### 2. `EVM.encodeABIWithSignature` — ABI encoding from Cadence

v0.8 uses `EVM.encodeABIWithSignature` for all calldata. Key footgun: `[UInt8]` encodes
as `uint8[]` (each byte → 32-byte word), NOT Solidity `bytes`. Wrap in `EVM.EVMBytes`:

```cadence
// WRONG — encodes as uint8[] (ABI dynamic array of uint8)
EVM.encodeABIWithSignature("update(...,bytes,...)", [..., byteArray, ...])

// CORRECT — encodes as bytes (Solidity bytes = ABI bytes)
EVM.encodeABIWithSignature("update(...,bytes,...)", [..., EVM.EVMBytes(value: byteArray), ...])
```

### 3. `EVM.dryCall` — read-only EVM call (no state change)

Used for proof verification without altering state:

```cadence
let dryResult = EVM.dryCall(
  from: callerCOA.address(),
  to: verifierEVMAddress,
  data: verifyProofCalldata,
  gasLimit: 500000,
  value: EVM.Balance(attoflow: 0)
)
assert(dryResult.status == EVM.Status.successful, message: "proof verify failed")
```

## MemoKey resource (JanusFT path)

JanusFT tokens use a Cadence `MemoKey` resource stored in the user's Cadence account at
`/storage/openjanusMemoKey` (published at `/public/openjanusMemoKey`).

The SDK installs the MemoKey resource via the `installInbox` / `installInboxAndCheckpoint`
Cadence templates:

```typescript
import { installInboxAndCheckpoint } from "@claucondor/sdk";
import * as fcl from "@onflow/fcl";

await fcl.mutate({
  cadence: installInboxAndCheckpoint,
  args: (arg, t) => [
    arg(pubkeyX.toString(), t.UInt256),
    arg(pubkeyY.toString(), t.UInt256),
  ],
  limit: 9999,
});
```

This transaction:
1. Creates the Cadence `ShieldedInbox` resource at `/storage/janusShieldedInbox`
2. Creates the MemoKey resource with the user's BabyJub pubkey
3. Creates the Cadence checkpoint resource (if applicable)

## JanusFT.CommitmentRegistry

`JanusFT` stores per-user Pedersen commitments in a Cadence `commitments` dictionary
(a `{Address: Commitment}` map) inside the `JanusFT` contract resource.

Access is via the `JanusFT` Cadence contract, not via an EVM call. The SDK
`JanusFTAdapter.getCommitment(cadenceAddr)` fetches this via a Cadence script.

When checking if a JanusFT slot is fresh:

```typescript
import { isFreshSlotCommit } from "@claucondor/sdk";

const commit = await ftAdapter.getCommitment(cadenceAddr);
const fresh = isFreshSlotCommit(commit);  // true if (0,0) or (0,1)
```

## ShieldedCheckpoint — COA required

`ShieldedCheckpoint.read(token)` uses `msg.sender` to gate access. Only the COA
can call it for its own slot. The SDK reads checkpoints via an `eth_call` simulated
with `from = coa` (owner-gated read):

```typescript
import { ShieldedCheckpointClient, TOKEN_REGISTRY } from "@claucondor/sdk";

const cp = new ShieldedCheckpointClient();
// wallet.address must be the COA EVM address
const snapshot = await cp.readAndDecrypt(wallet, memoPrivkey, TOKEN_REGISTRY.flow.proxy);
```

`getPortfolioView` handles this automatically by simulating `eth_call` with `from=coa`.

## Compute Unit budget

All Cadence + EVM work within a single transaction shares the 9999 CU ceiling.
v0.8 atomic templates approach but do not exceed this limit:

| Template | Approximate CU |
|----------|---------------|
| `wrapFlowAtomic` (wrap + checkpoint) | ~5000-7000 |
| `combinedShieldedTransferWithCheckpoint` | ~7000-9000 |
| `installInboxAndCheckpoint` | ~2000-4000 |

Do not add extra EVM calls alongside `combinedShieldedTransferWithCheckpoint`. Run
proof generation client-side before the Cadence tx — never inside the same tx.

## cadenceAddrToEvmToken helper

JanusFT uses the Cadence deployer address as its "EVM token identifier" (padded to 20
bytes). The SDK provides:

```typescript
import { cadenceAddrToEvmToken } from "@claucondor/sdk";

const evmTokenId = cadenceAddrToEvmToken("0x4b6bc58bc8bf5dcc");
// Returns the padded 20-byte hex string used in ShieldedCheckpoint and ShieldedInbox
```

## Further reading

- [v03-architecture.md](v03-architecture.md) — Full v0.8.x architecture + module map
- [recovery.md](recovery.md) — COA-based ShieldedCheckpoint reads
- `flow-crossvm` skill — Comprehensive Cross-VM guide (COA setup, dryCall patterns)
