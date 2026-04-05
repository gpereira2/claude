#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MCP_FILE="$REPO_ROOT/mcp.json"
CLAUDE_JSON="$HOME/.claude.json"

# Check dependencies
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed." >&2
  echo "Install it: brew install jq (macOS) or sudo apt install jq (Linux)" >&2
  exit 1
fi

# Validate mcp.json exists and has mcpServers
if [[ ! -f "$MCP_FILE" ]]; then
  echo "Error: $MCP_FILE not found." >&2
  exit 1
fi

if ! jq -e '.mcpServers' "$MCP_FILE" &>/dev/null; then
  echo "Error: $MCP_FILE missing mcpServers key." >&2
  exit 1
fi

# Create ~/.claude.json if it doesn't exist
if [[ ! -f "$CLAUDE_JSON" ]]; then
  echo '{}' > "$CLAUDE_JSON"
fi

# Merge: repo mcp.json mcpServers into ~/.claude.json
# Existing entries in ~/.claude.json are preserved; repo entries override on conflict
MERGED=$(jq -s '
  .[0] as $claude |
  .[1].mcpServers as $repo_servers |
  $claude | .mcpServers = ((.mcpServers // {}) * $repo_servers)
' "$CLAUDE_JSON" "$MCP_FILE")

echo "$MERGED" > "$CLAUDE_JSON"

SERVERS_COUNT=$(jq '.mcpServers | length' "$MCP_FILE")
echo "Merged $SERVERS_COUNT MCP server(s) from mcp.json into $CLAUDE_JSON"
