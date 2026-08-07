---
name: Manage Skills
description: This skill should be used when the user says "list loaded skills", "disable skills", "skills are wasting tokens", "too many skills loaded", "which skills are active", "unload skills", "skill token cost", or "skills killing my budget". Skill bodies lazy-load — only descriptions cost tokens every session; size the fix to that reality.
version: 1.1.0
---

# Manage Skills

Audit and reduce skill token overhead.

## Token Cost of Skills — the Real Model

Skill bodies are **lazy-loaded**: only the frontmatter `name` + `description`
of every installed skill loads at session start; the SKILL.md body loads only
when the skill is actually invoked. So:

- Constant cost per installed skill: its description (~50–150 tokens)
- Plugin with 10 skills: ~500–1,500 tokens of descriptions, every session
- Body cost (can be thousands of tokens): paid only on invocation

The lever is therefore the *number of installed skills* (description
overhead) and *bloated descriptions* — not body size. A 5,000-word body you
never invoke costs you nothing.

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

The real mechanisms (there is no `autoLoadSkills` setting — do not invent
one):

- **Remove a plugin**: `/plugin remove <name>` — removes its skills' descriptions from every session
- **Bundled skills**: set `"disableBundledSkills": true` in `settings.json` to skip Claude Code's built-in skills at startup
- **Skill invoked when unwanted**: tighten its `description` (add "Do NOT use for…" anti-triggers) rather than trying to block loading

## Recommended Minimal Skill Set

Keep only plugins actively needed for current work. Remove:
- Design/SEO/marketing plugins during coding sessions
- Large documentation plugins when not writing docs
- Any plugin with 5+ skills where you only use 1–2

## Estimate Skill Token Cost

Constant cost = descriptions. Measure those, not bodies:

```bash
# Words in each skill's frontmatter description (constant, every session)
for f in ~/.claude/plugins/*/skills/*/SKILL.md; do
  awk '/^description:/{f=1} f&&/^[a-z]+:/&&!/^description:/{exit} f' "$f" | wc -w | xargs echo "$f"
done

# Body word counts (cost only when invoked)
find ~/.claude/plugins -name "SKILL.md" -exec wc -w {} \; | sort -n
```

A body over 3,000 words is only a problem for skills you invoke often —
suggest moving detail into `references/` files, which load on demand.

## Additional Resources

- **`references/skill-audit.md`** — Full audit procedure and cost reduction strategies
