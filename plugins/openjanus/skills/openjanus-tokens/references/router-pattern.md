# Router Pattern — JanusFlow Cadence Upgrade Architecture

JanusFlow uses a router/facade + swappable implementation pattern (introduced in v0.2.0-router, still used in v0.5.4).
This document explains when to use it, how it works, its tradeoffs, and security
implications for apps building on JanusFlow.

Cross-reference: [[crypto-notes/008-router-pattern-cadence-vault]] (audits-kb private)

## The pattern in one sentence

The contract at the canonical address (the router) holds all state and exposes the
public API. A separate impl contract holds pure logic and is swappable. Apps always
import the router address — they are transparent to impl upgrades.

## Why not just update the contract in place?

In Cadence, you can update a contract at its existing address — but only if the new
code is backward compatible (no removed fields, no incompatible storage layout
changes, no changes to `init()` resource requirements). For significant logic changes
(e.g., switching verifier addresses or adding fee logic), you cannot update in place.

Additionally, Flow prevents removing a contract (deploying a completely different
contract) at an existing address without `FlowServiceAccount` authorization, which
is not available on testnet without special access.

The router pattern solves this: the router contract itself is minimal and stable
(just custody + dispatch), so it never needs to be updated. Logic goes in the impl,
which is a separate contract that can be replaced.

## How JanusFlow implements it

### Contracts at `0x5dcbeb41055ec57e` (Cadence layer)

```
JanusFlow.cdc        — router: custody + dispatch + admin + MemoKey registry
```

The Cadence router dispatches to the EVM proxy (`0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078`)
via COA. The EVM proxy is itself a UUPS proxy pointing at the current impl
(`0x0d54cf5560548A267EB31b4a90858c9b37e0C740`, v0.5.5-fees).

### State ownership

| What | Where |
|------|-------|
| FLOW vault (all user deposits) | JanusFlow.cdc (Cadence) |
| Commitment map (user → Pedersen point) | JanusFlow EVM proxy |
| MemoKey registry (user → BabyJubJub PK) | JanusFlow EVM proxy + Cadence resource |
| Validation logic (proof checks, fee deduction) | JanusFlow EVM impl (UUPS swappable) |
| Admin control | EVM UUPS owner (admin COA) + Cadence AdminResource |

### Dispatch pattern

When a user calls `JanusFlow.wrap(...)` via Cadence, the router:
1. Withdraws FLOW from the signer's `FlowToken.Vault`
2. ABI-encodes the EVM calldata and calls the proxy via COA
3. The EVM impl validates the Groth16 proof, deducts fee, updates commitment slot
4. On success: Cadence emits a Cadence-side event; EVM emits `Wrapped` + `WrapWithSnapshot`

## The 48h time-lock upgrade flow

This is adapted from Compound/Aave governance time-lock patterns.

### Step 1: Admin proposes swap

```
adminRef.proposeImplSwap(newImplCapability, newVersion: "0.2.0")
```

- Sets `pendingImpl` and `pendingVersion` in router storage
- Records `proposedAt = getCurrentBlock().timestamp`
- Emits `ImplSwapProposed(newVersion, proposedAt)` event

### Step 2: 48h observation window

The time-lock gives app developers 48h to:
- Review the new impl source code
- Test the new impl against their app
- Submit concerns / halt requests to the admin
- Prepare any UI updates needed

### Step 3: Admin finalizes (or cancels)

```
adminRef.finalizeImplSwap()   // after 48h
// or
adminRef.cancelImplSwap()     // any time before finalize
```

`finalizeImplSwap()` panics if called before the time-lock expires (verified on-chain).
This was confirmed in e2e testing: finalize was rejected with error code 1101 when called
immediately after propose.

## Security implications

### Single point of custody risk

All FLOW deposits sit in the JanusFlow router contract. If the router has a bug in its
custody logic, all funds are at risk. The impl is stateless — impl bugs can affect
privacy properties but NOT custody.

**Mitigation:** Keep the router minimal. Custody logic (vault operations) should be simple
and audited. Complex logic goes in the impl.

### Impl trust: apps trust whatever impl is active

When a user calls `wrapAndEncrypt`, they implicitly trust the currently active impl to
validate their proof correctly. If a malicious impl is swapped in, it could:
- Accept invalid proofs (fake wraps)
- Return wrong slot updates
- Cause incorrect FLOW accounting

**Mitigation:** The 48h time-lock gives users and integrators time to react. If a
malicious impl is proposed, anyone who monitors on-chain events can alert before the swap.
For production, the AdminResource should be held by a multi-sig account so no single actor
can propose a swap unilaterally.

### Missing pause: what happens without emergency stop?

If the router has no `pause()` function, and a bug is discovered in the impl (e.g., a
proof verification bypass), there is no way to halt deposits until a new impl is deployed.
The pause function in JanusFlow addresses this: admin can pause immediately to stop
bleeding, then propose + finalize a fixed impl within 48h.

**Detection checklist for auditors:**
- [ ] Does the router have `pause()` and `unpause()`?
- [ ] Does `pause()` halt all write operations including `wrap`, `shieldedTransfer`, and `unwrap`?
- [ ] Does `pause()` preserve read access (`balanceOfCommitment`, `totalLocked`, `isPaused`)?
- [ ] Is the time-lock enforced on-chain (not just off-chain by convention)?
- [ ] Is the AdminResource held by a multi-sig or a single EOA?
- [ ] Does the impl have any storage access? (It should not — state belongs in the router)

## Tradeoffs vs per-token isolation

An alternative design: each user deploys their own token contract. This provides
isolation — a bug in one user's contract doesn't affect others.

| | Router pattern | Per-token isolation |
|--|----------------|---------------------|
| Custody concentration | All in router | Per user |
| Upgrade coordination | One admin for all | Each user upgrades themselves |
| Gas cost per deploy | One deployment | N deployments |
| Pause scope | All users paused together | Per-user granularity |
| Admin complexity | One AdminResource | N admin paths |

For OpenJanus, the router pattern is appropriate because:
1. The FLOW token is shared infrastructure, not per-user
2. Single deployment is sufficient for testnet and early mainnet
3. The pause + time-lock mitigates the custody concentration risk

## Apps building on JanusFlow: what to verify

If you are building an app that integrates JanusFlow:

1. **Watch for ImplSwapProposed events.** Subscribe to these events on Flow. When you see
   one, review the proposed impl before the 48h window closes.

2. **Handle the paused state.** Your app UI should call `isPaused()` before showing
   "Wrap" or "Transfer" buttons. Display a clear error if the contract is paused.

3. **Do not cache the impl address.** Your app imports `JanusFlow from 0x5dcbeb41055ec57e`
   — let the router dispatch. Do not try to call JanusFlowImpl directly.

4. **Test against pause scenarios.** Simulate a paused state in your tests. Ensure your
   app handles the revert gracefully (surfacing the error to the user, not crashing).

## See also

- [janus-flow.md](janus-flow.md) — JanusFlow full reference + Cadence templates
- [canonical-addresses.md](../../openjanus-deploy/references/canonical-addresses.md) — All deployed addresses
- [../../../openjanus-sdk/references/quickstart.md](../../../openjanus-sdk/references/quickstart.md) — SDK integration guide
