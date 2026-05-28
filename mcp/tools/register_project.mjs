import { q } from "../db.mjs";

export const tool = {
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
};
