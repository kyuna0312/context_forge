#!/usr/bin/env bash
# ltx.sh — LTX (Low Token eXchange Format) v1 encoding library
# Source this file to get ltx_header, ltx_row, ltx_human functions.
# LTX spec: schema-based, row-oriented, pipe-delimited, minimal delimiters.
#
# Usage:
#   source "$CLAUDE_PLUGIN_ROOT/scripts/ltx.sh"
#   ltx_header "file|words|tokens|level"
#   ltx_row "$file" "$words" "$tokens" "$level"
#   ltx_human "⚠ Warning message for humans"

# ltx_header: emit schema line to stdout
# Args: schema fields as a single pipe-separated string
# Example: ltx_header "file|words|tokens|level"
ltx_header() {
  echo "@v1:${1}"
}

# ltx_row: emit one data row to stdout
# Args: each field as a separate argument
# Example: ltx_row "~/.claude/CLAUDE.md" "850" "1105" "critical"
ltx_row() {
  local IFS='|'
  echo "$*"
}

# ltx_human: emit human-readable message to stderr
# Args: message string
# Example: ltx_human "⚠ TOKEN SAVER [CRITICAL]: file is 850 words"
ltx_human() {
  echo "$1" >&2
}
