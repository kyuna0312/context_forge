# settings.json Reference — Token Impact Ratings

Only documented keys appear here. An unknown key in settings.json is
silently ignored — recommending one is a placebo optimization.

## Token-Affecting Settings

### autoMemoryEnabled
- **Default**: true
- **Token impact**: MEDIUM — auto memory content loads each session
- **Recommended**: `false` if you don't rely on auto memory
- **Trade-off**: You must explicitly reference remembered content

### disableBundledSkills
- **Default**: false (bundled skills active)
- **Token impact**: MEDIUM — bundled skills' descriptions load at startup
- **Recommended**: `true` if you don't use Claude Code's built-in skills
- **Trade-off**: Bundled skills (except `/doctor`) unavailable

### autoCompactEnabled
- **Default**: true
- **Token impact**: NEUTRAL (prevents hard stops at context limit)
- **Recommended**: keep `true`

### autoCompactWindow
- **Default**: model-specific
- **Range**: 100,000–1,000,000 tokens
- **Token impact**: controls *when* auto-compaction fires
- **Recommended**: set via the `/autocompact` command, not by hand

### disabledMcpjsonServers
- **Default**: `[]`
- **Token impact**: MEDIUM per server — a rejected server's tool schemas never load
- **Recommended**: list `.mcp.json` servers this machine doesn't need

## What Does NOT Exist

There is no `autoLoadSkills`, `autoLoadMemory`, `compactOnContextFull`,
`compactThreshold`, `verboseOutput`, or `plugins.autoEnable`. Skill bodies
lazy-load by design — only frontmatter descriptions cost tokens every
session, so no setting is needed to "stop skills loading".

## Full Low-Token Config

```json
{
  "autoMemoryEnabled": false,
  "disableBundledSkills": true,
  "autoCompactEnabled": true,
  "disabledMcpjsonServers": ["unused-server-name"]
}
```

## Per-Project Settings

Create `.claude/settings.json` (shared) or `.claude/settings.local.json`
(personal) in the project root to override global:

```json
{
  "autoMemoryEnabled": false,
  "disabledMcpjsonServers": ["server-not-needed-here"]
}
```

Plugins are not toggled via settings — manage them with `/plugin install`
and `/plugin remove`.

## Where the Tokens Actually Go

| Source | Constant cost | Lever |
|--------|---------------|-------|
| CLAUDE.md (global + project) | words × 1.3 | `/context_forge:optimize-claudemd` |
| Skill descriptions (~100t each) | count × ~100 | `/plugin remove` unused plugins |
| Auto memory | varies | `autoMemoryEnabled: false` |
| MCP tool schemas | varies per server | `disabledMcpjsonServers` |

CLAUDE.md is usually the biggest line item — check it first.

## Backup Before Editing

Always backup settings before modifying:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.backup.$(date +%Y%m%d)
```

To restore:
```bash
cp ~/.claude/settings.json.backup.[DATE] ~/.claude/settings.json
```
