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
   - Populate `evidence` on every finding: the specific thing read that makes the claim true — the line, the surrounding pattern, the convention it contravenes, the caller that would break. Not a restatement of `detail`. A finding whose evidence cannot be written as something concrete that was *read* is a hunch; drop it rather than shipping it.
   - Set `blocking: true` only where merging first would cause damage a follow-up cannot undo (the four conditions under "Approve by default"). Default `false`. Claiming `blocking` sends the finding to the gate in Step 2.5, which will demote it if the evidence does not carry the claim.
   - Note positive observations briefly (one line max).
4. Forbids it from posting anything to the PR. Read-only via `gh`.
5. Embeds the worker-conduct block from `${CLAUDE_PLUGIN_ROOT}/skills/agent-selector/references/worker-conduct.md` **verbatim**, immediately before the return contract below — never paraphrased. (`CLAUDE_PLUGIN_ROOT` is empty in a raw checkout; fall back to the checkout path.) Reviewers are read-only STANDARD-tier dispatches, so do not append the DEEP/FRONTIER self-refutation rule.

### Severity definitions

- **critical** — bug, security issue, data integrity risk, broken build, missing tests on new behaviour, a CLAUDE.md violation that must be fixed before merge, or a clear structural regression the author cannot justify (see the structural pass escalation rule).
- **important** — design concerns, structural smells with a concrete judo move, missing edge cases, performance risk, unclear naming, test gaps that should be filled before merge.
- **suggestion** — style nits, optional refactors, minor structural improvements, doc improvements; safe to merge without addressing.

Severity describes the **finding**. It does not decide the recommendation — see below.

### Approve by default

The default recommendation is **approve**, and it stays approve even when the review carries critical and important findings. The author is trusted to address the comments after approval.

This is deliberate. Blocking a PR costs the author a full round-trip — they wait, context-switch away, come back cold — and that cost lands on every finding equally, whether it was a genuine defect or a naming preference. Approving with comments hands the author the decision about sequencing while still putting the findings in front of them. Most of the time they simply fix them and merge, which is the outcome everyone wanted, reached faster.

Reserve **request_changes** for the narrow class where merging first would cause real damage that a follow-up cannot undo:

- data loss, corruption, or an irreversible migration
- a security hole or leaked credential
- a break to the build or to production behaviour on the happy path
- a change that would be substantially harder to unpick after it ships

Everything else is **approve**, with the findings posted as comments. If a finding is serious but does not meet that bar, say so plainly in the comment ("this looks like a real bug, worth fixing before merge") and still approve — the words carry the urgency, the block is not needed to make the point.

Use **comment** only when the PR genuinely cannot be judged yet: it is a draft, the diff is incomplete, or a blocker prevented the review from finishing.

