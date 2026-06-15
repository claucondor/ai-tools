# Maintenance Notes

This file tracks (a) canonical assignments for known duplicate-claim clusters and (b) content that requires re-verification on version updates.

## Canonical Assignments

| Cluster | Canonical file | Pointers in |
|---------|---------------|-------------|
| pi_b Fp2 swap (verifyProof returns false) | `plugins/openjanus/skills/openjanus-primitives/references/pi-b-fp2-swap.md` | `plugins/openjanus/skills/openjanus-primitives/references/groth16.md`, `plugins/openjanus/skills/openjanus-primitives/SKILL.md` |
| CU ceiling 9999 | `plugins/openjanus/skills/openjanus-deploy/references/compute-units-limit.md` | `plugins/openjanus/skills/openjanus-sdk/references/cross-vm-coa-pattern.md`, `plugins/openjanus/skills/openjanus-sdk/SKILL.md` |
| COA vs Cadence address | `plugins/openjanus/skills/openjanus-deploy/references/flow-account-vs-coa.md` | `plugins/openjanus/skills/openjanus-sdk/SKILL.md`, `plugins/openjanus/skills/openjanus-tokens/references/janus-flow.md` |
| Blinding factor loss | `plugins/openjanus/skills/openjanus-sdk/references/quickstart.md` (P2) | `plugins/openjanus/skills/openjanus-sdk/SKILL.md` (P2) |
| `approve` before `wrap` (WRAPPER mode) | `plugins/openjanus/skills/openjanus-tokens/references/janus-token.md` (P1) | `plugins/openjanus/skills/openjanus-tokens/references/creating-custom-instances.md`, `plugins/openjanus/skills/openjanus-tokens/SKILL.md` (P1) |

## Version-sensitive entries

| Entry | File | Version | Re-verify trigger |
|-------|------|---------|------------------|
| All EVM proxy addresses | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` | v0.8.2 contracts | On new contract deploy or UUPS upgrade |
| MemoKeyRegistry address | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` | v0.8 (immutable) | Never (immutable) |
| ShieldedInbox address | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` | v0.8 (immutable) | Never (immutable) |
| ShieldedCheckpoint address | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` | v0.8.2 (multi-token re-deploy 2026-06-11) | On next checkpoint contract upgrade |
| AmountDiscloseVerifier / ConfidentialTransferVerifier / ClaimBatchVerifier | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` | v0.8 | On circuit upgrade |
| CU ceiling "9999" | `plugins/openjanus/skills/openjanus-deploy/references/compute-units-limit.md` | testnet 2026-05 | On mainnet launch or Flow protocol upgrade |
| SDK version `^0.8.2` | README.md, install.md, SKILL.md files | v0.8.2 | On next SDK version bump |

## Canonical Assignment Update (v0.6.5 stack sync)

All address and version references audited and updated 2026-06-02:

| What changed | Before | After |
|---|---|---|
| JanusFlow proxy | 0x09A3DCa868... | 0x2458ae2d26... |
| JanusWFLOW proxy | (new token) | 0x00129E94d5... |
| JanusMockUSDC proxy | 0xf2C04b1A32... (JanusERC20) | 0xd45FDa099C... |
| JanusFT Cadence | 0xbef3c77681c15397 | 0x7599043aea001283 |
| MemoKeyRegistry | (new, immutable) | 0x05D104962f... |
| WFLOW9 underlying | (new) | 0xe7BbEAcC04... |
| MockUSDC underlying | 0x3e8973dE56... | 0x8405E88317... |
| AmountDiscloseVerifier | 0x9c83b2b1EF... | 0xD0ED393653... |
| ConfidentialTransferVerifier | 0x48f791D2a4... | 0x84852aF72D... |
| SDK version | 0.5.x | 0.6.5 |
| contracts tag | (unversioned) | v0.6.4 |

## Canonical Assignment Update (v0.8.2 stack sync)

All address and version references audited and updated 2026-06-15. Full v0.8 redeployment
(clean slate 2026-06-09). JanusWFLOW dropped from TOKEN_REGISTRY; 3 tokens only now.

| What changed | Before (v0.6.x) | After (v0.8.2) |
|---|---|---|
| JanusFlow EVM proxy | 0x2458ae2d26... | 0xA64340C1d3... |
| JanusERC20 (mockusdc) proxy | 0xd45FDa099C... | 0xFD8F82bE17... |
| JanusWFLOW | 0x00129E94d5... | **REMOVED** (wflow token dropped) |
| JanusFT Cadence deployer | 0x7599043aea001283 | 0x4b6bc58bc8bf5dcc |
| MemoKeyRegistry | 0x05D104962f... | 0x361bD4d037... |
| BabyJub.sol | 0x27139AFda7... | 0xD79C90b797... |
| AmountDiscloseVerifier | 0xD0ED393653... | 0xf7B634D412... |
| ConfidentialTransferVerifier | 0x84852aF72D... | 0x38e69fE7Ba... |
| ShieldedInbox (EVM) | (new) | 0x0C787AAcbA... |
| ShieldedCheckpoint (EVM) | (new) | 0x88C9fD443B... |
| ClaimBatchVerifier N=10 | (new) | 0x66f25B8f2e... |
| Cadence ShieldedCheckpoint | (new) | 0xd1a02aa46d9151bb |
| MockUSDC underlying | 0x8405E88317... | 0xd49Ff95027... |
| SDK version | 0.6.5 | 0.8.2 (tarball: claucondor-sdk-0.8.2.tgz) |
| Primitives package | @openjanus/pedersen | @openjanus/commitment |
| PrivateTip demo | github.com/claucondor/private-tip | https://privatetip.vercel.app |

## Last Audit

Date: 2026-06-15
Total pitfall entries: ~20 (across 4 skills + 4 gotchas files) — re-verify after skills update for v0.8.2
Next recommended audit: when total pitfall entries exceeds 60, or on major SDK version bump.
