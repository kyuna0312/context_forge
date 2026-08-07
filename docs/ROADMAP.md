# Roadmap & Deliberate Ceilings

The backlog, plus the ponytail-style corners deliberately cut with a known
ceiling. When one of these starts to hurt, this file says what the upgrade
path is. Nothing here is a bug — bugs get fixed, not listed.

## Deliberate ceilings (upgrade when it hurts)

| Ceiling | Where | Upgrade path |
|---------|-------|--------------|
| Suggestion kinds `add_file` / `change_stack` reserved but unimplemented — `apply_suggestion` errors on them | `mcp/tools.mjs`, `schema.sql` | Implement handlers when recurring file/stack drift actually shows up in changelogs |
| `version: "latest"` stored literally when applying a suggestion without an explicit version | `apply_suggestion` | User re-applies with a pinned version; could auto-resolve from the npm registry if that becomes routine |
| `compute_suggestions` upserts in an N+1 loop | `mcp/tools.mjs` | Single `INSERT ... SELECT` when suggestion volume is more than a handful |
| record-change matcher covers `Write\|Edit` only — `MultiEdit` / `NotebookEdit` changes are not recorded | `hooks/hooks.json` | Extend the matcher when those tools matter for tracked projects |
| Project attachment is "latest project whose root_path is a prefix" — nested projects pick the newest registration | `record-change.mjs` | Longest-prefix match if nested projects become real |
| No DB-backed integration tests — CI has no Postgres; MCP tool handlers are covered by contract/source tests only | `tests/`, CI | Add a Postgres service container to `test.yml` + a small tool-handler suite |
| Statusline reads only the `5h` rate-limit window | `statusline-command.sh` | Surface other windows when Claude Code exposes ones users watch |
| One seed template (`node-ts-basic`) | `mcp/db/seed-example.sql` | Add templates as real stacks get scaffolded; follow the dollar-quoting warning in the seed header |

## Backlog

- **Marketplace publishing** — `.claude-plugin/marketplace.json` exists but
  the publish flow is undocumented; write it down when first publishing.
- **`add_file` back-mapping** — the schema supports suggesting whole files;
  needs a changelog signal (recurring `file_created` outside the template
  file set) and an `apply_suggestion` branch.
- **Forge dashboards** — `get_changelog` output is markdown-only today; an
  LTX schema for changelog rows would let the token-saver half render it.

## Done (this file's history is not a changelog — see git log)

Major hardening landed 2026-08-07: fabricated settings keys purged from all
skills, MCP server crash/hang fixes, statusline field-shift fix, seed `\n`
corruption fix, tests 10 → 13 with cross-reference coverage.
