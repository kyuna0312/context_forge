#!/usr/bin/env bash
# validate-hooks.sh: Validate Claude Code hook configuration and hook scripts.
# Usage: bash validate-hooks.sh [path/to/hooks.json]
set -euo pipefail

readonly HOOKS_FILE="${1:-$HOME/.claude/settings.json}"
error_count=0
warning_count=0

print_header() {
  echo "=== Hook Validator ==="
  echo "File: $HOOKS_FILE"
  echo ""
}

fail() {
  echo "✗ $1" >&2
  error_count=$(( error_count + 1 ))
}

warn() {
  echo "⚠ $1"
  warning_count=$(( warning_count + 1 ))
}

check_file_exists() {
  if [ ! -f "$HOOKS_FILE" ]; then
    echo "ERROR: File not found: $HOOKS_FILE" >&2
    exit 1
  fi
}

validate_json_syntax() {
  echo "--- JSON Syntax ---"
  if python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$HOOKS_FILE" 2>/dev/null; then
    echo "✓ Valid JSON"
  else
    fail "Invalid JSON"
    python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$HOOKS_FILE" 2>&1 | head -5
    echo ""
    echo "Fix: python3 -m json.tool $HOOKS_FILE"
    exit 1
  fi
}

extract_hook_entries() {
  python3 - "$HOOKS_FILE" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as fh:
    data = json.load(fh)

hooks = data.get("hooks", data) if isinstance(data.get("hooks"), dict) else data

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
                print(f"CMD:{hook.get('command', '')}")
                t = hook.get("timeout")
                if t is not None and not isinstance(t, (int, float)):
                    print(f"WARN_TIMEOUT:{event}: timeout is {t!r} — must be a number, not a string")
PYEOF
}

check_hook_events() {
  echo "--- Hook Events ---"
  local event_count=0

  while IFS= read -r line; do
    case "$line" in
      EVENT:*)
        echo "✓ Event: ${line#EVENT:}"
        event_count=$(( event_count + 1 ))
        ;;
      WARN_EVENT:*)
        warn "Unknown event: ${line#WARN_EVENT:} (check spelling — case-sensitive)"
        ;;
      ERROR_ENTRIES:*)
        fail "${line#ERROR_ENTRIES:} entries is not an array"
        ;;
      WARN_TIMEOUT:*)
        warn "${line#WARN_TIMEOUT:}"
        ;;
    esac
  done <<< "$(extract_hook_entries)"

  echo ""
  echo "Events found: $event_count"
}

check_hook_scripts() {
  echo ""
  echo "--- Command Scripts ---"

  while IFS= read -r line; do
    [ "${line#CMD:}" = "$line" ] && continue
    local cmd="${line#CMD:}"

    local script_path=""
    for token in $cmd; do
      # Strip surrounding quotes — hook commands typically quote their paths
      token="${token%\"}"; token="${token#\"}"
      token="${token%\'}"; token="${token#\'}"
      case "$token" in
        /*|~/*|./*|\$CLAUDE_PLUGIN_ROOT/*|\$HOME/*|\${CLAUDE_PLUGIN_ROOT}/*|\${HOME}/*)
          script_path="$token"
          break
          ;;
      esac
    done

    if [ -z "$script_path" ]; then
      echo "→ Command: $cmd (no file path detected)"
      continue
    fi

    # A plugin path can't be checked without the root — warn, don't fail
    if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ] && [[ "$script_path" == *CLAUDE_PLUGIN_ROOT* ]]; then
      warn "Cannot expand $script_path — set CLAUDE_PLUGIN_ROOT to validate plugin paths"
      continue
    fi

    # Expand $VAR references and leading ~ without eval
    local expanded_path="${script_path/\$\{CLAUDE_PLUGIN_ROOT\}/${CLAUDE_PLUGIN_ROOT:-}}"
    expanded_path="${expanded_path/\$CLAUDE_PLUGIN_ROOT/${CLAUDE_PLUGIN_ROOT:-}}"
    expanded_path="${expanded_path/\$\{HOME\}/$HOME}"
    expanded_path="${expanded_path/\$HOME/$HOME}"
    expanded_path="${expanded_path/#\~/$HOME}"

    if [ ! -f "$expanded_path" ]; then
      fail "Script missing: $expanded_path"
      continue
    fi

    echo "✓ Script exists: $expanded_path"

    # +x only matters when the script itself is the command; invocation via
    # an interpreter (bash/node/python3 script) needs no execute bit.
    local first_token="${cmd%% *}"
    first_token="${first_token%\"}"; first_token="${first_token#\"}"
    if [ "$first_token" = "$script_path" ] && [ ! -x "$expanded_path" ]; then
      warn "Not executable: $expanded_path — fix: chmod +x $expanded_path"
    fi

    if [[ "$expanded_path" == *.sh ]]; then
      if bash -n "$expanded_path" 2>/dev/null; then
        echo "  ✓ Bash syntax OK"
      else
        fail "Bash syntax error in $expanded_path:"
        bash -n "$expanded_path" 2>&1 | head -3
      fi
    fi

    if [[ "$expanded_path" == *.py ]]; then
      if python3 -m py_compile "$expanded_path" 2>/dev/null; then
        echo "  ✓ Python syntax OK"
      else
        fail "Python syntax error in $expanded_path:"
        python3 -m py_compile "$expanded_path" 2>&1 | head -3
      fi
    fi

    if [[ "$expanded_path" == *.mjs || "$expanded_path" == *.js || "$expanded_path" == *.cjs ]]; then
      if node --check "$expanded_path" 2>/dev/null; then
        echo "  ✓ Node syntax OK"
      else
        fail "Node syntax error in $expanded_path:"
        node --check "$expanded_path" 2>&1 | head -3
      fi
    fi
  done <<< "$(extract_hook_entries)"
}

print_summary() {
  echo ""
  echo "--- Summary ---"
  echo "Errors: $error_count | Warnings: $warning_count"
  echo ""

  if [ "$error_count" -gt 0 ]; then
    echo "✗ Validation FAILED ($error_count errors)" >&2
    echo "Run /debug-hooks for guided repair" >&2
    exit 1
  elif [ "$warning_count" -gt 0 ]; then
    echo "⚠ Validation PASSED with $warning_count warnings"
  else
    echo "✓ Validation PASSED"
  fi
}

print_header
check_file_exists
validate_json_syntax
check_hook_events
check_hook_scripts
print_summary
