#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_ROOT/config"
CLAUDE_DIR="$HOME/.claude"

# Tracked files to symlink from config/ into ~/.claude/
SYMLINK_FILES=(
  CLAUDE.md
  settings.json
  keybindings.json
  statusline-command.sh
)

# Tracked directories to symlink from config/ into ~/.claude/
SYMLINK_DIRS=(
  agents
  skills
)

echo "=== Claude Code Config Installer ==="
echo "Source: $CONFIG_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# Ensure ~/.claude exists
mkdir -p "$CLAUDE_DIR"

# --- Symlink files ---
for file in "${SYMLINK_FILES[@]}"; do
  src="$CONFIG_DIR/$file"
  dst="$CLAUDE_DIR/$file"

  if [[ ! -f "$src" ]]; then
    echo "SKIP  $file (not found in repo)"
    continue
  fi

  if [[ -L "$dst" ]]; then
    current_target=$(readlink "$dst")
    if [[ "$current_target" == "$src" ]]; then
      echo "OK    $file (already linked)"
      continue
    fi
    echo "RELINK $file (was -> $current_target)"
    rm "$dst"
  elif [[ -f "$dst" ]]; then
    echo "BACKUP $file -> $file.bak"
    mv "$dst" "$dst.bak"
  fi

  ln -s "$src" "$dst"
  echo "LINK  $file -> $src"
done

# --- Symlink directories ---
for dir in "${SYMLINK_DIRS[@]}"; do
  src="$CONFIG_DIR/$dir"
  dst="$CLAUDE_DIR/$dir"

  if [[ ! -d "$src" ]]; then
    echo "SKIP  $dir/ (not found in repo)"
    continue
  fi

  if [[ -L "$dst" ]]; then
    current_target=$(readlink "$dst")
    if [[ "$current_target" == "$src" ]]; then
      echo "OK    $dir/ (already linked)"
      continue
    fi
    echo "RELINK $dir/ (was -> $current_target)"
    rm "$dst"
  elif [[ -d "$dst" ]]; then
    echo "BACKUP $dir/ -> $dir.bak/"
    mv "$dst" "$dst.bak"
  fi

  ln -s "$src" "$dst"
  echo "LINK  $dir/ -> $src"
done

# --- Merge local overrides into settings.json ---
LOCAL_SETTINGS="$CONFIG_DIR/settings.local.json"
if [[ -f "$LOCAL_SETTINGS" ]]; then
  if command -v jq &>/dev/null; then
    echo ""
    echo "Merging settings.local.json overrides..."
    MERGED=$(jq -s '.[0] * .[1]' "$CONFIG_DIR/settings.json" "$LOCAL_SETTINGS")
    # Write merged result to ~/.claude/settings.json (replacing the symlink with a file)
    rm -f "$CLAUDE_DIR/settings.json"
    echo "$MERGED" > "$CLAUDE_DIR/settings.json"
    echo "OK    settings.json (merged with local overrides)"
  else
    echo ""
    echo "WARN  jq not installed — skipping settings.local.json merge"
    echo "      Install: brew install jq"
  fi
fi

# --- Merge MCP servers ---
echo ""
bash "$SCRIPT_DIR/merge-mcp.sh"

echo ""
echo "Done. Review any .bak files if you need to recover previous config."
