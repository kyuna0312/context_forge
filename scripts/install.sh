#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_NAME="context_forge"
CLAUDE_PLUGINS_DIR="${HOME}/.claude/plugins"

echo "Installing $PLUGIN_NAME..."

# Warn (don't fail) about missing runtime deps — hooks need these at session start.
if ! command -v node >/dev/null 2>&1; then
  echo "Warning: node not found — the record-change hook and forge MCP server won't run."
elif [ "$(node -p 'parseInt(process.versions.node)')" -lt 18 ]; then
  echo "Warning: node $(node -v) found, but >=18 is required for the MCP server."
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Warning: python3 not found — settings.json validation in the session-start hook will be skipped."
fi

# Option A: symlink into Claude plugins directory (preferred)
mkdir -p "$CLAUDE_PLUGINS_DIR"

if [ -L "${CLAUDE_PLUGINS_DIR}/${PLUGIN_NAME}" ]; then
  echo "Removing existing symlink (-> $(readlink "${CLAUDE_PLUGINS_DIR}/${PLUGIN_NAME}"))..."
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

# Install statusline script — never silently clobber a user-modified copy
STATUSLINE_SRC="$PLUGIN_DIR/scripts/statusline-command.sh"
STATUSLINE_DEST="${HOME}/.claude/statusline-command.sh"
if [ -f "$STATUSLINE_SRC" ]; then
  if [ -f "$STATUSLINE_DEST" ] && cmp -s "$STATUSLINE_SRC" "$STATUSLINE_DEST"; then
    echo "Statusline already up to date: $STATUSLINE_DEST"
  else
    if [ -f "$STATUSLINE_DEST" ]; then
      backup="${STATUSLINE_DEST}.backup.$(date +%Y%m%d-%H%M%S)"
      cp "$STATUSLINE_DEST" "$backup"
      echo "Existing statusline differs — backed up to $backup"
    fi
    cp "$STATUSLINE_SRC" "$STATUSLINE_DEST"
    chmod +x "$STATUSLINE_DEST"
    echo "Installed statusline: $STATUSLINE_DEST"
  fi
fi

echo ""
echo "Done! Plugin '$PLUGIN_NAME' installed."
echo "Start Claude Code with: claude"
echo "Or use in place: claude --plugin-dir $PLUGIN_DIR"
echo ""
echo "Optional — forge half (DB-backed scaffolding):"
echo "  cd $PLUGIN_DIR/mcp && npm install"
echo "  export FORGE_DATABASE_URL=postgres://..."
echo "  psql \"\$FORGE_DATABASE_URL\" -f $PLUGIN_DIR/mcp/db/schema.sql"
