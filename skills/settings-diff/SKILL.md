---
name: Settings Diff
description: This skill should be used when the user says "show settings diff", "what changed in settings", "compare settings before after", "settings optimization preview", "preview settings changes", or "show me what tune-settings will change". Only documented settings keys appear in diffs — never invented ones.
version: 1.1.0
---

# Settings Diff

Show a before/after diff of settings.json changes before applying. Always run this before writing settings changes.

## Diff Procedure

### Step 1: Read Current Settings

Read all relevant settings files:
- `~/.claude/settings.json`
- `~/.claude/settings.local.json`
- `./.claude/settings.json`
- `./.claude/settings.local.json`

### Step 2: Compute Proposed Changes

Based on optimization goals, compute the minimal diff needed. Never change
settings not related to the stated goal, and **never propose a key that
isn't in the official settings reference** — an unknown key is silently
ignored, so the diff would promise savings it can't deliver.

### Step 3: Present Diff

Format diff clearly:

```
SETTINGS DIFF
═════════════
File: ~/.claude/settings.json

BEFORE                           AFTER
─────────────────────────────────────────────────────
"autoMemoryEnabled": true    →   "autoMemoryEnabled": false
[not present]                →   "disableBundledSkills": true

Impact:
  Token reduction: ~[N] tokens per response (~[%]%)
  Behavior change: Auto memory off; bundled skills skipped at startup.
  Reversible: Yes (edit settings.json to revert)
```

### Step 4: Confirm Before Writing

Always ask:
```
Apply these changes to [file]? (yes/no)
```

Never write without explicit confirmation.

## Diff Format for Multiple Files

When changes span multiple files:

```
SETTINGS DIFF — 2 files
═══════════════════════

[1/2] ~/.claude/settings.json
──────────────────────────────
  "autoMemoryEnabled": true → false
  + "disableBundledSkills": true

[2/2] ./.claude/settings.local.json  
──────────────────────────────────────
  + "disabledMcpjsonServers": ["unused-server"]

Apply both changes? (yes/no/select)
```

## Revert Instructions

After any settings change, show revert command:

```
To revert: edit [file] and restore original values.
Backup saved to: [file].backup.[timestamp]
```

Always create a `.backup` copy before writing changes.

