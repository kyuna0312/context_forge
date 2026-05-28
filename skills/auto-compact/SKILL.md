---
name: Auto Compact
description: This skill should be used when the user says "auto compact", "enable auto compact", "compact on context full", "automatic context compression", "prevent context limit errors", "set up auto compaction", or "context keeps hitting limit".
version: 1.0.0
---

# Auto Compact

Configure Claude Code to automatically compact conversation history when context approaches its limit, preventing hard stops and maintaining session continuity.

## What Compaction Does

When context window fills:
- **Without compaction**: Claude stops responding, session breaks
- **With compaction**: Claude summarizes old conversation, frees space, continues

Compaction preserves:
- Current task state
- Recent file edits
- Active errors being debugged

Compaction discards:
- Old conversation turns
- Previously loaded file contents no longer needed
- Resolved intermediate steps

## Enable Auto Compaction

### Option 1: Settings File

Add to `~/.claude/settings.json` (global) or `.claude/settings.json` (project):

```json
{
  "compactOnContextFull": true,
  "compactThreshold": 0.85
}
```

`compactThreshold: 0.85` = trigger compaction at 85% context usage.

### Option 2: During Session

To trigger manual compaction now:

```
/compact
```

Claude will summarize current context and continue with reduced token usage.

### Option 3: PreCompact Hook

Configure hook to run before compaction for custom summary logic:

```json
{
  "PreCompact": [{
    "hooks": [{
      "type": "command",
      "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/scripts/pre-compact.sh",
      "timeout": 15
    }]
  }]
}
```

Create `hooks/scripts/pre-compact.sh` with custom pre-compaction logic, for example:

```bash
#!/usr/bin/env bash
# Runs before Claude compacts context. Use to save state, log context usage, etc.
echo "Compacting context at $(date)" >> ~/.claude/compact.log
```

## Compact Trigger Prompt

To manually compact with preserved context, use:

```
Compact context now.

Preserve:
- Current task: [TASK]
- Active files: [FILES]
- Current errors: [ERRORS IF ANY]

Summarize everything else. Continue where we left off.
```

## Monitor Context Usage

Check current context fill level:
- Claude Code shows context usage in status line
- At 70%+ usage: consider voluntary compaction
- At 85%+ usage: auto-compact triggers (if enabled)

## Additional Resources

- **`references/compact-strategies.md`** — Custom compaction strategies and PreCompact hook examples
