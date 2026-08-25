---
description: "Create a draft PR for the current branch in a standard format — ticket-prefixed title, What / Why / How / Test sections, draft, based on the repository's default branch, no pre-selected reviewers. Handles the tail — optional commit + push, draft PR, CI chase, mark-ready — with every irreversible step behind explicit confirmation."
argument-hint: "[optional: short description or ticket override, e.g. 'ABC-1234' or 'Fix flaky test']"
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
---

# /create-pr

Open a draft pull request for the current local branch.

**Base branch:** the repository's own default branch, resolved at run time — never assumed to be `main`. Resolve it once and reuse it:

```bash
BASE_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
[ -n "$BASE_BRANCH" ] || BASE_BRANCH="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null)"
[ -n "$BASE_BRANCH" ] || BASE_BRANCH=main
```

The local ref is tried first (no network, works in a worktree); `gh` is the authoritative fallback when `origin/HEAD` isn't set.

**Hard rules — non-negotiable:**

- Never run `gh pr create` until the assembled title + body has been shown and explicitly approved.
- Never commit, `git push`, or `gh pr ready` without an explicit go for that specific step — and never `--force`.
- Never mention Claude or AI co-authorship anywhere in the title or body.
- Never invent a ticket. If the branch carries none, the title prefix is `[NO-TICKET]`.
- Use the headings `## What`, `## Why`, `## How`, `## Test` (and `## Scope` when relevant) — unless the repo ships a PR template, which wins (Step 3).
- The body carries intent and approach. GitHub already renders the file list and the diff, so never inventory files or narrate the diff line by line.
- Tests earn a mention only as signal CI does not already show — a specific behaviour now covered, or a deliberate gap. A bare count ("14 tests passing") is noise.
- `## Risks` appears only when the user raised a concern or the template asks for one. Never speculate.
- When the *why* is not established by the session, ticket or commits, ask one open question. Offering candidate reasons or a pre-written draft invents the answer the user then ratifies.

**Arguments:** "$ARGUMENTS" — empty → derive from branch + commits; a ticket key (e.g. `ABC-1234`) → override the branch-derived ticket; anything else → a hint for the title description.

## Step 1 — Pre-flight (each gated step needs its own explicit go)

1. `git rev-parse --abbrev-ref HEAD` → must not be the base branch (`main`/`master`/`develop`).
2. `git status --porcelain` → if dirty, show `git diff --stat`, propose a one-line commit message (what changed, ticket included; no reasoning — that belongs in the body), and wait for a go before committing.
3. `git status -sb` → check sync with `origin/<branch>`. Ahead / no upstream → offer to push (`git push -u origin <branch>` when no upstream); wait for the go. Behind → tell the user to pull/rebase; abort. `[gone]` → abort ("branch was merged and its remote is gone; start a new branch off the base").
4. `gh pr view --json url,state 2>/dev/null` → no PR → create mode. Open PR → update mode (run the commit/push gates, then offer to regenerate title/body via `gh pr edit`; never flip draft/ready unless asked). Merged/closed → print URL + state and stop.
   - After any `gh pr edit`, re-verify the draft flag: `gh api repos/{owner}/{repo}/pulls/{n} --jq '.draft'`. `gh pr edit` has been observed to silently flip a draft PR to ready — if it did, restore it with `gh pr ready {n} --undo`.

## Step 2 — Extract the ticket

- Lowercase branch name; if it matches `^[a-z]+-[0-9]+$`, uppercase the prefix → `ABC-1234`.
- A ticket-shaped token in `$ARGUMENTS` (`^[A-Z]+-[0-9]+$`) overrides it.
- Otherwise → `NO-TICKET`.
- If an issue-tracker MCP is configured, use it to fetch the ticket's title + URL for the body; otherwise proceed without.

## Step 3 — Gather context (diff against the merge base, not the base branch directly)

```bash
BASE=$(git merge-base "$BASE_BRANCH" HEAD)
git log "$BASE"..HEAD --format=%B
git diff "$BASE"..HEAD --stat
git diff "$BASE"..HEAD --name-only
```

If `$BASE` equals `HEAD`, abort ("nothing to PR: branch has no commits ahead of the base"). Classify the diff as **backend-only**, **frontend/mixed**, or **config-only** — this drives the Test section.

**Reconcile the diff against the intent** before writing a word of the body:

- Files outside what the session or ticket called for → stop and surface them; ask whether to proceed, split them out, or drop them.
- Intended changes absent from the diff → surface that too; a PR that silently does less than it claims is the costlier direction.

