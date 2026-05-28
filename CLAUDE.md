# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

context_forge is a Claude Code plugin that combines two things in one package:

1. **Token-waste reduction** — 14 skills, one diagnostic agent, a session-start hook, and a status line script.
2. **DB-backed project scaffolding** — three slash commands (`/scaffold`, `/changelog`, `/sync-template`), a `PostToolUse` hook, and an MCP server (`forge-db`) that exposes Postgres-stored templates so the model never invents template content or guesses dependency versions.

Bash scripts + markdown for the token-saver half. Node + Postgres (via `pg`) for the forge half. No tests, no build system. The MCP server has its own `package.json` under `mcp/`.

## Installation

```bash
# Symlink into Claude plugins (preferred)
bash scripts/install.sh

# Or load in place
claude --plugin-dir /path/to/context_forge
```

`install.sh` creates `~/.claude/plugins/context_forge -> <repo>` and copies `scripts/statusline-command.sh` to `~/.claude/statusline-command.sh`.

Requires `python3` (hooks + status line) and `node` ≥18 (MCP server + record-change hook). For the forge half: `npm install` inside `mcp/` and export `FORGE_DATABASE_URL` before launching Claude Code.

## Architecture

### Plugin entry points

- **`.claude-plugin/plugin.json`** — plugin manifest (name, version, keywords)
- **`.mcp.json`** — registers the `forge-db` MCP server, reads `${FORGE_DATABASE_URL}` from env, launches `mcp/server.mjs` via stdio
- **`hooks/hooks.json`** — declares hook events: `SessionStart` → `session-start.sh`, `PostToolUse` (`Write|Edit`) → `record-change.mjs`
- **`commands/*.md`** — slash command definitions (frontmatter with `allowed-tools` whitelist) for `/scaffold`, `/changelog`, `/sync-template`
- **`skills/*/SKILL.md`** — each skill is a directory containing a `SKILL.md` (frontmatter + instructions) and optional `references/` docs and `scripts/`
- **`agents/hook-error-fixer.md`** — agent definition (frontmatter: model, tools, color) + full diagnostic instructions
- **`mcp/server.mjs`** — MCP server exposing 7 forge-db tools
- **`mcp/db/schema.sql`** — Postgres schema (templates, template_files, template_deps, projects, changelogs, template_suggestions)

### LTX output format

All token-saver hooks and skills emit structured data in **LTX (Low Token eXchange Format)**:

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

### Record-change hook (forge)

`hooks/scripts/record-change.mjs` runs after every `Write` or `Edit`. It reads the tool event JSON on stdin, looks up the most recent project whose `root_path` is a prefix of the touched file, and inserts a `changelogs` row (`file_created` or `file_edited`). It never blocks the tool — any error exits 0. Requires `FORGE_DATABASE_URL` exported; without it, the hook is a no-op.

### Status line script

`scripts/statusline-command.sh` reads JSON from stdin and renders a colored one-line status showing: dir, git branch, model, context-window bar, CLAUDE.md token estimate, and rate-limit %. Token estimate uses `words × 1.3`. Color thresholds: green → yellow (50%/390t) → orange (75%/780t) → red (90%/1300t). Requires Claude Code v2.1.97+ for `refreshInterval` support.

### Forge MCP server (`mcp/server.mjs`)

Stdio MCP server using `@modelcontextprotocol/sdk` + `pg`. Exposes 7 tools:

| Tool | Purpose |
|------|---------|
| `list_templates` | List template names + stack JSON (call before `/scaffold`) |
| `get_template` | Return one template's files (verbatim content) + pinned deps |
| `register_project` | Insert a row in `projects` after scaffolding |
| `record_change` | Append a changelog row (used by hook + manual stack changes) |
| `get_changelog` | Read recent changelog rows for a project (or all) |
| `compute_suggestions` | Find recurring manual `dep_added` rows and upsert pending suggestions |
| `apply_suggestion` | Insert the suggested dep into `template_deps`, mark suggestion applied |

**Anti-hallucination contract:** template names, file contents, and dependency versions are *only* what these tools return. The `/scaffold` command instructions forbid inventing names or guessing versions and require running the template's `typecheck`/`build` script to validate.

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`, `version`) followed by skill instructions
2. If the skill emits structured data, add a `## LTX Schema` section and use `scripts/ltx.sh` functions
3. Add optional `references/` docs and `scripts/` as needed — no registration required; Claude Code auto-discovers `SKILL.md` files

Several skills currently have only a `references/` doc and no `SKILL.md` yet (e.g., `auto-compact`, `check-claudemd-size`, `debug-hooks`, `estimate-tokens`, `manage-skills`, `project-isolation`, `settings-diff`, `tune-settings`). These are stubs awaiting full skill content.

## Adding a New Agent

Create `agents/<name>.md` with YAML frontmatter:
```yaml
---
name: <name>
model: inherit   # or claude-opus-4-5, etc.
color: yellow    # terminal color hint
tools: ["Read", "Write", "Grep", "Glob", "Bash"]
description: >-
  One-line trigger description
---
```
Follow with `## When to use` examples and the agent's full instructions.

## Adding a New Hook

Add a new event block to `hooks/hooks.json`. Use `$CLAUDE_PLUGIN_ROOT` for all script paths. Valid event names: `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `SubagentStop`, `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `Notification`.

## Adding a New Forge Template

