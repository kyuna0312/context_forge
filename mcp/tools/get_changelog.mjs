import { q } from "../db.mjs";

export const tool = {
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
};
