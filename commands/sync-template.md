---
description: "Analyse changelogs and suggest improvements to templates (the feedback loop)"
argument-hint: "[--apply]"
allowed-tools:
  - mcp__forge-db__compute_suggestions
  - mcp__forge-db__apply_suggestion
  - mcp__forge-db__list_templates
---

# Template feedback loop

This is the back-mapping step: look at what you actually added by hand across projects, and fold the recurring additions back into the templates.

## Steps

1. Call `compute_suggestions` (default `min_occurrences=2`). Zero pending suggestions → say so plainly and stop; do not fabricate one. Tool error → report the missing forge setup piece and stop.
2. For each pending suggestion, show it in plain language as a numbered list, e.g.:
   "1. You added `zod` by hand in 4 projects built from `nextjs-trpc-drizzle`. Add it to that template?"
   Include the occurrence count so the user can judge. The template *name* is not in the suggestion row (only `template_id`) — call `list_templates` once and map id → name from its result; never guess a name. (`get_template` can't help here: it looks up by name, not id.)
3. **Do not apply anything automatically.** Wait for the user to choose which suggestions to accept (by number or package name).
4. For each accepted suggestion, call `apply_suggestion` (one call per suggestion — it takes a single id). If the user names a specific version, pass it; otherwise pass `latest` and tell them they can pin it later.
5. After applying, briefly confirm which templates changed. If a call fails, surface the error verbatim and stop — do not retry silently or assume it succeeded.

If `$ARGUMENTS` contains `--apply`, you may still only apply suggestions the user explicitly confirms in this turn — the flag does not grant blanket approval.