Insert rows into `templates`, `template_files`, `template_deps` (see `mcp/db/seed-example.sql` for shape). Use `{{project_name}}` and `{{year}}` placeholders in file content — those are the only substitutions the scaffolder performs. Everything else is copied verbatim.

## Adding a New Slash Command

Create `commands/<name>.md` with YAML frontmatter declaring `description`, `argument-hint`, and `allowed-tools` (whitelist — including any `mcp__forge-db__*` tools you need). Body is the prompt template; `$ARGUMENTS`, `$0`, `$1`… expand to invocation args.

## Debugging

```bash
# Syntax-check a hook script
bash -n hooks/scripts/session-start.sh

# Run session-start hook manually
CLAUDE_PLUGIN_ROOT=$(pwd) bash hooks/scripts/session-start.sh

# Run record-change hook with a fake tool event
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x"}}' \
  | FORGE_DATABASE_URL="$FORGE_DATABASE_URL" node hooks/scripts/record-change.mjs

# Smoke-test the MCP server (will hang waiting for MCP stdio — Ctrl+C to exit)
DATABASE_URL="$FORGE_DATABASE_URL" node mcp/server.mjs

# Validate settings.json
python3 -m json.tool ~/.claude/settings.json

# Test status line script
echo '{"context_window":{"used_percentage":72},"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Sonnet"}}' \
  | bash scripts/statusline-command.sh

# Verify plugin symlink
ls -la ~/.claude/plugins/context_forge
```

## Coding conduct (Karpathy guidelines)

These rules govern any edit made to this repository, derived from Andrej Karpathy's observations on common LLM coding mistakes:

1. **Think before coding.** State assumptions before implementing. If multiple interpretations exist, present them — do not pick silently. If something is unclear, stop and ask.
2. **Simplicity first.** Write the minimum code that solves the problem. No speculative features, single-use abstractions, unrequested configurability, or error handling for impossible scenarios.
3. **Surgical changes.** Touch only what the request demands. Match existing style. Do not refactor adjacent code, reformat untouched lines, or delete pre-existing dead code unless asked. Remove only orphans the current change created.
4. **Goal-driven execution.** Transform every task into a verifiable success criterion (a passing test, a file with specific content, a green build). State a brief plan for multi-step tasks and verify each step against its criterion.

Apply judgment for trivial fixes (typos, doc rewording). Apply strictly for new skills, hooks, MCP changes, schema changes, and anything touching `mcp/`, `hooks/`, or the forge MCP contract.

## Project standards (adapted from Anthropic guidelines)

Adapted from the Anthropic internal coding standards template. The generic template assumes TypeScript/Python/Rust + a test suite; this repo is Bash + Node ESM + Markdown + Postgres. Do not paste the generic version verbatim in future sessions.

### Stack (factual, not aspirational)

- **Languages present:** Bash (hooks, scripts), Node.js ESM `.mjs` (MCP server + record-change hook), Markdown (skills, commands, docs), SQL (Postgres schema).
- **Not present:** TypeScript, Bun, Python source (only `python3 -m json.tool` for debug), Rust, any test framework, any linter, any bundler.
- **Single Node package:** `mcp/package.json` (deps: `@modelcontextprotocol/sdk`, `pg`). Nothing else has a `package.json`.

### Build, install, and verify commands

| Purpose | Command |
|---------|---------|
| Symlink plugin into `~/.claude/plugins/` | `bash scripts/install.sh` |
| Install MCP server deps | `cd mcp && npm install` |
| Apply forge schema | `psql "$FORGE_DATABASE_URL" -f mcp/db/schema.sql` |
| Validate every JSON file | `python3 -m json.tool <file>` |
| Syntax-check `.mjs` | `node --check <file>` |
| Syntax-check `.sh` | `bash -n <file>` |
| Smoke-test MCP server | `DATABASE_URL=$FORGE_DATABASE_URL node mcp/server.mjs` (Ctrl+C to exit) |
| Run record-change hook | `echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x"}}' \| FORGE_DATABASE_URL=$FORGE_DATABASE_URL node hooks/scripts/record-change.mjs` |
| Run session-start hook | `CLAUDE_PLUGIN_ROOT=$(pwd) bash hooks/scripts/session-start.sh` |

There is **no `npm test`, no `pytest`, no `npm run lint`, no `black`** in this repo. Do not invent them. If a test framework is added later, document it here at the same time.

### Steering rules

1. **Never hallucinate APIs, template names, package versions, or commands.** Copy MCP tool output verbatim. Every command in this file must exist and pass before being added.
2. **No new languages without explicit ask.** Current stack is Bash + Node `.mjs` + Markdown + SQL. Do not introduce TypeScript, Python source files, or Rust unless the user requests it.
3. **Strict value safety.** For any value that originates in `forge-db` (template content, dependency versions, file paths from changelogs), use the exact returned value. No reformatting, no upgrades, no normalisation.
4. **No new feature without verifiable success.** Before declaring a change done, run the relevant verify command from the table above (JSON parse, `node --check`, `bash -n`). For skill changes, run the broken-ref + second-person audit shown in this file's history.
5. **Tests, when introduced, live in `tests/` and must pass before commit.** The directory does not exist yet; do not block work on a gate that has no implementation. When the first test framework lands, this rule activates fully.
6. **Keep this file under 12,000 characters.** `wc -c CLAUDE.md` is the budget. Move detail to skill `references/` or feature-specific docs when the cap is approached. Do not pad with framing prose.
