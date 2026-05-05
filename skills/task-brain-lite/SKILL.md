---
name: task_brain_lite
description: |
  Task decomposition, prioritization, execution, and memory reuse engine. 
  Use this skill whenever the user says /task_brain, asks to "break down" a task, 
  "plan" or "decompose" a complex problem, mentions task complexity, or asks you 
  to figure out what to do first. Also trigger automatically when you detect a 
  task with multiple moving parts, unclear dependencies, or high ambiguity — 
  even if the user doesn't explicitly ask for planning. When in doubt, use it.
---

# task_brain_lite

Decompose → Prioritize → Execute → Remember → Reuse.

## Phase 1: ANALYZE

Before anything else, assess the task:

- **complexity**: Low / Medium / High
  - Low: 1 step, obvious path
  - Medium: 2–4 steps, some unknowns, no hard interdependencies
  - High: 5+ steps, or significant dep chain, or high ambiguity
- **deps**: list what blocks what (skip if Low)
- **memory_check**: run a 3-signal match against `.remember/logs/task_brain.jsonl`
  - Signal 1 (structural): same complexity class AND stored `n` within ±2 of current subtask count
  - Signal 2 (domain): ≥1 overlapping tag between current task keywords and stored `t`
  - Signal 3 (solution verb): a verb from stored `sol` appears in the current task description
  - Show `[memory: HIT — N/3 signals]` if N ≥ 2, else `[memory: miss]`

Show user: `[complexity: H] [deps: A→B, C→B] [memory: hit/miss]`

If complexity is Medium or High, initialize the task state table after the next phase.

## Phase 2: SPLIT (High complexity only)

Break into semantic subtasks:
- Each subtask = one clear action with verifiable output
- Max depth: 3 levels
- Preserve dependency edges
- Name tasks like: `verb_noun` (e.g., `parse_schema`, `write_tests`, `deploy_service`)

Show decomposition tree, then emit the initial task state table:

```
| task              | state                     |
|-------------------|---------------------------|
| parse_schema      | ready                     |
| write_models      | blocked(parse_schema)     |
| implement_auth    | blocked(write_models)     |
| write_tests       | blocked(implement_auth)   |
```

This table is the live state. Reprint it (compactly) after every EXECUTE cycle.

## Phase 2.5: SEQUENCE (Medium complexity only)

For Medium complexity, produce a flat ordered list — no tree, no depth:

1. `subtask_one` — reason it comes first (e.g., "needed by all others")
2. `subtask_two` — reason
3. `subtask_three` — reason

Rules:
- Max 4 items. If you need more, re-evaluate as High complexity.
- Each item has a one-phrase rationale for its position.
- After the list, emit the same compact state table format as SPLIT.

Use `[SEQUENCE]` header here, not `[SPLIT]`.

## Phase 3: PRIORITY

Score each task:

```
Ready tasks:   score = 1.0 + (1 / complexity_weight)
               complexity_weight: L=1, M=2, H=3

Blocked tasks: score = 0.5  if unmet_deps_count == 1
               score = 0.0  if unmet_deps_count > 1

Done tasks:    score = -1   (excluded from selection)
```

Pick the highest-scoring ready task. Ties: prefer lower complexity (easy wins first).

If no ready tasks remain, surface the blocked task with score 0.5:
- Show: `Next: [task] (score: 0.50) | Waiting on: [blocker]`
- Never silently stop — always tell the user what needs to happen next.

Show: `Next: [task_name] (score: X.XX)`

## Phase 4: EXECUTE

**Before executing**, check for memory hit:
- If memory hit (from Phase 1): load the matching entry now
- Show: `[memory] Adapting: {s} ({e}) → {sol}`
- Apply the prior approach to current context; skip steps already covered
- If context has shifted significantly, note the delta and proceed fresh

Execute **one task only**. Output only what's needed.

**Done criteria** — before moving on, state the verifiable artifact:
- A file changed, a command succeeded, a decision made, a question answered
- Write: `Done: [one-line artifact description]`
- Update the task state table: mark this task `done`, unlock its dependents to `ready`

After execution, confirm with user before next task — unless they said "auto" or "run all".

## Phase 5: LOG

After each completed task, append to `.remember/logs/task_brain.jsonl`:

```json
{"s": "task_name", "e": "2026-04-20", "sol": "one-line summary of approach", "t": ["tag1", "tag2"], "cx": "M", "n": 3}
```

Fields:
- `s`: task slug/name
- `e`: date completed
- `sol`: solution summary (what worked, key insight)
- `t`: tags for future retrieval (language, domain, pattern type)
- `cx`: complexity class (L/M/H) — used in Signal 1 of memory match
- `n`: total subtask count in this session — used in Signal 1 of memory match

Show: `[LOG] ✓ saved`

## Phase 6: REUSE (Reference)

REUSE executes during Phase 4. This section defines the matching algorithm for reference:

Match score = number of signals fired:
- Signal 1 (structural): same `cx` AND |current_n − stored_n| ≤ 2
- Signal 2 (domain): ≥1 tag overlap between current task keywords and stored `t`
- Signal 3 (solution verb): verb in stored `sol` appears in current task description

Show memory hit if score ≥ 2. Never reuse blindly — if context has shifted, note the delta.

## Output Format

Print phase headers only when the phase runs:

| Complexity | Phases shown |
|------------|-------------|
| Low        | `[ANALYZE]`, `[EXECUTE]`, `[LOG]` |
| Medium     | `[ANALYZE]`, `[SEQUENCE]`, `[PRIORITY]`, `[EXECUTE]`, `[LOG]` |
| High       | `[ANALYZE]`, `[SPLIT]`, `[PRIORITY]`, `[EXECUTE]`, `[LOG]` |

- Never print `[REUSE]` as a header — reuse output appears inline within `[EXECUTE]`
- Always reprint the task state table after SPLIT or SEQUENCE, and after each EXECUTE cycle
- Keep it tight. No phase explanation unless user asks "why".
