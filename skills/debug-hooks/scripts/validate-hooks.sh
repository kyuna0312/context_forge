#!/bin/bash
# validate-hooks.sh: Validate Claude Code hook configuration and scripts
# Usage: bash validate-hooks.sh [hooks.json path]
set -euo pipefail

HOOKS_FILE="${1:-$HOME/.claude/settings.json}"
ERRORS=0
WARNINGS=0

echo "=== Hook Validator ==="
echo "File: $HOOKS_FILE"
echo ""

# Check file exists
if [ ! -f "$HOOKS_FILE" ]; then
  echo "ERROR: File not found: $HOOKS_FILE"
  exit 1
fi

# Validate JSON syntax
echo "--- JSON Syntax ---"
if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$HOOKS_FILE" 2>/dev/null; then
  echo "✓ Valid JSON"
else
  echo "✗ Invalid JSON"
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$HOOKS_FILE" 2>&1 | head -5
  ERRORS=$((ERRORS + 1))
  echo ""
  echo "Fix: Use https://jsonlint.com or:"
  echo "  python3 -m json.tool $HOOKS_FILE"
  exit 1
fi

echo ""
echo "--- Hook Events ---"

# Extract hook commands from JSON (handles both direct and wrapper format)
COMMANDS=$(python3 - "$HOOKS_FILE" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

# Handle plugin wrapper format: {"hooks": {...}}
if "hooks" in data and isinstance(data["hooks"], dict):
    hooks = data["hooks"]
else:
    hooks = data

valid_events = {
    "PreToolUse", "PostToolUse", "SessionStart", "SessionEnd",
    "Stop", "SubagentStop", "UserPromptSubmit", "PreCompact", "Notification"
}

for event, entries in hooks.items():
    if event in ("description", "version"):
        continue
    if event not in valid_events:
        print(f"WARN_EVENT:{event}")
        continue
    print(f"EVENT:{event}")
    if not isinstance(entries, list):
        print(f"ERROR_ENTRIES:{event}")
        continue
    for entry in entries:
        for hook in entry.get("hooks", []):
            if hook.get("type") == "command":
                print(f"CMD:{hook['command']}")
PYEOF
)

EVENT_COUNT=0
CMD_COUNT=0

while IFS= read -r line; do
  if [[ "$line" == EVENT:* ]]; then
    event="${line#EVENT:}"
    echo "✓ Event: $event"
    EVENT_COUNT=$((EVENT_COUNT + 1))
  elif [[ "$line" == WARN_EVENT:* ]]; then
    event="${line#WARN_EVENT:}"
    echo "⚠ Unknown event: $event (check spelling, case-sensitive)"
    WARNINGS=$((WARNINGS + 1))
  elif [[ "$line" == ERROR_ENTRIES:* ]]; then
    event="${line#ERROR_ENTRIES:}"
    echo "✗ $event entries is not an array"
    ERRORS=$((ERRORS + 1))
  elif [[ "$line" == CMD:* ]]; then
    cmd="${line#CMD:}"
    CMD_COUNT=$((CMD_COUNT + 1))
  fi
done <<< "$COMMANDS"

echo ""
echo "--- Command Scripts ---"

# Re-extract commands and check them
while IFS= read -r line; do
  if [[ "$line" == CMD:* ]]; then
    cmd="${line#CMD:}"

    # Extract script path (first token that looks like a path)
    script_path=""
    for token in $cmd; do
      if [[ "$token" == /* ]] || [[ "$token" == ~/* ]] || [[ "$token" == ./* ]]; then
        script_path="$token"
        break
      fi
    done

    # Expand env vars in path
    script_path_expanded=$(eval echo "$script_path" 2>/dev/null || echo "$script_path")

    if [ -z "$script_path" ]; then
      echo "→ Command: $cmd (no file path detected)"
    elif [ -f "$script_path_expanded" ]; then
      echo "✓ Script exists: $script_path_expanded"

      # Check executable
      if [ ! -x "$script_path_expanded" ]; then
        echo "  ⚠ Not executable. Fix: chmod +x $script_path_expanded"
        WARNINGS=$((WARNINGS + 1))
      fi

      # Check syntax for bash/sh scripts
      if [[ "$script_path_expanded" == *.sh ]]; then
        if bash -n "$script_path_expanded" 2>/dev/null; then
          echo "  ✓ Bash syntax OK"
        else
          echo "  ✗ Bash syntax error:"
          bash -n "$script_path_expanded" 2>&1 | head -3
          ERRORS=$((ERRORS + 1))
        fi
      fi

      # Check syntax for Python scripts
      if [[ "$script_path_expanded" == *.py ]]; then
        if python3 -m py_compile "$script_path_expanded" 2>/dev/null; then
          echo "  ✓ Python syntax OK"
        else
          echo "  ✗ Python syntax error:"
          python3 -m py_compile "$script_path_expanded" 2>&1 | head -3
          ERRORS=$((ERRORS + 1))
        fi
      fi
    else
      echo "✗ Script missing: $script_path_expanded"
      ERRORS=$((ERRORS + 1))
    fi
  fi
done <<< "$COMMANDS"

echo ""
echo "--- Summary ---"
echo "Events: $EVENT_COUNT, Commands: $CMD_COUNT"
echo "Errors: $ERRORS, Warnings: $WARNINGS"
echo ""

if [ "$ERRORS" -gt 0 ]; then
  echo "✗ Validation FAILED ($ERRORS errors)"
  echo "Run /kyuna_token_saver:debug-hooks for guided repair"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo "⚠ Validation PASSED with $WARNINGS warnings"
  exit 0
else
  echo "✓ Validation PASSED"
  exit 0
fi
