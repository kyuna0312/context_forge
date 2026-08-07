# Context Reset Strategies

## When to Reset

| Signal | Action |
|--------|--------|
| Response latency increases | Reset imminent |
| Claude says "context limit" | Reset now |
| Answers become vague/confused | Reset now |
| Unrelated history polluting responses | Reset now |
| Token estimate > 80k | Plan reset |

## Summary Templates

### Minimal (< 50 tokens)
```
Working on: [file/feature]
Done: [X, Y]
Next: [Z]
Key constraint: [rule]
```

### Standard (< 150 tokens)
```
Project: [name] — [tech stack]
Task: [description]
Progress: [what's done]
Blocked on: [issue if any]
Files changed: [list]
Next step: [specific action]
Rules: [constraints Claude must remember]
```

### Technical (< 200 tokens)
```
Project: [name]
Stack: [versions]
Task: [description]

Done:
- [item 1]
- [item 2]

In progress:
- [current file/function]

Next:
- [specific next action]

Decisions made:
- [key choice and reason]

Constraints:
- [hard rule]
- [style rule]
```

## Reset Prompt Pattern

After summarizing state, use this to open new session:

```
Continue my work. Context:

[PASTE SUMMARY HERE]

Resume at: [exact next action]
```

## What to Include in Summary

**Always include:**
- Current file being edited
- What was just completed
- The very next action needed
- Any hard constraints or rules

**Include if relevant:**
- Error messages being debugged
- API/schema details
- Performance constraints

**Exclude:**
- Conversation history
- Explanations Claude already gave
- Completed tasks with no future relevance
- Code that's already been written and works

## Multi-Session Projects

For long projects, maintain a `CONTEXT.md` file in project root:

```markdown
# [Project] Context

## Status
[current state]

## Next
[next action]

## Decisions
- [decision]: [reason]
```

Update after each session. At reset time, just reference it:
```
See CONTEXT.md for full state. Next step: [X]
```

## Token Cost of NOT Resetting

Every response re-pays the whole context as input tokens:

```
cost per response ≈ context tokens × input price per token
```

At 150k tokens near the limit, each response costs 15× what it did at 10k —
for current per-token rates, see https://www.anthropic.com/pricing. Resetting
from 80k+ back to a lean summary pays for itself within a few responses.
