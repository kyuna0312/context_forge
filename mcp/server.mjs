#!/usr/bin/env node
// project-forge MCP server
// Exposes Postgres-backed tools so the model never guesses template facts.
//
// Requires:  npm i @modelcontextprotocol/sdk pg
// Env:       DATABASE_URL (Postgres connection string)

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import pg from "pg";

const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function q(text, params = []) {
  const client = await pool.connect();
  try {
    return (await client.query(text, params)).rows;
  } finally {
    client.release();
  }
}

const tools = [
  {
    name: "list_templates",
    description:
      "List all available project templates with their stack. Call this before scaffolding so you pick a real template name — never invent one.",
    inputSchema: { type: "object", properties: {} },
    handler: async () =>
      q("SELECT id, name, description, stack_json FROM templates ORDER BY name"),
  },
  {
    name: "get_template",
    description:
      "Get the full definition of one template: its files (verbatim content) and dependencies (exact pinned versions). Use this content literally; do not rewrite or guess package versions.",
    inputSchema: {
      type: "object",
      properties: { name: { type: "string" } },
      required: ["name"],
    },
    handler: async ({ name }) => {
      const [tpl] = await q("SELECT * FROM templates WHERE name = $1", [name]);
      if (!tpl) throw new Error(`No template named "${name}". Call list_templates first.`);
      const files = await q(
        "SELECT path, content, is_binary, ord FROM template_files WHERE template_id=$1 ORDER BY ord, path",
        [tpl.id]
      );
      const deps = await q(
        "SELECT package, version, dev_dep FROM template_deps WHERE template_id=$1 ORDER BY package",
        [tpl.id]
      );
      return { template: tpl, files, deps };
    },
  },
  {
    name: "register_project",
    description:
      "Record a newly scaffolded project so future changes can be tracked against its template.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string" },
        template_name: { type: "string" },
        root_path: { type: "string" },
      },
      required: ["name", "root_path"],
    },
    handler: async ({ name, template_name, root_path }) => {
      let template_id = null;
      if (template_name) {
        const [t] = await q("SELECT id FROM templates WHERE name=$1", [template_name]);
        template_id = t?.id ?? null;
      }
      const [row] = await q(
        "INSERT INTO projects (name, template_id, root_path) VALUES ($1,$2,$3) RETURNING *",
        [name, template_id, root_path]
      );
      return row;
    },
  },
  {
    name: "record_change",
    description:
      "Append a changelog entry. Normally called automatically by the hook, but can be called manually for stack changes.",
    inputSchema: {
      type: "object",
      properties: {
        project_name: { type: "string" },
        change_type: {
          type: "string",
          enum: ["file_created", "file_edited", "dep_added", "stack_changed"],
        },
        file_path: { type: "string" },
        package: { type: "string" },
        version: { type: "string" },
        summary: { type: "string" },
      },
      required: ["change_type"],
    },
    handler: async (a) => {
      const [proj] = a.project_name
        ? await q("SELECT id FROM projects WHERE name=$1 ORDER BY id DESC LIMIT 1", [a.project_name])
        : [];
      const [row] = await q(
        `INSERT INTO changelogs
           (project_id, project_name, change_type, file_path, package, version, summary)
         VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
        [proj?.id ?? null, a.project_name ?? null, a.change_type,
         a.file_path ?? null, a.package ?? null, a.version ?? null, a.summary ?? null]
      );
      return row;
    },
  },
  {
    name: "get_changelog",
    description: "Read recent changelog entries for a project (or all projects).",
    inputSchema: {
      type: "object",
      properties: {
        project_name: { type: "string" },
        limit: { type: "number", default: 50 },
      },
    },
    handler: async ({ project_name, limit = 50 }) =>
      project_name
        ? q("SELECT * FROM changelogs WHERE project_name=$1 ORDER BY id DESC LIMIT $2", [project_name, limit])
        : q("SELECT * FROM changelogs ORDER BY id DESC LIMIT $1", [limit]),
  },
  {
    name: "compute_suggestions",
    description:
      "Analyse changelogs and produce/update template-improvement suggestions (the back-mapping feedback loop). E.g. if a dependency was manually added across many projects of the same template, suggest adding it to the template. Returns pending suggestions.",
    inputSchema: {
      type: "object",
      properties: { min_occurrences: { type: "number", default: 2 } },
    },
    handler: async ({ min_occurrences = 2 }) => {
      // Find deps added manually, grouped by the project's template + package.
      const rows = await q(
        `SELECT p.template_id, c.package, COUNT(DISTINCT c.project_id) AS seen
           FROM changelogs c
           JOIN projects p ON p.id = c.project_id
          WHERE c.change_type = 'dep_added'
            AND c.package IS NOT NULL
            AND p.template_id IS NOT NULL
            AND NOT EXISTS (
              SELECT 1 FROM template_deps td
               WHERE td.template_id = p.template_id AND td.package = c.package
            )
          GROUP BY p.template_id, c.package
         HAVING COUNT(DISTINCT c.project_id) >= $1`,
        [min_occurrences]
      );
      for (const r of rows) {
        await q(
          `INSERT INTO template_suggestions (template_id, kind, payload, occurrences)
           VALUES ($1,'add_dep',$2,$3)
           ON CONFLICT (template_id, kind, payload)
           DO UPDATE SET occurrences = EXCLUDED.occurrences, status='pending'`,
          [r.template_id, JSON.stringify({ package: r.package }), Number(r.seen)]
        );
      }
      return q("SELECT * FROM template_suggestions WHERE status='pending' ORDER BY occurrences DESC");
    },
  },
  {
    name: "apply_suggestion",
    description:
      "Apply a pending suggestion to its template (e.g. add the dependency) and mark it applied. Ask the user before calling this.",
    inputSchema: {
      type: "object",
      properties: { suggestion_id: { type: "number" }, version: { type: "string", default: "latest" } },
      required: ["suggestion_id"],
    },
    handler: async ({ suggestion_id, version = "latest" }) => {
      const [s] = await q("SELECT * FROM template_suggestions WHERE id=$1", [suggestion_id]);
      if (!s) throw new Error("No such suggestion");
      if (s.kind === "add_dep") {
        const pkg = s.payload.package;
        await q(
          `INSERT INTO template_deps (template_id, package, version)
           VALUES ($1,$2,$3) ON CONFLICT (template_id, package) DO NOTHING`,
          [s.template_id, pkg, version]
        );
      }
      await q("UPDATE template_suggestions SET status='applied' WHERE id=$1", [suggestion_id]);
      return { applied: suggestion_id };
    },
  },
];

const server = new Server(
  { name: "forge-db", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: tools.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })),
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const tool = tools.find((t) => t.name === req.params.name);
  if (!tool) throw new Error(`Unknown tool: ${req.params.name}`);
  try {
    const result = await tool.handler(req.params.arguments ?? {});
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  } catch (err) {
    return { content: [{ type: "text", text: `ERROR: ${err.message}` }], isError: true };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
