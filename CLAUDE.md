# CLAUDE.md — context_forge Rules

Guidance for Claude Code working in this repository. Rules are grouped into four sections: **A. Architecture · B. Anti-Hallucination & Value Safety · C. Extending the Plugin · D. Agent Operating Mode**. A compressed **DO NOT** checklist closes the file.

## Project

context_forge is a Claude Code plugin combining two halves:

1. **Token-waste reduction** — 15 skills, one diagnostic agent, a session-start hook, and a status line script.
2. **DB-backed project scaffolding (forge)** — `/scaffold`, `/changelog`, `/sync-template` slash commands, a `PostToolUse` hook, and the `forge-db` MCP server exposing Postgres-stored templates so the model never invents template content or guesses dependency versions.

Bash + markdown for the token-saver half; Node ESM + Postgres (`pg`) for the forge half. Tests: zero-dep `node --test` suite in `tests/`. No build system.

**Install**: `bash scripts/install.sh` (symlinks into `~/.claude/plugins/`, copies + backs up the statusline script) or `claude --plugin-dir <repo>`. Requires `python3` and `node` ≥18. Forge half additionally: `cd mcp && npm install` + `FORGE_DATABASE_URL` exported before launching Claude Code.

---

## A. Architecture

### Plugin entry points

- **`.claude-plugin/plugin.json`** — plugin manifest (name, version, keywords)
- **`.mcp.json`** — registers `forge-db`, reads `${FORGE_DATABASE_URL}`, launches `mcp/server.mjs` via stdio
- **`hooks/hooks.json`** — `SessionStart` → `session-start.sh`, `PostToolUse` (`Write|Edit`) → `mcp/record-change.mjs` (both with timeouts)
- **`commands/*.md`** — slash commands (frontmatter with `allowed-tools` whitelist)
- **`skills/*/SKILL.md`** — frontmatter + instructions, optional `references/` and `scripts/`
- **`agents/hook-error-fixer.md`** — agent definition (frontmatter: model, tools, color) + diagnostic instructions
- **`mcp/server.mjs`** — SDK wiring; tools live in `mcp/tools.mjs`, DB helper in `mcp/db.mjs`
- **`mcp/db/schema.sql`** — Postgres schema (templates, template_files, template_deps, projects, changelogs, template_suggestions)

### LTX output format

Token-saver hooks and some skills emit **LTX (Low Token eXchange Format)**:

```
@v1:field1|field2|field3     ← schema header
value|value|value             ← pipe-delimited data rows
```

Human warnings → **stderr**; LTX rows → **stdout**. The three one-line emitters (`ltx_header`, `ltx_row`, `ltx_human`) live inline in `hooks/scripts/session-start.sh` — copy them into any new LTX-emitting script. A skill that emits LTX documents it in a `## LTX Schema` section; a skill that doesn't must not carry a dead schema section.

Hook and skill scripts must use `$CLAUDE_PLUGIN_ROOT` (never hardcoded paths) for plugin files. That variable only resolves inside plugin hooks — user-facing examples use real paths like `~/.claude/hooks/`.

### Session-start hook

`hooks/scripts/session-start.sh` on every `SessionStart`: checks CLAUDE.md word counts (`WARN_WORDS=600`, `CRIT_WORDS=1000`, `-ef` guard against case-insensitive double-count), validates `~/.claude/settings.json` (emits `skipped` when python3 is absent), emits LTX schema `@v1:file|words|tokens|level`.

### Record-change hook (forge)

`mcp/record-change.mjs` after every `Write`/`Edit`: reads the tool event JSON on stdin, attaches the file to the most recent project whose `root_path` is a prefix, inserts a `changelogs` row. **It never blocks the tool** — every error exits 0; `pg` is imported lazily and the connect timeout is 3s. Without `FORGE_DATABASE_URL` or `mcp/node_modules` it is a silent no-op **by design** — check those before declaring it broken.

### Status line script

