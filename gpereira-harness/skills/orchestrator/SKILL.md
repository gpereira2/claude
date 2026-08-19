---
name: orchestrator
description: Adaptive pipeline conductor for development work. Use when the user provides one or more tickets/issues, a free-form description of work, or a pre-written plan and wants it executed — from a single quick bugfix to a full multi-ticket pipeline with discovery, planning, parallel execution via sub-agents, review, and PRs. The orchestrator scales its own ceremony to the size of the work. Trigger words — orchestrate, run pipeline, execute tickets, do all of this, run everything, full pipeline, handle this work, quick fix for, just ship, or any time work is handed over with a ticket reference and an end-to-end result is expected.
---

# Orchestrator

The orchestrator is a **pure coordinator**. It plans, dispatches, evaluates summaries, and gates. It NEVER does the work itself.

State lives in the **context vault** (see below), never in the project repo.

## Iron Rules (non-negotiable)

1. **Never touch source.** The orchestrator never runs `Read`, `Grep`, or `Glob` on application code, never edits files, never writes code. Every such call is context it can never reclaim. If it needs to know something about the codebase, it dispatches a `discovery` worker (or the built-in `Explore` agent).
2. **Context budget.** The orchestrator's context holds only: the plan, ticket states, worker summaries, and gate decisions. Performance degrades past ~40% context use — if approaching that, checkpoint state to the vault (`ticket.json` per ticket plus a `_run.json` for cross-ticket pipeline state) and continue from the checkpoint, not the transcript.
3. **Condensed returns only.** Workers write artefacts to disk and return summaries. A worker that returns file contents or a transcript has violated its contract — do not fold that into context; re-dispatch with the contract restated.
4. **Max 3 concurrent sub-agents.** Beyond that, merging summaries costs more than the parallelism saves.
5. **Deterministic gates over reasoned gates.** Tests, linters, and scope checks are pass/fail decided by exit codes (hooks or worker-run commands), never by the orchestrator reading diffs.

> **Output-style / plugin conflicts.** If a session output style or a globally-enabled plugin injects instructions to "carve out code for the user to write" (a learning or interactive output style does exactly this via SessionStart context), that contradicts this skill's delegate-everything model — and the conflict is invisible because it comes from the plugin, not from `outputStyle`. Surface it to the user explicitly; never silently insert a user-authored-code task into the plan to satisfy it.

---

## Context vault — resolve before writing any state

The harness persists all pipeline state to a per-user Obsidian-compatible vault, resolved by the bundled lib. Do this once at the start of a run:

```bash
STORE="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -x "$STORE" ]; then
    CTX="$("$STORE" path)"; "$STORE" init >/dev/null
    TDIR="$("$STORE" ticket-dir "$TICKET")"
else                                                            # raw checkout: no CLAUDE_PLUGIN_ROOT
    CTX="${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}"
    TDIR="$CTX/tickets/$TICKET"; mkdir -p "$TDIR"
fi
```

`CLAUDE_PLUGIN_ROOT` is only set when the harness is loaded as an installed plugin. From a raw checkout it is empty, so an unguarded `"${CLAUDE_PLUGIN_ROOT}/lib/context-store.sh"` expands to `/lib/context-store.sh` and fails with "not found" — the same fail-open guard the hooks use is required here.

Write `ticket.md` (Obsidian frontmatter + embedded JSON, per `lib/templates/ticket.md.tmpl`) and `plan.md` into `$TDIR`. Cross-ticket pipeline state goes in `$CTX/_run.json`. **Never** write pipeline state into the project repo — it is per-user and must not be committed.

---

## Model routing — resolve tiers at runtime, never hardcode IDs

```bash
MODELS="$("${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh")"   # {"LIGHT":...,"STANDARD":...,"DEEP":...,"FRONTIER":...}
DEEP="$("${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh" DEEP)"
```

Tiers map to model **families** (regex patterns in `lib/tiers.json`), resolved to the newest live model at runtime with an offline fallback. Retune by editing `tiers.json` alone.

---

## Phase 0: Input Normalisation + Mode Selection

Accept: a single ticket (`PROJECT-1234`, a URL, "work on 1234"), a ticket list, a free-form description, or a pre-written plan. If an issue-tracker MCP is configured, fetch ticket detail through it; otherwise take the description as given. Normalise refs to a consistent `PROJECT-NUMBER` form. For free-form/doc input, present the extracted work units for confirmation.

