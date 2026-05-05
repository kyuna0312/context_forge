#!/bin/bash
# kyuna_token_saver: SessionStart hook
# Checks claude.md size and reports token cost warnings on session start
set -uo pipefail

WARN_WORDS=600
CRIT_WORDS=1000

check_file() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    local words tokens
    words=$(wc -w < "$path")
    tokens=$(( words * 13 / 10 ))
    if [ "$words" -ge "$CRIT_WORDS" ]; then
      echo "⚠ TOKEN SAVER [CRITICAL]: $label is ${words} words (~${tokens} tokens). Run /kyuna_token_saver:optimize-claudemd"
    elif [ "$words" -ge "$WARN_WORDS" ]; then
      echo "⚠ TOKEN SAVER [WARNING]: $label is ${words} words (~${tokens} tokens). Consider optimizing."
    fi
  fi
}

# Check all claude.md locations
check_file "$HOME/.claude/CLAUDE.md" "~/.claude/CLAUDE.md"
check_file "$HOME/.claude/claude.md" "~/.claude/claude.md"

if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  check_file "$CLAUDE_PROJECT_DIR/CLAUDE.md" "CLAUDE.md (project)"
  check_file "$CLAUDE_PROJECT_DIR/claude.md" "claude.md (project)"
fi

# Check for hook errors in settings
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$SETTINGS" 2>/dev/null; then
    echo "⚠ TOKEN SAVER: settings.json has invalid JSON. Run /kyuna_token_saver:debug-hooks"
  fi
fi

exit 0
