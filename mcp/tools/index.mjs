// Ordered registry of forge-db MCP tools. The order here is the order in
// which tools are advertised via ListTools — keep it stable so clients that
// memoise the response don't churn.

import { tool as list_templates } from "./list_templates.mjs";
import { tool as get_template } from "./get_template.mjs";
import { tool as register_project } from "./register_project.mjs";
import { tool as record_change } from "./record_change.mjs";
import { tool as get_changelog } from "./get_changelog.mjs";
import { tool as compute_suggestions } from "./compute_suggestions.mjs";
import { tool as apply_suggestion } from "./apply_suggestion.mjs";

export const tools = [
  list_templates,
  get_template,
  register_project,
  record_change,
  get_changelog,
  compute_suggestions,
  apply_suggestion,
];
