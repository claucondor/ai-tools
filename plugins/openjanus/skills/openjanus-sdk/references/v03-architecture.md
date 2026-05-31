# v0.3 Architecture — JanusToken Abstract Base + Janus&lt;X&gt; Concretes

`@openjanus/sdk` ships a single abstract base class (`JanusToken`) and three
concrete extensions: `JanusFlow` (native FLOW, production), `JanusERC20`
(ERC20-wrapping, testnet), and `JanusFTCadence` (Cadence FT, in validation).
All concretes plug into the same abstract base without changing the API surface.

## The pattern in one sentence

`JanusToken` defines the shielded-pool primitives (commitments, total supply,
`shieldedTransfer`). Each `Janus<X>` concrete owns the asset-specific entry
points (`wrap` / `unwrap` for native FLOW, `mint` / `burn` for an ERC-20
wrapper, etc.). Apps interact with the concrete class.

## Why an abstract base

- **Shared shielded-pool semantics** — `commitments[user]`, `totalSupplyCommitment()`,
  `totalLocked()`, and `shieldedTransfer(to, publicInputs, proof)` are identical
  across every asset type. Putting them on the base means every future token
  inherits the same audited code path.
- **Single proof system** — every concrete uses the same
  `AmountDiscloseVerifier` + `ConfidentialTransferVerifier` pair. A new asset
  type does not need a new circuit unless it changes the commitment shape.
- **Single ABI surface** — Solidity-side `JanusToken` is also an abstract
  base. ERC-20 wrappers, native-token wrappers, and yield-bearing tokens all
  conform to the same `shieldedTransfer` selector. Indexers and explorers can
  decode any `Janus<X>` event without per-token code.

## Class hierarchy

```
JanusToken (abstract base, src/tokens/janus-token.ts)
│
├── connect(provider): Promise<this>
├── connectWithSigner(signer): Promise<this>
├── balanceOfCommitment(addr): Promise<Point>
├── totalSupplyCommitment():    Promise<Point>
├── totalLocked():               Promise<bigint>
├── shieldedTransfer({ to, publicInputs, proof }): Promise<TxResponse>
└── (no wrap / unwrap — those are concrete-specific)

JanusFlow (concrete, src/tokens/janus-flow.ts)   — native FLOW
│
└── extends JanusToken
    ├── wrap({ amountWei, txCommit, amountProof })
    ├── unwrap({ claimedAmountWei, recipient, ... })
    └── maxWrap(): Promise<bigint>      // 18 FLOW cap on testnet
```

`JanusFlowCadence` is a separate read-only helper for the Cadence router
(`0x5dcbeb41055ec57e`). It does NOT extend `JanusToken` — it exists because
Cadence transactions are signed via FCL, not via an ethers signer.

## Deployed in v0.3

| Concrete | EVM proxy | Cadence router | Notes |
|----------|-----------|----------------|-------|
| `JanusFlow` (native FLOW) | `0x09A3DCa868EcC39360fDe4E22046eCfcbA5b4078` | `0x5dcbeb41055ec57e` | Production |
| `JanusToken` (abstract)   | NOT deployed standalone | — | Template only |

Future (not in v0.3):

- `JanusUSDC` (ERC-20 wrapper, v1.1 candidate)
- `JanusFT` (generic ERC-20 / FT wrapper, multi-token, v1.1+ candidate)

## Privacy properties (validated empirically)

The v0.3 stack was validated against the canonical five-channel question set
in `cadence-crypto-lab/docs/privacy-validation/PRIVACY-MATRIX.md` (variant
L11 / ConfidentialFLOW path B2). Per operation:

