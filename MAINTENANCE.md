# Maintenance Notes

This file tracks (a) canonical assignments for known duplicate-claim clusters and (b) content that requires re-verification on version updates.

## Canonical Assignments

| Cluster | Canonical file | Pointers in |
|---------|---------------|-------------|
| pi_b Fp2 swap (verifyProof returns false) | `docs/gotchas/pi-b-fp2-swap.md` | `docs/primitives/groth16.md`, `plugins/openjanus/skills/openjanus-primitives/SKILL.md` |
| CU ceiling 9999 | `docs/gotchas/compute-units-limit.md` | `docs/patterns/cross-vm-coa-pattern.md`, `docs/sdk/advanced-usage.md` |
| COA vs Cadence address | `docs/gotchas/flow-account-vs-coa.md` | `docs/sdk/advanced-usage.md`, `docs/contracts/janus-flow.md` |
| Blinding factor loss | `docs/sdk/basic-transfer.md` (P2), `docs/sdk/install.md` | `plugins/openjanus/skills/openjanus-sdk/SKILL.md` (P2) |
| `approve` before `wrap` (WRAPPER mode) | `docs/contracts/janus-token.md` (P1) | `docs/contracts/creating-custom-instances.md`, `plugins/openjanus/skills/openjanus-tokens/SKILL.md` (P1) |

## Version-sensitive entries

| Entry | File | Version | Re-verify trigger |
|-------|------|---------|------------------|
| JanusFlow v1.1.0 changes | `docs/contracts/janus-flow.md` | v1.1.0 | On JanusFlow v1.2.0 deploy |
| CU ceiling "9999" | `docs/gotchas/compute-units-limit.md` | testnet 2026-05 | On mainnet launch or Flow protocol upgrade |
| ConfidentialTransferVerifier address | `docs/deployments/canonical-addresses.md` | testnet | On mainnet deploy or circuit upgrade |

## Last Audit

Date: 2026-05-25
Total pitfall entries: ~20 (across 4 skills + 4 gotchas files)
Next recommended audit: when total pitfall entries exceeds 60, or on major SDK version bump.