Then **select a mode** — this is what makes the pipeline flexible. Ceremony scales to the work, exactly as agent-selector scales models to tasks.

> **"Mode" is not the `effort` parameter.** Mode sizes the *pipeline* — how many phases, gates and workers a run gets. `effort` is a per-dispatch model setting routed independently of tier (see agent-selector). A Quick-mode run can still dispatch a `high`-effort worker, and a Full-mode run is mostly `low`/`medium` ones.

| Mode | When | Pipeline |
|---|---|---|
| ⚡ **Quick** | Single small ticket: clear bugfix, copy change, config tweak, one-file change with an obvious approach | Skip Phases 1–3. One combined discovery+implement worker, one review worker, then Completion. 1–2 sub-agents total. |
| 🚶 **Standard** | 1–3 tickets, clear acceptance criteria, single domain each | Light critical review (top 3–5 questions only, batched in one message). Plan by a single DEEP-tier planner. Grouped execution with review gates. |
| 🏗️ **Full** | Epics, 4+ tickets, cross-domain work, schema changes, ambiguous specs, anything irreversible | The complete pipeline below: dependency inference, full critical review, DEEP-tier plan + independent plan review, per-group gates, final review. |
| 🔍 **Discovery** | No ticket, no code change; the deliverable is a findings/ideation **report** — a pain-point sweep, an audit, a spike | Parallel read-only discovery workers → main-loop synthesis → report saved to the vault (`$CTX/spikes/`). No plan approval, no execution, no gates, no PR. |

Worker-count rules (mirror these when sizing a run): 1 worker for a simple lookup or fix; 2–4 workers for a standard ticket (discovery, implement, test, review); a full manifest via agent-selector only for Full mode.

State the chosen mode in one line and proceed. In Quick mode, that line also names the intended worker and is the run's single approval — wait for a yes here, because no plan phase follows to catch it. The user can override ("run this as Full"). **Default down, escalate up**: if a Quick run surfaces unexpected complexity (schema change, cross-domain import, ambiguous AC), stop and escalate the mode — never push through.

**Discovery mode** skips the entire ticket-execution spine. Dispatch parallel read-only workers (built-in `Explore`, or the `discovery` agent at STANDARD tier for convention-sensitive sweeps), each returning a findings array; synthesise in the main loop; save the report to `$CTX/spikes/`. Findings return contract:

```json
{"area":"<domain/subsystem>","findings":[{"title":"<one line>","detail":"<=80 words>","evidence":"<path or query>","severity":"high|medium|low"}],"gaps":["<what wasn't covered>"]}
```

---

## Phase 1: Dependency Inference & Execution Order *(Standard: abbreviated · Full: complete)*

Dispatch a single `discovery` worker per ticket (parallel, max 3 at a time) to gather context — the orchestrator does not fetch these itself beyond the initial ticket read.

**Routing note**: pure codebase questions with no ticket context ("where is X handled?", "does a helper for Y exist?") go to the **built-in `Explore` agent** — it is cheaper and auto-routed. The custom `discovery` worker is for *ticket* discovery, which needs issue-tracker fetches and the harness return format (and, unlike `Explore`, honours project conventions files, so convention-sensitive questions belong with `discovery` too). Each `discovery` worker gathers:

1. Ticket detail via the configured issue-tracker MCP (summary, acceptance criteria, comments, linked issues). Whichever system holds the ticket is used for all its transitions.
2. Existing state check: the ticket's vault folder — resume from `ticket.json` if present.
3. Existing branches: `git branch --list '*{ticket}*'` and the remote equivalent (`git branch -r`). Also check **stale/related branches** — a parked spike, or a sibling ticket carved from the same epic, often already holds a half-built scaffold. Run `git diff --stat <base>...origin/<related-branch>` on any such branch: its diff is high-signal for scope and dependency decisions, and skipping it risks planning a from-scratch build that duplicates or conflicts with work that already exists.
4. Existing PRs for the ticket (via your Git host CLI/MCP) — if one is in flight, read its diff + description *before* planning. An existing PR often already defines the fix scope; planning from scratch duplicates or contradicts it.
5. A ≤200-word relevance summary: affected domain(s), likely files (paths only), risks.

**Every negative existence claim carries where it searched.** A worker's "no X exists" is a claim about its own search, not about the codebase — a bounded grep that missed a generically-named module reads exactly like proof of absence. Require any "no dedicated X found" / "nothing handles Y" finding to name the paths, globs and search terms actually run, and treat a claim without that provenance as unverified. The same applies to structural-sharing claims ("both trees wrap the same component"): duplicated copies and a shared import look identical in a file listing.

