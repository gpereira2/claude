---
description: "Review every PR where I'm a requested reviewer, in parallel, with a compiled recommendation per PR. Never posts without explicit approval."
argument-hint: "[optional: single PR URL/number to review just one]"
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Task", "Agent", "REPL"]
---

# /review-queue — Default Behaviour

Review pull requests where I'm a requested reviewer. By default, runs across **all** open, non-draft PRs assigned to me in parallel; if a PR URL or number is supplied as an argument, review only that one.

**Hard rule**: Never post a review, approval, change request, or PR comment. Compile findings, present recommendations, wait for me to explicitly tell you what to post. No exceptions.

**Arguments:** "$ARGUMENTS"

## Step 1 — Discover the review queue

- If `$ARGUMENTS` contains a PR URL or `#number`, treat it as the single target PR — review it even if it's a draft, but flag its draft state in the summary.
- Otherwise, run:
  ```
  gh search prs --review-requested=@me --state=open --draft=false --json number,title,url,repository,author,createdAt,updatedAt,isDraft --limit 50
  ```
- **Drafts are out of scope**: `--draft=false` excludes them at the search level. As a belt-and-braces check, drop any result with `isDraft: true` before dispatching sub-agents, and mention how many drafts were skipped (if any).
- Report the count up front: "Found N PRs awaiting review." If zero, stop.

## Step 2 — Gather context per PR (in parallel)

For each PR, dispatch a sub-agent using the `Agent` tool. Run them **in parallel** in a single message (multiple Agent tool uses in one block). Use `pr-review-toolkit:code-reviewer` as the `subagent_type` when available, otherwise fall back to `general-purpose`.

Each sub-agent receives a self-contained prompt that:

1. Names the PR (`owner/repo#number`, title, author, URL).
2. Instructs it to fetch, using `gh`:
   - PR metadata: `gh pr view <num> -R <repo> --json title,body,author,baseRefName,headRefName,mergeable,additions,deletions,changedFiles,labels`
   - Diff: `gh pr diff <num> -R <repo>`
   - Existing comments and reviews:
     - `gh pr view <num> -R <repo> --json comments,reviews,reviewRequests`
     - `gh api repos/<repo>/pulls/<num>/comments` for inline review comments
   - Linked issue-tracker ticket if present in title/body
3. Tells it to:
   - Read existing review comments and reviews **first** — do not duplicate what has already been raised, and explicitly mark issues already flagged by another reviewer as "already raised by @user".
   - For every file with more than ~10 changed lines, read the **entire file**, not just the diff hunks — structural judgement depends on surrounding patterns, pre-change file size, and existing conventions.
   - Assess against the project's CLAUDE.md / AGENTS.md standards if present.
   - Run the **structural quality pass** (below) alongside the correctness/standards pass.
   - Skip anything CI tooling already enforces (Pint, ESLint, Prettier, PHPStan, type-checkers) — findings must be judgement no linter can make.
   - Categorise every finding as **critical**, **important**, or **suggestion** (see definitions below).
   - Note positive observations briefly (one line max).
4. Forbids it from posting anything to the PR. Read-only via `gh`.
5. Embeds the worker-conduct block from `${CLAUDE_PLUGIN_ROOT}/skills/agent-selector/references/worker-conduct.md` **verbatim**, immediately before the return contract below — never paraphrased. (`CLAUDE_PLUGIN_ROOT` is empty in a raw checkout; fall back to the checkout path.) Reviewers are read-only STANDARD-tier dispatches, so do not append the DEEP/FRONTIER self-refutation rule.

### Severity definitions

- **critical** — bug, security issue, data integrity risk, broken build, missing tests on new behaviour, a CLAUDE.md violation that must be fixed before merge, or a clear structural regression the author cannot justify (see the structural pass escalation rule).
- **important** — design concerns, structural smells with a concrete judo move, missing edge cases, performance risk, unclear naming, test gaps that should be filled before merge.
- **suggestion** — style nits, optional refactors, minor structural improvements, doc improvements; safe to merge without addressing.

