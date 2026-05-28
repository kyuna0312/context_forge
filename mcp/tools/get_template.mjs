import { q } from "../db.mjs";

export const tool = {
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
};
