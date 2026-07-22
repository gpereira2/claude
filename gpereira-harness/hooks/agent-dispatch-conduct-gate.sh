#!/bin/bash
# PreToolUse(Task) gate: a dispatch that carries a return contract must also
# embed the worker-conduct block. Silent (exit 0, no output) in the pass case
# so normal permission flow is untouched. PreToolUse uses the hookSpecificOutput
# / permissionDecision contract (not the {decision,reason} shape).
input=$(cat)
prompt=$(echo "$input" | jq -r '.tool_input.prompt // empty')
[ -z "$prompt" ] && exit 0
if echo "$prompt" | grep -qiE "return contract" && ! echo "$prompt" | grep -qi "conduct"; then
  jq -nc '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"This dispatch carries a return contract but no conduct block. Embed the worker-conduct block from the agent-selector skill (\"Worker conduct block — embed verbatim in every dispatch\") immediately before the return contract, then retry."}}'
fi
exit 0
