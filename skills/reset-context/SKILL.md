---
name: Reset Context
description: This skill should be used when the user says "reset context", "clear context", "things are getting slow", "session is bloated", "too much context", "start fresh", "context is full", or asks to reduce memory usage mid-session. Do NOT use for a merely long-but-healthy session — a reset that loses working context costs more than it saves.
version: 1.1.0
---

# Reset Context

Perform a controlled context reset to eliminate accumulated bloat and restore fast, focused Claude responses. Use this when sessions slow down due to excess history, loaded skills, or memory files.

## When to Apply

- Responses feel slow or unfocused
- Claude is referencing irrelevant earlier conversation
- Many skills or files have been loaded during session
- User explicitly requests a fresh start

## Prefer the Native Commands

Claude Code already ships the reset primitives — use them before any manual
procedure:

- **`/compact`** — summarizes old history in place, keeps the session going. First choice when the user wants to continue the same task.
- **`/clear`** — wipes conversation history entirely. Choose when switching tasks or when compaction isn't enough.

This skill's real job is the step neither command does: capturing a paste-back
summary *before* the reset so nothing load-bearing is lost.

## Reset Procedure

### Step 1: Identify What to Preserve

Scan current conversation for:
- Active file paths being edited
- Current git branch
- Specific error messages being debugged
- Any user-defined constraints or preferences

Include only these. Discard everything else.

### Step 2: Emit the Paste-Back Summary

Capture the preserved context in under 200 tokens:

```
Current task: [one line]
Key files: [list paths]
Next action: [one line]
```

Output this to the user so they can paste it back after reset.

### Step 3: Instruct the Reset

Tell the user: run `/compact` (same task) or `/clear` (fresh start), then
paste the summary from Step 2 as their next message. If they want extra
strictness after `/clear`, prepend:

```
Only keep the pasted summary. Ignore memory files and skills unless
explicitly requested.
```

## Impact

A proper context reset reduces per-response token usage by eliminating:
- Loaded skill bodies (each skill = 1,000-5,000 tokens)
- Memory file content
- Repeated conversation history
- Stale tool results

## Additional Resources

- **`references/reset-strategies.md`** — Advanced reset patterns for different session types
