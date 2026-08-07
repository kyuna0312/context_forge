# Project Isolation Patterns

## Why Isolate

- Global CLAUDE.md loads for every project — irrelevant context wastes tokens
- Global settings apply everywhere — per-project needs differ
- Skill plugins active globally — most not relevant to current work

## File Locations

| File | Scope | Purpose |
|------|-------|---------|
| `~/.claude/CLAUDE.md` | Global | Rules for all projects |
| `[project]/CLAUDE.md` | Project | Project-specific rules (merged with global) |
| `~/.claude/settings.json` | Global | Default settings |
| `[project]/.claude/settings.json` | Project | Overrides for this project |

## Project CLAUDE.md Template

```markdown
# [Project Name]
Stack: [e.g., Next.js 14, TypeScript strict, PostgreSQL]

## Rules
- [Style rule]
- [Constraint]
- [Git convention]
```

Target: < 100 words, < 130 tokens.

## Project settings.json Template

Only documented keys (there is no per-project plugin toggle or
`autoLoadSkills` — plugins are managed with `/plugin`, and skill bodies
lazy-load anyway):

```json
{
  "autoMemoryEnabled": false,
  "disabledMcpjsonServers": ["server-not-needed-here"]
}
```

### What to set per-project

**autoMemoryEnabled: false** when:
- Auto memory content isn't relevant to this project
- Reference remembered content manually instead

**disabledMcpjsonServers: [names]** when:
- The project's `.mcp.json` (or a global one) registers servers this
  project never uses — their tool schemas stop loading

## Token Savings from Isolation

The dominant lever is CLAUDE.md size — measure with
`/context_forge:estimate-tokens` before and after instead of trusting
projected numbers:

```
Global CLAUDE.md: 800 words = ~1,040 tokens constant
Project CLAUDE.md at 80 words = ~104 tokens constant
Plus: skill descriptions of removed plugins, disabled MCP schemas
```

## Multi-Project Setup Pattern

```
~/
├── .claude/
│   ├── CLAUDE.md          # Global: coding style only
│   └── settings.json      # Global: autoMemoryEnabled false
└── projects/
    ├── web-app/
    │   ├── CLAUDE.md      # Project: Next.js rules
    │   └── .claude/
    │       └── settings.json  # Project: disable data-pipeline MCP servers
    └── data-pipeline/
        ├── CLAUDE.md      # Project: Python/data rules
        └── .claude/
            └── settings.json  # Project: disable web MCP servers
```

## Global CLAUDE.md Best Practices

Keep global CLAUDE.md to universal rules only:
- Code style (formatting, naming)
- Git conventions
- Language preference

Move to project CLAUDE.md:
- Framework-specific rules
- Project constraints
- Team conventions
- Deployment notes

Rule of thumb: If it's only true for one project, it belongs in project CLAUDE.md.
