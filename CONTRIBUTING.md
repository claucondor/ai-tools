# Contributing to openjanus/ai-tools

This repository contains Markdown-only plugin content for the OpenJanus Claude Code plugin marketplace. All contributions are to `.md` files, `marketplace.json`, or `plugin.json` — there is no code to build or compile.

## Content policy

This is a **public repository**. Before adding any content, ask: "would I want a competitor auditor to learn this?"

**OK to include:**
- Usage documentation and code examples
- Operational gotchas (e.g., pi_b swap, CU limits, COA setup)
- Deployment guides and canonical addresses
- High-level architecture descriptions

**Do NOT include:**
- Vulnerability writeups with attack vectors
- Audit checklists with security-sensitive details
- Deep circuit security analysis
- Bug postmortems with exploitable information

When in doubt, leave it out — the operator will add back if needed.

## Adding a pitfall entry

Before writing a new pitfall, grep the existing content for the symptom:

```bash
grep -ri "your symptom keywords" plugins/openjanus/skills/
```

If a matching entry already exists, do NOT duplicate it. Add a short cross-reference instead:

```
> See canonical treatment in [filename](path).
```

## Skill and plugin registration

**Registering a new skill requires changes in three places:**

1. Create `plugins/openjanus/skills/<name>/SKILL.md` with YAML frontmatter
2. Update the Skill Routing Guide table in `AGENTS.md`
3. Update the skill catalog table in `README.md`

**Registering a new plugin requires changes in four places:**

1. Create `plugins/<name>/.claude-plugin/plugin.json`
2. Create `plugins/<name>/skills/`
3. Add an entry to `plugins` array in `.claude-plugin/marketplace.json`
4. Update `README.md`

## SKILL.md conventions

- YAML frontmatter with `name` and `description` is required
- `description` must include trigger phrases AND non-trigger redirects
- Navigation map must link to actual docs files that exist
- Common Pitfalls section: use `## Common Pitfalls` heading, not "Gotchas" or "Anti-Patterns"

## Reference file conventions

- 200–300 lines per file; split larger topics
- Kebab-case filenames
- Code examples must be runnable (no pseudo-code)
- Use `@openjanus/sdk` imports, not raw imports from `circomlibjs` or `snarkjs`

## Validation

```bash
claude plugin validate .
```

This schema-validates `marketplace.json` and each `plugin.json`.