`## How` describes the diff in front of you, not the plan you set out with.

**Detect a PR template** — a repo that ships one has already decided its structure:

```bash
find .github -maxdepth 2 -iname "*pull_request_template*" 2>/dev/null
```

If one exists it replaces the default headings: fill its sections, leave checkboxes unchecked unless you know they are done, and write `N/A` where there is nothing real to say. Keep the ticket reference line regardless.

## Step 4 — Title

`[TICKET] <imperative one-line description>` (or `[NO-TICKET] …`). Source the description from `$ARGUMENTS` (if prose) → ticket summary → first commit subject. Short, imperative, no trailing period.

## Step 5 — Body

```markdown
<ticket reference line — if a real ticket: "Ticket: [TICKET](<url>)"; else omit>

## What
<one line — what the change adds or does>

## Why
<the problem/motivation, 1–2 sentences. Bug → the cause.>

## How
<the approach, briefly. Call out any deliberate/conservative decision and why.>

## Test
<see variations>

## Scope
<when relevant — what was verified, coverage, blast radius>
```

Variations:
- **Backend-only** → `## Test` is `Automated tests added.` (name the key regression test if it sharpens the picture). Omit `## Scope` unless there's real blast radius.
- **Frontend / mixed** → `Automated tests added.` + a short numbered manual walkthrough (the flow to click through, what to confirm), and ask for a screenshot/recording on the PR.
- **Config-only** → `Automated tests added: N/A — <one-line reason>.` + numbered manual verification steps with exact commands.

**GitHub rendering:** one unwrapped line per paragraph — GitHub turns single newlines into line breaks, so column-wrapped prose snaps mid-sentence. Blank line between paragraphs, one bullet per line. `#42` in prose auto-links to issue 42; rephrase if you mean the number.

**Diagrams — when structure moved and prose would be worse.** A mermaid block earns its place when the change rearranges components, flows or states; it is noise on a single-file fix. Skip it for bug fixes that left the workflow intact, dependency bumps, docs-only changes, and refactors with no structural change.

| What changed | Block |
|---|---|
| New service, module, or dependency wiring | `graph TB` / `graph LR` |
| API call path or multi-step workflow | `sequenceDiagram` |
| Schema or model relationships | `classDiagram` |
| Status or lifecycle transitions | `stateDiagram-v2` |
| Branching decision logic | `flowchart TD` |

Draw only what changed, label nodes with real identifiers from the diff, and include just enough surrounding context to place them. Mark new components with `:::new` and a `classDef new fill:#90EE90,stroke:#006400` line rather than redrawing the system. Two focused diagrams beat one crowded one.

Content guidance: concise within each section; a one-line fix gets a one-line What/Why/How. Plain, approachable language — name identifiers but explain cause and fix in plain terms. British English, no emoji, no "this PR does X" preamble, no Claude mentions. End with a bold **Follow-ups (not in this PR):** line when there's deliberately-deferred work.

## Step 6 — Confirmation gate

Print the assembled title + body in one fenced block, then:

```
About to run:
  gh pr create --draft --base <base> --title "<title>" --body-file -

Branch: <branch>  →  base: <base>
Draft: yes   Reviewers: none (added only on explicit request)

Reply 'go' to open the PR, or tell me what to change.
```

Do not proceed without an explicit affirmative.

## Step 7 — Create

```bash
gh pr create --draft --base "$BASE_BRANCH" --title "<title>" --body-file - <<'EOF'
<assembled body>
EOF
```

If `gh` fails, report the raw error and stop — no retry with different flags.

## Step 8 — Post-creation

1. Print the PR URL on its own line.
2. Offer to chase CI: poll `gh pr checks <num>` periodically (cap ~30 min). Green → offer `gh pr ready <num>`. Red → summarise the failure and stop (no unprompted fixes).
3. If the ticket is real and a tracker MCP is configured, offer to move it to Review — resolve the tool from the live MCP surface; don't hardcode a connection-specific `mcp__…__` prefix.

## Notes

- Reviewers are never added by default. To add a **team** reviewer, note that `gh pr create --reviewer org/team` silently drops teams; use `gh api repos/{owner}/{repo}/pulls/{n}/requested_reviewers -X POST -f 'team_reviewers[]=<slug>'` and confirm.
- Heredoc uses `<<'EOF'` (quoted) so `$`, backticks, etc. in the body pass literally.
- Always diff against `git merge-base "$BASE_BRANCH" HEAD`, never the base branch directly, so the file-classifier stays honest on branches that lag behind.
