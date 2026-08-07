# Forge Setup
_Last updated: 2026-08-07 | Source: README.md + session debugging_

## Summary
The forge half (scaffolding + changelog) needs Postgres. Without `FORGE_DATABASE_URL` it is inert by design — the token-saver half keeps working.

## Key Points
- Setup: `cd mcp && npm install`, export `FORGE_DATABASE_URL="postgres://user:pass@host:5432/forge"`, then `psql "$FORGE_DATABASE_URL" -f mcp/db/schema.sql` (+ `seed-example.sql` for the `node-ts-basic` test template).
- The variable must be exported **in the shell that launches Claude Code** — `.mcp.json` expands `${FORGE_DATABASE_URL}` at launch.
- **Gotcha**: if unset at launch, the literal string `${FORGE_DATABASE_URL}` is passed as `DATABASE_URL`; `pg` mangles it into host `base`, so tools fail with `getaddrinfo ENOTFOUND base` instead of a clear "not set" error. Fix: export + restart.
- 7 MCP tools: `list_templates`, `get_template`, `register_project`, `record_change`, `get_changelog`, `compute_suggestions`, `apply_suggestion`.

## Related
- [[installation]]
