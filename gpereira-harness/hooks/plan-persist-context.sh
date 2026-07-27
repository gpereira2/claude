#!/bin/bash
# PostToolUse(ExitPlanMode) hook: after a plan is approved, prompt Claude to
# persist the plan and its decisions to the context vault before implementing.
# Vault-resolved via context-store.sh ($CLAUDE_CONTEXT_DIR). Fail-open.
#
# Honours CLAUDE_HARNESS_VAULT_HINTS=0 (see storage-root-hint.sh) — an installer
# that persists plans somewhere project-specific needs one destination, not two.
[ "${CLAUDE_HARNESS_VAULT_HINTS:-1}" = "0" ] && exit 0

input=$(cat)

store="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -x "$store" ]; then
    CTX="$("$store" path 2>/dev/null)"
fi
CTX="${CTX:-${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}}"
[ -n "$CTX" ] || exit 0

cwd=$(echo "$input" | jq -r '.cwd // empty')
branch=$(git -C "${cwd:-$PWD}" branch --show-current 2>/dev/null)
ticket=$(printf '%s' "$branch" | grep -oiE '[A-Za-z][A-Za-z0-9]*-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]')
today=$(date +%Y-%m-%d)

if [ -n "$ticket" ]; then
    dest="${CTX}/tickets/${ticket}/plan.md (create or append — it is the ticket's running context file)"
else
    dest="${CTX}/plans/${today}-<descriptive-slug>.md"
fi

jq -n --arg ctx "Plan approved — before implementing, persist it to ${dest}: the plan itself, key decisions with their rationale, and rejected alternatives. Keep the file updated if the plan changes mid-implementation; it is the durable record for handovers and future sessions, and it lives in the vault, not the repo." \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
exit 0
