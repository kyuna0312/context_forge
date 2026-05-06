# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

context_guard is a Claude Code plugin for reducing token waste. It ships 14 skills, one diagnostic agent, a session-start hook, and a status line script. No build system, no package manager, no tests — all components are bash scripts and markdown files.

## Installation

```bash
# Symlink into Claude plugins
bash scripts/install.sh

# Or load in place
claude --plugin-dir /path/to/context_guard
```

Requires `python3` at runtime (used by hooks and the status line script).

## Architecture

### Plugin entry points

- **`.claude-plugin/plugin.json`** — plugin manifest (name, version, keywords)
- **`hooks/hooks.json`** — declares hook events; currently registers `SessionStart` → `hooks/scripts/session-start.sh`
- **`skills/*/SKILL.md`** — each skill is a directory containing a `SKILL.md` (frontmatter + instructions) and optional `references/` docs and `scripts/`
- **`agents/hook-error-fixer.md`** — agent definition (frontmatter: model, tools, color) + full diagnostic instructions

### LTX output format

All hooks and skills emit structured data in **LTX (Low Token eXchange Format)**:

```
@v1:field1|field2|field3     ← schema header
value|value|value             ← data rows (pipe-delimited)
```

Human-readable warnings go to **stderr**; machine-readable LTX rows go to **stdout**. The shared encoding library is `scripts/ltx.sh` — source it to get `ltx_header`, `ltx_row`, and `ltx_human`.

Hook and skill scripts must use `$CLAUDE_PLUGIN_ROOT` (not hardcoded paths) when referencing plugin files.

### Session-start hook

`hooks/scripts/session-start.sh` runs on every `SessionStart`. It:
1. Checks CLAUDE.md word count against thresholds (`WARN_WORDS=600`, `CRIT_WORDS=1000`)
2. Validates `~/.claude/settings.json` JSON syntax
3. Emits LTX rows with schema `@v1:file|words|tokens|level`

### Token status line

`skills/token-statusline/scripts/token-status.sh` reads JSON from stdin (Claude Code injects `context_window.used_percentage`) and prints a colored bar. The install script copies it to `~/.claude/token-status.sh`. Requires Claude Code v2.1.97+ for `refreshInterval` support.

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`, `version`) followed by skill instructions
2. If the skill emits structured data, add a `## LTX Schema` section and use `scripts/ltx.sh` functions
3. Add optional `references/` docs and `scripts/` as needed — no registration required; Claude Code auto-discovers `SKILL.md` files

## Adding a New Hook

Add a new event block to `hooks/hooks.json`. Use `$CLAUDE_PLUGIN_ROOT` for all script paths. Valid event names: `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `SubagentStop`, `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `Notification`.

## Debugging Hooks

```bash
# Syntax-check a hook script
bash -n hooks/scripts/session-start.sh

# Run session-start hook manually
CLAUDE_PLUGIN_ROOT=$(pwd) bash hooks/scripts/session-start.sh

# Validate settings.json
python3 -m json.tool ~/.claude/settings.json

# Test status line script
echo '{"context_window":{"used_percentage":72},"workspace":{"current_dir":"'"$PWD"'"}}' \
  | bash skills/token-statusline/scripts/token-status.sh
```
