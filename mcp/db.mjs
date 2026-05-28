// Shared Postgres connection-string resolution for the forge-db MCP server
// and the record-change PostToolUse hook. Accepts FORGE_DATABASE_URL first
// (canonical) and falls back to DATABASE_URL so the same module works whether
// invoked from .mcp.json (which sets DATABASE_URL from ${FORGE_DATABASE_URL})
// or invoked directly with FORGE_DATABASE_URL in the environment.

export function dbUrl() {
  return process.env.FORGE_DATABASE_URL || process.env.DATABASE_URL;
}
