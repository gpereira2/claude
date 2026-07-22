#!/bin/bash
# Render a markdown summary table from a subagent trace JSONL.
# Usage: subagent-trace-summary.sh [file]
# With no argument, resolves the current context's trace the same way the trace
# hook does (ticket branch → tickets/<TICKET>/subagents.jsonl in the vault,
# else today's traces/subagents-YYYY-MM-DD.jsonl).

file="$1"
if [ -z "$file" ]; then
    store="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -x "$store" ]; then
        CTX="$("$store" path 2>/dev/null)"
    fi
    CTX="${CTX:-${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}}"
    branch=$(git branch --show-current 2>/dev/null)
    ticket=$(printf '%s' "$branch" | grep -oiE '[A-Za-z][A-Za-z0-9]*-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]')
    if [ -n "$ticket" ] && [ -f "$CTX/tickets/${ticket}/subagents.jsonl" ]; then
        file="$CTX/tickets/${ticket}/subagents.jsonl"
    else
        file="$CTX/traces/subagents-$(date +%Y-%m-%d).jsonl"
    fi
fi
[ -f "$file" ] || { echo "No trace file at $file" >&2; exit 1; }

echo "# Subagent trace — $(basename "$file")"
echo
echo "| Time (UTC) | Agent | Status | Duration | Out tokens | Task | Summary |"
echo "|---|---|---|---|---|---|---|"
grep '^{' "$file" | jq -r 'select(.event=="stop") |
    [ (.ts | split("T")[1] | rtrimstr("Z")),
      (.agent_type // "?"),
      (.status // "?"),
      (if .duration_s then "\(.duration_s)s" else "?" end),
      (.output_tokens // "?" | tostring),
      ((.task // "") | gsub("[\\n|]"; " ") | .[0:70]),
      ((.summary // "") | gsub("[\\n|]"; " ") | .[0:100])
    ] | "| " + join(" | ") + " |"'
echo
total=$(grep -c '"event":"stop"' "$file")
toks=$(grep '^{' "$file" | jq -s '[.[] | select(.event=="stop") | .output_tokens // 0] | add')
echo "**${total} subagents, ~${toks} output tokens total.**"
