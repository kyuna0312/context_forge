---
name: LLM Wiki
description: This skill should be used when the user says "build a wiki", "maintain a wiki", "ingest docs into wiki", "query my wiki", "set up llm wiki", "wiki-based knowledge base", "stop re-reading docs every session", "persistent knowledge base", or "compress my docs into wiki pages". Do NOT use for source code (grep the code — a wiki copy of it rots) or for one-off questions about a document.
version: 1.2.0
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
printf '# Wiki Index\n\n## Pages\n' > wiki/index.md
printf '# Ingest Log\n' > wiki/log.md
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
   — if the source is smaller than the wiki page would be (a short README,
   a config file), skip it: re-reading it is cheaper than maintaining a copy
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
4. Create a new page only if answering required going back to raw sources —
   that gap is the signal a page is missing. Synthesis alone is not a page.
5. Log to `wiki/log.md` only when the wiki changed (`[DATE] INGEST/UPDATE: …`).
   Don't log read-only queries — a write per question is ceremony, and the
   log would outgrow the wiki.

### Lint: Health Check

Periodically check wiki integrity:

```
Contradictions:  pages with conflicting claims
Stale pages:     source file's mtime is newer than the page's "Last updated"
Orphaned pages:  not referenced in index.md
Missing links:   [[references]] with no matching file
```

A stale page is worse than no page — it answers confidently and wrong.
Re-ingest or delete; never leave it.

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

## When NOT to Build a Wiki

- **Source code** — the code is its own source of truth; a wiki copy drifts
  the moment the code changes. Wiki *decisions and concepts*, grep the code.
- **Sources smaller than their page** (short README, config file) —
  re-reading the original is cheaper than maintaining a copy.
- **One-off questions** — answer from the doc directly; a wiki pays off on
  the second read, not the first.
- **Anything with a maintained upstream reference** (official API docs you
  can fetch) — wiki only the project-specific deltas and gotchas.

## Integration with context_forge

- Run `/context_forge:estimate-tokens` after wiki setup to measure baseline
- Add the `wiki/` reference to CLAUDE.md via `/context_forge:optimize-claudemd`

## Additional Resources

- **`references/wiki-patterns.md`** — Page templates and multi-project wiki setups
