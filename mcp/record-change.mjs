#!/usr/bin/env node
// PostToolUse hook: records Write/Edit operations into the changelogs table.
// Claude Code passes the hook a JSON payload on stdin describing the tool call.
// We stay deliberately small and never block the tool — on any error we exit 0.
//
// Env: FORGE_DATABASE_URL (canonical) or DATABASE_URL (fallback) —
// same DB the MCP server uses; resolution lives in ./db.mjs.

import pg from "pg";
import { dbUrl } from "./db.mjs";

async function main() {
  const raw = await read(process.stdin);
  let evt = {};
  try { evt = JSON.parse(raw || "{}"); } catch { return; }

  const tool = evt.tool_name || evt.toolName;
  const input = evt.tool_input || evt.toolInput || {};
  const filePath = input.file_path || input.path;
  if (!filePath) return;

  const changeType =
    tool === "Write" ? "file_created" :
    tool === "Edit"  ? "file_edited"  : "file_edited";

  const url = dbUrl();
  if (!url) return;

  const client = new pg.Client({ connectionString: url });
  await client.connect();
  try {
    // Best-effort: attach to the most recent project whose root_path is a prefix.
    const { rows } = await client.query(
      "SELECT name FROM projects WHERE $1 LIKE root_path || '%' ORDER BY id DESC LIMIT 1",
      [filePath]
    );
    const projectName = rows[0]?.name ?? null;

    await client.query(
      `INSERT INTO changelogs (project_name, change_type, file_path, summary)
       VALUES ($1,$2,$3,$4)`,
      [projectName, changeType, filePath, `${tool} ${filePath}`]
    );
  } catch {
    // never disrupt the session
  } finally {
    await client.end().catch(() => {});
  }
}

function read(stream) {
  return new Promise((resolve) => {
    let data = "";
    stream.setEncoding("utf8");
    stream.on("data", (c) => (data += c));
    stream.on("end", () => resolve(data));
    stream.on("error", () => resolve(""));
    setTimeout(() => resolve(data), 2000); // safety timeout
  });
}

main().then(() => process.exit(0)).catch(() => process.exit(0));
