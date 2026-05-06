# LTX Refactor Design — context_guard

**Date:** 2026-05-06
**Status:** Approved
**Branch:** feat/llm-wiki

---

## Overview

Refactor context_guard to adopt LTX (Low Token eXchange Format) as the structured output layer across all skills and hooks that emit data. LTX is a schema-based, row-oriented serialization format that minimizes token usage compared to JSON while remaining human-readable and easy to parse.

---

## LTX Format Reference

### Header (schema line)
```
@v1:field1|field2|field3
```
- MUST begin with `@`
- MUST include version (`v1`)
- MUST include schema fields after `:`
- MUST be the first line of any LTX block

### Rows
```
value|value|value
```

### Example
```
@v1:name|age|city
Kyuna|25|Tokyo
Hana|22|Osaka
```

---

## Architecture

### Shared Library: `scripts/ltx.sh`

Single bash library sourced by all hooks and scripts. No duplication across 14 skills.

**Functions:**
```bash
ltx_header <schema>   # prints @v1:<schema> to stdout
ltx_row <values...>   # prints pipe-delimited row to stdout
ltx_human <message>   # prints human summary to stderr
```

All hooks and scripts that emit structured data source this file.

---

## Hook: Dual-Channel Output

`hooks/scripts/session-start.sh` emits two channels simultaneously:

**stdout — LTX (machine readable):**
```
@v1:file|words|tokens|level
~/.claude/CLAUDE.md|850|1105|critical
./CLAUDE.md|320|416|ok
settings.json|0|0|valid
```

**stderr — human readable:**
```
⚠ TOKEN SAVER [CRITICAL]: ~/.claude/CLAUDE.md is 850 words (~1105 tokens). Run /optimize-claudemd
```

Rules:
- `ltx_header()` + `ltx_row()` → stdout always
- `ltx_human()` → stderr only when threshold exceeded
- Valid/ok entries still appear as LTX rows (for machine consumers) but produce no stderr output

---

## Skill Schemas

Each data-emitting skill gets an inline `## LTX Schema` section in its `SKILL.md`. Schema is authoritative and self-contained per skill. Claude reads this section and formats structured output as LTX rows when responding.

### Skills with LTX schemas

| Skill | Schema |
|-------|--------|
| `estimate-tokens` | `@v1:source\|words\|tokens\|status` |
| `check-claudemd-size` | `@v1:file\|words\|tokens\|level` |
| `token-statusline` | `@v1:context_pct\|bar\|md_tokens\|color` |
| `debug-hooks` | `@v1:hook\|status\|error\|fix` |
| `tune-settings` | `@v1:setting\|current\|recommended\|action` |

### Skills without LTX schemas (procedural)

These skills instruct Claude to take actions rather than emit data rows. No LTX schema needed.

- `low-token-mode`
- `reset-context`
- `manage-skills`
- `project-isolation`
- `auto-compact`
- `settings-diff`
- `task-brain-lite`
- `llm-wiki`
- `optimize-claudemd`

---

## Files Changed

### New
- `scripts/ltx.sh` — shared LTX encoding library

### Modified
- `hooks/scripts/session-start.sh` — dual-channel output via `ltx.sh`
- `skills/estimate-tokens/SKILL.md` — add `## LTX Schema` section
- `skills/check-claudemd-size/SKILL.md` — add `## LTX Schema` section
- `skills/token-statusline/SKILL.md` — add `## LTX Schema` section
- `skills/debug-hooks/SKILL.md` — add `## LTX Schema` section
- `skills/tune-settings/SKILL.md` — add `## LTX Schema` section
- `README.md` — document LTX format and dual-channel hook output

### Untouched
- 9 procedural skills
- `plugin.json`, `hooks.json`
- All `references/` files

---

## Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Schema location | Inline per skill | Self-contained, matches plugin structure |
| Hook output | Dual channel (stdout LTX + stderr human) | Machine consumers get LTX; humans still see warnings |
| Shared lib | `scripts/ltx.sh` | Avoid duplicating encoding logic across 14 skills |
| Scope | 5 data-emitting skills only | Procedural skills have no structured output to serialize |
| LTX version | v1 | Initial version, forward-compatible via version field |