Set `recommendation_reason` to the reason for the *finding load*, not for the approval — "approving with 2 important findings on error handling" is more useful than "looks good".

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
    "critical": [{"title":"...","file":"path:line","detail":"...","evidence":"...","blocking":false,"already_raised_by":null,"judo_move":null}],
    "important": [{"title":"...","file":"path:line","detail":"...","evidence":"...","blocking":false,"already_raised_by":null,"judo_move":null}],
    "suggestion": [{"title":"...","file":"path:line","detail":"...","evidence":"...","blocking":false,"already_raised_by":null,"judo_move":null}]
  },
  "counts": {"critical": 0, "important": 0, "suggestion": 0},
  "positives": ["..."],
  "recommendation": "approve | comment | request_changes",
  "recommendation_reason": "<one sentence>",
  "blocker": null
}
```

If the sub-agent cannot complete (e.g. `gh` failure, repo not accessible), it must return the same schema with `status: "blocked"`, `recommendation: null` and `blocker: "<reason>"`.

## Step 2.5 — Gate the blocking claims

Every finding a sub-agent marked `blocking: true`, plus any PR where the recommendation came back `request_changes`, goes through one cheap adversarial check before it reaches me. Nothing else does.

**Why only these.** Under approve-by-default a weak finding posted as `nitpick (non-blocking):` costs the author two seconds to skim past — filtering it would spend more than it saves. The only findings that do damage are the ones that hold a PR up. Put the whole gate there and it stays small enough to run on every review.

Dispatch one **LIGHT-tier** judge per blocking claim (resolve via `${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh LIGHT`; never hardcode a model ID). Run them in parallel within the standing 3-agent cap. Each judge gets only the finding's `title`, `detail`, `evidence`, and the `file:line` hunk — not the whole diff. The question is deliberately narrow and textual, which is what makes the light tier the right one:

> Does the stated evidence support the stated claim, and does the claim meet the bar for blocking a merge? Argue for **UNSUPPORTED** first and only settle on SUPPORTED if the evidence defeats that argument.

The adversarial framing is load-bearing. A judge asked to "rate this finding" agrees with it — holistic quality-rating judges systematically over-rate, which is why the harness's own `disagreement-panel.md` frames every judge as "find why this fails" rather than "score this".

Each judge returns:

```json
{ "verdict": "SUPPORTED | UNSUPPORTED | ABSTAIN", "reason": "<one sentence>" }
```

`ABSTAIN` is a real answer, for a judge that genuinely cannot tell from what it was given.

**Applying the verdict — demote, never delete:**

| Verdict | Effect |
|---|---|
| `SUPPORTED` | Keeps `(blocking)`. Counts towards `request_changes`. |
| `UNSUPPORTED` | Demoted to `(non-blocking)`; the comment still posts. |
| `ABSTAIN` | Demoted to `(non-blocking)`. |

Demotion rather than deletion is the point. A finding that fails the gate has failed to justify *holding up the PR*, which is a different and much weaker claim than being wrong. Deleting it would throw away a possibly-real observation to win an argument about severity, and the author is the one best placed to judge it. Report the demotions to me with each judge's `reason` so I can see what the gate did and overrule it.

If no finding claims `blocking` and no PR recommends `request_changes` — the common case — skip this step entirely and say so.

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

### Writing the comments

Everything posted to GitHub is read by the author, and often by people who did not write the code and were not in the discussion behind it. Write for that wider reader. The rules below govern every posted sentence.

**Label every comment, using [Conventional Comments](https://conventionalcomments.org/).** The format is `label (decoration): subject`, and both halves matter:

| Label | For |
|---|---|
| `praise:` | Something done well. Not filler — name the specific thing |
| `nitpick:` | Trivial, preference-based |
| `suggestion:` | A concrete proposed improvement |
| `issue:` | A real problem with the code |
| `question:` | A possible concern where I am genuinely unsure |
| `todo:` | Small, necessary, uncontroversial |

The decoration carries the weight, separately from the type: **`(non-blocking)` is the default and applies to almost everything, including most `issue:` comments.** Use `(blocking)` only where the PR meets the request_changes bar above.

Keeping these two dimensions apart is the whole point. An `issue:` the author is trusted to fix after merging is `issue (non-blocking):` — the comment keeps its full seriousness while explicitly not holding the PR. Folding weight into the label word forces a false choice between understating the problem and blocking on it.

An unlabelled comment reads as mandatory, which is how a naming preference stalls a PR for a day. The labels are what make approve-by-default safe: the author sees at a glance what to act on now and what to note and move past.

Example: `issue (non-blocking): the retry loop re-reads the file on each attempt, so a file changed mid-run gives inconsistent results. Reading once before the loop fixes it.`

**Structure** — carried from the `adhd` skill, which governs how any text of mine is shaped:

1. Lead with the finding, after the label. No preamble, no restating what the code does before saying what is wrong with it.
2. One comment, one issue. Two problems in one thread means the second gets lost when the first is resolved.
3. Give the concrete next action where one exists — the replacement line, the helper to call, the file to move it to.
4. Complete sentences, British English. No fragments or arrow chains.

**Register** — carried from the `for-junior-dev` skill:

1. Gloss a term the first time it appears. "This is an N+1 query — the loop runs one database query per row."
2. One idea per sentence.
3. Name the thing: `UserService::resolve()`, not "the service method".
4. Drop `just`, `simply`, `obviously`. They tell the author they should have found this easy, and the reliable effect is that they stop asking questions rather than start.

**Two rules that override the above**, because outbound review comments are not the same as replies to me:

- **Comment on the code, never the person.** "Why did you use threads here" becomes "the concurrency here adds complexity without a performance gain." The second is easier to answer and carries no charge.
- **Keep the praise.** The `adhd` skill suppresses praise because I do not need it in my own replies. In a review it is doing real work: telling an author what they got right is what makes the pattern stick, and it is often the more useful half of the review. Post the `positives` — one line each, specific, naming the actual thing.

**Say why.** A comment that states a rule without its reason is one the author has to take on trust, and cannot apply to the next PR themselves. One clause is usually enough.

**Prefer pointing out the problem to prescribing the fix** when both work. It is the author's PR, they hold the context, and they frequently land on something better than the reviewer's suggestion. Prescribe directly when the fix is genuinely a single known answer.

### Pre-posting checklist (mandatory)

Before showing me any draft text destined for GitHub, and again immediately before posting the approved text, verify every item:

1. **Inline-only** — every finding is anchored to a `file:line` and posted as an inline review comment; the top-level review message is minimal (one or two sentences, no restated finding list).
2. **Every comment is labelled and decorated** — `label (decoration): subject`, with `(non-blocking)` on everything that does not meet the request_changes bar. Suggestions are posted as `nitpick (non-blocking):` or `suggestion (non-blocking):` rather than withheld: the decoration is what stops them reading as blocking, so they cost nothing to share.
3. **No em-dashes** — the posted text contains no `—` characters; rewrite with commas, colons, or parentheses.
4. **Nothing already raised** — findings marked `already_raised_by` are never re-posted.
5. **Recommendation is approve** unless the PR meets the request_changes bar above. If the draft says request_changes, name which of the four conditions it meets; if none, change it to approve.
6. **Every `(blocking)` decoration survived Step 2.5** with a `SUPPORTED` verdict. Any that did not is demoted to `(non-blocking)` before the text is drafted, not after.
7. **Positives are included** — at least the ones the sub-agent returned, one line each.
8. **Read it as the author** — no comment addresses the person rather than the code, and no comment contains `just`, `simply`, or `obviously`.

If any check fails, fix the draft before presenting it — never present-and-caveat.

## Notes

- Parallel cap: launch up to 3 sub-agents at once (the standing 2–3 cap). If there are more than 3 PRs, batch them.
- Sub-agents are read-only — pass them `gh` permissions only.
- If a sub-agent's `blocker` is non-null, still include it in the summary and flag it for me.
- Severity calibration: be honest. If a PR has nothing critical, do not invent critical items. The goal is signal, not theatre. This applies doubly to the structural pass — a smell is a labelled heuristic ("possible Feature Envy"), not an automatic finding.
- If invoked inside a worktree or feature branch with no `$ARGUMENTS`, ignore the local branch — this command is for **other people's PRs awaiting my review**, not the current branch. To review the current branch, use `/pr-review-toolkit:review-pr`.
