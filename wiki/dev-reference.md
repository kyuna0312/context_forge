# Dev Reference — smoke-test one-liners
_Last updated: 2026-08-07 | Source: CLAUDE.md verify table (moved here during optimization)_

## Summary
Verbose verify commands moved out of CLAUDE.md. The short ones (`node --test`, `python3 -m json.tool`, `bash -n`, `node --check`, `psql … -f mcp/db/schema.sql`) stay in CLAUDE.md.

## Key Points
- **Smoke MCP server**: `DATABASE_URL=$FORGE_DATABASE_URL node mcp/server.mjs` (Ctrl+C to exit)
- **Run record-change hook**: `echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x"}}' | FORGE_DATABASE_URL=$FORGE_DATABASE_URL node mcp/record-change.mjs`
- **Run session-start hook**: `CLAUDE_PLUGIN_ROOT=$(pwd) bash hooks/scripts/session-start.sh`
- **Test status line**: `echo '{"context_window":{"used_percentage":72},"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Fable 5"}}' | bash scripts/statusline-command.sh` — the model name must render whole; truncated = outdated installed copy.

## Related
- [[forge-setup]]
