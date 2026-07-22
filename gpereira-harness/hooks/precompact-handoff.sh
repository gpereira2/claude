#!/bin/bash
# PreCompact hook: snapshot in-flight session state to a session-keyed handoff
# file before compaction. The matching SessionStart hook (sessionstart-handoff.sh)
# re-injects it on resume/compact. PreCompact stdout is NOT injected as context,
# so persistence to disk is the only channel.

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

[ -n "$session_id" ] && [ -f "$transcript" ] || exit 0

dir="$HOME/.claude/handoff"
mkdir -p "$dir"
out="$dir/$session_id.md"

branch=$(git -C "${cwd:-.}" symbolic-ref --short HEAD 2>/dev/null || echo "n/a")

extract() { # $1=type $2=count $3=char cap per message
  jq -r --arg t "$1" '
    select(.type==$t) | .message.content |
    if type=="array" then [.[] | select(.type=="text") | .text] | join(" ") else . end |
    select(length>0)' "$transcript" 2>/dev/null \
    | grep -v '^<' | tail -n "$2" | cut -c1-"$3"
}

{
  echo "# Pre-compaction session snapshot"
  echo "Generated: $(date '+%Y-%m-%d %H:%M') | cwd: ${cwd:-?} | branch: $branch"
  echo
  echo "## Recent user messages (oldest first)"
  extract user 15 500
  echo
  echo "## Recent assistant activity (oldest first)"
  extract assistant 10 300
} > "$out"

# Prune handoff files older than 7 days
find "$dir" -name '*.md' -mtime +7 -delete 2>/dev/null

exit 0
