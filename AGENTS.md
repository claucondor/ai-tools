# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Codex, Cursor, Copilot, and others)
when working in this repository. It is loaded into agent context automatically — keep it concise.

## Overview

This repository is a Claude Code plugin marketplace for the OpenJanus privacy stack on Flow. It ships
one plugin, `openjanus`, containing four skills that provide domain knowledge for building confidential
token applications using ZK proofs on Flow EVM and Cadence.

**Target users**: Developers building apps on top of OpenJanus — apps that use `@openjanus/sdk`,
JanusToken contracts, JanusFlow, or the underlying BabyJubJub / Pedersen / Groth16 primitives.

Content is Markdown only — there is no code to build, compile, or test.

## How Skills Work

Skills use a three-level progressive disclosure system:

1. **Metadata** (~100 words) — The `name` and `description` in YAML frontmatter. Always loaded into
   the agent's context. This is how the agent decides whether to activate a skill.
2. **SKILL.md body** (~200 words) — Loaded when the skill triggers. Contains overview, quick start,
   and a navigation map pointing to reference files.
3. **Reference files / docs** — Loaded on demand when the agent needs detailed information.

## Repository Layout

```
.claude-plugin/marketplace.json          Marketplace catalog, registers plugins
plugins/openjanus/
    .claude-plugin/plugin.json           Plugin metadata
    skills/<skill-name>/
        SKILL.md                         Skill entry point with YAML frontmatter
CLAUDE.md                                @-include to AGENTS.md (backwards compat)
docs/                                    Reference documentation organized by tier
    primitives/                          BabyJubJub, Pedersen, Groth16
    contracts/                           JanusToken, JanusFlow standards
    sdk/                                 @openjanus/sdk usage guides
    patterns/                            Recipes for common app patterns
    gotchas/                             Operational pitfalls (PUBLIC-SAFE only)
    decision-trees/                      When to use what
    deployments/                         Canonical addresses
prompts/                                 Drop-in CLAUDE.md / .cursorrules templates
examples/                                Step-by-step walkthroughs
README.md                                User-facing install + skill catalog
```

## Plugin and Skills

One plugin is registered in `.claude-plugin/marketplace.json`:

- **openjanus** (`plugins/openjanus/`) — v0.1.0, category `blockchain`

It contains these four skills:

| Skill | Primary use |
|-------|------------|
| `openjanus-sdk` | `@openjanus/sdk` installation and usage |
| `openjanus-primitives` | BabyJubJub, Pedersen, Groth16 low-level reference |
| `openjanus-tokens` | JanusToken / JanusFlow contract patterns |
| `openjanus-deploy` | Deploying new JanusToken instances |

## Skill Routing Guide

| Developer need | Primary skill | May also need |
|----------------|--------------|---------------|
| Install or use `@openjanus/sdk` | `openjanus-sdk` | |
| Read a JanusToken balance | `openjanus-sdk` | |
| Generate a ZK transfer proof | `openjanus-sdk` | `openjanus-primitives` |
| Wrap/transfer/unwrap FLOW via JanusFlow | `openjanus-sdk` | `openjanus-tokens` |
| Understand Pedersen commitment math | `openjanus-primitives` | |
| Debug pi_b swap / verifyProof returns false | `openjanus-primitives` | |
| Understand JanusToken interface / modes | `openjanus-tokens` | |
| Create a custom JanusToken instance | `openjanus-tokens` | `openjanus-deploy` |
| Deploy BabyJub.sol or verifier | `openjanus-deploy` | |
| Deploy JanusToken WRAPPER for an ERC-20 | `openjanus-deploy` | `openjanus-tokens` |
| COA setup for Cadence cross-VM calls | `openjanus-sdk` | |

## Install and Validate Commands

There is no build or test target. Validate structural changes with:

- `claude plugin validate .` — schema-validates `marketplace.json` and each `plugin.json`

End-user install:

```
/plugin marketplace add openjanus/ai-tools
/plugin install openjanus@openjanus-ai-tools
```

## Conventions

- **No code, only Markdown.** Every change is to `.md` files, `marketplace.json`, or `plugin.json`.
- **Kebab-case names.** Plugin and skill directory names must be kebab-case and match the `name` field.
- **SKILL.md frontmatter is required.** Each skill needs YAML with `name` and `description`.
- **Reference files stay 200–300 lines.** Split larger topics into multiple files.
- **Heading convention**: `## Common Pitfalls` for developer-error prevention.
- **Maintenance**: grep first before adding a new pitfall to avoid duplicates.

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
grep -ri "your symptom keywords" plugins/openjanus/skills/ docs/
```

If a matching entry exists, add a cross-reference instead of duplicating.
