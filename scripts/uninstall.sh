#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_NAME="context_forge"
STATUSLINE="${HOME}/.claude/statusline-command.sh"

if command -v claude >/dev/null 2>&1; then
  claude plugin uninstall "$PLUGIN_NAME@$PLUGIN_NAME" 2>/dev/null \
    && echo "Uninstalled plugin: $PLUGIN_NAME@$PLUGIN_NAME" \
    || echo "Plugin not installed — nothing to uninstall."
  claude plugin marketplace remove "$PLUGIN_NAME" 2>/dev/null \
    && echo "Removed marketplace: $PLUGIN_NAME" \
    || true
fi

# Legacy symlink from older installs
if [ -L "$HOME/.claude/plugins/$PLUGIN_NAME" ]; then
  rm "$HOME/.claude/plugins/$PLUGIN_NAME"
  echo "Removed legacy symlink: ~/.claude/plugins/$PLUGIN_NAME"
fi

# Only remove the statusline copy if it is ours (unchanged since install)
if [ -f "$STATUSLINE" ] && cmp -s "$STATUSLINE" "$PLUGIN_DIR/scripts/statusline-command.sh"; then
  rm "$STATUSLINE"
  echo "Removed statusline: $STATUSLINE"
fi

echo "Done. Plugin '$PLUGIN_NAME' uninstalled."
