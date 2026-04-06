#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================="
echo "  Claude Config — Full Install"
echo "=================================="
echo ""

# --- Claude Code ---
echo "--- Claude Code ---"
bash "$SCRIPT_DIR/scripts/install.sh"
echo ""

# --- OpenCode ---
echo "--- OpenCode ---"
bash "$SCRIPT_DIR/scripts/install-opencode.sh"
echo ""

echo "=================================="
echo "  All done."
echo "=================================="
