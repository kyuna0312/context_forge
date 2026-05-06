#!/usr/bin/env bash
# Claude Code status line — Lucy Edgerunner palette
# Reads JSON from stdin, outputs a single status line.

input=$(cat)

# ── Colors (Lucy Edgerunner palette) ──────────────────────────────────────────
lavender="\033[38;2;200;165;255m"   # #c8a5ff  — lavender
gold="\033[38;2;255;217;125m"       # #ffd97d  — gold
mint="\033[38;2;157;255;204m"       # #9dffcc  — mint
muted="\033[38;2;196;176;216m"      # #c4b0d8  — muted
peach="\033[38;2;255;179;160m"      # #ffb3a0  — peach
reset="\033[0m"
ctx_green="\033[38;2;157;255;204m"
ctx_yellow="\033[38;2;255;217;125m"
ctx_orange="\033[38;2;255;179;100m"
ctx_red="\033[38;2;255;120;120m"

# ── Extract fields ─────────────────────────────────────────────────────────────
read -r cwd model used_pct rl_pct <<< "$(echo "$input" | python3 -c "
import json, sys
d = json.load(sys.stdin)
w = d.get('workspace', {})
cw = d.get('context_window', {})
rl = d.get('rate_limits', {}).get('5h', {})
print(
    w.get('current_dir', d.get('cwd', '')),
    d.get('model', {}).get('display_name', ''),
    cw.get('used_percentage', ''),
    rl.get('used_percentage', '')
)
" 2>/dev/null || echo "   ")"

# ── Directory: collapse $HOME to ~ and trim to last 3 components ───────────────
home_dir="${HOME:-/root}"
short_dir="${cwd/#$home_dir/\~}"
# Keep at most 3 path segments
short_dir=$(echo "$short_dir" | awk -F'/' '{
  n = NF; start = (n > 3) ? n - 2 : 1;
  out = "";
  if (n > 3) out = "…/";
  for (i = start; i <= n; i++) { out = out $i; if (i < n) out = out "/"; }
  print out
}')

# ── Git branch ────────────────────────────────────────────────────────────────
branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && branch=" $branch"
fi

# ── Context usage bar ─────────────────────────────────────────────────────────
ctx_part=""
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  ctx_color="$ctx_green"
  [ "$used_int" -ge 50 ] && ctx_color="$ctx_yellow"
  [ "$used_int" -ge 75 ] && ctx_color="$ctx_orange"
  [ "$used_int" -ge 90 ] && ctx_color="$ctx_red"
  filled=$(( used_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty);  do bar="${bar}░"; done
  ctx_part="${ctx_color}ctx [${bar}] ${used_int}%${reset}"
fi

# ── CLAUDE.md token estimate ──────────────────────────────────────────────────
md_part=""
count_tokens() { local f="$1"; [ -f "$f" ] && echo "$(( $(wc -w < "$f") * 13 / 10 ))" || echo 0; }
total_md=$(( $(count_tokens "$HOME/.claude/CLAUDE.md") + $(count_tokens "$cwd/CLAUDE.md") ))
if [ "$total_md" -gt 0 ]; then
  md_color="$ctx_green"
  [ "$total_md" -ge 390  ] && md_color="$ctx_yellow"
  [ "$total_md" -ge 780  ] && md_color="$ctx_orange"
  [ "$total_md" -ge 1300 ] && md_color="$ctx_red"
  md_part="${muted}md:${reset}${md_color}~${total_md}t${reset}"
fi

# ── Rate limit (if available) ─────────────────────────────────────────────────
rl_part=""
if [ -n "$rl_pct" ] && [ "$rl_pct" != "" ]; then
  rl_int=$(printf "%.0f" "$rl_pct" 2>/dev/null || echo 0)
  if [ "$rl_int" -ge 70 ]; then
    rl_color="$ctx_yellow"
    [ "$rl_int" -ge 90 ] && rl_color="$ctx_red"
    rl_part="${muted}rate:${reset}${rl_color}${rl_int}%${reset}"
  fi
fi

# ── Assemble line ─────────────────────────────────────────────────────────────
printf "%b" "${lavender}${short_dir}${reset}"
[ -n "$branch" ] && printf "%b" "${muted}${branch}${reset}"
[ -n "$model" ]  && printf "%b" " ${gold}${model}${reset}"
[ -n "$ctx_part" ] && printf "%b" " ${muted}│${reset} ${ctx_part}"
[ -n "$md_part"  ] && printf "%b" " ${muted}│${reset} ${md_part}"
[ -n "$rl_part"  ] && printf "%b" " ${muted}│${reset} ${rl_part}"
printf "\n"
