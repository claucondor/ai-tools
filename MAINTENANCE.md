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
| JanusFlow v1.1.0 changes | `plugins/openjanus/skills/openjanus-tokens/references/janus-flow.md` | v1.1.0 | On JanusFlow v1.2.0 deploy |
| CU ceiling "9999" | `plugins/openjanus/skills/openjanus-deploy/references/compute-units-limit.md` | testnet 2026-05 | On mainnet launch or Flow protocol upgrade |
| ConfidentialTransferVerifier address | `plugins/openjanus/skills/openjanus-deploy/references/canonical-addresses.md` | testnet | On mainnet deploy or circuit upgrade |

## Last Audit

Date: 2026-05-25
Total pitfall entries: ~20 (across 4 skills + 4 gotchas files)
Next recommended audit: when total pitfall entries exceeds 60, or on major SDK version bump.
