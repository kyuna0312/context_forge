---
name: LLM Wiki
description: This skill should be used when the user says "build a wiki", "maintain a wiki", "ingest docs into wiki", "query my wiki", "set up llm wiki", "wiki-based knowledge base", "stop re-reading docs every session", "persistent knowledge base", or "compress my docs into wiki pages".
version: 1.0.0
---

# LLM Wiki

Build and maintain a persistent wiki Claude can reference instead of re-ingesting raw documents each session. Derived from Karpathy's LLM Wiki pattern.

**Why it works:** Raw docs reloaded every session = wasted tokens. A wiki is a distilled, pre-summarized artifact — same knowledge, 10x lower token cost.

## Architecture

```
raw-sources/   (immutable originals)
  └── docs, PDFs, changelogs, README files

wiki/          (LLM-maintained markdown pages)
  ├── index.md        ← content catalog
  ├── log.md          ← append-only ingest/query log
  └── [topic].md      ← one page per concept

CLAUDE.md      (tells Claude: "reference wiki/ instead of raw-sources/")
```

## Setup

Create wiki directory at project root or `~/.claude/wiki/` for global:

```bash
mkdir -p wiki
echo "# Wiki Index\n\n## Pages\n" > wiki/index.md
echo "# Ingest Log\n" > wiki/log.md
```

Add to `CLAUDE.md`:

```markdown
## Knowledge Base
Wiki at `wiki/`. Reference wiki pages instead of raw source files.
Do not re-read raw docs unless wiki page is missing or stale.
```

## Operations

### Ingest: Add New Source to Wiki

When user provides a doc, URL, or file to ingest:

1. Read the source
2. Identify 3-5 key concepts worth persisting
3. Create or update `wiki/[topic].md` per concept (one page per topic)
4. Update `wiki/index.md` with new pages
5. Append to `wiki/log.md`: `[DATE] INGEST: [source] → [pages updated]`

Per wiki page format:
```markdown
# [Topic]
_Last updated: [DATE] | Source: [origin]_

## Summary
[2-3 sentence distillation]

## Key Points
- [point 1]
- [point 2]

## Related
- [[other-wiki-page]]
```

### Query: Answer from Wiki

When user asks a question:

1. Search `wiki/index.md` for relevant pages
2. Read matching wiki pages
3. Synthesize answer with citations: `(wiki/[page].md)`
4. If the answer reveals new insight worth keeping, create a new wiki page for it
5. Append to `wiki/log.md`: `[DATE] QUERY: [question] → [pages used]`

### Lint: Health Check

Periodically check wiki integrity:

```
Contradictions:  pages with conflicting claims
Stale pages:     last updated > 90 days AND source has changed
Orphaned pages:  not referenced in index.md
Missing links:   [[references]] with no matching file
```

Report format:
```
WIKI HEALTH
===========
Pages: [N]
Last ingest: [DATE]
Issues found:
- [issue 1]
- [issue 2]
Recommendation: [action]
```

## Token Savings Estimate

| Approach | Tokens per session |
|----------|--------------------|
| Re-read raw 50-page doc | ~15,000 tokens |
| Reference 3 wiki pages | ~600 tokens |
| **Savings** | **~96%** |

## Integration with context-forge

- Run `/estimate-tokens` after wiki setup to measure baseline
- Add `wiki/` reference to CLAUDE.md using `/optimize-claudemd`
- Session-start hook warns if raw docs loaded but wiki exists

## Additional Resources

- **`references/wiki-patterns.md`** — Page templates and multi-project wiki setups
