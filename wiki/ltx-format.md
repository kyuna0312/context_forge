# LTX Format
_Last updated: 2026-08-07 | Source: README.md_

## Summary
LTX (Low Token eXchange Format) is the schema-based, pipe-delimited output format hooks and skills emit: one `@v1:<field|field>` header line, then pipe-delimited data rows. Machine rows → stdout; human warnings → stderr.

## Key Points
- Skill schemas: `estimate-tokens` `@v1:source|words|tokens|status` · `check-claudemd-size` `@v1:file|words|tokens|level` · `debug-hooks` `@v1:hook|status|error|fix` · `tune-settings` `@v1:setting|current|recommended|action`.
- Session-start hook emits `@v1:file|words|tokens|level`; stderr warning only when thresholds exceeded.
- Each emitting skill documents its schema in a `## LTX Schema` section of its SKILL.md.

## Related
- [[installation]]
