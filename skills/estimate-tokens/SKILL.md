---
name: Estimate Tokens
description: This skill should be used when the user says "estimate token usage", "how many tokens am I using", "token cost of my setup", "audit token budget", "what's eating my context", "token usage breakdown", or "how expensive is my session".
version: 1.2.0
---

# Estimate Tokens

Audit and report approximate token usage across all context sources: claude.md, skills, memory files, plugins, and conversation history.

## Token Estimation Formula

```
1 word ≈ 1.3 tokens
1 line of code ≈ 10-15 tokens
1KB of text ≈ 200-300 tokens
```

## Audit Procedure

### Step 1: Scan claude.md Files

```bash
wc -w ~/.claude/CLAUDE.md 2>/dev/null || echo "No global CLAUDE.md"
wc -w ./CLAUDE.md 2>/dev/null || echo "No project CLAUDE.md"
```

Report: `CLAUDE.md: ~[words] words ≈ [words * 1.3] tokens`

### Step 2: Scan Installed Skills

```bash
find ~/.claude/plugins -name "SKILL.md" -exec wc -w {} \; 2>/dev/null | sort -rn | head -20
```

Skill bodies lazy-load — only frontmatter descriptions are a constant cost
(~50–150 tokens each, every session). Report *description count × ~100* as
the constant estimate; body word counts × 1.3 are the per-invocation cost.

### Step 3: Scan Memory Files

```bash
wc -w ~/.claude/memory/*.md 2>/dev/null
find .remember -name "*.md" -exec wc -w {} \; 2>/dev/null
```

### Step 4: Count Active Plugins

```bash
ls ~/.claude/plugins/ 2>/dev/null | wc -l
```

Each active plugin = at minimum plugin.json metadata overhead.

### Step 5: Generate Report

Output formatted breakdown:

```
TOKEN USAGE AUDIT
=================
claude.md (global):    ~[N] tokens
claude.md (project):   ~[N] tokens
Skill descriptions:    ~[N] tokens  ([X] skills, constant)
Memory files:          ~[N] tokens
─────────────────────────────────
TOTAL CONSTANT COST:   ~[N] tokens per response

Top token consumers:
1. [skill-name]: ~[N] tokens
2. [skill-name]: ~[N] tokens
3. [memory-file]: ~[N] tokens

Recommendation: [action to reduce]
```

## Optimization Priorities

Based on audit results, recommend in order:

1. **claude.md > 500 words** → Run optimize-claudemd skill (usually the biggest constant cost)
2. **Memory files > 1,000 words** → Archive old entries
3. **10+ installed plugins** → `/plugin remove` project-irrelevant ones (each skill's description is constant overhead)
4. **Frequently-invoked skill with 3,000+ word body** → Move detail to `references/` files

## LTX Schema

Emit structured output as LTX rows when reporting per-source token estimates.

```
@v1:source|words|tokens|status
```

| Field | Description |
|-------|-------------|
| `source` | File or category (e.g. `~/.claude/CLAUDE.md`, `skills`) |
| `words` | Raw word count |
| `tokens` | Estimated tokens (`words * 1.3`, rounded) |
| `status` | `ok`, `warn` (approaching limit), `critical` (over limit) |

Example:
```
@v1:source|words|tokens|status
~/.claude/CLAUDE.md|850|1105|critical
./CLAUDE.md|320|416|ok
skills|2400|3120|warn
```

## Additional Resources

- **`references/token-benchmarks.md`** — Token cost benchmarks for common setups
