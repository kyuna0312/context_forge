import { q } from "../db.mjs";

export const tool = {
  name: "list_templates",
  description:
    "List all available project templates with their stack. Call this before scaffolding so you pick a real template name — never invent one.",
  inputSchema: { type: "object", properties: {} },
  handler: async () =>
    q("SELECT id, name, description, stack_json FROM templates ORDER BY name"),
};