| Operation | msg.value | calldata | storage | events | commit bruteforce | Verdict |
|-----------|-----------|----------|---------|--------|-------------------|---------|
| `wrap`             | **LEAK** (by design — boundary, msg.value carries amount) | HIDE | HIDE per-user / **LEAK** `totalLocked` (by design) | **LEAK** `Wrapped(user, amount)` (by design) | N/A | MIXED — pass for boundary |
| `shieldedTransfer` | HIDE (not payable)                  | HIDE (publicInputs are 6 commitment coords; no amount) | HIDE (commitments are points) | HIDE (`ConfidentialTransfer(from, to)` — no amount) | HIDE (128-bit blinding) | **PASS — fully shielded** |
| `unwrap`           | HIDE (not payable)                  | **LEAK** `claimedAmount` (by design — needed to release FLOW) | HIDE per-user / **LEAK** `totalLocked` (by design) | **LEAK** `Unwrapped(user, recipient, amount)` (by design) | N/A | MIXED — pass for boundary |

Compared to the deprecated v0.2 `JanusToken` (ElGamal+SCALE):

| Channel | v0.2 JanusToken (deprecated `0x025efe7e...`) | v0.3 JanusFlow shieldedTransfer |
|---------|---------------------------------------------|--------------------------------|
| msg.value | **LEAK** (wrap payable) | HIDE (not payable on transfer) |
| calldata | **LEAK** (`transferUnits`, `claimedUnits`) | HIDE (publicInputs only) |
| storage view | **LEAK** (`locked[user]` public mapping) | HIDE (commitment point only) |
| events | **LEAK** (`Wrapped`, `Unwrapped` emit amount) | HIDE (`ConfidentialTransfer(from, to)`) |
| commit bruteforce | N/A (cleartext) | HIDE (128-bit blinding) |

Reference: `cadence-crypto-lab/docs/privacy-validation/PRIVACY-MATRIX.md`,
`variant-janus-v2-audit.json` (deprecated v0.2 evidence), and
`v03-smoke.mjs` (v0.3 empirical reproduction).

## Versioning policy

The SDK class names do NOT carry a version suffix (no `JanusToken_v3`,
`JanusFlowV3`, etc.). Versioning is communicated through:

- npm semver (`@openjanus/sdk@^0.5.4`)
- deployed addresses (each major contract version gets a new address)
- the `JANUS_FLOW_VERSION` constant exported from the SDK (`"0.5.4"` in current release)

If you see `JanusTokenV2` or `JanusFlowImpl` in code, that is legacy v0.2
nomenclature inherited from the router/impl pattern of that release. v0.3
replaces the router/impl indirection with UUPS on the EVM side (the proxy is
stable, the impl is swappable) and a simple Cadence façade on the cross-VM side.

## Building a new `Janus<X>` concrete

To add (e.g.) `JanusUSDC`:

1. Deploy a Solidity contract that extends the on-chain `JanusToken` abstract
   base and implements `wrap(amountUsdc, txCommit, amountProof)` via
   `IERC20(usdc).transferFrom(msg.sender, address(this), amountUsdc)`.
2. Create `src/tokens/janus-usdc.ts` extending the SDK `JanusToken` class with
   matching wrap / unwrap method signatures.
3. Re-export from `src/tokens/index.ts` and add a `JANUS_USDC_TESTNET` constant.
4. Add tests under `tests/unit/tokens/janus-usdc.test.ts`.

The shielded-transfer proof builder (`buildShieldedTransferProof`) and the
amount-disclose proof builder (`buildAmountDiscloseProof`) are reused
unchanged — the underlying circuits are asset-agnostic.

## See also

- [quickstart.md](quickstart.md) — Full v0.3 workflow
- [migration-v02-to-v03.md](migration-v02-to-v03.md) — v0.2 ElGamal API rewrite recipes
- [../../../openjanus-tokens/references/janus-token.md](../../../openjanus-tokens/references/janus-token.md) — Solidity-side abstract base
- [../../../openjanus-tokens/references/janus-flow.md](../../../openjanus-tokens/references/janus-flow.md) — JanusFlow concrete details
- [../../../openjanus-deploy/references/canonical-addresses.md](../../../openjanus-deploy/references/canonical-addresses.md)