Infer ordering from the summaries:
- Shared domain + schema changes → serial (migration before logic).
- Test tasks that rebuild a shared test schema per run (`migrate:fresh` or equivalent) → serial with each other, unless each worker gets an isolated schema. Concurrent rebuilds surface as spurious lock-wait timeouts and deadlocks on unrelated tests, not as an obvious contention error (principle #15).
- Explicit `blocks` / `is blocked by` relations in the tracker → respect them.
- Unrelated domains → parallel.
- Support/bug tickets → isolated, never parallel with feature work.

Record the execution order (Parallel Group A / Serial after A / Isolated) — it goes into the plan and is approved with it at the single approval gate in Phase 3, not separately here. Do not stop for approval in this phase.

---

## Phase 2: Critical Review *(Quick: skip · Standard: top questions only · Full: complete)*

Interrogate the ticket(s) and discovery summaries (invoke a `critical-reviewer` skill if you have one, otherwise do it in the main loop). Surface ambiguities, assumptions, edge cases, and gaps **before any task is written**: AC completeness, edge cases, scope boundaries, domain impact, existing-code overlap, architecture decisions, dependencies, testing strategy, and any security/tenant-isolation boundaries relevant to your codebase.

- **Standard mode**: present only the highest-impact 3–5 questions in a single batch. Everything else becomes stated assumptions in the plan ("Assuming X — flag if wrong").
- **Full mode**: present the complete list, grouped by category. Do not proceed until blockers are resolved. Unanswerable questions → ticket flagged and skipped (with reason in the final summary).

Fold resolved answers into ticket context before planning.

---

## Phase 3: Plan Creation *(Quick: skip · Standard: single planner · Full: planner + independent reviewer)*

Planning is done entirely by sub-agents.

**Planner** (DEEP tier — in every mode that plans at all):

The planner is never routed down to save money. Plan writing is a DEEP row in agent-selector's deterministic table, and *"deterministic before inferential — if a task matches the routing table, its tier is settled"* means mode does not re-litigate it. The mechanism: a planner runs **once**, and the workers it specifies run many times over — how precisely the plan names contracts, file scopes and verification is what decides whether those workers arrive at the answer or grope for it. Cheap workers are only viable downstream of an explicit plan, so a thinner plan is not a saving, it is a cost moved onto the fleet and multiplied. Standard mode earns its savings by dispatching fewer workers and fewer gates, never by thinking less about what they are told.
1. Write the plan directly, covering: problem statement, approach, domain identification, task breakdown with ACs mapped, risks, and test strategy. Where the work can be carved more than one way, break it into **vertical slices** — tracer bullets, each independently demoable end-to-end — per agent-selector's Step 1, not horizontal layers.
2. Run `agent-selector` to produce the task manifest (tasks, tiers, tools, dependencies, parallel groups).

**User tier/model overrides apply pipeline-wide.** If the user overrides tier selection at any point ("put implementers on the DEEP tier", "use STANDARD for everything"), that override holds for the rest of the run — record it in `ticket.json` (`model_override`) so a resumed run honours it. When execution uses the Workflow tool, a pipeline-wide override must be pinned via `opts.model` on **every** `agent()` call: Workflow agents inherit the main-loop model by default, so the override is silently lost otherwise (see agent-selector Step 5).

**Discovery findings reach the planner as unverified input.** The planner dispatch must say so, and must require first-party re-verification of two kinds of claim before any task is built on them: a **negative existence claim** ("no dedicated model / service / preference store exists") and a **structural-sharing claim** ("both trees use the same shell component"). Those are the two that turn into whole slices of duplicated infrastructure — a generic property-bag store that discovery's search terms missed will be re-invented as a new table, model, service and DTO, and only an independent plan reviewer catches it. Re-verifying costs one grep; the slice costs a group.

The plan must include: domain identification, the manifest, parallel groups with serial gates, a review gate after each group, a UI test plan if a frontend is touched, and worktree references.

**Browser test plans name a browser tool that can actually read the page.** A host-integrated browser extension is the safer first choice: an in-app browser pane may refuse its DOM-read tools on non-standard origins (per-action approval) even though navigation succeeds, so starting there costs a round-trip that yields nothing. And when the plan calls for a request-count or page-load baseline, measure from the web server's access logs rather than `performance.getEntriesByType('resource')` — under a dev-mode bundler the ~250-entry resource buffer fills with module scripts before the app's own XHRs fire, and `setResourceTimingBufferSize` does not survive a reload. When dev-mode tooling floods browser instrumentation, measure at the server boundary instead.

### Ticket folder structure — one folder per ticket, in the vault

```
$CTX/tickets/{TICKET}/
├── plan.md        # narrative plan — prose, approach, risks (human/LLM readable)
└── ticket.json    # machine state — the source of truth for resume/inference
```

`ticket.json` holds everything that is *state* rather than *prose*, so any resumed run parses it deterministically instead of re-reading a transcript:

```json
{
  "ticket": "PROJ-1234",
  "mode": "standard",
  "status": "executing",
  "model_override": null,
  "ticket_status": "In Progress",
  "worktree": "<worktree path>",
  "manifest": [
    { "id": 1, "task": "...", "tier": "LIGHT", "effort": "low", "agent": "implementer", "status": "done", "retries": 0,
      "artefacts": ["src/..."] }
  ],
  "groups": [ { "group": "A", "tasks": [1], "status": "done" } ],
  "gates": [ { "after_group": "A", "result": "pass", "blockers": [] } ],
  "assumptions": ["..."],
  "pr": null
}
```

Update `ticket.json` after every group and gate. The vault ticket folder is the **only** persistence layer. **On resume or after compaction: re-read `ticket.json` first, `plan.md` second, transcript never.**

**Plan Reviewer** (Full mode only, DEEP tier, fresh context): every AC maps to a task; critical-review answers reflected; tier assignments sane; parallel groups have no hidden dependencies; no scope creep. Blockers → planner re-runs with feedback. Suggestions → user decides.

**Single approval gate — the run's only stop.** Present the plan (including the Phase 1 execution order) for one approval. Once approved, the pipeline runs to completion without further approval stops: groups dispatch automatically, gates halt only on failure. Move ticket(s) to In Progress after plan approval.

---

## Phase 4: Execution

**No per-group approvals.** The plan approval (Phase 3) covers every group; in Quick mode — which skips Phases 1–3 — state the mode and intended worker in one message and take a single approval there instead. Groups proceed automatically in dependency order. The pipeline stops mid-run only when a gate fails, the escalation cascade exhausts, or a Quick run escalates its mode — never to ask permission for the next group.

### Delegation contract — every dispatched worker prompt MUST contain all eight

0. **Routing** — the tier *and* the effort from the manifest, both pinned explicitly at dispatch (Task `model`/`effort`, Workflow `opts.model`/`opts.effort`). Omitting either inherits the session's value and silently discards the manifest's routing.
1. **Objective** — one task, one responsibility, stated in one sentence.
2. **Output format** — the Return Contract below, verbatim.
3. **Tool & convention guidance** — which project conventions/skills to follow, which tools it may use, and where to look first.
4. **Boundaries** — which files/domains are in scope; an explicit "do not touch" list; no unrelated changes.
5. **Context** — the worktree path, the plan at `$CTX/tickets/{TICKET}/plan.md`, and the outputs of prerequisite tasks (paths, not contents).
6. **Verification** — the exact test and lint commands to run before reporting done, plus a pre-commit self-check (null-safe access on all hops, no duplicated logic, every new branch/method has a test, reuse existing helpers). Browser-verification tasks name the specific browser tool to use, and take any request-count or load baseline from web-server access logs rather than browser resource timing.
7. **Conduct** — the worker-conduct block from `${CLAUDE_PLUGIN_ROOT}/skills/agent-selector/references/worker-conduct.md`, pasted verbatim, identical for every tier. Resolve it with the same fail-open guard as the context store above: from a raw checkout `CLAUDE_PLUGIN_ROOT` is empty and the path collapses, so fall back to the checkout path. Add no other self-verification step — only DEEP/FRONTIER dispatches get that file's self-refutation rule, and below DEEP a double-check step costs tokens without improving results.

**Mechanical migration dispatches state the target's public contract inline, never by reference.** When a fan-out updates call sites, mocks, or specs against a module that changed shape, spell out the full contract in the prompt — which named exports, which keys, which aliases, which destructuring form. "Update the mocks to match the new module" produces guesswork; the exact contract produces clean parallel migrations across a dozen agents.

A vague dispatch produces a vague result and there is no mid-flight correction — get the contract right the first time.

### Return Contract — every worker's final message is exactly one line of JSON

```json
{"task_id":"<id>","status":"ok|partial|blocked|failed","summary":"<≤150 words — what changed and why>","files_changed":["<paths only, never contents>"],"commands_run":["<cmd>"],"tests":{"ran":true,"passed":true,"command":"<cmd>","failure_tail":null},"assumptions":["<decision made without asking>"],"blocker":null,"followups":["<note>"]}
```

`ok` requires `tests.ran: true`; any silent gap → `partial`; `failed` feeds the escalation cascade with `tests.failure_tail` (last ~15 lines of failing output) as evidence. A worker resumed or re-notified after completing must re-emit the full populated contract — never an empty-array acknowledgement — see the resume rule in `${CLAUDE_PLUGIN_ROOT}/skills/agent-selector/references/spawn-examples.md`.

**Delivery recovery** — a background worker's completion notification is a signal, not the payload: post-completion system turns can displace the final-message slot, so the notification's result field often carries no contract. When it doesn't, read the last JSON contract match from the worker's task output-file transcript — that is the durable artefact — before doing anything else. Only if the transcript has no contract, fall back to a resend ping asking the worker to re-emit its final JSON verbatim; re-dispatching the work is the last resort. *(Verified 2026-07-23: three background workers all emitted correct contracts, but post-completion turns left "complete and delivered" prose in the final-message slot, so the notification carried nothing and the contract had to be regex-extracted from the transcript. Deliberately not automated — the recovery order is cheap to follow by hand and a resend ping costs less than a re-run.)*

### Worktree setup (per ticket)

Isolate each ticket in its own git worktree so parallel workers never collide:

```bash
BASE="${CLAUDE_BASE_BRANCH:-main}"
WT_ROOT="${CLAUDE_WORKTREE_DIR:-$(git rev-parse --show-toplevel)/.worktrees}"
TICKET_WORKTREE="${WT_ROOT}/{ticket-lowercase}"
mkdir -p "$WT_ROOT"
git fetch origin "$BASE"
git worktree add "$TICKET_WORKTREE" -b {ticket-lowercase} "origin/$BASE"
```

Copy any local, uncommitted environment files the build needs into the worktree. Delegate worktree creation to a LIGHT-tier worker when 3+ worktrees are needed.

### Dispatch rules

- Groups run **sequentially by dependency**: database → backend → frontend → tests.
- Within a group, dispatch independent tasks **in one batch** (single message, multiple Task calls) — max 3 concurrent.
- Workers never integrate each other's output. Integration is **dispatched, never performed in the main loop** (Iron Rule 1): the orchestrator sequences it as its own task and sends it to a worker with fresh context, and never to either author — whoever wrote one side of a collision is the worst-placed agent to judge which side should win, because the reasoning that produced their version is exactly what they will re-apply. No named agent covers this shape yet: route it to `implementer` scoped to integration only, and flag the named-agent gap as a manifest follow-up. Within a group, write sets must be disjoint — the worktree is per ticket, not per task, so two workers editing one file silently lose one set of edits.
- After each group: one status line (finished / remaining / issues).

### Review gate (after each group) — fast gate

Intermediate gates optimise for **speed** — they run between every group, so a slow gate multiplies across the pipeline. Dispatch a single `reviewer` worker (fresh context, read-only tools) against the group's diff, running a code-review skill if you have one, augmented with a project checklist: null safety on all access hops, no duplication of existing helpers, test coverage of every new branch, transactions around multi-write sequences, tenant/isolation scoping where relevant, and diff-scope discipline.

Deterministic checks (tests pass, linter clean) come from exit codes, not the reviewer's judgement. Prefer a `SubagentStop` hook enforcing "tests pass + no writes outside `$TICKET_WORKTREE`" if configured; the reviewer then covers only what hooks can't.

**When the group migrated tests, tell the reviewer to check assertions against intended behaviour, not current wiring.** An agent updating a spec preserves whatever the code does, bugs included — a migrated green test can encode the defect it was supposed to catch. The gate prompt must name the intent side to compare against (the component's props, the fixture's domain meaning, the acceptance criteria) so the reviewer verifies expected values rather than trusting a passing suite.

**Treat every worker's `status`, `files_changed`, and `tests` fields as claims to verify, not facts.** At the gate, reconcile them against `git status --porcelain` (a worker reporting "1 file changed" when the tree shows 12 has misnarrated its work) and a first-party re-run of the test command — a sub-agent's "21 passed" is a claim until the gate reproduces it.

**The worker was handed the commands it is graded on, so check for a gamed pass, not just a pass.** Delegation-contract item 6 gives every worker the exact test and lint invocations the gate will judge it by — which makes weakening the target a cheaper route to green than fixing the code. Have the reviewer confirm the diff did not soften assertions, add `skip`/`only`/`pending` markers, loosen a matcher to a tautology, widen an expected type, or quietly narrow the task's scope to whatever already passed. A suite that goes green because it now asks less is a regression the exit code cannot see.

Blockers fixed before the next group. Suggestions → user.

### Failure escalation (cheap-first cascade)

1. Retry once at **one effort step up on the same tier** (per agent-selector's cascade — effort climbs before tier, because most failures are under-thought rather than under-powered), including the failure summary and `tests.failure_tail` — not the full transcript — in the new prompt.
2. **Re-specify once, before buying a bigger model** — but only on evidence that the *dispatch* was the defect: a `blocked` on a false premise, an `assumptions` array carrying a load-bearing guess, or a failure naming something the prompt never supplied (a contract, a path, a fixture). Rewrite the prompt and re-run the same rung. One planner inference is cheaper than a re-run a tier up, and an under-specified task fails identically at every tier. Skip this rung when the evidence shows a genuine capability failure — the approach itself is wrong — and climb instead.
3. Still failing → retry once at the next tier up, with effort reset to that tier's routed level.
4. Second failure at the same tier after its effort step → escalate to the user with what was attempted and why it failed.

**Original tier → effort step → re-specify (once, on dispatch-defect evidence only) → one tier upgrade → user.** One retry per rung, one re-specify per task; never a second of either.

### Final review (Full mode, per ticket) — deep gate

This is the slow, thorough pass — it runs **once per ticket, after all groups complete**, never between groups. Run your most thorough review skill/agent (or a review team, if your setup has one) covering code quality, silent failures, security, and test coverage. Synthesise, deduplicate, and present blockers → suggestions → nits.

---

## Phase 5: Completion (per ticket)

1. **Promote knowledge** to the vault (`$CTX/knowledge/`): `feature/{slug}.md` (how features work), `technical/{slug}.md` (architecture patterns) — only genuinely reusable discoveries, one focused file each.
2. **Finalise state**: set `ticket.json` → `"status": "complete"`, record the PR URL; keep the ticket folder (it is the audit trail).
3. **PR**: open a draft PR against your base branch via your Git host CLI/MCP, title `[TICKET] Description`, body from your repo's PR template, and include a link back to the ticket in whichever system it lives in. Test plan: "Automated tests added" for backend-only; concise manual steps for frontend.
4. **Transition** the ticket to Review via the same tracker it was fetched from.
5. **Worktree cleanup**: `git worktree remove "$TICKET_WORKTREE" && git branch -d {ticket-lowercase}`.

---

## Phase 6: Final Summary

```
## Pipeline Complete (mode: {Quick|Standard|Full})

### ✅ Completed ({n})
- PROJ-1234 — [summary] — PR #42 (draft) — Review

### ⏭️ Skipped ({n})
- PROJ-9012 — [reason]

### 🧠 Knowledge saved
- $CTX/knowledge/feature/... · technical/...

### 📋 Actions required
- [what the user must do to unblock anything]
```

---

## Quick Reference

One approval per run: the plan (Standard/Full) or the mode statement (Quick). Everything else runs on deterministic gates.

| Phase | Quick | Standard | Full | Approval gate |
|---|---|---|---|---|
| 0 — Normalise + mode | ✅ | ✅ | ✅ | Quick: whole-run approval here; others: confirm free-form input only |
| 1 — Dependency inference | — | abbreviated | ✅ | — (folded into plan) |
| 2 — Critical review | — | top 3–5 Qs | full | blocker Q&A only (Full) |
| 3 — Plan + review | — | planner only | planner + reviewer | ✅ the run's single approval |
| 4 — Execution | 1 worker | grouped | full manifest | — (auto-proceeds) |
| 4x — Fast gate | 1 reviewer | ✅ per group | ✅ per group | blockers only |
| 4y — Deep gate | — | — | ✅ once per ticket | blockers only |
| 5 — Completion | ✅ | ✅ | ✅ | — |
| 6 — Summary | ✅ | ✅ | ✅ | — |

**Discovery mode** uses none of the rows above: Phase 0 (mode select) → parallel read-only workers → main-loop synthesis → report to `$CTX/spikes/`. No gates, no PR.

**The orchestrator's health check**: at any point, if its context contains file contents, diffs, or worker transcripts — something has gone wrong. Fix the delegation, don't absorb the work.