### Structural quality pass (code judo)

Alongside correctness, every sub-agent hunts for structural problems and simplification opportunities (adapted from Intercom's thermo-nuclear-code-review). The guiding principle is **code judo**: look for restructurings that keep behaviour identical while whole branches, helpers, modes, conditionals, or layers disappear. Don't settle for "this could be a bit cleaner" when a reframing would delete the complexity outright — prefer the solution that feels inevitable in hindsight.

**Standards to check:**

1. **Ambitious simplification** — if a code judo move exists that deletes complexity rather than rearranging it, push for that path.
2. **File size** — flag a PR that pushes a file past 1000 lines without strong structural justification ("this is where the other methods live" is not one). Vue components: decompose past ~300 lines of template.
3. **Spaghetti growth** — new ad-hoc conditionals, scattered special cases, or one-off branches in unrelated flows are a design problem, not a nit; the logic belongs in a dedicated abstraction, policy object, or module.
4. **Clean over merely working** — if behaviour can stay the same while structure gets meaningfully simpler, say so; prefer removing moving pieces over spreading complexity around.
5. **Direct over magical** — flag thin abstractions, identity wrappers, and pass-through helpers that add indirection without buying clarity; be sceptical of generic mechanisms hiding simple data-shape assumptions.
6. **Type/boundary cleanliness** — question unnecessary optionality, loose array/`mixed` params where a typed DTO/enum/value object could exist, and silent fallbacks papering over unclear invariants.
7. **Canonical layer** — feature logic must not leak into shared paths; reuse the existing canonical helper instead of a near-duplicate; controllers stay thin, domain logic lives in services.
8. **Feature-flag debt** — flag checks in 3+ locations, no cleanup path, deep branching inside methods rather than wrapping at a higher level, or nested flag conditionals.
9. **Orchestration smells** — needless sequential work, non-atomic multi-step updates that can leave state half-applied, and non-idempotent queue jobs.

**Code smell baseline (Fowler)** — widens recall beyond the standards; each reads *what it is → the fix*:

- **Mysterious Name** → rename; if no honest name comes easily, the murky design underneath is the real finding
- **Duplicated Code** → extract the shared shape, or reuse the canonical helper that already exists
- **Feature Envy** (method reaches into another object's data more than its own) → move the method to the data it envies
- **Data Clumps** (same fields/params keep travelling together) → bundle into a value object / DTO
- **Primitive Obsession** (string/array standing in for a domain concept) → give the concept its own type
- **Repeated Switches** (same if/match cascade recurring on the same type) → polymorphism, enum dispatch, or one shared map
- **Shotgun Surgery** (one logical change forces scattered edits across unrelated files) → gather into one module
- **Divergent Change** (one file edited for several unrelated reasons) → split so each module changes for one reason
- **Speculative Generality** (abstraction/params/hooks for needs the change doesn't have) → delete; inline until a real need shows up
- **Message Chains** (`$a->b()->c()->d()`) → hide the walk behind one method on the first object
- **Middle Man** (mostly delegates onward) → cut it, call the real target directly
- **Refused Bequest** (subclass ignores most of what it inherits) → composition over inheritance

**Two binding rules** (keep the pass honest, prevent noise):

- **The repo overrides the baseline.** A documented convention, an existing deliberate pattern in the surrounding code, or a team standard wins — suppress the smell, don't flag it.
- **Every smell is a judgement call, never a hard violation.** Structural findings default to **important** or **suggestion**. Escalate to **critical** only when the regression is clear and unjustifiable: an unexplained 1000-line crossing, feature checks scattered across shared code, a duplicate of a canonical helper, or a missed judo move that would delete whole categories of complexity.

Every structural finding must name the standard/smell violated, anchor to `file:line`, and populate `judo_move` with the concrete restructuring — not a vague observation.

### Return contract (required)

End the sub-agent prompt with the following block verbatim. The sub-agent's **final message must be exactly one line of JSON** matching this schema — no prose after it.

```
{
  "task_id": "<owner/repo#number>",
  "status": "ok | blocked",
  "pr": "<owner/repo#number>",
  "title": "<pr title>",
  "url": "<pr url>",
  "author": "<github login>",
  "summary": "<2-3 sentence plain-English description of what the PR does and the overall state>",
  "existing_review_state": "<one line: any prior reviews, who reviewed, what status>",
  "findings": {
    "critical": [{"title":"...","file":"path:line","detail":"...","already_raised_by":null,"judo_move":null}],
    "important": [{"title":"...","file":"path:line","detail":"...","already_raised_by":null,"judo_move":null}],
    "suggestion": [{"title":"...","file":"path:line","detail":"...","already_raised_by":null,"judo_move":null}]
  },
  "counts": {"critical": 0, "important": 0, "suggestion": 0},
  "positives": ["..."],
  "recommendation": "approve | comment | request_changes",
  "recommendation_reason": "<one sentence>",
  "blocker": null
}
```

If the sub-agent cannot complete (e.g. `gh` failure, repo not accessible), it must return the same schema with `status: "blocked"`, `recommendation: null` and `blocker: "<reason>"`.

## Step 3 — Compile the summary for me

After all sub-agents return, render a single message containing:

### Header line
> Reviewed N PRs. X recommend approve · Y recommend comment · Z recommend request changes.

### Per-PR block (repeat for each PR, ordered by recommendation severity: request_changes → comment → approve)

```
─────────────────────────────────────────────
[owner/repo#NUMBER] Title — @author
URL: <url>
Recommendation: REQUEST CHANGES | COMMENT | APPROVE  (reason: <one sentence>)
Counts: <C> critical · <I> important · <S> suggestion
Prior reviews: <one line>

Summary: <2-3 sentence plain-English>

Critical (C):
  1. <title> — <file:line>
     <detail>  [already raised by @user — if applicable]
     Judo move: <concrete restructuring — structural findings only>
  ...

Important (I):
  1. ...

Suggestions (S):
  1. ...

Positives:
  - ...
─────────────────────────────────────────────
```

### Footer — action menu

End with a numbered list of suggested next actions for me, e.g.:

```
What would you like to do? (nothing happens until you tell me)
  1. Post the recommendation for PR #X as <approve/comment/request_changes>
  2. Drill into a specific finding
  3. Re-run review on PR #Y after I push a fix
  4. Skip — close the review
```

## Step 4 — Wait

Do not run `gh pr review`, `gh pr comment`, `gh pr approve`, or any other write operation. Wait for me to pick an option. When I do, confirm the exact text I want posted before posting.

### Pre-posting checklist (mandatory)

Before showing me any draft text destined for GitHub, and again immediately before posting the approved text, verify every item:

1. **Inline-only** — every finding is anchored to a `file:line` and posted as an inline review comment; the top-level review message is minimal (one or two sentences, no restated finding list).
2. **Severity filter** — only critical and important findings get posted; suggestions stay in our chat unless I explicitly ask to include one.
3. **No em-dashes** — the posted text contains no `—` characters; rewrite with commas, colons, or parentheses.
4. **Nothing already raised** — findings marked `already_raised_by` are never re-posted.

If any check fails, fix the draft before presenting it — never present-and-caveat.

## Notes

- Parallel cap: launch up to 3 sub-agents at once (the standing 2–3 cap). If there are more than 3 PRs, batch them.
- Sub-agents are read-only — pass them `gh` permissions only.
- If a sub-agent's `blocker` is non-null, still include it in the summary and flag it for me.
- Severity calibration: be honest. If a PR has nothing critical, do not invent critical items. The goal is signal, not theatre. This applies doubly to the structural pass — a smell is a labelled heuristic ("possible Feature Envy"), not an automatic finding.
- If invoked inside a worktree or feature branch with no `$ARGUMENTS`, ignore the local branch — this command is for **other people's PRs awaiting my review**, not the current branch. To review the current branch, use `/pr-review-toolkit:review-pr`.
