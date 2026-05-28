---
description: "Analyse changelogs and suggest improvements to templates (the feedback loop)"
argument-hint: "[--apply]"
allowed-tools:
  - mcp__forge-db__compute_suggestions
  - mcp__forge-db__apply_suggestion
  - mcp__forge-db__get_template
---

# Template feedback loop

This is the back-mapping step: look at what you actually added by hand across projects, and fold the recurring additions back into the templates.

## Steps

1. Call `compute_suggestions` (default `min_occurrences=2`).
2. For each pending suggestion, show it in plain language, e.g.:
   "You added `zod` by hand in 4 projects built from `nextjs-trpc-drizzle`. Add it to that template?"
   Include the occurrence count so the user can judge.
3. **Do not apply anything automatically.** Wait for the user to choose which suggestions to accept.
4. For each accepted suggestion, call `apply_suggestion`. If the user names a specific version, pass it; otherwise pass `latest` and tell them they can pin it later.
5. After applying, briefly confirm which templates changed.

If `$ARGUMENTS` contains `--apply`, you may still only apply suggestions the user explicitly confirms in this turn — the flag does not grant blanket approval.
