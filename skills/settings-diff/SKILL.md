---
name: Settings Diff
description: This skill should be used when the user says "show settings diff", "what changed in settings", "compare settings before after", "settings optimization preview", "preview settings changes", or "show me what tune-settings will change".
version: 1.0.0
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

Based on optimization goals, compute the minimal diff needed. Never change settings not related to the stated goal.

### Step 3: Present Diff

Format diff clearly:

```
SETTINGS DIFF
═════════════
File: ~/.claude/settings.json

BEFORE                           AFTER
─────────────────────────────────────────────────────
"autoLoadMemory": true      →    "autoLoadMemory": false
"autoLoadSkills": true      →    "autoLoadSkills": false
[not present]               →    "compactOnContextFull": true

Impact:
  Token reduction: ~[N] tokens per response (~[%]%)
  Behavior change: Skills no longer auto-load. Use trigger phrases to load manually.
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
  "autoLoadMemory": true → false
  + "compactOnContextFull": true

[2/2] ./.claude/settings.local.json  
──────────────────────────────────────
  + "plugins.autoEnable": false

Apply both changes? (yes/no/select)
```

## Revert Instructions

After any settings change, show revert command:

```
To revert: edit [file] and restore original values.
Backup saved to: [file].backup.[timestamp]
```

Always create a `.backup` copy before writing changes.

## Additional Resources

- **`references/settings-reference.md`** — Full settings key reference (shared with tune-settings skill)
