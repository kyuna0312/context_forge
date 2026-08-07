# Settings Diff and Safety Reference

## Why Always Diff First

Settings changes are hard to reverse without a backup. Showing a diff before writing:
1. Prevents accidental overwrites
2. Makes changes reviewable
3. Builds user confidence
4. Documents what changed

## Backup Convention

Always create a timestamped backup:
```bash
cp ~/.claude/settings.json ~/.claude/settings.json.backup.$(date +%Y%m%d-%H%M%S)
```

Backup naming: `settings.json.backup.YYYYMMDD-HHMMSS`

To restore:
```bash
# List backups
ls ~/.claude/settings.json.backup.*

# Restore specific backup
cp ~/.claude/settings.json.backup.20241015-143022 ~/.claude/settings.json
```

## Diff Display Format

Show changes clearly before applying:

```
Current settings.json:
{
  "autoMemoryEnabled": true      ← will change
}

Proposed changes:
{
  "autoMemoryEnabled": false,    ← auto memory off
  "disableBundledSkills": true   ← bundled skills skipped at startup
}

Token savings: ~[measure, don't guess] tokens/session
```

Only documented keys may appear in a diff. An unknown key is silently
ignored by Claude Code, so proposing one promises savings that never
materialize.

## Settings Merge vs Replace

### Safe merge (preferred)
Read existing → add/update only changed keys → write back.

Preserves any custom settings not being changed.

### Replace (destructive)
Write entire new file. Loses any keys not explicitly included.

**Never replace** — always merge.

## Settings JSON Structure

```json
{
  "autoMemoryEnabled": false,
  "disableBundledSkills": true,
  "autoCompactEnabled": true,
  "disabledMcpjsonServers": ["unused-server"]
}
```

## What Each Setting Affects

| Setting | Change | Risk |
|---------|--------|------|
| autoMemoryEnabled | false | Low — memory can still be referenced manually |
| disableBundledSkills | true | Low — bundled skills (except /doctor) unavailable |
| autoCompactEnabled | true | Low — it's the default; keep it |
| disabledMcpjsonServers | [names] | Medium — listed servers' tools become unavailable |

All changes are reversible by editing settings.json.

## Python Merge Pattern

Safe settings merge without destroying existing config:

```python
import json
from pathlib import Path

settings_path = Path.home() / ".claude" / "settings.json"

# Read existing (or start empty)
existing = {}
if settings_path.exists():
    with open(settings_path) as f:
        existing = json.load(f)

# Apply changes (merge, don't replace)
changes = {
    "autoMemoryEnabled": False,
    "disableBundledSkills": True
}
existing.update(changes)

# Write back
with open(settings_path, "w") as f:
    json.dump(existing, f, indent=2)
```

## Validation After Write

After writing settings.json, validate:

```bash
python3 -c "import json; json.load(open('$HOME/.claude/settings.json'))" && echo "Valid JSON" || echo "ERROR: Invalid JSON"
```
