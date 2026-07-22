#!/bin/bash
# SessionStart hook (matcher: resume|compact): re-inject the pre-compaction
# snapshot written by precompact-handoff.sh. SessionStart stdout is added to
# context automatically.

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
f="$HOME/.claude/handoff/$session_id.md"

if [ -n "$session_id" ] && [ -f "$f" ]; then
  echo "Pre-compaction state snapshot (from PreCompact handoff hook — use to re-anchor on the in-flight task):"
  cat "$f"
fi
exit 0
