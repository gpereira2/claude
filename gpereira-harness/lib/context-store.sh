#!/usr/bin/env bash
# context-store.sh — resolve and manage the harness context folder.
#
# Location precedence:
#   1. $CLAUDE_CONTEXT_DIR   (user override)
#   2. ~/.claude/context     (default)
#
# The context folder holds per-ticket state (ticket.json + plan.md and notes).
# All markdown written here is Obsidian-compatible:
#   - YAML frontmatter delimited by --- ... ---
#   - [[wikilinks]] resolve within the vault (the context dir IS the vault)
#   - relative paths only; no absolute machine paths baked into notes
#   - JSON is fenced as ```json so it renders in Obsidian preview
#
# Usage:
#   context-store.sh path                 # print resolved context dir
#   context-store.sh init                 # create dir + .obsidian marker + index
#   context-store.sh ticket-dir TICKET    # print/create per-ticket subdir

set -euo pipefail

context_dir() {
  printf '%s' "${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}"
}

init_store() {
  local dir; dir="$(context_dir)"
  mkdir -p "$dir/tickets"
  # Obsidian treats any folder with a .obsidian dir as a vault root.
  mkdir -p "$dir/.obsidian"
  if [ ! -f "$dir/index.md" ]; then
    cat > "$dir/index.md" <<'EOF'
---
title: Claude Harness Context
type: index
tags: [claude, harness, index]
---

# Context Vault

This vault is the harness context store. Per-ticket state lives under
`tickets/`. Each ticket folder contains an Obsidian-compatible `ticket.md`
(frontmatter + embedded JSON) and a `plan.md`.

## Tickets

_Auto-listed as tickets are created — see the `tickets/` folder._
EOF
  fi
  printf '%s\n' "$dir"
}

ticket_dir() {
  local ticket="$1"
  [ -n "$ticket" ] || { echo "ticket-dir: TICKET required" >&2; exit 1; }
  local dir; dir="$(context_dir)/tickets/$ticket"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

cmd="${1:-path}"
case "$cmd" in
  path)       context_dir; echo ;;
  init)       init_store ;;
  ticket-dir) ticket_dir "${2:-}" ;;
  *)          echo "unknown command: $cmd" >&2; exit 1 ;;
esac
