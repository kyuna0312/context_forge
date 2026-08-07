#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_NAME="context_forge"
LINK="${HOME}/.claude/plugins/${PLUGIN_NAME}"
STATUSLINE="${HOME}/.claude/statusline-command.sh"

if [ -L "$LINK" ]; then
  rm "$LINK"
  echo "Removed symlink: $LINK"
else
  echo "No symlink at $LINK — nothing to remove."
fi

# Only remove the statusline copy if it is ours (unchanged since install)
if [ -f "$STATUSLINE" ] && cmp -s "$STATUSLINE" "$PLUGIN_DIR/scripts/statusline-command.sh"; then
  rm "$STATUSLINE"
  echo "Removed statusline: $STATUSLINE"
fi

echo "Done. Plugin '$PLUGIN_NAME' uninstalled."
