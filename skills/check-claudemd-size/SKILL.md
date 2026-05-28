---
name: Check Claude.md Size
description: This skill should be used when the user says "check claude.md size", "is my claude.md too big", "claude.md token cost", "how big is claude.md", or when triggered automatically on session start to warn about oversized claude.md files.
version: 1.0.0
---

# Check Claude.md Size

Measure and report claude.md file sizes. Warn when files exceed optimal token budget. Suggest optimization when needed.

## Size Thresholds

| Size | Status | Action |
|------|--------|--------|
| < 300 words | Optimal | No action needed |
| 300-600 words | Acceptable | Monitor growth |
| 600-1,000 words | Bloated | Run optimize-claudemd |
| > 1,000 words | Critical | Immediate optimization needed |

## Check Procedure

### Scan All claude.md Files

```bash
# Global
wc -w ~/.claude/CLAUDE.md 2>/dev/null
wc -w ~/.claude/claude.md 2>/dev/null

# Project
wc -w ./CLAUDE.md 2>/dev/null
wc -w ./claude.md 2>/dev/null
```

### Report Format

```
CLAUDE.MD SIZE CHECK
====================
Global (~/.claude/CLAUDE.md):   [N] words ≈ [N*1.3] tokens  [STATUS]
Project (./CLAUDE.md):          [N] words ≈ [N*1.3] tokens  [STATUS]

Combined constant cost: ~[N] tokens per response

[WARNING if any file is Bloated/Critical]
Run: /context_guard:optimize-claudemd to reduce size
```

## Automatic Session-Start Check

This skill is called by the SessionStart hook. On session start:

1. Check all claude.md file sizes
2. If any file > 600 words: print warning
3. If any file > 1,000 words: print critical warning with optimization command

Warning format:
```
⚠ TOKEN SAVER: claude.md is [N] words ([STATUS])
  Run /context_guard:optimize-claudemd to reduce by ~[%]%
```

## What Makes claude.md Grow

Common causes of bloat:
- Accumulated instructions over time without pruning
- Paste of full API docs or schemas
- Duplicate rules from different sessions
- Long prose explanations instead of bullet rules
- Examples that should be in `references/` files

## LTX Schema

Emit structured output as LTX rows when reporting file sizes.

```
@v1:file|words|tokens|level
```

| Field | Description |
|-------|-------------|
| `file` | Path to the claude.md file checked |
| `words` | Raw word count |
| `tokens` | Estimated tokens (`words * 1.3`, rounded) |
| `level` | `ok`, `warn` (600–999 words), `critical` (≥1000 words) |

Example:
```
@v1:file|words|tokens|level
~/.claude/CLAUDE.md|850|1105|critical
./CLAUDE.md|320|416|ok
```

