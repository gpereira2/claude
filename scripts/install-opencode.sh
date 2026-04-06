#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MCP_FILE="$REPO_ROOT/mcp.json"
OPENCODE_DIR="$HOME/.config/opencode"
OPENCODE_JSON="$OPENCODE_DIR/opencode.json"

echo "=== OpenCode Config Installer ==="

# Check dependencies
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed." >&2
  echo "Install it: brew install jq (macOS) or sudo apt install jq (Linux)" >&2
  exit 1
fi

if [[ ! -f "$MCP_FILE" ]]; then
  echo "Error: $MCP_FILE not found." >&2
  exit 1
fi

mkdir -p "$OPENCODE_DIR"

# Convert Claude MCP format -> OpenCode MCP format
# Claude: { mcpServers: { name: { command, args } | { type: "http", url } } }
# OpenCode: { mcp: { name: { type: "local"|"remote", command: [cmd, ...args] | url, headers, enabled } } }
OPENCODE_MCP=$(jq '
  .mcpServers | to_entries | map(
    if .value.command then
      # Local server: command + args -> type: local, command: [cmd, ...args]
      {
        key: .key,
        value: {
          type: "local",
          command: ([.value.command] + (.value.args // [])),
          enabled: true
        }
      }
    else
      # Remote/HTTP server: url -> type: remote, url, headers
      {
        key: .key,
        value: {
          type: "remote",
          url: .value.url,
          headers: { "Accept": "application/json, text/event-stream" },
          enabled: true
        }
      }
    end
  ) | from_entries
' "$MCP_FILE")

# OpenCode reads CLAUDE.md natively (Claude Code compatibility).
# Add explicit instructions reference so it also picks up CLAUDE.md from ~/.claude/.
INSTRUCTIONS='["CLAUDE.md"]'

# Build opencode.json — merge with existing if present
if [[ -f "$OPENCODE_JSON" ]]; then
  echo "Merging config into existing $OPENCODE_JSON..."
  EXISTING=$(cat "$OPENCODE_JSON")
  echo "$EXISTING" | jq \
    --argjson mcp "$OPENCODE_MCP" \
    --argjson instructions "$INSTRUCTIONS" \
    '.mcp = ((.mcp // {}) * $mcp) | .instructions = $instructions' > "$OPENCODE_JSON"
else
  echo "Creating $OPENCODE_JSON..."
  jq -n \
    --argjson mcp "$OPENCODE_MCP" \
    --argjson instructions "$INSTRUCTIONS" \
    '{ "$schema": "https://opencode.ai/config.json", instructions: $instructions, mcp: $mcp }' > "$OPENCODE_JSON"
fi

SERVER_COUNT=$(echo "$OPENCODE_MCP" | jq 'length')
echo "OK    $SERVER_COUNT MCP server(s) synced from shared mcp.json"

# --- Symlink plugins directory ---
PLUGINS_SRC="$REPO_ROOT/config/opencode/plugins"
PLUGINS_DST="$OPENCODE_DIR/plugins"

if [[ -d "$PLUGINS_SRC" ]]; then
  if [[ -L "$PLUGINS_DST" ]]; then
    current_target=$(readlink "$PLUGINS_DST")
    if [[ "$current_target" == "$PLUGINS_SRC" ]]; then
      echo "OK    plugins/ (already linked)"
    else
      echo "RELINK plugins/ (was -> $current_target)"
      rm "$PLUGINS_DST"
      ln -s "$PLUGINS_SRC" "$PLUGINS_DST"
      echo "LINK  plugins/ -> $PLUGINS_SRC"
    fi
  elif [[ -d "$PLUGINS_DST" ]]; then
    echo "BACKUP plugins/ -> plugins.bak/"
    mv "$PLUGINS_DST" "$PLUGINS_DST.bak"
    ln -s "$PLUGINS_SRC" "$PLUGINS_DST"
    echo "LINK  plugins/ -> $PLUGINS_SRC"
  else
    ln -s "$PLUGINS_SRC" "$PLUGINS_DST"
    echo "LINK  plugins/ -> $PLUGINS_SRC"
  fi
fi

# --- Symlink tui.json ---
TUI_SRC="$REPO_ROOT/config/opencode/tui.json"
TUI_DST="$OPENCODE_DIR/tui.json"

if [[ -f "$TUI_SRC" ]]; then
  if [[ -L "$TUI_DST" ]]; then
    current_target=$(readlink "$TUI_DST")
    if [[ "$current_target" == "$TUI_SRC" ]]; then
      echo "OK    tui.json (already linked)"
    else
      rm "$TUI_DST"
      ln -s "$TUI_SRC" "$TUI_DST"
      echo "LINK  tui.json -> $TUI_SRC"
    fi
  elif [[ -f "$TUI_DST" ]]; then
    mv "$TUI_DST" "$TUI_DST.bak"
    echo "BACKUP tui.json -> tui.json.bak"
    ln -s "$TUI_SRC" "$TUI_DST"
    echo "LINK  tui.json -> $TUI_SRC"
  else
    ln -s "$TUI_SRC" "$TUI_DST"
    echo "LINK  tui.json -> $TUI_SRC"
  fi
fi

echo ""
echo "Done."
