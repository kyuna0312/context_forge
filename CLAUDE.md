# CLAUDE.md — context_forge Rules

context_forge is a Claude Code plugin, two halves:

1. **Token-waste reduction** — 15 skills, `hook-error-fixer` agent, session-start hook, status line script.
2. **Forge: DB-backed scaffolding** — `/scaffold`, `/changelog`, `/sync-template`, a `PostToolUse` hook, and the `forge-db` MCP server exposing Postgres-stored templates so the model never invents template content or guesses dependency versions.

Stack: Bash + Markdown (token half); Node ESM + Postgres `pg` (forge half), single `package.json` in `mcp/`. Tests: zero-dep `node --test` suite in `tests/`. No build system. Install: `bash scripts/install.sh` — marketplace registration; a bare symlink under `~/.claude/plugins` is NOT discovered. Dev: `claude --plugin-dir <repo>`. Needs `python3`, `node` ≥18; forge also `cd mcp && npm install` + `FORGE_DATABASE_URL` exported at launch. Wiki: read `wiki/` before raw docs.

## A. Architecture

Entry points: `.claude-plugin/plugin.json` (manifest) · `.mcp.json` (forge-db, reads `${FORGE_DATABASE_URL}`, stdio `mcp/server.mjs`) · `hooks/hooks.json` (SessionStart → `session-start.sh`; PostToolUse `Write|Edit` → `mcp/record-change.mjs`; both with timeouts) · `commands/*.md` (frontmatter `allowed-tools` whitelist) · `skills/*/SKILL.md` · `agents/hook-error-fixer.md` · `mcp/tools.mjs` + `mcp/db.mjs` · `mcp/db/schema.sql`.

- **LTX format**: `@v1:field|field` header line + pipe-delimited rows. LTX → stdout, human warnings → stderr. The three emitters (`ltx_header`, `ltx_row`, `ltx_human`) live in `hooks/scripts/session-start.sh` — copy them into any new emitting script. A skill that emits LTX documents a `## LTX Schema` section; one that doesn't must not carry a dead schema section.
- Hook/skill scripts use `$CLAUDE_PLUGIN_ROOT` for plugin files, never hardcoded paths — but never show that variable in user-facing examples (it only resolves inside plugin hooks; use real paths like `~/.claude/hooks/`).
- **session-start.sh**: CLAUDE.md word check (`WARN_WORDS=600`, `CRIT_WORDS=1000`, `-ef` guard against double-count), settings.json validation (`skipped` when python3 absent), schema `@v1:file|words|tokens|level`.
- **record-change.mjs**: attaches the written file to the most recent project whose `root_path` is a prefix, inserts a `changelogs` row. **Never blocks the tool** — every error exits 0, `pg` imported lazily, 3s connect timeout. Without `FORGE_DATABASE_URL` or `mcp/node_modules` it is a silent no-op BY DESIGN — check those before declaring it broken.
- **statusline-command.sh**: stdin JSON → dir, branch, model, context bar, CLAUDE.md tokens (words × 1.3), rate-limit %. Fields `\x1f`-separated (names contain spaces). Green → yellow (50%/390t) → orange (75%/780t) → red (90%/1300t). Needs Claude Code ≥ 2.1.97.
- **forge-db tools** (7): `list_templates` (also the only `template_id`→name map) · `get_template` (by NAME; verbatim files + pinned deps) · `register_project` (errors on unknown template) · `record_change` (`dep_added` requires `package`) · `get_changelog` (limit 1–500, default 50) · `compute_suggestions` · `apply_suggestion` (`dep_inserted: false` = package already present, existing version kept; errors on unimplemented kinds). Tool errors (unset URL, unreachable DB) surface as clear messages — report them; never fabricate data to fill the gap.

## B. Anti-Hallucination & Value Safety (CRITICAL)

1. Template names, file contents, and dependency versions exist ONLY in forge-db tool output. Copy verbatim — no reformatting, upgrades, or normalisation. `/scaffold` must run the template's `typecheck`/`build`.
2. Never write undocumented settings keys. `autoLoadSkills`, `autoLoadMemory`, `compactOnContextFull`, `verboseOutput`, `plugins.autoEnable` do NOT exist. Real keys in this repo's docs: `autoMemoryEnabled`, `autoCompactEnabled`/`autoCompactWindow`, `disableBundledSkills`, `disabledMcpjsonServers`, `statusLine`. Verify anything else against official docs first.
3. Skill bodies lazy-load — only frontmatter descriptions cost tokens every session. Don't write docs claiming otherwise.
4. Every command written into docs or this file must exist and pass first. No `npm test`, `pytest`, `npm run lint`, `black` — the only test entry point is `node --test`.
5. On any forge-db error: stop and report the missing piece (env var, schema, connectivity). Zero rows means "nothing recorded", not license to guess.

## C. Extending

- **Skill**: `skills/<name>/SKILL.md`, frontmatter `name`/`description`/`version`; triggers AND anti-triggers ("Do NOT use for…") in the description; LTX emitters copied from `session-start.sh` if it emits. Auto-discovered.
- **Agent**: `agents/<name>.md`, frontmatter `name`, `model: inherit`, `color`, `tools: [...]`, `description`, then `## When to use` + instructions.
- **Hook**: block in `hooks/hooks.json`. Valid events only: `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `SubagentStop`, `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `Notification`. Always set `timeout`; degrade to no-op, never block tools.
- **Forge template**: rows in `templates`/`template_files`/`template_deps` (shape: `mcp/db/seed-example.sql`). Only `{{project_name}}` and `{{year}}` substituted; all else verbatim.
- **Slash command**: `commands/<name>.md` with `description`, `argument-hint`, `allowed-tools` (incl. needed `mcp__forge-db__*`). `$ARGUMENTS`, `$0`, `$1`… expand.

## D. Operating Mode

Ponytail (lazy-senior-dev ladder) is injected every session by its own plugin hook — it applies here in full. Repo-specific additions:

- Bug fix = root cause: grep every caller of the function you touch; one guard in the shared function beats a patch per caller.
- Platform-native first: Node built-ins over packages (`fs.mkdirSync({recursive:true})`, `crypto.randomUUID()`); DB over app code (`UNIQUE`/`FK`/`CHECK`, `DEFAULT now()` — `schema.sql` already works this way). Mark deliberate corner-cuts with a `ponytail:` comment naming ceiling + upgrade path.
- Never lazy about: understanding the problem, validation at trust boundaries, error handling preventing data loss, security, anything explicitly requested.
- Non-trivial logic leaves ONE runnable check in `tests/repo.test.mjs`; trivial one-liners need none.
- Strict for anything touching `mcp/`, `hooks/`, schema, or the forge contract; judgment for trivial fixes. No new languages without explicit ask — stack is Bash + Node `.mjs` + Markdown + SQL.

**Verify**: `node --test` (repo root) · JSON: `python3 -m json.tool <f>` · syntax: `bash -n` / `node --check` · schema: `psql "$FORGE_DATABASE_URL" -f mcp/db/schema.sql`. Hook/statusline/MCP smoke-test one-liners: `wiki/dev-reference.md`.

**Forced**: `node --test` green before EVERY commit — the suite covers JSON validity, hook config/events, frontmatter, script syntax, hook runtime, and cross-references (forge-db tool names, SKILL.md file refs, `.mcp.json` path); the broken-ref audit is automated, don't redo it by hand. A successful file write ≠ correct code — run the relevant verify command before saying "done". This file stays under 12,000 chars (`wc -c CLAUDE.md`); move detail to `wiki/` or skill `references/`, don't pad.
