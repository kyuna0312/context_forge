---
name: Tune Settings
description: This skill should be used when the user says "optimize settings.json", "tune settings for low tokens", "settings.json for performance", "disable auto memory", "configure for token savings", "minimal context window settings", or "settings taking too many tokens". Only proposes documented settings keys — never invented ones.
version: 1.1.0
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

Identify token-costly configuration. Only these keys are real — **never
propose a key you cannot find in the official settings reference; a
fabricated key is silently ignored and the "optimization" is a placebo:**

| Setting | Cost | Recommendation |
|---------|------|----------------|
| `autoMemoryEnabled: true` (default) | Medium | `false` if auto memory isn't used |
| `disableBundledSkills` unset | Medium | `true` to skip bundled skills at startup |
| Unused MCP servers in `.mcp.json` | Medium | Add to `disabledMcpjsonServers` |
| `autoCompactWindow` unset | Low | Tune via `/autocompact` if compaction fires too late |
| Hook scripts that read files | Medium | Audit hooks |
| Unused plugins | Low–Medium | `/plugin remove <name>` (not a settings key) |

Note: skill *bodies* lazy-load — only frontmatter descriptions cost tokens
every session. The biggest constant cost is usually CLAUDE.md itself; check
that first (`/context_forge:check-claudemd-size`) before touching settings.

## Step 3: Apply Token-Saving Config

Recommended low-token `settings.json` (real keys only):

```json
{
  "autoMemoryEnabled": false,
  "disableBundledSkills": true,
  "autoCompactEnabled": true,
  "disabledMcpjsonServers": ["unused-server-name"]
}
```

Key settings explained:
- `autoMemoryEnabled: false` — Disables auto memory loading each session
- `disableBundledSkills: true` — Skips Claude Code's bundled skills at startup
- `autoCompactEnabled: true` — Auto-compact instead of erroring at context limit (default, keep it)
- `disabledMcpjsonServers` — Rejects listed `.mcp.json` servers so their tool schemas never load

## Step 4: Show Diff and Confirm

Display before/after diff:
```diff
- "autoMemoryEnabled": true,
+ "autoMemoryEnabled": false,
+ "disableBundledSkills": true,
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
| `setting` | Settings key (e.g. `autoMemoryEnabled`) |
| `current` | Current value or `missing` if not set |
| `recommended` | Recommended value for token savings |
| `action` | `change`, `keep`, `add` |

Example:
```
@v1:setting|current|recommended|action
autoMemoryEnabled|true|false|change
disableBundledSkills|missing|true|add
autoCompactEnabled|true|true|keep
```

## Additional Resources

- **`references/settings-reference.md`** — Full settings.json reference with token impact ratings
