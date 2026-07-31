---
description: "Start work on a ticket the right way — fetch it from the configured issue tracker, branch from a fresh base with the conventional name, choose branch vs worktree, surface the acceptance criteria, seed the ticket's vault folder, then assess and recommend whether to hand off to the orchestrator. Ends at a ready workspace and an approved next step; never implements."
argument-hint: "[ticket key, e.g. 'ABC-1234']"
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Write"]
---

# /start-ticket

Front of the workflow. Turns a ticket key into a correctly-set-up branch (or
worktree) with the acceptance criteria summarised and the vault seeded, so the
work can begin without the manual setup ritual. `/create-pr` is the other
bookend.

**Base branch:** `${CLAUDE_BASE_BRANCH:-main}` (override by exporting `CLAUDE_BASE_BRANCH`).

**Input:** a ticket key in `$ARGUMENTS` (e.g. `ABC-1234`). If none was given, ask for it.

**Hard rules:**

- Never branch over a dirty working tree.
- Never branch from a stale local base — always fetch first. This is the single
  most common setup mistake and the main reason this command exists.
- Never start implementing here. This command's job ends at a ready workspace
  and an agreed next step.

## Step 1 — Fetch the ticket

If an issue-tracker MCP is configured, fetch the ticket through it — resolve the
tool from the live MCP surface; don't hardcode a connection-specific `mcp__…__`
prefix. Whichever system holds the ticket is the one used for all its later
transitions. Capture:

- Summary and description
- Acceptance criteria
- Comments carrying QA or stakeholder context

If the fetch fails, report the raw error and stop — don't guess the ticket's
intent. If no tracker is configured, ask the user to paste the summary and
acceptance criteria, and carry on from there.

## Step 2 — Check the working tree is safe to leave

```bash
git status --short
```

Dirty → stop and ask how to proceed (stash, commit, or abandon). Never branch
over uncommitted work silently.

## Step 3 — Derive the branch name

Lowercase the ticket key: `ABC-1234` → `abc-1234`. Used for both the branch and,
if chosen, the worktree directory. `/create-pr` performs the inverse (lowercase
branch → uppercase ticket prefix), so the pair only stays consistent if the
branch is named this way.

## Step 4 — Decide the strategy

Ask once, with a recommendation:

- **In-place branch** — fastest; reuses the current checkout and whatever local
  services it points at. Good when the workspace is free and the ticket is
  code-only.
- **Worktree** — isolated checkout, so the current one stays untouched. Good when
  something is already in flight here, or when the ticket needs its own
  environment.

Recommend a worktree when the ticket implies migrations or schema/destructive
changes — look for words like *column*, *table*, *migration*, *schema*, *new
field*. Those are the changes you least want sharing a workspace with unrelated
work.

## Step 5 — Set it up

**In-place branch:**

```bash
BASE="${CLAUDE_BASE_BRANCH:-main}"
git fetch origin "$BASE"
git checkout -b <lowercase-key> "origin/$BASE"
```

**Worktree:**

```bash
BASE="${CLAUDE_BASE_BRANCH:-main}"
git fetch origin "$BASE"
git worktree add -b <lowercase-key> "../<lowercase-key>" "origin/$BASE"
```

Then `cd` into it.

A project with per-worktree setup (dependency install, env file, database, container
stack) can export `CLAUDE_HARNESS_WORKTREE_SETUP` as a command to run inside the new
worktree; if it is set, run it and report its output. Otherwise say plainly that no
project setup step is configured, and let the user run theirs.

## Step 6 — Seed the ticket's vault folder

Resolve the vault with the same fail-open guard the hooks use — `CLAUDE_PLUGIN_ROOT`
is empty in a raw checkout, and unguarded it expands to `/lib/context-store.sh`:

```bash
STORE="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -x "$STORE" ]; then
    CTX="$("$STORE" path)"; "$STORE" init >/dev/null
    TDIR="$("$STORE" ticket-dir "$TICKET")"
else
    CTX="${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}"
    TDIR="$CTX/tickets/$TICKET"; mkdir -p "$TDIR"
fi
```

Write `$TDIR/ticket.md` following `lib/templates/ticket.md.tmpl` — YAML
frontmatter, the state callout, and the machine state fenced as a `json` block.
Fill `status` with `started` and `tier` with the mode chosen in step 7 (or
`null` if going direct). The embedded JSON carries the summary, acceptance
criteria, relevant comments, the branch/worktree decision, and the workspace path.

The orchestrator's `discovery` worker checks this folder before doing anything
else, so whichever path step 7 takes, the ticket is never fetched twice. Never
write this state into the project repo — it is per-user and must not be committed.

## Step 7 — Assess, recommend, hand off

Present a concise summary:

- Ticket: key, title, one-line goal
- Acceptance criteria as a checklist
- Branch or worktree created, from which base
- Where the vault folder is

Then assess whether the orchestrator pipeline fits, using its own mode table as
the yardstick:

| Signal in the ticket | Recommendation |
|---|---|
| Single small fix, one file/domain, clear AC, obvious approach | Orchestrator ⚡ Quick — or skip it and go direct |
| 1–3 clear ACs, single domain, code + tests | Orchestrator 🚶 Standard |
| Cross-domain, schema changes, 4+ ACs, ambiguity, anything irreversible | Orchestrator 🏗️ Full |
| No code change wanted — the deliverable is a findings report | Orchestrator 🔍 Discovery |

Then gate on **confidence that the orchestrator is not needed**:

- **High confidence it isn't** — every signal points at the first row: one
  file, one domain, clear AC, no schema change, nothing irreversible. Don't ask.
  State one line ("Small single-domain fix — going direct, no orchestrator") and
  proceed on the direct path.
- **Anything less** — the ticket matches a later row, or the signals are mixed.
  Ask, with the recommendation stated and one line on which signals drove it:
  *"This touches two domains and adds a migration — I recommend the orchestrator
  in Standard mode. Invoke it?"* The user decides.

Doubt counts against skipping the question. If the ticket text undersells the work
— vague AC, unfamiliar area, words like *column* / *migration* / *flow* — that
alone drops confidence below the ask threshold.

- **Orchestrator path:** invoke the `orchestrator` skill with the ticket key and
  workspace path, noting that discovery is pre-seeded from `$TDIR/ticket.md`.
- **Direct path:** implementation still goes through **sub-agents, not inline
  work** — route each piece via the `agent-selector` skill (model tier *and*
  agent, both selected) even when it's a single implementer + test-writer pair.
  The main session plans, dispatches, and reviews; it does not write the code.

Either way, stop here. Do not start implementing inside this command.

## Notes

- `${CLAUDE_BASE_BRANCH:-main}` is the same variable `/create-pr` targets, so the
  branch you start here is the branch it will PR against.
- The ticket key is uppercased for the vault folder and lowercased for the branch.
  Keep that split — `/create-pr`'s ticket extraction and the plan-persist hook
  both derive an uppercase key from a lowercase branch.

