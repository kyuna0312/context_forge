---
name: Optimize Claude.md
description: This skill should be used when the user says "optimize claude.md", "claude.md is too big", "shrink claude.md", "claude.md taking too many tokens", "trim claude.md", "rewrite claude.md", or "my claude.md is bloated". Do NOT rewrite a file already under 300 words — report it as optimal instead.
version: 1.1.0
---

# Optimize Claude.md

Read, analyze, and rewrite `claude.md` (or `CLAUDE.md`) to reduce token cost while preserving all meaningful constraints. Target: under 300 words (~390 tokens — the same "optimal" threshold check-claudemd-size and the status line use).

If the file is already under 300 words, stop: report "already optimal" and
change nothing. Optimizing an optimal file is pure churn.

## Step 1: Find and Read the File

Check these locations in order:
1. `./CLAUDE.md` (project root)
2. `./claude.md`
3. `~/.claude/CLAUDE.md` (global)
4. `~/.claude/claude.md`

Read the file. Count approximate word count.

## Step 2: Analyze Content

Categorize each section:

| Category | Keep? | Action |
|----------|-------|--------|
| Coding style rules | Yes | Compress to bullets |
| Project structure | Yes | One-line per item |
| Important constraints | Yes | Keep verbatim |
| Pleasantries / tone instructions | Maybe | Cut if not essential |
| Repeated instructions | No | Remove duplicates |
| Obvious defaults | No | Remove ("always use git" etc.) |
| Long explanations | No | Replace with one-line rule |
| Examples longer than 3 lines | No | Remove or move to references/ |

## Step 3: Rewrite

Apply these compression rules:

1. **Bullets over prose** — Replace paragraphs with bullet lists
2. **Imperative tense** — "Use TypeScript strict mode" not "You should use TypeScript strict mode"
3. **No justifications** — Remove "because X" explanations
4. **Merge related rules** — Combine similar rules into one line
5. **Cut obvious defaults** — Remove anything Claude does by default anyway

Target structure:
```markdown
# Project: [NAME]
Stack: [tech stack, one line]

## Code Style
- [rule 1]
- [rule 2]

## Constraints
- [hard constraint 1]
- [hard constraint 2]

## Structure
- [key path 1]: [purpose]
- [key path 2]: [purpose]
```

Compression rule zero: **never silently drop a constraint.** When unsure
whether a rule is load-bearing, keep it and flag it in the diff — the user
decides. A 50-token saving is not worth one lost hard constraint.

## Step 4: Show Diff and Confirm

Present:
```
BEFORE: ~[N] words (~[N*1.3] tokens)
AFTER:  ~[N] words (~[N*1.3] tokens)
Reduction: [%]%
```

Show the optimized version. Ask user to confirm before writing.

## Step 5: Write File

On confirmation, overwrite the file with the optimized version.

## Additional Resources

- **`references/claudemd-templates.md`** — Optimized claude.md templates for common project types
