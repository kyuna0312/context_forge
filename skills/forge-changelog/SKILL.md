---
name: forge-changelog
description: This skill should be used when the user asks to "show recent changes", "show forge changelog", "show changelog for <project>", "what did I add this week", "what files did I touch today", "what packages keep recurring", "what drifts from the template", "review template suggestions", "show pending forge suggestions", "sync forge templates", "apply template suggestion", or "compute back-mapping suggestions". Provides read, drift-discovery, and template back-mapping workflows that wrap the `forge-db` MCP tools (`get_changelog`, `compute_suggestions`, `apply_suggestion`).
version: 0.1.0
---

# forge-changelog

Surface the forge changelog and the template back-mapping loop. Forge records every `Write` / `Edit` into a Postgres `changelogs` table via a `PostToolUse` hook; this skill turns that raw stream into three useful workflows: reading recent activity, discovering drift between projects and their templates, and applying recurring drift back into the templates.

This skill complements the `/changelog` and `/sync-template` slash commands. The commands are explicit invocations; this skill activates when the user phrases the same intent in conversation (e.g. "what packages keep showing up across my Next.js projects?" instead of typing `/sync-template`).

## Required environment

The forge half of context_forge depends on:

- `FORGE_DATABASE_URL` exported in the shell that launched Claude Code
- The `forge-db` MCP server reachable (registered in `.mcp.json`)
- Postgres schema applied (`mcp/db/schema.sql`)

If any forge-db tool returns an error like `connection refused` or `relation does not exist`, stop and report the missing piece — do not fabricate changelog data to fill the gap.

## When to activate

Activate on intent, not on exact wording. Treat these intents as in-scope:

| Intent | Example phrasing | Workflow |
|--------|------------------|----------|
| Read history | "what did I change in `acme-api` yesterday" | Read workflow |
| Filter by type | "list packages I added by hand" | Read workflow + client-side filter |
| Discover drift | "what keeps showing up across all my Next.js projects" | Drift workflow |
| Review suggestions | "show pending template suggestions" | Drift workflow |
| Apply suggestion | "fold zod into the nextjs-trpc-drizzle template" | Apply workflow |
| Cross-project rollup | "what files did I touch today" (no project) | Read workflow, omit `project_name` |

Out of scope — defer or refuse:

- Writing new changelog rows manually (use `record_change` in `/scaffold` or hooks, not from this skill).
- Inventing a `change_type` outside `{file_created, file_edited, dep_added, stack_changed}`.
- Applying suggestions without explicit per-item user confirmation.

## Workflow 1 — Read changelog

Use when the user wants to see what happened (a project, a day, "lately").

1. Resolve the project name. If the user named one, pass it as `project_name`. If they said "all projects" or omitted, do not pass `project_name` — that returns global history.
2. Resolve the limit. Default to 50. If the user said "lately" or "this week", request 200 and filter client-side by `created_at`.
3. Call `mcp__forge-db__get_changelog` with the resolved args.
4. Group the returned rows by **calendar day**, newest day first. Within a day, keep the order returned by the tool (newest `id` first).
5. Render each row as: `HH:MM — <change_type> — <file_path or package> [— summary]`. Strip the project name from the per-row line if all rows in the result share one project; otherwise prefix `[project_name]`.
6. Report the row count and the date range covered. Do not editorialise — state only what the rows show.

If the tool returns zero rows, say so plainly. Do not pad the answer with a guess at what "probably" changed.

## Workflow 2 — Discover drift (back-mapping)

Use when the user wants to know what manual additions recur — the signal that a template is incomplete.

1. Call `mcp__forge-db__compute_suggestions` with `min_occurrences` defaulting to `2`. If the user said "really recurring" or "only frequent", raise it to `3` or higher.
2. The tool returns pending suggestions, ordered by occurrence count descending. Each row carries `template_id`, `kind` (currently always `add_dep`), `payload` (JSON `{ "package": "..." }`), `occurrences`, and `status`.
3. For each suggestion, render one plain-language line:
   `[<occurrences>×] Add <package> to template "<template name>" — currently added by hand in <occurrences> project(s).`
   The template name is not in the suggestion row — look it up by calling `mcp__forge-db__get_template` once per distinct `template_id` (or note the IDs and ask the user if many templates are involved). Cache results within the response.
4. List suggestions sorted by occurrences desc. Stop after rendering; do not apply anything.
5. Ask the user which suggestions to apply (by id or by package name). Wait for an explicit answer.

If the tool returns zero pending suggestions, say so plainly. Possible reasons: not enough manual deps yet (raise the threshold? lower it?), or every recurring dep is already in the template.

## Workflow 3 — Apply suggestion

Use only after the user explicitly named which suggestions to apply.

1. For each chosen suggestion, call `mcp__forge-db__apply_suggestion` with `suggestion_id` and a `version`. If the user named a version (`"zod 3.23"`), pass it; otherwise pass `"latest"` and note in the reply that the user can pin it later by re-running with an explicit version.
2. Call the tool once per suggestion. Do not batch — the MCP tool takes a single id at a time.
3. After all calls succeed, report which templates changed and which packages were added.
4. If a call fails, surface the error verbatim and stop. Do not retry silently and do not assume the failed one succeeded.

Never apply suggestions on a `--apply` flag alone. The slash command's `--apply` exists, but it does not grant blanket approval — the skill must still confirm each item with the user in this turn.

## Anti-hallucination rules

These match the broader forge contract — break them and the skill produces lies:

- Changelog rows, suggestion rows, template names, and package versions are **only** what the MCP tools returned. Do not invent or extrapolate.
- `change_type` is a closed enum: `file_created`, `file_edited`, `dep_added`, `stack_changed`. Do not coin new types.
- If a row's `project_name` is `null` (denormalised fallback), say "unattached" — do not guess which project it belonged to.
- If `compute_suggestions` returns nothing, the answer is "nothing pending", not a fabricated suggestion.
- Group, sort, and filter rows in the response. Do not summarise them into invented prose.

## Output format

Default to plain markdown (this skill speaks in chat, not via LTX). Use a short heading per calendar day, then a bullet per row. Example shape:

```
### 2026-05-28
- 14:02 — file_edited — src/api/users.ts
- 13:55 — dep_added — zod (3.23.8)
- 09:11 — file_created — src/api/users.ts

### 2026-05-27
- 17:30 — stack_changed — runtime: node18 → node20
```

For suggestion review, use a numbered list so the user can reference items by number when choosing what to apply.

## Tools used

All forge-db MCP tools, called only via the registered `forge-db` server:

- `mcp__forge-db__get_changelog` — read workflow
- `mcp__forge-db__compute_suggestions` — drift workflow
- `mcp__forge-db__get_template` — template name lookup during drift workflow
- `mcp__forge-db__apply_suggestion` — apply workflow

Do **not** call `record_change` from this skill — it is reserved for the hook and the `/scaffold` command.

## Additional resources

### Reference files

- **`references/mcp-tool-reference.md`** — full input/output schema for each forge-db tool used here, plus edge cases (null project_name, stack_delta, conflict semantics on `apply_suggestion`).

### Related components

- `commands/changelog.md` — `/changelog` slash command (thin wrapper, same data source).
- `commands/sync-template.md` — `/sync-template` slash command (same drift + apply flow).
- `hooks/scripts/record-change.mjs` — `PostToolUse` hook that writes the changelog rows this skill reads.
- `mcp/db/schema.sql` — Postgres schema defining the tables and the `change_type` enum-as-text.
