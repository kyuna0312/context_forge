#!/usr/bin/env bash
# token-status.sh: Status line script showing context window + CLAUDE.md token cost
# Output: single colored line for Claude Code status line
# Input: JSON from stdin (Claude Code status line protocol)
#
# Usage in ~/.claude/settings.json:
#   "statusLine": {
#     "type": "command",
#     "command": "bash /path/to/token-status.sh",
#     "refreshInterval": 30
#   }

input=$(cat)

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN="\033[38;2;157;255;204m"    # mint green — healthy
YELLOW="\033[38;2;255;217;125m"   # gold — warning
ORANGE="\033[38;2;255;179;100m"   # orange — elevated
RED="\033[38;2;255;120;120m"      # red — critical
MUTED="\033[38;2;196;176;216m"    # muted purple — labels
RESET="\033[0m"

# ── Extract all JSON fields in one python3 call ───────────────────────────────
read -r used_pct cwd rl_pct <<< "$(echo "$input" | python3 -c "
import json, sys
d = json.load(sys.stdin)
cw = d.get('context_window', {})
w = d.get('workspace', {})
rl = d.get('rate_limits', {}).get('5h', {})
print(
    cw.get('used_percentage', ''),
    w.get('current_dir', d.get('cwd', '')),
    rl.get('used_percentage', '')
)
" 2>/dev/null || echo "  ")"

# ── Context window bar ────────────────────────────────────────────────────────
ctx_bar=""
ctx_color="$GREEN"

if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")

  # Pick color based on usage
  if [ "$used_int" -ge 90 ]; then
    ctx_color="$RED"
  elif [ "$used_int" -ge 75 ]; then
    ctx_color="$ORANGE"
  elif [ "$used_int" -ge 50 ]; then
    ctx_color="$YELLOW"
  fi

  # Build mini bar: 10-char wide
  filled=$(( used_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty);  do bar="${bar}░"; done

  ctx_bar="${ctx_color}ctx [${bar}] ${used_int}%${RESET}"
fi

# ── CLAUDE.md token estimate ──────────────────────────────────────────────────
md_tokens=""

count_words_tokens() {
  local f="$1"
  if [ -f "$f" ]; then
    words=$(wc -w < "$f" 2>/dev/null || echo 0)
    tokens=$(echo "$words * 13 / 10" | bc 2>/dev/null || echo 0)
    echo "$tokens"
  else
    echo 0
  fi
}

global_tokens=$(count_words_tokens "$HOME/.claude/CLAUDE.md")
project_tokens=0
if [ -n "$cwd" ] && [ -f "$cwd/CLAUDE.md" ]; then
  project_tokens=$(count_words_tokens "$cwd/CLAUDE.md")
fi

total_md=$(( global_tokens + project_tokens ))

if [ "$total_md" -gt 0 ]; then
  md_color="$GREEN"
  if [ "$total_md" -ge 1300 ]; then
    md_color="$RED"
  elif [ "$total_md" -ge 780 ]; then
    md_color="$ORANGE"
  elif [ "$total_md" -ge 390 ]; then
    md_color="$YELLOW"
  fi
  md_tokens="${MUTED}md:${RESET}${md_color}~${total_md}t${RESET}"
fi

# ── Rate limit (if available) ─────────────────────────────────────────────────
rate_part=""
if [ -n "$rl_pct" ]; then
  rl_int=$(printf "%.0f" "$rl_pct")
  if [ "$rl_int" -ge 70 ]; then
    rl_color="$YELLOW"
    [ "$rl_int" -ge 90 ] && rl_color="$RED"
    rate_part=" ${MUTED}rate:${RESET}${rl_color}${rl_int}%${RESET}"
  fi
fi

# ── Assemble output ───────────────────────────────────────────────────────────
parts=()
[ -n "$ctx_bar" ]    && parts+=("$ctx_bar")
[ -n "$md_tokens" ]  && parts+=("$md_tokens")
[ -n "$rate_part" ]  && parts+=("$rate_part")

if [ ${#parts[@]} -gt 0 ]; then
  # Join with space separator
  output=""
  for part in "${parts[@]}"; do
    [ -n "$output" ] && output="${output} ${MUTED}│${RESET} "
    output="${output}${part}"
  done
  printf "%s\n" "$output"
fi
