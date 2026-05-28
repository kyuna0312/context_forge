import { q } from "../db.mjs";

export const tool = {
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
};
