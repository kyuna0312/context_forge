#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_NAME="context_guard"

echo "Installing $PLUGIN_NAME..."

# Check claude CLI exists
if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found. Install Claude Code first: https://claude.ai/code"
  exit 1
fi

# Remove existing plugin install if present
claude plugin remove "$PLUGIN_NAME" 2>/dev/null && echo "Removed existing plugin." || true

# Remove stale local marketplace if present
claude plugin marketplace remove "$PLUGIN_NAME" 2>/dev/null && echo "Removed stale marketplace." || true

# Register this directory as a local marketplace
echo "Registering local marketplace at $PLUGIN_DIR ..."
claude plugin marketplace add "$PLUGIN_DIR"

# Install the plugin from the local marketplace
claude plugin install "${PLUGIN_NAME}@${PLUGIN_NAME}"

echo ""
echo "Done! Plugin '$PLUGIN_NAME' installed."
echo "Restart Claude Code to activate hooks and skills."
