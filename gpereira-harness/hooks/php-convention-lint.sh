#!/usr/bin/env bash
# PostToolUse(Write|Edit) hook: warns on two PHP/Laravel house conventions that
# static analysers and style fixers do not cover, because both are project
# policy rather than correctness:
#   1. Log:: messages without a bracketed [Context] prefix (grep/APM traceability).
#   2. Static job dispatch, which hides constructor args from argument-type analysis.
#
# Opt-in (CLAUDE_HARNESS_PHP_LINT=1) and off by default — these are one project's
# conventions, not universal PHP, so it must never fire in a codebase that has
# not asked for it. Advisory only: reports via additionalContext, never blocks.
[ "${CLAUDE_HARNESS_PHP_LINT:-0}" = "1" ] || exit 0

input=$(cat)

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
case "$file" in
    *.php) ;;
    *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

logs=$(grep -nE "Log::(info|warning|error|debug|notice|critical|alert|emergency)\([[:space:]]*['\"][^[]" "$file" 2>/dev/null) || true
jobs=$(grep -nE "[A-Z][A-Za-z0-9_]*Job::dispatch\(" "$file" 2>/dev/null) || true

[ -z "$logs" ] && [ -z "$jobs" ] && exit 0

report=""
if [ -n "$logs" ]; then
    report="Log:: call(s) without a bracketed [Context] prefix — prefix the message with [ClassName] or [ClassName::method] so log searches can pinpoint the source:
${logs}"
fi
if [ -n "$jobs" ]; then
    [ -n "$report" ] && report="${report}

"
    report="${report}Static job dispatch — use dispatch(new SomeJob(...)) or Bus::dispatchSync(new SomeJob(...)) so constructor arguments stay explicit and analysable:
${jobs}"
fi

jq -n --arg ctx "Convention check on ${file} — fix before moving on:

${report}" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
exit 0
