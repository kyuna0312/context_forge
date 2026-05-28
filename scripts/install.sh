#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_NAME="context-forge"
CLAUDE_PLUGINS_DIR="${HOME}/.claude/plugins"

echo "Installing $PLUGIN_NAME..."

# Option A: symlink into Claude plugins directory (preferred)
mkdir -p "$CLAUDE_PLUGINS_DIR"

if [ -L "${CLAUDE_PLUGINS_DIR}/${PLUGIN_NAME}" ]; then
  echo "Removing existing symlink..."
  rm "${CLAUDE_PLUGINS_DIR}/${PLUGIN_NAME}"
fi

if [ -d "${CLAUDE_PLUGINS_DIR}/${PLUGIN_NAME}" ]; then
  echo "Warning: ${CLAUDE_PLUGINS_DIR}/${PLUGIN_NAME} already exists as a directory."
  echo "Remove it manually and re-run, or use --plugin-dir instead:"
  echo "  claude --plugin-dir $PLUGIN_DIR"
  exit 1
fi

ln -s "$PLUGIN_DIR" "${CLAUDE_PLUGINS_DIR}/${PLUGIN_NAME}"
echo "Linked: ${CLAUDE_PLUGINS_DIR}/${PLUGIN_NAME} -> $PLUGIN_DIR"

# Install statusline script
STATUSLINE_SRC="$PLUGIN_DIR/scripts/statusline-command.sh"
STATUSLINE_DEST="${HOME}/.claude/statusline-command.sh"
if [ -f "$STATUSLINE_SRC" ]; then
  cp "$STATUSLINE_SRC" "$STATUSLINE_DEST"
  chmod +x "$STATUSLINE_DEST"
  echo "Installed statusline: $STATUSLINE_DEST"
fi

echo ""
echo "Done! Plugin '$PLUGIN_NAME' installed."
echo "Start Claude Code with: claude"
echo "Or use in place: claude --plugin-dir $PLUGIN_DIR"
