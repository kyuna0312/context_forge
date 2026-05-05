---
name: Project Isolation
description: This skill should be used when the user says "isolate project context", "project scope only", "exclude other projects", "global context is leaking", "Claude remembers wrong project", "isolate session", or "context from wrong project".
version: 1.0.0
---

# Project Isolation

Constrain Claude's context to only the current project. Prevents cross-project memory contamination and eliminates irrelevant context that wastes tokens.

## The Problem

By default, Claude Code loads:
- Global memory files (`~/.claude/memory/`)
- All session history
- Global `claude.md`
- All installed plugins

## Create Project Scope

### Step 1: Create project-local claude.md

In the project root, create or update `CLAUDE.md`:

```markdown
## Project Scope

This is an isolated project context.

EXCLUDE from context:
- Global memory files
- Other project histories  
- Plugins: [list plugins not relevant to this project]

INCLUDE only:
- Files in this repository
- Current conversation

Project: [PROJECT NAME]
Stack: [e.g., Next.js, PostgreSQL]
Key constraints: [e.g., no external dependencies, TypeScript strict mode]
```

### Step 2: Instruct Claude at Session Start

Paste this at the start of each isolated session:

```
Create new project scope.

Only include:
- Files in current repository: [PATH]
- This conversation

Exclude:
- Global memory
- Other project context
- Previous unrelated sessions

Confirm isolated context before continuing.
```

### Step 3: Verify Isolation

After applying, Claude should confirm:
- Current working directory
- Active repository
- No references to other projects

If Claude references another project, repeat isolation prompt.

## Per-Project Plugin Config

Create `.claude/settings.local.json` in project root:

```json
{
  "plugins": {
    "enabled": ["plugin-relevant-to-this-project"],
    "disabled": ["unrelated-plugin-1", "unrelated-plugin-2"]
  }
}
```

## Additional Resources

- **`references/isolation-patterns.md`** — Templates for different project types (mono-repo, microservices, etc.)
