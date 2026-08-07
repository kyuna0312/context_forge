# Architecture

How the two halves of context_forge fit together end to end. Component-level
reference lives in [CLAUDE.md](../CLAUDE.md) §A; install/setup in the
[README](../README.md). This document tells the flows.

---

## Half 1 — Token-saver

### Session start

```
Claude Code SessionStart
  └─ hooks/hooks.json (timeout 15)
       └─ hooks/scripts/session-start.sh
            ├─ word-counts ~/.claude/CLAUDE.md + $CLAUDE_PROJECT_DIR/CLAUDE.md
            │    (-ef guard: CLAUDE.md/claude.md are one file on macOS)
            ├─ validates ~/.claude/settings.json (python3 absent → "skipped")
            ├─ stdout → LTX rows   @v1:file|words|tokens|level
            └─ stderr → human warnings (only when thresholds exceeded)
```

Thresholds: warn ≥600 words, critical ≥1000. Token estimate = words × 1.3.

### Status line

```
Claude Code (every refreshInterval / event)
  └─ JSON on stdin → scripts/statusline-command.sh → one ANSI line
```

Fields travel `\x1f`-separated between the embedded python parser and bash —
model names ("Fable 5") and paths contain spaces, which would shift
space-split fields. The script is *copied* to `~/.claude/` by `install.sh`;
it does not update itself — re-run `install.sh` after pulling.

### Skills

Lazy-loaded: every installed skill's frontmatter description (~100 tokens)
loads each session; the SKILL.md body loads only on invocation. The plugin's
own token advice is built on this fact — the constant cost lever is
description count and CLAUDE.md size, not body size.

---

## Half 2 — Forge (DB-backed scaffolding)

### The loop at a glance

```
/scaffold ──────────► project files + register_project
     Write/Edit ────► record-change hook ────► changelogs
/sync-template ─────► compute_suggestions ──► pending suggestions
     user confirms ─► apply_suggestion ─────► template_deps (template improved)
     next /scaffold ► better template
```

### Scaffold flow

1. `list_templates` — the only valid source of template names (and the only
   `template_id` → name map; `get_template` looks up by name only).
2. `get_template` — files + deps returned verbatim. The model is a copier:
   only `{{project_name}}` and `{{year}}` are substituted.
3. Files written under the new project dir. Guards: refuse a non-empty
   target dir; reject absolute/`..` paths from the DB (trust boundary).
4. Deps written with the **exact** returned versions, then install + the
   template's `typecheck`/`build` script — success is verified, not claimed.
5. `register_project` records name + root_path (errors on unknown template).

### Change tracking

```
PostToolUse (Write|Edit, timeout 10)
  └─ mcp/record-change.mjs   (stdin: tool event JSON)
       ├─ no FORGE_DATABASE_URL / no mcp/node_modules → silent no-op BY DESIGN
       ├─ pg.Client connectionTimeoutMillis: 3000 (unreachable host ≠ hang)
       ├─ project = latest projects row whose root_path prefixes the file
       └─ INSERT changelogs (file_created | file_edited) — any error → exit 0
```

The hook must never block the tool; that constraint shapes everything above.
Manual `dep_added` / `stack_changed` rows go through the `record_change` MCP
tool (`dep_added` requires `package`).

### Back-mapping (template feedback)

`compute_suggestions` aggregates `dep_added` rows across projects of the same
template, skipping packages already in `template_deps`, and upserts pending
`template_suggestions` (`min_occurrences` default 2). `apply_suggestion`
inserts the dep (`ON CONFLICT DO NOTHING` — the return's `dep_inserted:
false` means the package was already there and the existing pinned version
won) and marks the suggestion applied. Unimplemented kinds (`add_file`,
`change_stack`) error instead of silently flipping to applied.

### Failure modes

| Condition | Behavior |
|-----------|----------|
| `FORGE_DATABASE_URL` unset | MCP tools error with an explicit message; record-change is a no-op |
| DB host unreachable | Tool call errors after 5s (pool) / hook gives up after 3s |
| Idle connection dropped | Pool logs to stderr; server keeps running |
| Tool returns zero rows | The answer is "nothing recorded" — never fabricated data |

---

## Data model

```
templates ─┬─< template_files   (verbatim content, {{placeholders}})
           ├─< template_deps    (exact pinned versions)
           └─< template_suggestions  (pending | applied | dismissed)
projects ──┬─ template_id → templates
           └─< changelogs      (append-only; project_name denormalised fallback)
```

Schema: `mcp/db/schema.sql` (idempotent). Seed: `mcp/db/seed-example.sql` —
note its header warning: file contents must be dollar-quoted; `'\n'` in a
plain literal stores backslash+n and scaffolds garbage.

---

## LTX (Low Token eXchange Format)

```
@v1:field1|field2|field3     ← schema header, once
value|value|value             ← data rows
```

stdout carries LTX (machine), stderr carries prose (human). Emitters are
three one-line bash functions in `session-start.sh` — copy them, don't
abstract them. A skill documents its schema in a `## LTX Schema` section;
a skill that never emits LTX must not carry one.
