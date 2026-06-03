# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Codex, Cursor, Copilot, and others)
when working in this repository. It is loaded into agent context automatically — keep it concise.

## Overview

This repository is a Claude Code plugin marketplace for the Janus privacy stack on Flow. It ships
one plugin, `openjanus`, containing five skills that provide domain knowledge for building confidential
token applications using ZK proofs on Flow EVM and Cadence.

**Target users**: Developers building apps on top of the Janus privacy stack — apps that use `@claucondor/sdk`,
JanusToken contracts, JanusFlow, or the underlying BabyJubJub / ElGamal / Groth16 primitives.

Content is Markdown only — there is no code to build, compile, or test.

## How Skills Work

Skills follow the Anthropic official Agent Skills standard — a skill is a **folder**, not just a file.
Three-level progressive disclosure:

1. **Metadata** (~100 words) — The `name` and `description` in YAML frontmatter in `SKILL.md`.
   Always loaded into the agent's context. This is how the agent decides whether to activate a skill.
2. **SKILL.md body** (~300 words) — Loaded when the skill triggers. Contains overview, quick start,
   references section, and common gotchas.
3. **`references/` files** — Loaded on demand when the agent reads a path from the SKILL.md body.
   Detail docs, 200–300 lines each. Never loaded unless explicitly needed.

This achieves ~33x token efficiency vs. loading all docs upfront.

## Repository Layout

```
plugins/openjanus/
    .claude-plugin/plugin.json           Plugin metadata
    skills/<skill-name>/
        SKILL.md                         Skill entry point: YAML frontmatter + body
        references/                      Detail docs, loaded on-demand
            *.md
CLAUDE.md                                @-include to AGENTS.md (backwards compat)
prompts/                                 Drop-in CLAUDE.md / .cursorrules templates
examples/                                Step-by-step walkthroughs
README.md                                User-facing install + skill catalog
```

## Plugin and Skills

One plugin is registered in `.claude-plugin/marketplace.json`:

- **openjanus** (`plugins/openjanus/`) — v0.6.5 SDK / v0.6.4 contracts, category `blockchain`

It contains five skills:

| Skill | Primary use |
|-------|------------|
| `openjanus-sdk` | `@claucondor/sdk@^0.6.5` — `sdk.token(id)` generic adapter, 4 tokens, MemoKeyRegistry |
| `openjanus-primitives` | BabyJubJub, Pedersen, Groth16 low-level reference |
| `openjanus-tokens` | JanusFlow / JanusWFLOW / JanusMockUSDC / JanusFT contract patterns |
| `openjanus-elgamal` | ECIES ShieldedNote encryption, BabyJub keypair derivation (sign-derive), MemoKey |
| `openjanus-deploy` | Deploying new JanusToken instances, canonical v0.6.4 addresses, circuit artifacts |

## Skill Routing Guide

| Developer need | Primary skill | May also need |
|----------------|--------------|---------------|
| Install or use `@claucondor/sdk` | `openjanus-sdk` | |
| Read a JanusToken slot | `openjanus-sdk` | |
| Generate an encrypt or decrypt proof | `openjanus-elgamal` | `openjanus-sdk` |
| Wrap/transfer/unwrap FLOW via JanusFlow | `openjanus-sdk` | `openjanus-tokens` |
| Encrypt/decrypt ShieldedNote memos | `openjanus-elgamal` | |
| Understand Pedersen commitment math | `openjanus-primitives` | |
| Debug pi_b swap / verifyProof returns false | `openjanus-primitives` | |
| Understand JanusToken interface / modes | `openjanus-tokens` | |
| Create a custom JanusToken instance | `openjanus-tokens` | `openjanus-deploy` |
| Deploy BabyJub.sol or verifier | `openjanus-deploy` | |
| Deploy JanusToken WRAPPER for an ERC-20 | `openjanus-deploy` | `openjanus-tokens` |
| Canonical deployed addresses | `openjanus-deploy` | |
| COA setup for Cadence cross-VM calls | `openjanus-deploy` | |
| 9999 CU ceiling / compute units | `openjanus-deploy` | |
| BabyJub keypair derivation (sign-derive) | `openjanus-elgamal` | |

## Install and Validate Commands

There is no build or test target. Validate structural changes with:

- `claude plugin validate .` — schema-validates `marketplace.json` and each `plugin.json`

End-user install:

```
/plugin marketplace add claucondor/ai-tools
/plugin install openjanus@claucondor-ai-tools
```

## Conventions

- **No code, only Markdown.** Every change is to `.md` files, `marketplace.json`, or `plugin.json`.
- **Kebab-case names.** Plugin and skill directory names must be kebab-case and match the `name` field.
- **SKILL.md frontmatter is required.** Each skill needs YAML with `name` and `description`.
- **Reference files stay 200–300 lines.** Split larger topics into multiple files.
- **Heading convention**: `## Common gotchas` for developer-error prevention (lowercase per Anthropic style).
- **Maintenance**: grep first before adding a new pitfall to avoid duplicates.

```bash
grep -ri "your symptom keywords" plugins/openjanus/skills/
```

## Content Policy

This repository is public. Content must be PUBLIC-SAFE:

- Usage documentation, operational gotchas, and deployment guides: OK
- Detailed vulnerability writeups with attack vectors: NOT included (kept private)
- Audit checklists or deep ZK circuit security analysis: NOT included
- High-level statements about privacy properties ("amount privacy only"): OK

When in doubt: "would I want a competitor auditor to learn this from my docs?" If yes, keep it out.

## Maintenance Discipline

Before adding a new pitfall or common-error entry: **grep first.**

```bash
grep -ri "your symptom keywords" plugins/openjanus/skills/
```

If a matching entry exists, add a cross-reference instead of duplicating.
