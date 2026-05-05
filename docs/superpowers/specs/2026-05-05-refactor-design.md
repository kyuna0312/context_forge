# Refactor Design: context_guard / kyuna_token_saver

**Date:** 2026-05-05
**Approach:** Option 3 — Restructure then refactor
**Scope:** Full audit — shell scripts, SKILL.md files, JSON manifests
**Priority:** Clarity first — rename and restructure freely, behavior changes allowed

---

## Goals

1. Produce a coherent, navigable directory layout
2. Apply clean-code principles uniformly across all file types
3. Eliminate inconsistency in naming, structure, and error handling
4. Keep install flow intact

---

## Phase 1: Directory Restructure

### Changes

| Before | After | Reason |
|--------|-------|--------|
| `install.sh` (root) | `scripts/install.sh` | Root stays clean; scripts have a home |
| `skills/debug-hooks/scripts/validate-hooks.sh` | stays in-skill | Skill-scoped script, not global |
| All other paths | unchanged | Already consistent |

### Target Layout

```
context_guard/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
│   └── hook-error-fixer.md
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── session-start.sh
├── scripts/
│   └── install.sh
├── skills/
│   ├── auto-compact/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── compact-strategies.md
│   ├── check-claudemd-size/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── size-thresholds.md
│   ├── debug-hooks/
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   └── validate-hooks.sh
│   │   └── references/
│   │       └── hook-errors.md
│   ├── estimate-tokens/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── token-benchmarks.md
│   ├── low-token-mode/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── token-patterns.md
│   ├── manage-skills/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── skill-audit.md
│   ├── optimize-claudemd/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── claudemd-templates.md
│   ├── project-isolation/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── isolation-patterns.md
│   ├── reset-context/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── reset-strategies.md
│   ├── settings-diff/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── diff-safety.md
│   ├── task-brain-lite/
│   │   └── SKILL.md
│   └── token-statusline/
│       ├── SKILL.md
│       └── references/
│           └── statusline-setup.md
└── README.md
```

### Constraints

- `hooks.json` references `$CLAUDE_PLUGIN_ROOT/hooks/scripts/session-start.sh` — path must stay valid after move
- `install.sh` references relative paths — update after move to `scripts/`
- README install instructions reference `install.sh` at root — update after move

---

## Phase 2: Content Refactor

### 2a. Shell Scripts

**Files:** `hooks/scripts/session-start.sh`, `skills/debug-hooks/scripts/validate-hooks.sh`

**Contract (Clean Code chapters 2, 3, 7):**

- Variables: full intent-revealing names — no single-letter locals
- Logic blocks: extracted into named functions (`check_size()`, `warn_user()`, `print_status()`)
- Error handling: every `exit` gets an explicit code and a stderr message
- One responsibility per script: `session-start.sh` checks CLAUDE.md size and warns — nothing else
- No silent failures: `set -e` or explicit error traps where appropriate

### 2b. SKILL.md Files

**Files:** All 11 skill SKILL.md files

**Contract (Clean Code chapters 2, 4, 5):**

- Frontmatter shape: `name`, `description`, `version` — present in every skill, in that order
- Description triggers: uniform phrasing — `"Use this skill when the user says..."` or `"Use this skill when..."`
- Headers: `##` for major sections, `###` for sub-steps — no level mixing
- Prose style: imperative only — cut all "This is useful because..." justification sentences
- Every skill ends with `## Additional Resources` block listing its `references/` files
- `task-brain-lite` gets `version` field added (currently missing)

### 2c. JSON Manifests

**Files:** `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `hooks/hooks.json`

**Contract (Clean Code chapter 2):**

- `plugin.json`: kebab-case `name`, all fields present (`name`, `version`, `description`, `author`, `keywords`)
- `marketplace.json`: must match `plugin.json` metadata exactly — no drift
- `hooks.json`: `description` is a single clear sentence; all hook commands use `$CLAUDE_PLUGIN_ROOT` — no hardcoded paths

---

## Success Criteria

- [ ] `install.sh` runs from `scripts/install.sh` without errors
- [ ] `hooks.json` path resolves correctly after restructure
- [ ] All 11 SKILL.md files pass frontmatter shape check (name, description, version)
- [ ] All shell scripts have no single-letter variables and no silent exits
- [ ] `plugin.json` and `marketplace.json` are in sync
- [ ] README updated to reflect new `scripts/install.sh` path

---

## Out of Scope

- Adding the `clean-code` skill from `kyuna0312/clean-code-skills` (not requested)
- Adding new skills or capabilities
- Changing what scripts output (output changes are allowed but not required)
