# context_guard

A Claude Code plugin that reduces token waste and extends context window life. Includes 14 skills, a diagnostic agent, session-start hooks, and a live status line showing context usage.

---

## Skills

| Skill | What it does |
|-------|-------------|
| `optimize-claudemd` | Compresses bloated CLAUDE.md — cuts 40–80% of tokens loaded every session |
| `low-token-mode` | Switches Claude to terse response style — cuts reply tokens by 30–50% |
| `reset-context` | Safely resets context window when near full — prevents hard stops |
| `tune-settings` | Diffs and applies token-saving settings (`autoLoadMemory`, `autoLoadSkills`, etc.) |
| `manage-skills` | Audits loaded skills, disables unused ones — reduces session overhead |
| `project-isolation` | Scopes skills and hooks to current project only |
| `estimate-tokens` | Estimates tokens in any file before loading it |
| `auto-compact` | Configures `compactOnContextFull` — auto-compacts instead of stopping |
| `settings-diff` | Shows before/after diff before writing any settings change |
| `check-claudemd-size` | Reports CLAUDE.md word/token count with color-coded warnings |
| `token-statusline` | Adds live context bar to Claude Code status line |
| `debug-hooks` | Diagnoses broken hook configurations with detailed validation output |
| `task-brain-lite` | Decomposes complex tasks into prioritized, dependency-aware subtasks |
| `llm-wiki` | Builds a persistent wiki Claude references instead of re-reading raw docs — up to 96% token savings on repeated knowledge |

**Agent:** `hook-error-fixer` — diagnoses and auto-fixes broken hook configurations.

**Hook:** Session-start script that warns when CLAUDE.md exceeds size thresholds.

**Status line:**
```
ctx [████████░░] 82%  │  md:~650t
```

---

## Requirements

- Claude Code v2.1.97 or later (for `refreshInterval` support)
- `python3` — used by the token status line script and hook validation

---

## Installation

### Option A — Clone directly into Claude plugins

```bash
git clone https://github.com/kyuna0312/context_guard.git ~/.claude/plugins/context_guard
```

### Option B — Clone anywhere, load with --plugin-dir

```bash
git clone https://github.com/kyuna0312/context_guard.git ~/context_guard
claude --plugin-dir ~/context_guard
```

### Option C — Use the install script

```bash
git clone https://github.com/kyuna0312/context_guard.git ~/context_guard
bash ~/context_guard/scripts/install.sh
```

The install script symlinks the plugin into `~/.claude/plugins/context_guard`.

### Option D — Use in place (Desktop)

```bash
claude --plugin-dir ~/Desktop/context_guard
```

---

## Token Status Line Setup

The status line shows live context window usage at the bottom of the terminal.

**Step 1 — Copy script to permanent location:**

```bash
cp ~/.claude/plugins/context_guard/skills/token-statusline/scripts/token-status.sh ~/.claude/token-status.sh
chmod +x ~/.claude/token-status.sh
```

**Step 2 — Add to `~/.claude/settings.json`:**

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/token-status.sh",
    "refreshInterval": 30
  }
}
```

**Step 3 — Restart Claude Code.**

**Test before wiring up:**

```bash
echo '{"context_window":{"used_percentage":72},"workspace":{"current_dir":"'"$PWD"'"}}' \
  | bash ~/.claude/token-status.sh
```

Expected output: `ctx [███████░░░] 72%`

**Color thresholds:**

| Context % | Color  |
|-----------|--------|
| 0–49%     | Green  |
| 50–74%    | Yellow |
| 75–89%    | Orange |
| 90–100%   | Red    |

---

## Session-Start Hook

Runs automatically when Claude Code starts. Warns if CLAUDE.md exceeds size thresholds.

To customize thresholds, edit `hooks/scripts/session-start.sh`:

```bash
readonly WARN_WORDS=600    # yellow warning
readonly CRIT_WORDS=1000   # red critical
```

---

## LTX Output Format

Skills and hooks emit structured data in **LTX (Low Token eXchange Format)** — a schema-based, pipe-delimited format that minimizes token overhead compared to JSON.

### Format

```
@v1:field1|field2|field3
value|value|value
value|value|value
```

- Header line: `@v1:<schema>` — defines field names
- Data rows: pipe-delimited values, one per line

### Example — session-start hook output

**stdout (LTX, machine-readable):**
```
@v1:file|words|tokens|level
~/.claude/CLAUDE.md|850|1105|critical
./CLAUDE.md|320|416|ok
~/.claude/settings.json|0|0|valid
```

**stderr (human-readable, only when thresholds exceeded):**
```
⚠ TOKEN SAVER [CRITICAL]: ~/.claude/CLAUDE.md is 850 words (~1105 tokens). Run /optimize-claudemd
```

### Skill Schemas

| Skill | LTX Schema |
|-------|------------|
| `estimate-tokens` | `@v1:source\|words\|tokens\|status` |
| `check-claudemd-size` | `@v1:file\|words\|tokens\|level` |
| `token-statusline` | `@v1:context_pct\|bar\|md_tokens\|color` |
| `debug-hooks` | `@v1:hook\|status\|error\|fix` |
| `tune-settings` | `@v1:setting\|current\|recommended\|action` |

Each skill's `SKILL.md` contains a `## LTX Schema` section with field definitions and examples.

---

## Skills Quick Reference

Trigger any skill by describing what you want:

- *"optimize my CLAUDE.md"* → `optimize-claudemd`
- *"switch to low token mode"* → `low-token-mode`
- *"reset context"* → `reset-context`
- *"check my settings"* → `tune-settings`
- *"how many tokens is this file?"* → `estimate-tokens`
- *"set up auto compact"* → `auto-compact`
- *"how big is my CLAUDE.md?"* → `check-claudemd-size`
- *"show me settings diff before saving"* → `settings-diff`
- *"add token counter to status line"* → `token-statusline`
- *"audit my loaded skills"* → `manage-skills`
- *"isolate this project"* → `project-isolation`
- *"validate my hooks"* → `debug-hooks`
- *"break down this task"* → `task-brain-lite`
- *"fix my hooks"* → triggers `hook-error-fixer` agent
- *"build a wiki from my docs"* → `llm-wiki`
- *"stop re-reading docs every session"* → `llm-wiki`

---

## Project Structure

```
context_guard/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # Marketplace metadata
├── agents/
│   └── hook-error-fixer.md      # Auto-diagnoses broken hooks
├── hooks/
│   ├── hooks.json               # Hook event configuration
│   └── scripts/
│       └── session-start.sh     # CLAUDE.md size warning on startup
├── scripts/
│   ├── install.sh               # Installation helper (symlinks plugin)
│   └── ltx.sh                   # Shared LTX encoding library (sourced by hooks/scripts)
└── skills/
    ├── auto-compact/
    ├── check-claudemd-size/
    ├── debug-hooks/
    │   └── scripts/
    │       └── validate-hooks.sh
    ├── estimate-tokens/
    ├── llm-wiki/
    │   └── references/
    │       └── wiki-patterns.md
    ├── low-token-mode/
    ├── manage-skills/
    ├── optimize-claudemd/
    ├── project-isolation/
    ├── reset-context/
    ├── settings-diff/
    ├── task-brain-lite/
    ├── token-statusline/
    │   └── scripts/
    │       └── token-status.sh  # Status line script (copy to ~/.claude/)
    └── tune-settings/
```

---

## License

MIT
