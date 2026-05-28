---
description: "Show recent changes recorded for a project"
argument-hint: "[project-name]"
allowed-tools:
  - mcp__forge-db__get_changelog
---

# Project changelog

Argument `$0` = project name (optional; omit to show changes across all projects).

## Steps

1. Call `get_changelog` with `project_name=$0` (or no project to see everything).
2. Present the entries grouped by day, newest first. For each entry show: time, change_type, and the file/package involved.
3. Only report what the tool returned. Do not summarise changes that aren't in the data.
