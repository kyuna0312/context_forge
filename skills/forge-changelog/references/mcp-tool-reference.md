# forge-db MCP tool reference

Full input/output shape and edge cases for the four forge-db tools used by the `forge-changelog` skill. Source of truth: `mcp/server.mjs` and `mcp/db/schema.sql`.

Load this reference when:

- An MCP call returned a column or value whose meaning is unclear.
- The user asks a question that depends on a specific tool's semantics (e.g. "does `apply_suggestion` overwrite an existing dep?").
- Composing a sequence of calls and the order or argument types are uncertain.

---

## `mcp__forge-db__get_changelog`

**Purpose:** Read recent changelog rows.

**Input:**

```json
{ "project_name": "string (optional)", "limit": "number (default 50)" }
```

**Behaviour:**

- With `project_name`: `SELECT * FROM changelogs WHERE project_name=$1 ORDER BY id DESC LIMIT $2`
- Without `project_name`: `SELECT * FROM changelogs ORDER BY id DESC LIMIT $1`
- `id DESC` is effectively newest-first because `id` is `SERIAL`.

**Returned row shape (per `schema.sql`):**

| Column | Type | Notes |
|--------|------|-------|
| `id` | integer | Primary key, monotonically increasing |
| `project_id` | integer or null | FK to `projects.id`; null if the project was not registered when the hook fired |
| `project_name` | text or null | Denormalised — present even when `project_id` is null (set by the hook from a `LIKE` match on `root_path`) |
| `change_type` | text | One of `file_created`, `file_edited`, `dep_added`, `stack_changed` |
| `file_path` | text or null | Set for file events |
| `package` | text or null | Set only when `change_type = 'dep_added'` |
| `version` | text or null | Optional pinned version that accompanied a `dep_added` row |
| `stack_delta` | JSONB or null | Diff vs the template's stack for `stack_changed` rows (not yet emitted automatically — roadmap) |
| `summary` | text or null | Free-form, e.g. `"Write /path/to/file"` from the hook |
| `created_at` | timestamptz | UTC by default |

**Edge cases:**

- Pre-registration writes appear with `project_id = null` and `project_name = null` (or a stale name if the path matched an old project). Treat these as "unattached" and never invent the project.
- `limit` is forwarded as a SQL `LIMIT` — passing a very large number is safe but wasteful; prefer 200 max for "this week" style queries and filter client-side.
- The hook attaches a project via `WHERE $1 LIKE root_path || '%'`. Special LIKE chars (`_`, `%`) inside a `root_path` would over-match — rare in practice but possible.

---

## `mcp__forge-db__compute_suggestions`

**Purpose:** Find recurring manual additions across projects of the same template and upsert pending suggestions.

**Input:**

```json
{ "min_occurrences": "number (default 2)" }
```

**Behaviour:**

1. Runs a SQL query that:
   - Joins `changelogs c` to `projects p` on `p.id = c.project_id` (so rows with `project_id = null` are ignored entirely — only registered projects count).
   - Keeps rows where `change_type = 'dep_added'` and `package IS NOT NULL`.
   - Excludes packages already present in the project's template (`template_deps`).
   - Groups by `(p.template_id, c.package)`.
   - Filters to groups where `COUNT(DISTINCT c.project_id) >= min_occurrences`.
2. For each result row, upserts into `template_suggestions` with `kind='add_dep'`, `payload={"package":"<pkg>"}`, and the seen count. Conflict target is `(template_id, kind, payload)` — re-running refreshes `occurrences` and resets `status='pending'`.
3. Returns all rows from `template_suggestions WHERE status='pending' ORDER BY occurrences DESC`.

**Returned row shape:**

| Column | Type | Notes |
|--------|------|-------|
| `id` | integer | Suggestion id — pass to `apply_suggestion` |
| `template_id` | integer | FK to `templates.id`; resolve via `get_template` if a name is needed |
| `kind` | text | Currently always `add_dep`; `add_file` and `change_stack` are reserved in the schema but unimplemented |
| `payload` | JSONB | For `add_dep`: `{"package": "<name>"}` |
| `occurrences` | integer | Number of distinct projects the package appeared in (from the latest `compute_suggestions` run) |
| `status` | text | `pending` (only ones returned), `applied`, or `dismissed` |
| `created_at` | timestamptz | Time the suggestion first appeared |

