#!/usr/bin/env node
// forge-db MCP server — exposes Postgres-backed tools so the model never
// guesses template facts. Tool implementations live in mcp/tools.mjs;
// this file is just SDK wiring (transport, registration, dispatch).
//
// Requires:  npm i @modelcontextprotocol/sdk pg zod
// Env:       FORGE_DATABASE_URL or DATABASE_URL (see db.mjs)

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { tools } from "./tools.mjs";

const server = new McpServer({ name: "forge-db", version: "0.1.0" });

for (const { name, description, inputSchema, handler } of tools) {
  server.registerTool(name, { description, inputSchema }, async (args) => {
    try {
      const result = await handler(args ?? {});
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    } catch (err) {
      return { content: [{ type: "text", text: `ERROR: ${err.message}` }], isError: true };
    }
  });
}

await server.connect(new StdioServerTransport());