`scripts/statusline-command.sh` reads JSON from stdin, renders dir, git branch, model, context bar, CLAUDE.md token estimate (words × 1.3), rate-limit %. Fields travel `\x1f`-separated (model names and paths contain spaces). Color thresholds: green → yellow (50%/390t) → orange (75%/780t) → red (90%/1300t). Requires Claude Code v2.1.97+ for `refreshInterval`.

### Forge MCP server (`mcp/server.mjs` + `tools.mjs`)

Stdio server (`McpServer` + zod raw shapes) exposing 7 tools:

| Tool | Purpose |
|------|---------|
| `list_templates` | Names + stack JSON; also the only `template_id` → name map (`get_template` looks up by *name* only) |
| `get_template` | One template's files (verbatim) + pinned deps |
| `register_project` | Insert `projects` row; errors on unknown template name |
| `record_change` | Append changelog row; `dep_added` requires `package` |
| `get_changelog` | Recent rows (limit 1–500, default 50) |
| `compute_suggestions` | Upsert recurring manual-dep suggestions |
| `apply_suggestion` | Apply one suggestion; returns `dep_inserted` (false = package already present, existing version kept); errors on unimplemented kinds |

Tool errors (unset URL, unreachable DB) surface as clear messages — report them to the user; never fabricate data to fill the gap.

---

## B. Anti-Hallucination & Value Safety (CRITICAL)

1. **Template names, file contents, and dependency versions exist ONLY in forge-db tool output.** Copy verbatim — no reformatting, upgrades, or normalisation. `/scaffold` must run the template's `typecheck`/`build` to validate.
2. **Never write undocumented Claude Code settings keys.** `autoLoadSkills`, `autoLoadMemory`, `compactOnContextFull`, `verboseOutput`, `plugins.autoEnable` do **not exist**. Real keys used in this repo's docs: `autoMemoryEnabled`, `autoCompactEnabled`/`autoCompactWindow`, `disableBundledSkills`, `disabledMcpjsonServers`, `statusLine`. Verify anything else against official docs first.
3. **Skill bodies lazy-load** — only frontmatter descriptions cost tokens every session. Don't write skill docs that claim otherwise.
4. **Every command written into docs or this file must exist and pass before being added.** No `npm test`, `pytest`, `npm run lint`, or `black` here — the only test entry point is `node --test`.
5. On any forge-db error: stop and report the missing piece (env var, schema, connectivity). Zero rows means "nothing recorded", not license to guess.

---

## C. Extending the Plugin

- **Skill**: `skills/<name>/SKILL.md` with `name`/`description`/`version` frontmatter. Triggers AND anti-triggers ("Do NOT use for…") in the description. LTX emitters copied from `session-start.sh` if it emits structured data. Auto-discovered, no registration.
- **Agent**: `agents/<name>.md` with `name`, `model: inherit`, `color`, `tools: [...]`, `description` frontmatter, then `## When to use` examples + instructions.
- **Hook**: new event block in `hooks/hooks.json`. Valid events: `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `SubagentStop`, `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `Notification`. Always set a `timeout`; scripts must degrade to no-op rather than block tools.
- **Forge template**: rows in `templates`/`template_files`/`template_deps` (shape: `mcp/db/seed-example.sql`). Only `{{project_name}}` and `{{year}}` are substituted; everything else is copied verbatim.
- **Slash command**: `commands/<name>.md` with `description`, `argument-hint`, `allowed-tools` (whitelist incl. needed `mcp__forge-db__*`). `$ARGUMENTS`, `$0`, `$1`… expand to args.

---

## D. Agent Operating Mode

### Working agreement (ponytail: lazy senior dev)

Lazy = efficient, not careless. The best code is the code never written. Before writing code, stop at the first rung that holds:

1. **Does this need to exist at all?** (YAGNI)
2. **Already in this repo?** Reuse the helper/pattern a few files over.
3. **Stdlib, native platform feature, or already-installed dep covers it?** Use it.
4. **Can it be one line?** One line.
5. **Only then:** the minimum code that works.

The ladder runs *after* understanding, never instead of it: read the task and the code it touches, trace the real flow end to end, then climb. State assumptions; multiple interpretations → present them; unclear → ask.

