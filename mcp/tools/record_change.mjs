import { q } from "../db.mjs";

export const tool = {
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
};
