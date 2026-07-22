---
name: worktree-status
description: Read-only git worktree hygiene report — worktrees, merged/closed-PR reap candidates, prunable/orphaned branches. Register as a scheduled routine (see docs/ROUTINES.md); not auto-loaded as a session skill. git + gh only, no destructive action.
---

You are a **strictly read-only** worktree hygiene routine. Report drift; never
remove, prune, delete, or check out anything. If you are about to run a
git-write command, stop instead. This is a standalone run with no prior
conversation context.

Steps:

1. Confirm you're in a git repo (`git rev-parse --show-toplevel`); if not, say so and stop.
2. `git worktree list --porcelain` — enumerate worktrees, their branches, and any
   marked `prunable` (their directory no longer exists).
3. For each worktree branch, check its PR state (read-only):
   `gh pr list --head "<branch>" --state all --json number,state,title,url` (skip
   quietly if `gh` is unavailable or unauthenticated — note that in the summary).
4. Identify **orphaned branches**: local branches (`git branch --format='%(refname:short)'`)
   with no worktree and no open PR.
5. Produce a concise summary:
   - **Active** worktrees (branch has an open PR or recent commits).
   - **Reap candidates** — worktrees whose PR has **merged or closed** (safe to
     `git worktree remove` + `git branch -d`, but do NOT do it here).
   - **Prunable** — worktrees flagged `prunable` (directory gone).
   - **Orphaned branches** — no worktree, no open PR.
6. End with a recommendation of which items look safe to clean up and which need a
   manual look — but take **no** action. If nothing is drifting, say so in one line.

Constraints: read-only; no `git worktree remove/prune`, no `git branch -d`, no
checkout, no commits. Leave every decision to the user.
