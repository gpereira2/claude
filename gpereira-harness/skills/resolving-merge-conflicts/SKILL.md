---
name: resolving-merge-conflicts
description: Work through an in-progress git merge or rebase conflict hunk by hunk and finish the operation — resolved, checked, and committed. Use when a merge or rebase has stopped on conflicts and needs finishing.
---

# Resolving merge conflicts

Resolve by **intent**, not by text. Before touching a hunk, understand *why* each side made its change; then preserve both intents where they fit together. The merge always gets finished.

## Steps

1. **See the current state.** Read the git history around the conflict and open the conflicting files. Know which operation is in progress (merge vs rebase) and which commit stopped it.

2. **Find each side's primary source.** For every conflict, trace both sides back to the change that owns them — the commit message, the PR, the originating issue or ticket. Understand deeply what each change was for. Reading the diff alone tells you *what* changed, not *why*; the why is what you resolve on.

3. **Resolve each hunk on intent.** Preserve both intents where they're compatible. Where they genuinely clash, keep the one matching the merge's stated goal and note the trade-off. Never invent new behaviour to paper over a clash, and never reach for `--abort` — the merge gets finished.

4. **Run the project's checks.** Discover them from the environment (`package.json` scripts, `Makefile`, `composer.json`, CI config) rather than assuming — typically typecheck, then tests, then format. Fix anything the merge broke.

5. **Finish the operation.** Stage everything and commit (or `rebase --continue` until every commit is replayed). Done when the working tree is conflict-free, the checks pass, and the merge or rebase has completed.
