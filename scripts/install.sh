#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_NAME="context_forge"

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

# Register + install through the plugin marketplace. A bare symlink under
# ~/.claude/plugins is NOT discovered by current Claude Code.
if ! command -v claude >/dev/null 2>&1; then
  echo "Error: claude CLI not found. Install Claude Code first, then re-run," >&2
  echo "or load the plugin in place: claude --plugin-dir $PLUGIN_DIR" >&2
  exit 1
fi

# add/install exit 0 even when already present, so update must run
# unconditionally — that's what refreshes the snapshot on re-runs.
# NOTE: updates are version-driven; bump .claude-plugin/*.json versions
# for local changes to propagate.
claude plugin marketplace add "$PLUGIN_DIR" 2>/dev/null || true
claude plugin marketplace update "$PLUGIN_NAME"
claude plugin install "$PLUGIN_NAME@$PLUGIN_NAME" 2>/dev/null || true
claude plugin update "$PLUGIN_NAME@$PLUGIN_NAME"

# Clean up the legacy symlink older versions of this script created — it was
# never discovered as a plugin.
if [ -L "$HOME/.claude/plugins/$PLUGIN_NAME" ]; then
  rm "$HOME/.claude/plugins/$PLUGIN_NAME"
  echo "Removed legacy symlink: ~/.claude/plugins/$PLUGIN_NAME"
fi

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
echo "Done! Plugin '$PLUGIN_NAME' installed (restart Claude Code to load it)."
echo "The install is a snapshot — after pulling repo updates, re-run this script."
echo ""
echo "Optional — forge half (DB-backed scaffolding):"
echo "  cd $PLUGIN_DIR/mcp && npm install"
echo "  export FORGE_DATABASE_URL=postgres://..."
echo "  psql \"\$FORGE_DATABASE_URL\" -f $PLUGIN_DIR/mcp/db/schema.sql"
