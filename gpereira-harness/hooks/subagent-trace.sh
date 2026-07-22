#!/bin/bash
# SubagentStart + SubagentStop hook: append a JSONL trace of every subagent to
# the context vault, so orchestrator runs are auditable next to the plan.
# Ticket branches log to tickets/<TICKET>/subagents.jsonl; otherwise
# traces/subagents-YYYY-MM-DD.jsonl. State lives in the vault, never the repo.
# Fail-open: any parsing uncertainty logs what it has (or exits 0).

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Resolve the vault via the plugin lib (falls back to the default location so
# the hook still works if CLAUDE_PLUGIN_ROOT is somehow unset).
store="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -x "$store" ]; then
    CTX="$("$store" path 2>/dev/null)"
fi
CTX="${CTX:-${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}}"
[ -n "$CTX" ] || exit 0

event=$(echo "$input" | jq -r '.hook_event_name // empty')
branch=$(git -C "${cwd:-$PWD}" branch --show-current 2>/dev/null)
ticket=$(printf '%s' "$branch" | grep -oiE '[A-Za-z][A-Za-z0-9]*-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]')

if [ -n "$ticket" ]; then
    out="$CTX/tickets/${ticket}/subagents.jsonl"
else
    out="$CTX/traces/subagents-$(date +%Y-%m-%d).jsonl"
fi
mkdir -p "$(dirname "$out")" 2>/dev/null || exit 0

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
atype=$(echo "$input" | jq -r '.agent_type // .subagent_type // empty')
aid=$(echo "$input" | jq -r '.agent_id // .session_id // empty')

if [ "$event" = "SubagentStart" ]; then
    task=$(echo "$input" | jq -r '.prompt // .tool_input.prompt // empty' | head -c 200)
    jq -nc --arg ts "$ts" --arg e start --arg t "$atype" --arg id "$aid" --arg task "$task" --arg br "$branch" \
        '{ts:$ts,event:$e,agent_type:$t,agent_id:$id,task:$task,branch:$br}' >> "$out"
    exit 0
fi

# SubagentStop: mine the transcript for task, duration, tokens, contract result.
# Real subagent transcripts are agent-<id>.jsonl; the harness also fires
# SubagentStop for internal events whose transcript_path is the MAIN session
# transcript — mining that logs whole-session durations/tokens as junk rows,
# so anything that isn't an agent-* transcript is skipped entirely.
transcript=$(echo "$input" | jq -r '.agent_transcript_path // .transcript_path // empty')
case "$(basename "$transcript")" in agent-*.jsonl) ;; *) exit 0 ;; esac
task="" dur="" toks="" status="" summary=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    task=$(head -c 100000 "$transcript" | grep '^{' | jq -r 'select(.type=="user") | .message.content | if type=="array" then (map(select(.type=="text")|.text)|join(" ")) else tostring end' 2>/dev/null | head -n 1 | head -c 200)
    first_ts=$(head -n 5 "$transcript" | jq -r '.timestamp // empty' 2>/dev/null | head -n 1)
    last_ts=$(tail -n 5 "$transcript" | jq -r '.timestamp // empty' 2>/dev/null | tail -n 1)
    if [ -n "$first_ts" ] && [ -n "$last_ts" ]; then
        f=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$(echo "$first_ts" | cut -c1-19)" +%s 2>/dev/null)
        l=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$(echo "$last_ts" | cut -c1-19)" +%s 2>/dev/null)
        [ -n "$f" ] && [ -n "$l" ] && dur=$((l - f))
    fi
    toks=$(head -c 5000000 "$transcript" | grep '^{' | jq -s '[.[] | select(.type=="assistant") | .message.usage.output_tokens // 0] | add' 2>/dev/null)
    final=$(tail -n 400 "$transcript" | grep '^{' | jq -r 'select(.type=="assistant") | .message.content | if type=="array" then (map(select(.type=="text")|.text)|join("\n")) else tostring end' 2>/dev/null | grep -v '^[[:space:]]*$' | tail -n 1)
    if echo "$final" | jq -e 'type=="object"' >/dev/null 2>&1; then
        status=$(echo "$final" | jq -r '.status // empty')
        summary=$(echo "$final" | jq -r '.summary // empty' | head -c 300)
    fi
fi

jq -nc --arg ts "$ts" --arg e stop --arg t "$atype" --arg id "$aid" --arg task "$task" \
    --arg dur "$dur" --arg toks "$toks" --arg st "$status" --arg sum "$summary" --arg br "$branch" --arg tr "$transcript" \
    '{ts:$ts,event:$e,agent_type:$t,agent_id:$id,task:$task,duration_s:($dur|if .=="" then null else tonumber end),output_tokens:($toks|if .=="" or .=="null" then null else tonumber end),status:$st,summary:$sum,branch:$br,transcript:$tr}' >> "$out"
exit 0
