---
name: Manage Skills
description: This skill should be used when the user says "list loaded skills", "disable skills", "skills are wasting tokens", "too many skills loaded", "which skills are active", "unload skills", "skill token cost", or "skills killing my budget".
version: 1.0.0
---

# Manage Skills

Audit and reduce skill token overhead. Skills silently consume 1,000-28,000 tokens each when loaded.

## Token Cost of Skills

Each loaded skill SKILL.md body costs tokens every response:
- Small skill: ~500-1,000 tokens
- Medium skill: ~1,500-3,000 tokens  
- Large skill: ~3,000-5,000 tokens
- Plugin with 10 skills: potentially 15,000-50,000 tokens constant overhead

## Audit Loaded Skills

To identify which skills are active, instruct user to run:

```bash
# List all installed plugins and their skills
ls ~/.claude/plugins/

# Check active plugin config
cat ~/.claude/settings.json | grep -i plugin
```

Then read and report:
1. Each plugin name
2. Number of skills per plugin
3. Estimated token cost per skill (check SKILL.md word count)

## Disable Unnecessary Skills

### Disable entire plugin:

Edit `~/.claude/settings.json` and set plugin enabled to false, or remove plugin from active list.

### Request selective loading:

Tell user to add to their `claude.md`:

```markdown
## Skill Loading Policy
Only load skills when explicitly requested with /skill-name.
Do not auto-load skills based on conversation context.
Disabled plugins: [list plugins not needed]
```

## Recommended Minimal Skill Set

For most coding sessions, keep only:
- `coding` — core development
- `terminal` — shell operations

Disable: design skills, data skills, SEO skills, marketing skills unless actively needed.

## Estimate Skill Token Cost

For each skill directory, estimate cost:

```bash
# Count words in all SKILL.md files
find ~/.claude/plugins -name "SKILL.md" -exec wc -w {} \; | sort -n
```

Skills over 3,000 words = high cost. Consider disabling or requesting optimization.

## Additional Resources

- **`references/skill-audit.md`** — Full audit procedure and cost reduction strategies
