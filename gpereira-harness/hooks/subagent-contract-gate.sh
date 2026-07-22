#!/bin/bash
# SubagentStop gate: when a subagent was dispatched under the canonical return
# contract, validate its final message is one line of honest contract JSON.
# Fail-open by design: any uncertainty exits 0 and never blocks.
input=$(cat)
[ "$(echo "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
{ [ -z "$transcript" ] || [ ! -f "$transcript" ]; } && exit 0
head -c 200000 "$transcript" | grep -qi "return contract" || exit 0
texts=$(tail -n 400 "$transcript" | grep '^{' | jq -r 'select(.type=="assistant") | .message.content | if type=="array" then (map(select(.type=="text") | .text) | join("\n")) else tostring end' 2>/dev/null)
final=$(printf '%s\n' "$texts" | grep -v '^[[:space:]]*$' | tail -n 1)
[ -z "$final" ] && exit 0
block() { jq -nc --arg r "$1" '{decision:"block",reason:$r}'; exit 0; }
echo "$final" | jq -e 'type=="object" and (.status|type=="string")' >/dev/null 2>&1 \
  || block "Your dispatch carried the canonical return contract, but the last line of your final message is not valid contract JSON. End with exactly one line of JSON matching the schema in your prompt — no prose after it."
status=$(echo "$final" | jq -r '.status')
case "$status" in ok|partial|blocked|failed|pass|blockers) ;; *) block "Contract status must be one of ok|partial|blocked|failed (got: $status). Correct the final JSON line." ;; esac
changed=$(echo "$final" | jq -r '(.files_changed // []) | length')
ran=$(echo "$final" | jq -r '.tests.ran // false')
if [ "$status" = "ok" ] && [ "$changed" -gt 0 ] && [ "$ran" != "true" ]; then
  block "You report status ok with files changed but tests.ran is not true. Run the verification command, or downgrade status to partial/failed with the reason stated in summary."
fi
if [ "$status" = "failed" ]; then
  ft=$(echo "$final" | jq -r '.tests.failure_tail // empty')
  [ -z "$ft" ] && block "Status failed requires tests.failure_tail to carry the last lines of the failing output as evidence."
fi
exit 0
