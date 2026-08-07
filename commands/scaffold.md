---
description: "Scaffold a new project from a DB-backed template"
argument-hint: "[template-name] [project-name]"
allowed-tools:
  - Read
  - Write
  - Bash
  - mcp__forge-db__list_templates
  - mcp__forge-db__get_template
  - mcp__forge-db__register_project
---

# Scaffold a project from a template

Arguments: `$ARGUMENTS`
- `$0` = template name (optional — if missing, list templates and ask)
- `$1` = new project name (optional — ask if missing)

## Rules (important — prevents hallucination)

1. **Never invent a template name.** Call `list_templates` first and pick a real one. If `$0` is empty or not in the list, show the list and stop to ask the user.
2. **Never guess file contents or dependency versions.** Call `get_template` and use the returned `files[].content` *verbatim* and `deps[].version` *exactly*. You are a copier here, not an author.
3. Substitute only the documented placeholders: `{{project_name}}`, `{{year}}`. Nothing else.
4. **If any forge-db tool errors** (connection refused, relation does not exist), stop and report the missing piece — never scaffold from memory.
5. **Never write outside the project directory.** Reject any template file whose `path` is absolute or contains `..` — report it as a bad template row instead of writing it.

## Steps

1. Call `list_templates`. If `$0` is empty or unknown, present the names + descriptions and ask which one. Stop.
2. Call `get_template` with the chosen name.
3. Create the project directory `$1/` (ask for the name if `$1` is empty). If the directory already exists and is non-empty, stop and ask — never overwrite existing files.
4. For each file in `files`, write it at `$1/{path}` using its `content` verbatim, applying only the allowed placeholder substitutions.
5. Build `package.json` dependencies from `deps` using the **exact** versions returned. Do not upgrade, downgrade, or add anything not listed.
6. Run the install command inside `$1/`, taken from the template's stack info (e.g. `npm install` for a Node stack). If the stack doesn't imply one, ask — don't guess a package manager.
7. After install succeeds, validate: run `npm run typecheck` or `npm run build` if such a script exists. Report any failure honestly — do not claim success you didn't verify.
8. Call `register_project` with the name, template name, and absolute root path.
9. Print a short summary: template used, file count, dependency count, validation result.