**Edge cases:**

- Re-running `compute_suggestions` after applying a suggestion does **not** re-surface it: applied suggestions stay `applied` unless the upsert path re-bumps them (which it can, because the upsert sets `status='pending'`). To avoid noisy re-suggestions, apply with a real version so the package is now in `template_deps` — the `NOT EXISTS` clause then excludes it next time.
- `project_id = null` changelogs are silently dropped from the join. Suggestions never form from unattached projects.
- `min_occurrences = 1` will surface every one-off dep — use only for debugging.

---

## `mcp__forge-db__get_template`

**Purpose:** Resolve a template name to its full definition; in this skill, used to render `template_id` → name during drift reporting.

**Input:**

```json
{ "name": "string (required)" }
```

**Behaviour:**

- `SELECT * FROM templates WHERE name = $1` — errors with `No template named "..." . Call list_templates first.` if missing.
- Then returns the template row plus its `template_files` (ordered by `ord, path`) and `template_deps` (ordered by `package`).

**Returned shape:**

```json
{
  "template": { "id": 1, "name": "node-ts-basic", "description": "...", "stack_json": {...}, "created_at": "...", "updated_at": "..." },
  "files":    [ { "path": "...", "content": "...", "is_binary": false, "ord": 0 } ],
  "deps":     [ { "package": "...", "version": "...", "dev_dep": false } ]
}
```

**Usage note for this skill:**

When rendering suggestions, only the `template.name` field is needed. The `files` and `deps` payloads can be large — fetching one template costs the full content payload. Cache the (id → name) mapping within a single response to avoid repeat calls.

If a name → id reverse lookup is needed (e.g. user says "for the nextjs-trpc-drizzle template, what's pending?"), call `get_template` with the name to get the id, then filter the suggestion list client-side.

---

## `mcp__forge-db__apply_suggestion`

**Purpose:** Insert the suggested dep into `template_deps` and mark the suggestion `applied`.

**Input:**

```json
{ "suggestion_id": "number (required)", "version": "string (default 'latest')" }
```

**Behaviour:**

1. Loads the suggestion by id; errors with `No such suggestion` if not found.
2. If `kind = 'add_dep'`:
   - `INSERT INTO template_deps (template_id, package, version) VALUES (...) ON CONFLICT (template_id, package) DO NOTHING`.
   - Effect: if the dep is already present at a different version, the existing row wins. To overwrite, the user must delete the existing row first.
3. Updates the suggestion to `status='applied'` regardless of the conflict outcome.
4. Returns `{ "applied": <suggestion_id> }`.

**Edge cases:**

- `kind` other than `add_dep` is silently no-op'd at step 2 (the `if` falls through), but the status flips to `applied`. Currently the schema only allows the unimplemented kinds `add_file` and `change_stack` to land here via direct SQL — there is no tool path that creates them.
- `version='latest'` is stored literally as the string `"latest"`. The scaffolder then uses it verbatim in `package.json`, which most package managers accept but it is not a pinned version. Tell the user to re-apply with an explicit version when they decide.
- Conflict on `(template_id, package)` is silent. If the user expected to overwrite an existing pinned version, surface this — the suggestion will still be marked applied even though no row changed.

---

## Cross-tool patterns

**Read-then-drift:** "what packages do I keep adding?" → `get_changelog` (limit ~200) → filter to `change_type='dep_added'` → if user wants to act on the recurrence, call `compute_suggestions` and switch to the drift workflow.

**Drift-then-apply:** `compute_suggestions` → per-template `get_template` for names → present numbered list → user picks → `apply_suggestion` per chosen id.

**Diagnosing zero results:** If `get_changelog` returns rows but `compute_suggestions` returns nothing, the cause is one of: (a) `project_id` is null on the dep_added rows (project not registered), (b) the package is already in `template_deps`, (c) `min_occurrences` is too high. Check (a) first by inspecting the `project_id` column in the changelog output.
