# Wiki Patterns Reference

## Page Templates

### Concept Page
```markdown
# [Concept Name]
_Last updated: [DATE] | Source: [origin file/URL]_

## Summary
[2-3 sentence distillation of what this is and why it matters]

## Key Points
- [key point 1]
- [key point 2]
- [key point 3]

## Code Example
```[lang]
[minimal example if applicable]
```

## Related
- [[related-topic-1]]
- [[related-topic-2]]
```

### API/Interface Page
```markdown
# [API/Module Name]
_Last updated: [DATE] | Source: [origin]_

## Purpose
[one-line purpose]

## Key Methods/Fields
| Name | Type | Description |
|------|------|-------------|
| [name] | [type] | [desc] |

## Usage Pattern
```[lang]
[common usage]
```

## Gotchas
- [known issue or footgun]

## Related
- [[related-page]]
```

### Decision Log Page
```markdown
# Decision: [Decision Name]
_Made: [DATE] | By: [who]_

## Context
[why this decision was needed]

## Decision
[what was decided]

## Alternatives Rejected
- [alt 1]: [why rejected]
- [alt 2]: [why rejected]

## Consequences
- [consequence 1]
- [consequence 2]
```

## Multi-Project Wiki Setup

For users with multiple projects, use a global wiki:

```
~/.claude/wiki/
  ├── index.md
  ├── log.md
  ├── [project-a]/
  │   └── [topic].md
  └── [project-b]/
      └── [topic].md
```

Global CLAUDE.md reference:
```markdown
## Global Wiki
Persistent knowledge at `~/.claude/wiki/`.
Project wikis at `~/.claude/wiki/[project-name]/`.
Query wiki before reading raw files.
```

## Index.md Structure

```markdown
# Wiki Index

## By Category

### Architecture
- [[system-design]] — overall system structure
- [[data-flow]] — how data moves through the system

### APIs
- [[auth-api]] — authentication endpoints
- [[payments-api]] — Stripe integration

### Decisions
- [[decision-database-choice]] — why PostgreSQL over MongoDB

## Recent Updates
| Date | Page | Change |
|------|------|--------|
| [DATE] | [[page]] | [what changed] |
```

## Log.md Format

Append-only. Never edit existing entries.

```markdown
# Ingest/Query Log

[2026-05-06] INGEST: docs/architecture.md → created [[system-design]], updated [[data-flow]]
[2026-05-06] QUERY: "how does auth work?" → [[auth-api]], [[system-design]]
[2026-05-06] LINT: 2 orphaned pages found — [[old-api]], [[deprecated-flow]]
[2026-05-07] INGEST: CHANGELOG v2.1 → updated [[payments-api]]
```
