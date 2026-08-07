# Token Benchmarks

## Word-to-Token Conversion

**Rule**: 1 word ≈ 1.3 tokens (English prose)

| Words | Tokens (approx) |
|-------|----------------|
| 100 | 130 |
| 300 | 390 |
| 500 | 650 |
| 1,000 | 1,300 |
| 2,000 | 2,600 |
| 5,000 | 6,500 |

**Code**: denser — 1 word ≈ 1.5-2 tokens due to punctuation, symbols.

## Baseline Token Costs by Component

### CLAUDE.md / Memory files
| Size | Tokens |
|------|--------|
| 50 words (minimal) | ~65 |
| 200 words (good) | ~260 |
| 600 words (bloated) | ~780 |
| 1,000 words (critical) | ~1,300 |

### Skills — lazy-loaded, two separate costs

| Component | When paid | Typical size |
|-----------|-----------|--------------|
| Frontmatter description | Every session (constant) | ~50–150 tokens each |
| SKILL.md body | Only when invoked | body words × 1.3 |

A plugin with 10 skills costs ~500–1,500 tokens of descriptions per
session; a 5,000-word body you never invoke costs nothing.

### Memory files (`.remember/*.md`, when loaded)
| Count | Avg tokens |
|-------|-----------|
| 1 file | ~390 |
| 5 files | ~1,950 |
| 10 files | ~3,900 |

## Total Session Budget Example

```
Component                          Tokens
------------------------------------------
System prompt (base)               ~2,000
Global CLAUDE.md (500 words)       ~650
Project CLAUDE.md (100 words)      ~130
15 skill descriptions (constant)   ~1,500
3 memory files                     ~1,170
------------------------------------------
Session start total:               ~5,450
+ each invoked skill's body, when it fires
```

Each response adds: user tokens + response tokens + above.

## Cost Arithmetic

Don't quote prices from memory — check the current rates at
https://www.anthropic.com/pricing. The arithmetic:

```
cost per response ≈ (context tokens × input price/token)
monthly savings   ≈ tokens saved/response × responses/day × 30 × price
```

At any price tier, a 10k-token reduction paid on every response compounds
fast — that's the whole thesis of this plugin.

## Quick Audit Command

```bash
echo "=== Token Audit ==="
for f in "$HOME/.claude/CLAUDE.md" ./CLAUDE.md .remember/*.md; do
  [ -f "$f" ] && echo "  $f: $(( $(wc -w < "$f") * 13 / 10 )) tokens"
done
```
