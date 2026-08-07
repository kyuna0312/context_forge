# Status Line Setup Reference

## How Claude Code Status Line Works

Status line runs a shell command that outputs a single colored line.
Claude Code passes JSON on stdin; script outputs ANSI-colored text.

### JSON Input Fields (available in script)

```json
{
  "context_window": {
    "used_percentage": 42.3,
    "remaining_percentage": 57.7
  },
  "workspace": {
    "current_dir": "/home/user/project",
    "git_worktree": "..."
  },
  "model": {
    "display_name": "Fable 5"
  },
  "rate_limits": {
    "5h":  { "used_percentage": 23.0, "resets_at": "2025-..." },
    "7d":  { "used_percentage": 11.0, "resets_at": "2025-..." }
  },
  "current_usage": { ... }
}
```

### Settings Configuration

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/script.sh",
    "refreshInterval": 30
  }
}
```

`refreshInterval` — seconds between auto-reruns (added in Claude Code v2.1.97).

---

## Setup Options

### Option A: Standalone (replace existing status line)

Copy script first (plugin path may change on reinstall):

```bash
cp "${CLAUDE_PLUGIN_ROOT}/scripts/statusline-command.sh" ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Then wire up:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 30
  }
}
```

Shows: `ctx [████████░░] 82%  │  md:~650t`

### Option B: Extend an existing status line

If you have your own status line script, add the token bar to it.

In existing script, after extracting `used_pct`:

```bash
# Token visualization block (add near end of existing script)
used_int=$(printf "%.0f" "${used_pct:-0}")

# Build bar
filled=$(( used_int / 10 ))
empty=$(( 10 - filled ))
bar=""; for i in $(seq 1 $filled); do bar="${bar}█"; done
for i in $(seq 1 $empty); do bar="${bar}░"; done

# Color thresholds
ctx_color="\033[38;2;157;255;204m"   # green
[ "$used_int" -ge 50 ] && ctx_color="\033[38;2;255;217;125m"   # yellow
[ "$used_int" -ge 75 ] && ctx_color="\033[38;2;255;179;100m"   # orange
[ "$used_int" -ge 90 ] && ctx_color="\033[38;2;255;120;120m"   # red

printf " ${ctx_color}ctx [${bar}] ${used_int}%%\033[0m"
```

---

## Thresholds Used in statusline-command.sh

| Context % | Color  | Meaning         |
|-----------|--------|-----------------|
| 0–49%     | Green  | Healthy          |
| 50–74%    | Yellow | Monitor          |
| 75–89%    | Orange | Getting full     |
| 90–100%   | Red    | Compact soon     |

| CLAUDE.md tokens | Color  | Meaning          |
|------------------|--------|------------------|
| < 390            | Green  | Optimal           |
| 390–779          | Yellow | Acceptable        |
| 780–1299         | Orange | Bloated           |
| ≥ 1300           | Red    | Critical — optimize|

---

## Troubleshooting

**Status line shows nothing:**
- Check script is executable: `chmod +x script.sh`
- Test manually: `echo '{}' | bash script.sh`
- Verify `python3` is installed: `which python3`

**No color:**
- Terminal must support ANSI color codes
- In tmux: ensure `set -g default-terminal "screen-256color"` in `.tmux.conf`

**Old value displayed:**
- `refreshInterval` controls rerun frequency (seconds)
- Without `refreshInterval`, script only runs on session start + on events

**Rate limit section not showing:**
- `rate_limits` field only populated on Claude.ai (not API/Bedrock)
- Section silently hidden when field is empty — correct behavior

---

## Token Cost of Status Line

Running the script every 30s has negligible cost — it runs locally,
never sends tokens to Claude. Only the display string costs ~0 tokens
(status line output is not part of conversation context).
