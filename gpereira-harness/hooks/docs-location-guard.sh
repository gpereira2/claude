#!/bin/bash
# PreToolUse(Write) guard — OPT-IN (set CLAUDE_HARNESS_DOCS_GUARD=1 to enable).
# When enabled, redirects NEW generated markdown that Claude tries to write into
# the project repo toward the context vault instead — keeping working notes and
# plans out of the shipping repo. Deny-with-reason is self-correcting: Claude
# retries at the vault path. Off by default so it never fights legitimate repo
# docs. Existing files, allowlisted docs, and paths outside the project pass
# through silently. Fail-open.

[ "${CLAUDE_HARNESS_DOCS_GUARD:-0}" = "1" ] || exit 0

input=$(cat)
fp=$(echo "$input" | jq -r '.tool_input.file_path // empty')
case "$fp" in *.md) ;; *) exit 0 ;; esac

proj="${CLAUDE_PROJECT_DIR:-}"
[ -n "$proj" ] || exit 0
case "$fp" in "$proj"/*) ;; *) exit 0 ;; esac   # outside the project (vault, scratchpad) — fine
[ -f "$fp" ] && exit 0                           # editing an existing doc — fine

rel="${fp#"$proj"/}"
case "$rel" in
    docs/*|.claude/*|documentation/*) exit 0 ;;   # legitimate repo doc locations
esac
case "$(basename "$fp")" in
    README.md|readme.md|CLAUDE.md|CLAUDE.local.md|AGENT.md|AGENTS.md|CHANGELOG.md|CONTRIBUTING.md|LICENSE.md) exit 0 ;;
esac

store="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -x "$store" ]; then
    CTX="$("$store" path 2>/dev/null)"
fi
CTX="${CTX:-${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}}"

jq -n --arg rel "$rel" --arg ctx "$CTX" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("Generated document \($rel) should live in the context vault, not the project repo. Retry the Write under \($ctx)/ — plans/, spikes/, investigations/, or tickets/<TICKET>/ — named YYYY-MM-DD-descriptive-slug.md. (Real repo docs under docs/, or README/CLAUDE/CHANGELOG/AGENTS, are allowed; this guard is opt-in via CLAUDE_HARNESS_DOCS_GUARD.)")}}'
exit 0
