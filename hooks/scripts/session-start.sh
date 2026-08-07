#!/usr/bin/env bash
# session-start.sh: Warn when CLAUDE.md exceeds token budget thresholds.
# Runs on SessionStart. Emits LTX rows to stdout, human warnings to stderr.
set -euo pipefail

# LTX emitters: schema header + pipe-delimited rows to stdout, human notes to stderr
ltx_header() { echo "@v1:${1}"; }
ltx_row()    { local IFS='|'; echo "$*"; }
ltx_human()  { echo "$1" >&2; }

readonly WARN_WORDS=600
readonly CRIT_WORDS=1000

# Emit schema header once
ltx_header "file|words|tokens|level"

check_claudemd_size() {
  local file_path="$1"
  local label="$2"

  if [ ! -f "$file_path" ]; then
    return 0
  fi

  local word_count token_estimate level
  # $((...)) strips the leading whitespace macOS wc emits
  word_count=$(( $(wc -w < "$file_path") ))
  token_estimate=$(( word_count * 13 / 10 ))

  if [ "$word_count" -ge "$CRIT_WORDS" ]; then
    level="critical"
    ltx_human "⚠ TOKEN SAVER [CRITICAL]: $label is ${word_count} words (~${token_estimate} tokens). Run /optimize-claudemd"
  elif [ "$word_count" -ge "$WARN_WORDS" ]; then
    level="warn"
    ltx_human "⚠ TOKEN SAVER [WARNING]: $label is ${word_count} words (~${token_estimate} tokens). Consider optimizing."
  else
    level="ok"
  fi

  ltx_row "$file_path" "$word_count" "$token_estimate" "$level"
}

validate_settings_json() {
  local settings_path="$HOME/.claude/settings.json"

  if [ ! -f "$settings_path" ]; then
    ltx_row "$settings_path" "0" "0" "missing"
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    ltx_row "$settings_path" "0" "0" "skipped"
    return 0
  fi

  if ! python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$settings_path" 2>/dev/null; then
    ltx_row "$settings_path" "0" "0" "invalid"
    ltx_human "⚠ TOKEN SAVER: settings.json has invalid JSON. Run /debug-hooks"
  else
    ltx_row "$settings_path" "0" "0" "valid"
  fi
}

# -ef guard: on case-insensitive filesystems (macOS default) CLAUDE.md and
# claude.md are the same file — without it the file is reported twice.
check_claudemd_size "$HOME/.claude/CLAUDE.md" "~/.claude/CLAUDE.md"
if ! [ "$HOME/.claude/claude.md" -ef "$HOME/.claude/CLAUDE.md" ]; then
  check_claudemd_size "$HOME/.claude/claude.md" "~/.claude/claude.md"
fi

if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  check_claudemd_size "$CLAUDE_PROJECT_DIR/CLAUDE.md" "CLAUDE.md (project)"
  if ! [ "$CLAUDE_PROJECT_DIR/claude.md" -ef "$CLAUDE_PROJECT_DIR/CLAUDE.md" ]; then
    check_claudemd_size "$CLAUDE_PROJECT_DIR/claude.md" "claude.md (project)"
  fi
fi

validate_settings_json
