---
name: Low Token Mode
description: This skill should be used when the user says "low token mode", "minimal responses", "short answers only", "save tokens", "be concise", "150 token limit", "stop explaining things", or "I'm running low on context". Do NOT activate for a one-off "keep it short" on a single answer — just answer short; the mode is for the rest of the session.
version: 1.1.0
---

# Low Token Mode

Activate a strict response discipline that minimizes token output without losing technical accuracy. Apply when users need to conserve context window budget.

## Persistence

ACTIVE EVERY RESPONSE once on. No drift back to verbose answers after a few
turns — the mode holds until an explicit deactivation phrase. If unsure
whether it's still on, it's on.

## Activation

When user requests low token mode, confirm activation and apply ALL rules below immediately:

```
LOW TOKEN MODE: ON
Max response: 150 tokens
No explanations unless asked.
```

## Rules to Apply

| Rule | Detail |
|------|--------|
| Max response length | 150 tokens |
| No explanations | Skip unless user says "explain" or "why" |
| Code over prose | Prefer code blocks over descriptions |
| No context repetition | Never restate the problem |
| Diff-style edits | Show only changed lines, not full files |
| Skip pleasantries | No "Sure!", "Great question", "Happy to help" |
| One word when possible | "Done." not "I have completed the task." |

## Response Patterns

**Standard answer:**
```
[result only]
```

**Code change:**
```diff
- old line
+ new line
```

**File edit:**
```
File: path/to/file.py, line 42
Change: `old_value` → `new_value`
```

**Error fix:**
```
Cause: [one line]
Fix: [code or command]
```

## What Never Gets Compressed

Brevity never trims: error messages the user needs to debug, warnings before
destructive or irreversible actions, security caveats, and anything the user
explicitly asked to have explained ("explain", "why", "walk me through").
Correctness beats the 150-token cap — go over the cap rather than ship a
truncated answer that misleads.

## Deactivation

Deactivate when user says "normal mode", "stop low token", "full responses", or "explain everything".

On deactivation:
```
LOW TOKEN MODE: OFF
Normal responses resumed.
```

## Additional Resources

- **`references/token-patterns.md`** — Response templates for common task types in low token mode
