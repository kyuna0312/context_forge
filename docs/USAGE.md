# Using context_forge — the daily workflow

Install first ([README §Installation](../README.md#installation)), restart
Claude Code, then everything below is available. Nothing here needs
memorizing — skills trigger on plain language.

## A normal day (token-saver half)

**Session start — automatic.** The hook checks your CLAUDE.md sizes and
warns when they're bloated; the status line renders at the bottom:

```
~/Desktop/my-app main Fable 5 │ ctx [████░░░░░░] 42% │ md:~2087t
```

Watch the context bar while you work: green → yellow (50%) → orange (75%) →
red (90%). Yellow/orange is the moment to run `/compact`.

**When you need to save tokens — just say it:**

| Say | Skill that fires | What happens |
|-----|------------------|--------------|
| "optimize my claude.md" / "claude.md is too big" | `optimize-claudemd` | Compresses it, shows a diff, asks before writing |
| "what's eating my context" | `estimate-tokens` | Per-source token breakdown + top consumers |
| "low token mode" | `low-token-mode` | 150-token response discipline until you say "normal mode" |
| "context is full" / "start fresh" | `reset-context` | Emits a paste-back summary, then points you at `/compact` or `/clear` |
| "tune my settings for tokens" | `tune-settings` | Proposes only documented keys, diff before write |
| "hook error" / "hook not working" | `debug-hooks` | Diagnoses; hands off to the `hook-error-fixer` agent for multi-step repair |
| "break down this task" / "plan this" | `task-brain-lite` | Complexity call → dependency table → one task per response |
| "stop re-reading docs every session" | `llm-wiki` | Builds a persistent wiki instead of raw-doc re-ingestion |

Direct invocation works too: `/context_forge:optimize-claudemd` etc.

## Forge half (needs Postgres)

One-time setup, in the shell that launches Claude Code:

```bash
export FORGE_DATABASE_URL="postgres://user:pass@host:5432/forge"
psql "$FORGE_DATABASE_URL" -f mcp/db/schema.sql
psql "$FORGE_DATABASE_URL" -f mcp/db/seed-example.sql   # example template
```

Without `FORGE_DATABASE_URL` the forge half is inert; the token-saver half
keeps working.

The loop — **templates improve themselves as you use them**:

1. `/scaffold node-ts-basic my-app` — creates a project from the DB
   template. Files and dependency versions are copied verbatim; the model
   invents nothing, and validates with the template's `typecheck`/`build`.
2. Work normally. Every `Write`/`Edit` is recorded to `changelogs`
   automatically by the PostToolUse hook. Read it back: `/changelog my-app`.
3. `/sync-template` — "you added `zod` by hand in 4 projects built from
   this template; fold it in?" Confirm, and the next `/scaffold` starts
   better.

Conversational phrasing works for the same flows: "what did I change
yesterday", "what packages keep recurring" (the `forge-changelog` skill).

## When something's off

- Statusline shows a truncated model name ("Fable" without "5") → your
  `~/.claude/` copy is outdated: re-run `bash scripts/install.sh`.
- record-change hook seems silent → by design it never blocks tools; check
  `FORGE_DATABASE_URL` and `mcp/node_modules` (see `debug-hooks`).
- Anything hook-related → `CLAUDE_PLUGIN_ROOT=<repo> bash <repo>/skills/debug-hooks/scripts/validate-hooks.sh <config>`

Deeper reading: [ARCHITECTURE.md](ARCHITECTURE.md) for the end-to-end
flows, [ROADMAP.md](ROADMAP.md) for known ceilings.
