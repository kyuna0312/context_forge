# Auto-Compact Strategies

## What Compaction Does

When context approaches limit, Claude summarizes conversation history into a compressed summary. Preserves:
- Key decisions made
- Files modified
- Current task state
- Important constraints

Loses:
- Exact wording of past exchanges
- Intermediate reasoning steps
- Verbose explanations already given

## The Real Settings

Auto-compaction is **on by default**. The documented keys:

```json
{
  "autoCompactEnabled": true,
  "autoCompactWindow": 500000
}
```

**`autoCompactEnabled: false`**: session hard-stops at the context limit —
only set false deliberately.

**`autoCompactWindow`** (100,000–1,000,000 tokens): the fullness at which
compaction fires; unset, Claude Code uses a model-specific default. Configure
it with the `/autocompact` command rather than hand-editing.

## When Compaction Triggers

Context limits are model-specific — read the live number from the status
line or `/context` rather than assuming one. Compaction fires when usage
reaches `autoCompactWindow` (or the model default).

## PreCompact Hook (Advanced)

Add important information before compaction:

```json
{
  "hooks": {
    "PreCompact": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/scripts/pre-compact.sh"
      }]
    }]
  }
}
```

Example pre-compact.sh:
```bash
#!/bin/bash
# Output key state to preserve through compaction
echo "=== PRESERVE THROUGH COMPACTION ==="
if [ -f "$CLAUDE_PROJECT_DIR/CONTEXT.md" ]; then
  cat "$CLAUDE_PROJECT_DIR/CONTEXT.md"
fi
echo "Current working directory: $CLAUDE_PROJECT_DIR"
```

## Compaction vs. Reset

| Situation | Use |
|-----------|-----|
| Long session, work ongoing | keep autoCompactEnabled (default) |
| Starting fresh after completion | /reset-context |
| Switching to unrelated task | New session |
| Context polluted with errors | Manual reset |

## Compaction Quality Tips

Before context fills, create a `CONTEXT.md` checkpoint:
```markdown
# Current Context

## Task
[What we're doing]

## State
[Where we are]

## Next
[Exact next step]
```

Compaction will include this file in summary, giving better continuity.

## Reducing the Need for Compaction

Cut constant context cost so sessions last longer between compactions:

```json
{
  "autoMemoryEnabled": false,
  "disableBundledSkills": true
}
```

Plus the non-settings levers, usually bigger:
- Trim CLAUDE.md (`/context_forge:optimize-claudemd`)
- Remove unused plugins (`/plugin remove`)
- Disable unused MCP servers (`disabledMcpjsonServers`)
