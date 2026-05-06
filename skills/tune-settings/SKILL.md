---
name: Tune Settings
description: This skill should be used when the user says "optimize settings.json", "tune settings for low tokens", "settings.json for performance", "disable auto memory", "configure for token savings", "minimal context window settings", or "settings taking too many tokens".
version: 1.0.0
---

# Tune Settings

Read and optimize `settings.json` (or `settings.local.json`) for minimal token usage. Show diff before writing.

## Step 1: Find Settings Files

Check in order:
1. `./.claude/settings.json` (project)
2. `./.claude/settings.local.json` (project local)
3. `~/.claude/settings.json` (global)
4. `~/.claude/settings.local.json` (global local)

Read all found files.

## Step 2: Analyze Current Settings

Identify token-costly settings:

| Setting | Cost | Recommendation |
|---------|------|----------------|
| `autoLoadMemory: true` | High | Set to `false` |
| `autoLoadSkills: true` | Very High | Set to `false` |
| Verbose logging enabled | Medium | Disable |
| Large `contextWindow` | High | Reduce to needed size |
| Hook scripts that read files | Medium | Audit hooks |
| Multiple MCP servers active | Medium | Disable unused |

## Step 3: Apply Token-Saving Config

Recommended low-token `settings.json`:

```json
{
  "autoLoadMemory": false,
  "autoLoadSkills": false,
  "compactOnContextFull": true,
  "verboseOutput": false,
  "plugins": {
    "autoEnable": false
  }
}
```

Key settings explained:
- `autoLoadMemory: false` — Prevents `.remember/` files from loading every session
- `autoLoadSkills: false` — Skills load only when explicitly triggered
- `compactOnContextFull: true` — Auto-compact instead of erroring at context limit
- `plugins.autoEnable: false` — Plugins require explicit activation

## Step 4: Show Diff and Confirm

Display before/after diff:
```diff
- "autoLoadMemory": true,
+ "autoLoadMemory": false,
- "autoLoadSkills": true,
+ "autoLoadSkills": false,
+ "compactOnContextFull": true,
```

Ask user to confirm scope: project settings or global settings.

## Step 5: Write File

On confirmation, write the updated settings file.

**Warning:** Changing global settings affects all Claude Code sessions.

## LTX Schema

Emit structured output as LTX rows when reporting settings analysis results.

```
@v1:setting|current|recommended|action
```

| Field | Description |
|-------|-------------|
| `setting` | Settings key (e.g. `autoLoadMemory`) |
| `current` | Current value or `missing` if not set |
| `recommended` | Recommended value for token savings |
| `action` | `change`, `keep`, `add` |

Example:
```
@v1:setting|current|recommended|action
autoLoadMemory|true|false|change
autoLoadSkills|true|false|change
compactOnContextFull|missing|true|add
verboseOutput|false|false|keep
```

## Additional Resources

- **`references/settings-reference.md`** — Full settings.json reference with token impact ratings