- **Bug fix = root cause, not symptom**: grep every caller of the function you touch; one guard in the shared function beats a patch per caller — and patching only the reported path leaves siblings broken.
- Deletion over addition; boring over clever; fewest files; shortest working diff — but the smallest change in the wrong place is a second bug.
- No unrequested abstractions, dependencies, or boilerplate. Question complex asks: "does Y already cover X?"
- Equal-size stdlib options → take the edge-case-correct one. Mark deliberate corner-cuts with a `ponytail:` comment naming the ceiling and upgrade path.
- **Platform-native first**: Node built-ins over packages (`fs.mkdirSync({recursive:true})`, `crypto.randomUUID()`, `[...new Set(arr)]`); DB over app code (`UNIQUE`/`FK`/`CHECK`, `DEFAULT now()` — `schema.sql` already works this way). A wrapper earns its place only when native is genuinely insufficient.
- **Never lazy about**: understanding the problem, validation at trust boundaries, error handling that prevents data loss, security, anything explicitly requested.
- Non-trivial logic leaves ONE runnable check behind — in this repo, a case in `tests/repo.test.mjs`. Trivial one-liners need none.

Apply judgment for trivial fixes; apply strictly for anything touching `mcp/`, `hooks/`, schema, or the forge contract. No new languages (TypeScript, Python source, Rust) without explicit ask — the stack is Bash + Node `.mjs` + Markdown + SQL, single `package.json` in `mcp/`.

### Verify commands

| Purpose | Command |
|---------|---------|
| Full test suite | `node --test` (repo root; discovers `tests/`) |
| Validate JSON | `python3 -m json.tool <file>` |
| Syntax-check | `bash -n <file>` / `node --check <file>` |
| Smoke MCP server | `DATABASE_URL=$FORGE_DATABASE_URL node mcp/server.mjs` (Ctrl+C) |
| Run record-change hook | `echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x"}}' \| FORGE_DATABASE_URL=$FORGE_DATABASE_URL node mcp/record-change.mjs` |
| Run session-start hook | `CLAUDE_PLUGIN_ROOT=$(pwd) bash hooks/scripts/session-start.sh` |
| Test status line | `echo '{"context_window":{"used_percentage":72},"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Fable 5"}}' \| bash scripts/statusline-command.sh` (model name must render whole) |
| Apply forge schema | `psql "$FORGE_DATABASE_URL" -f mcp/db/schema.sql` |

### Forced verification

- `node --test` must be green **before every commit**. The suite covers JSON validity, hook config/events, frontmatter, script syntax, hook runtime behavior, and cross-references (forge-db tool names used in commands/skills, SKILL.md file refs, `.mcp.json` script path) — the broken-ref audit is automated, don't redo it by hand.
- A successful file write ≠ correct code: run the relevant verify command from the table before saying "done".
- **This file stays under 12,000 characters** (`wc -c CLAUDE.md`). Move detail to skill `references/`; do not pad with framing prose.

---

## DO NOT (quick checklist)

- ❌ Invent template names/contents/versions (forge-db output only, verbatim) · ❌ Fabricate data when a forge tool errors or returns zero rows
- ❌ Write undocumented settings keys (`autoLoadSkills` etc. don't exist) · ❌ Add commands to docs that you haven't run
- ❌ `npm test` / `pytest` / `npm run lint` (only `node --test`) · ❌ New languages without ask
- ❌ Hardcode plugin paths in hooks (use `$CLAUDE_PLUGIN_ROOT`) — but never show `$CLAUDE_PLUGIN_ROOT` in user-facing config examples
- ❌ Let a hook block a tool (record-change exits 0 always; timeouts on every hook) · ❌ Invent hook event names
- ❌ Claim skills bulk-load bodies (lazy-loaded; descriptions are the constant cost) · ❌ Dead LTX sections in skills that never emit LTX
- ❌ Commit with failing `node --test` · ❌ Let this file exceed 12,000 chars
