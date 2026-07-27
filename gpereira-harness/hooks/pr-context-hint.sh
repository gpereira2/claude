#!/bin/bash
# SessionStart hook: inject the current branch's PR state — number, draft,
# CI check rollup, review decision, mergeability — so every session (main
# repo or worktree) opens knowing whether its work has a PR and where CI
# stands. Uses gh (read-only, allow-listed); no MCP/connector dependency.
# Skips default branches and non-GitHub repos. Fail-open: any failure
# exits 0 silently.

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd="${cwd:-${CLAUDE_PROJECT_DIR:-$PWD}}"
cd "$cwd" 2>/dev/null || exit 0

command -v gh >/dev/null 2>&1 || exit 0
branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] || exit 0
case "$branch" in develop|main|master) exit 0 ;; esac
git remote get-url origin 2>/dev/null | grep -q github || exit 0

export GH_NO_UPDATE_NOTIFIER=1 GH_PROMPT_DISABLED=1
out=$(gh pr view --json number,title,url,state,isDraft,mergeable,reviewDecision,baseRefName,statusCheckRollup --jq '
  (.statusCheckRollup // []) as $c |
  ($c | map((.conclusion // .state // .status // "PENDING") | ascii_upcase)
      | map(if . == "" then "PENDING" else . end)) as $s |
  ($s | map(select(. == "SUCCESS")) | length) as $ok |
  ($s | map(select(. == "FAILURE" or . == "ERROR" or . == "TIMED_OUT" or . == "CANCELLED" or . == "STARTUP_FAILURE")) | length) as $bad |
  ($s | map(select(. == "SKIPPED" or . == "NEUTRAL")) | length) as $skip |
  (($s | length) - $ok - $bad - $skip) as $run |
  (if ($s | length) == 0 then "no checks reported"
   else "\($ok) passed"
        + (if $bad > 0 then ", \($bad) FAILED" else "" end)
        + (if $run > 0 then ", \($run) running" else "" end)
        + (if $skip > 0 then ", \($skip) skipped" else "" end)
   end) as $ci |
  "[PR context] PR #\(.number) \"\(.title)\" — \(.state | ascii_downcase)"
  + (if .isDraft then " (draft)" else "" end)
  + " → \(.baseRefName) — CI: \($ci) — review: \((.reviewDecision // "none") | ascii_downcase) — mergeable: \((.mergeable // "unknown") | ascii_downcase) — \(.url)"
' 2>/dev/null)

if [ -n "$out" ]; then
    printf '%s\n' "$out"
else
    printf '[PR context] Branch %s has no PR yet.\n' "$branch"
fi
exit 0
