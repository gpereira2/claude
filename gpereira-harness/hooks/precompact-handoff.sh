#!/bin/bash
# PreCompact hook: snapshot in-flight session state to a session-keyed handoff
# file before compaction. The matching SessionStart hook (sessionstart-handoff.sh)
# re-injects it on resume/compact. PreCompact stdout is NOT injected as context,
# so persistence to disk is the only channel.
#
# This is the AUTOMATIC, mechanical tier of the handoff system — a shell hook has
# no model, so it can only dump raw transcript. The curated tier is the `handoff`
# skill, which synthesises a handoff doc and can seed itself from this snapshot.
# Both live under one vault folder: auto snapshots in handoffs/auto/, curated
# handoffs in handoffs/. Fail-open and side-effect-light — never run vault init here.

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

[ -n "$session_id" ] && [ -f "$transcript" ] || exit 0

# Resolve the vault the same way the skill does; fall back without init side effects.
STORE="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -x "$STORE" ]; then CTX="$("$STORE" path 2>/dev/null)"; fi
CTX="${CTX:-${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}}"
dir="$CTX/handoffs/auto"
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
  echo "---"
  echo "title: Pre-compaction snapshot ($session_id)"
  echo "type: handoff-auto"
  echo "tags: [handoff, auto]"
  echo "---"
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
