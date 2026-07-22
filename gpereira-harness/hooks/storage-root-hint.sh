#!/bin/bash
# SessionStart + SubagentStart hook: inject the canonical storage root — the
# harness context vault ($CLAUDE_CONTEXT_DIR, resolved via context-store.sh) —
# so generated docs (plans, notes, investigations) and traces are saved there,
# in the per-user vault, never scattered in the project repo. Fail-open.

input=$(cat)
event=$(echo "$input" | jq -r '.hook_event_name // "SessionStart"')

store="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -x "$store" ]; then
    CTX="$("$store" path 2>/dev/null)"
fi
CTX="${CTX:-${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}}"
[ -n "$CTX" ] || exit 0

msg="[storage root] Canonical document + state root: ${CTX} (the harness context vault). Save ALL generated docs (plans, tickets, investigations, notes) and subagent traces there — plans/, tickets/<TICKET>/, spikes/, traces/ — never in the project repo, which is for shipping code only."

if [ "$event" = "SessionStart" ]; then
    printf '%s\n' "$msg"
else
    jq -nc --arg e "$event" --arg m "$msg" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$m}}'
fi
exit 0
