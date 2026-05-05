---
name: Token Status Line
description: This skill should be used when the user asks to "add token counter to status line", "show context usage in status bar", "visualize token usage", "set up token status line", "live token counter", "show context window percentage", or wants to see token burn in the terminal status bar.
version: 1.0.0
---

# Token Status Line

Add live context window usage and CLAUDE.md token cost to the Claude Code status bar — visible at all times without asking.

## What It Shows

```
ctx [████████░░] 82%  │  md:~650t
```

- **ctx bar** — 10-char visual bar of context window usage (color-coded: green → yellow → orange → red)
- **md:~Nt** — estimated tokens loaded from CLAUDE.md files at session start

Rate limit usage appears only when near limits (≥70%) and on Claude.ai accounts.

## Quick Setup

**Step 1**: Copy plugin script to a stable path (recommended — plugin path may change):

```bash
# Copy to permanent location
cp "${CLAUDE_PLUGIN_ROOT}/skills/token-statusline/scripts/token-status.sh" ~/.claude/token-status.sh
chmod +x ~/.claude/token-status.sh
```

**Step 2**: Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/token-status.sh",
    "refreshInterval": 30
  }
}
```

**Step 3**: Restart Claude Code. Status line appears at bottom of terminal.

## If You Have an Existing Status Line

If `settings.json` already has a `statusLine.command`, choose:

- **Replace**: Swap the `command` path to `token-status.sh`
- **Extend**: Add the bar rendering block to your existing script (see `references/statusline-setup.md` Option B/C)
- **Patch Lucy Edgerunner** (`~/.claude/statusline-command.sh`): Replace the `ctx_part` block per Option C in references

## Color Thresholds

Context window:
- Green → under 50%
- Yellow → 50–74%
- Orange → 75–89%
- Red → 90%+ (compact now)

CLAUDE.md token cost:
- Green → under 390 tokens (optimal)
- Yellow → 390–779 (acceptable)
- Orange → 780–1299 (bloated)
- Red → 1300+ (optimize immediately)

## refreshInterval

```json
"refreshInterval": 30
```

Status line reruns every 30 seconds. Set lower (10) for faster updates; higher (60) for less CPU. Without `refreshInterval`, updates only on session events.

Requires Claude Code v2.1.97 or later.

## Manual Test

Test script output before wiring it up:

```bash
echo '{"context_window":{"used_percentage":72},"workspace":{"current_dir":"'"$PWD"'"}}' \
  | bash ~/.claude/token-status.sh
```

Should print a colored bar with `ctx [███████░░░] 72%` and CLAUDE.md token count.

## Additional Resources

- **`references/statusline-setup.md`** — Full JSON input schema, all 3 setup options, Lucy Edgerunner patch instructions, troubleshooting
- **`scripts/token-status.sh`** — Standalone status line script (copy to `~/.claude/` for permanent use)
