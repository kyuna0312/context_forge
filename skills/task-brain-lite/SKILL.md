---
name: Task Brain Lite
description: >-
  Structured task decomposition with dependency tracking and cross-session
  memory. Use when the user says "/task_brain", "task brain", "break down
  this task", "plan this", "decompose this problem", "what order should I do
  this in", or when a task has multiple moving parts, unclear dependencies,
  or high ambiguity. Do NOT use for single-step requests with an obvious
  path (just do them), conversational questions, or when the user asked for
  a plain answer — the ceremony must be smaller than the task.
version: 1.2.0
---

# task_brain_lite

You are a planner who hates planning. Every phase below exists to *shorten*
the path to done — the moment a phase stops paying for itself, skip it.

Decompose → Prioritize → Execute → Remember → Reuse.

## Phase 1: ANALYZE

Before anything else, assess the task:

- **complexity**: Low / Medium / High
  - Low: 1 step, obvious path
  - Medium: 2–4 steps, some unknowns, no hard interdependencies
  - High: 5+ steps, or significant dep chain, or high ambiguity
- **deps**: list what blocks what (skip if Low)
- **memory_check**: run a 3-signal match against `.remember/logs/task_brain.jsonl`
  (file missing or empty → `[memory: miss]`, no error, don't create it yet)
  - Signal 1 (structural): same complexity class AND stored `n` within ±2 of current subtask count — subtasks don't exist yet, so use the step estimate you just made for the complexity call
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
- Tag each subtask with its own complexity (L/M/H) — PRIORITY scores off this
- Never pad the split: if it yields one real subtask, the task was Low —
  drop the ceremony and just execute

Show decomposition tree, then emit the initial task state table:

```
| task              | cx | state                     |
|-------------------|----|---------------------------|
| parse_schema      | L  | ready                     |
| write_models      | M  | blocked(parse_schema)     |
| implement_auth    | H  | blocked(write_models)     |
| write_tests       | M  | blocked(implement_auth)   |
```

This table is the live state. Reprint it (compactly) after every EXECUTE cycle.

## Phase 2.5: SEQUENCE (Medium complexity only)

For Medium complexity, produce a flat ordered list — no tree, no depth:

1. `subtask_one` — reason it comes first (e.g., "needed by all others")
2. `subtask_two` — reason
3. `subtask_three` — reason

Rules:
- Max 4 items. For more than that, re-evaluate as High complexity.
- Each item has a one-phrase rationale for its position.
- After the list, emit the same compact state table format as SPLIT.

Use `[SEQUENCE]` header here, not `[SPLIT]`. The list order IS the execution
order — Medium skips PRIORITY entirely.

## Phase 3: PRIORITY (High complexity only)

Score each task using its `cx` tag from the SPLIT table:

```
Ready tasks:   score = 1.0 + (1 / complexity_weight)
               complexity_weight: L=1, M=2, H=3

Blocked tasks: score = 0.5  if unmet_deps_count == 1
               score = 0.0  if unmet_deps_count > 1

Done tasks:    score = -1   (excluded from selection)
```

Pick the highest-scoring ready task. Ties: prefer lower `cx` (easy wins first).

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

After each completed task, append to `.remember/logs/task_brain.jsonl`
(create the directory on first write: `mkdir -p .remember/logs`):

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

## Output Format

Print phase headers only when the phase runs:

| Complexity | Phases shown |
|------------|-------------|
| Low        | `[ANALYZE]`, `[EXECUTE]`, `[LOG]` |
| Medium     | `[ANALYZE]`, `[SEQUENCE]`, `[EXECUTE]`, `[LOG]` |
| High       | `[ANALYZE]`, `[SPLIT]`, `[PRIORITY]`, `[EXECUTE]`, `[LOG]` |

- Never print `[REUSE]` as a header — reuse output appears inline within `[EXECUTE]`
- Always reprint the task state table after SPLIT or SEQUENCE, and after each EXECUTE cycle
- Keep it tight. No phase explanation unless user asks "why".

Example — "rename this function everywhere":
`[complexity: L] [memory: miss]` → rename, `Done: 6 call sites updated, tests pass` → `[LOG] ✓ saved`. No tree, no table, three lines total.

## When NOT to use

- Single obvious step → no phases, no headers, just do it and log.
- The user asked a question, not for work → answer it; planning a reply is ceremony.
- Never manufacture subtasks to make a task look High — the overhead of the
  table must stay smaller than the work it tracks.
- Never let the state table replace doing: one EXECUTE per response beats a
  perfect plan with zero artifacts.

## Boundaries

Active for the current task until its table is fully `done` — the state
table persists across responses; reprint it, never rebuild it from scratch.
"stop task brain" / "normal mode": drop the phases mid-task and finish
plainly. "auto" / "run all": execute all ready tasks without per-task
confirmation. The plan is scaffolding; the artifact is the product.
