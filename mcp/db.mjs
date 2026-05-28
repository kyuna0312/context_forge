// Shared Postgres connection-string resolution and lazy pool/query helper
// for the forge-db MCP server. The record-change PostToolUse hook also
// imports dbUrl() from here but uses its own one-shot pg.Client, so the
// pool below is lazy — it is only instantiated on the first call to q().

import pg from "pg";

export function dbUrl() {
  return process.env.FORGE_DATABASE_URL || process.env.DATABASE_URL;
}

let _pool;
function pool() {
  if (!_pool) _pool = new pg.Pool({ connectionString: dbUrl() });
  return _pool;
}

export async function q(text, params = []) {
  const client = await pool().connect();
  try {
    return (await client.query(text, params)).rows;
  } finally {
    client.release();
  }
}
