#!/usr/bin/env bash
# session-start.sh: Warn when CLAUDE.md exceeds token budget thresholds.
# Runs on SessionStart. Checks global and project CLAUDE.md locations.
set -euo pipefail

readonly WARN_WORDS=600
readonly CRIT_WORDS=1000

check_claudemd_size() {
  local file_path="$1"
  local label="$2"

  [ -f "$file_path" ] || return 0

  local word_count token_estimate
  word_count=$(wc -w < "$file_path")
  token_estimate=$(( word_count * 13 / 10 ))

  if [ "$word_count" -ge "$CRIT_WORDS" ]; then
    echo "⚠ TOKEN SAVER [CRITICAL]: $label is ${word_count} words (~${token_estimate} tokens). Run /optimize-claudemd" >&2
  elif [ "$word_count" -ge "$WARN_WORDS" ]; then
    echo "⚠ TOKEN SAVER [WARNING]: $label is ${word_count} words (~${token_estimate} tokens). Consider optimizing." >&2
  fi
}

validate_settings_json() {
  local settings_path="$HOME/.claude/settings.json"

  [ -f "$settings_path" ] || return 0

  if ! python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$settings_path" 2>/dev/null; then
    echo "⚠ TOKEN SAVER: settings.json has invalid JSON. Run /debug-hooks" >&2
  fi
}

check_claudemd_size "$HOME/.claude/CLAUDE.md" "~/.claude/CLAUDE.md"
check_claudemd_size "$HOME/.claude/claude.md" "~/.claude/claude.md"

if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  check_claudemd_size "$CLAUDE_PROJECT_DIR/CLAUDE.md" "CLAUDE.md (project)"
  check_claudemd_size "$CLAUDE_PROJECT_DIR/claude.md" "claude.md (project)"
fi

validate_settings_json
