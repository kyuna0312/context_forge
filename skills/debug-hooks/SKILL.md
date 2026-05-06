---
name: Debug Hooks
description: This skill should be used when the user says "startup hook error", "hook not working", "debug hooks", "fix hook error", "SessionStart error", "hook script failing", "node:internal/modules error", "diagnose hook", or sees hook-related errors in Claude Code.
version: 1.0.0
---

# Debug Hooks

Diagnose and fix Claude Code hook errors. Covers startup hook failures, broken MCP configs, missing dependencies, and invalid hook schemas.

## Common Hook Errors

### Error: `node:internal/modules/cjs/loader`

Cause: Hook script references a Node.js file that doesn't exist or has bad require/import.

Fix procedure:
1. Read `~/.claude/settings.json` — find `SessionStart` hooks
2. Locate the referenced script path
3. Check if file exists: `ls [script-path]`
4. If missing: recreate or remove the hook entry
5. If exists: check for bad `require()` paths inside

### Error: `startup hook error`

Cause: Hook command fails on session start.

Fix procedure:
1. Run the hook command manually in terminal
2. Read error output
3. Common causes:
   - Missing npm package → `npm install [package]`
   - Wrong node version → check `node --version`
   - Bad file path → fix path in settings.json
   - Permission denied → `chmod +x [script]`

### Error: Hook silently does nothing

Cause: Wrong event matcher or hook not registered.

Fix procedure:
1. Read `hooks/hooks.json` or `settings.json` hooks section
2. Verify event name is exact: `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`
3. Verify matcher regex matches tool names
4. Test with `claude --debug` to see hook execution logs

## Full Diagnostic Procedure

```bash
# Step 1: Find all hook configs
find ~/.claude -name "hooks.json" 2>/dev/null
grep -r "hooks" ~/.claude/settings.json

# Step 2: Test each hook script manually
bash [hook-script-path]

# Step 3: Check node/python availability
which node && node --version
which python3 && python3 --version

# Step 4: Validate JSON syntax
cat ~/.claude/settings.json | python3 -m json.tool
```

## Fix Hook Schema Errors

Valid hook entry structure:
```json
{
  "SessionStart": [{
    "hooks": [{
      "type": "command",
      "command": "bash $CLAUDE_PLUGIN_ROOT/scripts/my-hook.sh",
      "timeout": 30
    }]
  }]
}
```

Common schema mistakes:
- Missing `hooks` array wrapper
- `type` not set to `"command"`
- Hardcoded absolute path instead of `$CLAUDE_PLUGIN_ROOT`
- Timeout as string instead of number

## Remove Broken Hook

To safely remove a broken hook from settings.json:
1. Read the file
2. Identify the broken hook entry
3. Show user the entry to remove
4. Confirm before editing
5. Remove entry and validate JSON

## LTX Schema

Emit structured output as LTX rows when reporting hook validation results.

```
@v1:hook|status|error|fix
```

| Field | Description |
|-------|-------------|
| `hook` | Hook identifier or script path |
| `status` | `ok`, `warn`, `error`, `missing` |
| `error` | Short error description or `-` if none |
| `fix` | Suggested fix command/action or `-` if none |

Example:
```
@v1:hook|status|error|fix
SessionStart:session-start.sh|ok|-|-
SessionStart:broken-hook.sh|error|file not found|recreate or remove hook entry
```

## Additional Resources

- **`references/hook-errors.md`** — Full error catalog with root causes and fixes
- **`scripts/validate-hooks.sh`** — Script to validate all hook configs
