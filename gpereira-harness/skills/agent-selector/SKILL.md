---
name: agent-selector
description: Breaks a plan or feature request into discrete tasks and routes each to the cheapest Claude model tier that can handle it AND to the right agent definition (named agents, built-in types, or plugin agents), using deterministic rules first and judgement only for ambiguous cases. Produces a task manifest with parallel groups, dependencies, per-task agents, and per-task return contracts, then spawns subagents. Also trigger on "which agent should run this", "pick an agent and model", "route this to agents", "split this into agents", "parallelise this plan", "which model should do what", "break this into tasks", "optimise model usage". Always prefer this over manual task breakdown when cost efficiency and parallelisation matter.
---

# Agent Selector

Route each task to the **cheapest tier that can handle it**, escalate on failure, and keep the routing itself nearly free: a lookup table costs zero tokens; an LLM judgement call costs one inference; dual-inference costs three. Spend in that order.

**Every dispatch selects two things, never one: a model tier AND an agent definition.** No subagent or Workflow task is spawned with only a model — the agent (named agent from `agents/`, built-in type, or plugin agent) determines the system prompt, tool allowlist, and return contract the worker runs under. A model without an agent is an unscoped worker; an agent without a routed tier is an unpriced one.

## Model Pool — families, never pinned versions

Tiers map to model **families**. The concrete model ID is always *the latest available version in that family*, resolved at runtime — this skill never hardcodes a version, so it never goes stale when a new Sonnet or Opus ships.

| Tier | Family | Resolves to | Default tools | Purpose |
|---|---|---|---|---|
| ⚡ **LIGHT** | haiku | latest Haiku | task-scoped only | Mechanical work and ops — no reasoning required |
| 🟡 **STANDARD** | sonnet | latest Sonnet | task-scoped | Implementation, refactoring, tests, debugging known issues, research |
| 🔴 **DEEP** | opus | latest Opus | task-scoped | Architecture, ambiguous specs, security, plan writing/review, reconciliation |
| 🚀 **FRONTIER** | fable (fallback: opus) | latest frontier model the key can see | any | Long-horizon autonomous work, cases where DEEP has already failed |

> **LIGHT ≠ premium "fast mode".** LIGHT resolves to Haiku — the cheapest model in the pool. It is unrelated to a session-level `/fast` toggle (a premium model with faster output at premium pricing), which this router never selects for any tier.

### Resolving model IDs — `${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh`

Run once at the start of a pipeline and cache the result for the whole run:

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh"          # {"LIGHT":...,"STANDARD":...,"DEEP":...,"FRONTIER":...}
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh" DEEP     # single tier → one model ID
```

`CLAUDE_PLUGIN_ROOT` is set only when the harness runs as an installed plugin. From a raw checkout it is empty and the path collapses to `/lib/resolve-models.sh` ("not found") — test `[ -x "$STORE" ]` before calling, and fall back to the checkout path or the tier defaults, exactly as the hooks do.

The resolver queries the Anthropic Models API and picks the newest live model whose ID matches each tier's family pattern in `lib/tiers.json`; when the API is unreachable (or the key can't see that family — e.g. FRONTIER/Fable on a key without access), it uses the pinned `fallback`. Retune which family a tier maps to by editing `tiers.json` alone.

> **Pinning an older version on hearsay — verify first.** Community claims that a previous point release is "leaner" or "more focused" for sub-agent work must be checked against official pricing and tokenizer notes before pinning; the fewer-tokens effect is usually a tokenizer-counting artefact, not a real cost saving. Stay on latest-in-family unless new evidence clears that bar.

**Where model references appear, in order of preference:**
1. **Named agents in `agents/`** — use alias frontmatter (`model: sonnet`), which tracks the family's latest automatically; the tool allowlist is enforced by configuration.
2. **Task tool / manifest dispatch** — use the resolved pool values.
3. **Headless `claude -p`** — pass explicit IDs from the resolver (aliases also work).

Tool scoping is least-privilege per task in the manifest (discovery: `Read, Grep, Glob`, no write; implementers: write to `$TICKET_WORKTREE` only).

---

## The Effort Axis — orthogonal to tier, routed separately

**Tier and effort are two independent dials and do not map one-to-one.** Tier answers *which model* — the capability floor the task needs at all. Effort answers *how hard that model thinks* on this particular instance of the task. Route them in separate passes; any tier may pair with any effort.

Conflating them is the common mistake, and it costs money in both directions: it forces a cheap model onto a task needing sustained reasoning, and it burns premium thinking on mechanical work that a capable model finishes in one pass.

| Effort | Task shape |
|---|---|
| `low` | Mechanical transforms, ops, single-file edits from a precise spec, generated boilerplate |
| `medium` | Implementation from a clear spec, **code review**, research sweeps, test writing, wide-but-shallow investigation |
| `high` | Ambiguous approach, cross-domain design, plan writing, reconciling conflicting outputs |
| `xhigh` | Demanding long-horizon agentic work, or a task `high` has already failed |

### The cross-product cases that prove they are independent

These pairings are the point of the two-axis design — write them into manifests deliberately, not as exceptions:

| Pairing | When | Why not the diagonal |
|---|---|---|
| **DEEP + `medium`** | Code review, diff gates | Review accuracy holds at lower effort, so a capable reviewer stays cheap enough to run on *every* group instead of once at the end |
| **LIGHT + `medium`** | Wide mechanical sweep with many small judgement calls | The work needs no deep capability, but hundreds of tiny decisions benefit from more than `low` |
| **DEEP + `xhigh`** | Architecture, security boundaries, irreversible migrations | The genuine top-right corner — rare, and priced accordingly |
| **STANDARD + `low`** | Bulk edits from a settled pattern | Sonnet for reliability, minimum thinking because the shape is already decided |

> **Effort defaults are a fallback, not a mapping.** When a task matches no effort row, default to `medium`, not to "whatever its tier suggests". Record a one-line reason for any task routed above `medium`.

### Pin effort explicitly on every dispatch

Effort inherits from the session when omitted, exactly as `model` does — so an unpinned dispatch silently flattens the whole fleet to the session's effort and discards the manifest's routing. Pass it on every call: the Task tool's `effort`, or a Workflow `agent()` call's `opts.effort`. This is the same failure mode as the `opts.model` trap below, and it is easier to miss because nothing errors — the run just costs the wrong amount.

---

## Step 1: Plan Analysis

Read the full plan. Identify:
- Atomic units of work — clear inputs, clear outputs, bounded file set, independently verifiable.
- Dependencies (serial vs parallel).

**Prefer vertical slices when the plan can be carved more than one way.** Cut **tracer bullets** — each unit runs end-to-end through every layer it touches (schema → logic → UI → test) to something independently demoable — rather than horizontal layers (all migrations, then all services, then all UI). A vertical slice is verifiable on its own and surfaces integration problems on the first slice instead of at the end. This shapes *what a unit is*; the database → backend → frontend build order and the disjoint-write parallel groups below still govern how one slice's tasks are then sequenced and parallelised.
- Ambiguous tasks — **flag, don't guess**:

```
⚠️ Needs clarification before assignment:
- "[task]" — unclear whether this extends existing architecture or needs new design. Which?
```

## Step 2: Deterministic Routing (covers ~80% of tasks, zero inference cost)

Match the task against this table **first**. Only tasks that match no row proceed to Step 3.

| Task pattern | Tier |
|---|---|
| Migration file, config change, boilerplate, renaming, formatting, simple CRUD scaffold | ⚡ LIGHT |
| Shell execution, file I/O, grepping logs, moving files, worktree setup, repetitive CLI | ⚡ LIGHT |
| Test generation from already-designed logic | ⚡ LIGHT |
| Feature implementation from a clear spec, single domain | 🟡 STANDARD |
| Refactor with a defined target shape; debugging a known issue | 🟡 STANDARD |
| Integration/e2e test design, factories, complex mocking | 🟡 STANDARD |
| Docs, API integration from docs, CI/build config | 🟡 STANDARD |
| Web research: unfamiliar libraries, CVEs, dependency audits (add `web_search`) | 🟡 STANDARD |
| Code review, coverage analysis, PR summaries (read-only tools) | 🟡 STANDARD |
| Schema design, query optimisation, data transformations | 🔴 DEEP |
| Architecture decisions, new system design, cross-domain/cross-service flow | 🔴 DEEP |
| Ambiguous spec where the *approach* is unclear (after clarification is exhausted) | 🔴 DEEP |
| Threat modelling, auth flow review, security boundaries | 🔴 DEEP |
| Plan writing, plan review, reconciliation, merging complex parallel outputs | 🔴 DEEP |
| Long-horizon autonomous work; anything DEEP has demonstrably failed at | 🚀 FRONTIER |

### Agent routing — the second half of every route

Every manifest row must resolve **five things**: the **agent type** (named / built-in / plugin), the **agent role** (what the worker is trusted to do — discovery, implementation, tests, review), the **agent file** (the `agents/<name>.md` path when a named agent is used; `—` for built-ins), the **model** (from the resolved pool, or the agent file's frontmatter default), and the **effort** (routed on task shape, independently of the model). A row missing any of the five is not dispatchable.

After the tier is settled, select the **agent** the task runs as, in this precedence order:

1. **Named agents** (this plugin's `agents/`, then any project/global agents): use one whose description matches the task type — `discovery` for ticket/context gathering, `implementer` for scoped code changes, `test-writer` for coverage tasks, `reviewer` for diff gates. Named agents pin the tool allowlist and embed the conduct + return contract in their body — prefer them whenever one fits, because the contract is then structural, not pasted.
2. **Plugin/specialist agents** (e.g. a code-reviewer agent) when their speciality matches exactly.
3. **Built-in types** as fallback: `Explore` for read-only codebase search, `Plan` for design/planning, `general-purpose` for multi-step work no named agent covers.

**Tier vs agent-frontmatter precedence:** a named agent's `model:` frontmatter is its calibrated default — trust it when it agrees with the routed tier. When they disagree, the routed tier wins only on **escalation** (pass the model override at dispatch: Task tool `model`, Workflow `agent()` `opts.model`); never silently downgrade an agent below its frontmatter tier.

If no agent in any category fits a recurring task shape, that is a signal to **create a named agent** for it (flag in the manifest as a follow-up) — not to keep dispatching unscoped general-purpose workers.

### Judgement fallback (Step 3) — only for unmatched tasks

> Single obvious implementation path → LIGHT or STANDARD.
> A skilled engineer would need to *think before starting* → DEEP.
> When in doubt → STANDARD. Never under-power, never default to DEEP "to be safe".

Record a one-line reason for any judgement-routed task so the user can override.

## Step 3: Cascade Escalation (replaces most dual-inference use)

The default quality mechanism is **cheap-first, escalate-on-failure** — it costs extra inference only when something actually fails:

**Climb effort before tier.** With two axes the ladder has twice the rungs at a fraction of the cost — raising effort on the same model is far cheaper than jumping a model family, and it fixes most failures, which are under-thought rather than under-powered:

```
LIGHT/low → LIGHT/medium → [re-specify once] → STANDARD/medium → STANDARD/high → DEEP/high → DEEP/xhigh → FRONTIER → human
```

Rule: **one effort step up first; only if that also fails, step up a tier** (resetting effort to that tier's routed level). One retry per rung, carrying a ≤150-word failure summary plus the returned `tests.failure_tail` evidence (never the failed transcript). Two failures at the same tier *after* its effort step → human. This cascade is shared with the orchestrator's failure-escalation rules — do not define a different one.

**Re-specify before you re-tier.** Before any tier climb, ask what the returned evidence actually indicts — the model, or the prompt. When it points at the dispatch, rewrite the prompt and re-run the *same* rung: an under-specified task fails identically at every tier, so buying a bigger model just pays more for the same miss. The tells are specific — `status: "blocked"` on a false premise, an `assumptions` array carrying a guess the task turned on, or a failure that names a contract, path or fixture the prompt never supplied. Re-specify **at most once per task**, and only on that evidence; when the evidence shows the approach itself is wrong rather than under-described, skip the rung and climb. This is the cheapest rung on the ladder and the most often skipped, because a failure reads as weakness in the worker long before it reads as vagueness in the instruction.

## Dual-Inference (exceptional — strict entry criteria)

Dual-inference costs **3× inference plus a serial reconciliation step**. It is justified only when ALL of these hold:

1. **Complex** — approach genuinely unclear to a skilled engineer, AND
2. **Critical** — a wrong answer is costly AND hard to detect later (irreversible migration, security boundary, core architecture), AND
3. **Not verifiable cheaply** — tests, review gates, or the escalation cascade cannot catch the error after the fact, AND
4. **User has opted in** — present it as a recommendation; never silently include it in a manifest.

Cap: **one dual-inference task per pipeline run**. If more seem to qualify, the plan is under-specified — go back to clarification.

When used: two sibling tasks, identical prompts, different models. Default pairing: **latest Sonnet + latest Opus** (the capability gap makes divergence meaningful). Reconcile with a DEEP-tier agent producing:

```
## Reconciliation Report
### Agreement (proceed)
### Divergence (A said X, B said Y — recommended resolution)
### Confidence Score: 0–100
### Final Recommendation (consumed by downstream tasks)
### Escalate to Human: yes/no
```

Never dual-inference: ambiguous tasks (clarify instead), tasks with one obvious answer, mechanical work, latency-critical paths.

Worked pairings, the reconciliation prompt, and the version-pinning variant (two releases within one family rather than two families) are in `references/dual-inference.md`.

**When the decision is contested as well as complex**, two models are the wrong shape — a 2-judge split has no way to resolve itself and averaging it destroys the signal. Escalate to the N-judge **disagreement panel** in `references/disagreement-panel.md`: distinct adversarial personas, spread across model generations, aggregated by divergence rather than majority vote. It is the generalisation of this section, not an alternative to it — use dual-inference for a second take on a single *task*, the panel for a *plan, design, or finding*.

## Step 4: Output — Task Manifest

Always produce the manifest and show it for confirmation before spawning anything.

```
## Task Manifest

| # | Task | Tier | Effort | Agent | Tools | Depends On | Run |
|---|------|------|--------|-------|-------|------------|-----|
| 1 | Create renewals migration | ⚡ LIGHT | `low` | implementer | fs (worktree only) | — | parallel |
| 2 | RenewalService business logic | 🟡 STANDARD | `medium` | implementer | fs (worktree only) | #1 | serial |
| 3 | Renewal flow architecture note | 🔴 DEEP | `high` | Plan (built-in) | read-only | — | parallel |
| 4 | Review group-A diff | 🔴 DEEP | `medium` | reviewer | read-only | #1, #3 | serial |

**Parallel groups** (max 3 concurrent per group):
- Group A: #1, #3
- Group B (after A): #2

**Routing**: {n} deterministic, {n} judgement-routed (reasons above), {n} dual-inference (user-approved)
**Effort**: {n} `low`, {n} `medium`, {n} `high`, {n} `xhigh` — reasons given for anything above `medium`
**Agents**: every row names its agent; tasks left on `general-purpose` are listed with a one-line reason (and a named-agent follow-up if the shape recurs)
**Cost note**: counted from the rows above, never estimated — e.g. "8 tasks: 3 LIGHT / 4 STANDARD / 1 DEEP; effort 5 `low` / 2 `medium` / 1 `high`". Both columns are already in the manifest, so this is arithmetic, and it turns the routing doctrine into something a finished run can be audited against instead of a claim. A qualitative gesture ("mostly cheap tiers") cannot be checked and hides the case where a fleet quietly drifted upward.
```

Rules:
- Max 3 tasks per parallel group — beyond that, summary-merging overhead exceeds the parallelism gain.
- Tasks in the same parallel group must have **disjoint write sets**. The worktree is per ticket, not per task, so two workers editing one file silently lose one set of edits — put overlapping writes in different groups. "No hidden dependencies" is about ordering and does not cover this.
- Every task's dispatch prompt must embed the orchestrator's **delegation contract** (objective, return contract, tools/conventions, boundaries, context paths, verification commands, conduct) — see the `orchestrator` skill, Phase 4.
- Every task returns the standard **Return Contract** — the one-line JSON schema in `references/spawn-examples.md`; artefacts to disk as paths, never inlined.
- Every dispatch embeds the worker-conduct block from `references/worker-conduct.md` verbatim — the same block for every tier, plus the self-refutation rule for DEEP/FRONTIER only.

## Step 5: Execution

### Native subagents (preferred)

Dispatch via the Task tool, batching each parallel group into a single message. Pass the manifest's agent as `subagent_type` and the routed model only when overriding the agent's frontmatter (escalation). Prompts must be fully self-contained — no shared state; prerequisite outputs passed as artefact paths.

For Workflow-tool runs, `opts.agentType` from the manifest is still mandatory on every `agent()` call — but the model rule is **not** the same as the Task tool, and this is a common silent trap. The Task tool honours the agent's frontmatter model when `model` is omitted; a Workflow `agent()` call with `opts.model` omitted **inherits the main-loop model instead**, ignoring the manifest's per-task tier. So pin `opts.model` explicitly on every `agent()` call whenever (a) the manifest assigns a tier that differs from the main-loop model, or (b) a model gate is in force (e.g. a permission-gated family in your setup) — otherwise inheritance flattens every worker to the main-loop model, mis-tiers the fleet, and can propagate a gated model with no per-use approval.

Use headless `claude -p --model <model>` **only** for detached/background runs outside an interactive session (e.g. CI, cron):

```bash
POOL="$("${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh")"
claude -p --model "$(jq -r .LIGHT     <<<"$POOL")" "[fully self-contained task prompt]" &
claude -p --model "$(jq -r .STANDARD <<<"$POOL")" "[fully self-contained task prompt]" &
wait
```

---

## Worker conduct block — embed verbatim in every dispatch

The block lives in `references/worker-conduct.md` — the single source of truth for all three call sites (here, the `orchestrator` skill's delegation contract, and `/review-queue`). Read it and paste its fenced block verbatim into every dispatch prompt, immediately before the return contract. Never paraphrase it, and never inline a second copy here — a divergent copy is how the two halves drift apart.

```bash
# installed as a plugin
cat "${CLAUDE_PLUGIN_ROOT}/skills/agent-selector/references/worker-conduct.md"
# raw checkout: CLAUDE_PLUGIN_ROOT is empty — resolve relative to this skill's own directory instead
```

DEEP- and FRONTIER-tier dispatches append the self-refutation rule documented there; LIGHT and STANDARD do not.

**Do not add self-verification instructions below DEEP tier.** Current models verify their own work and catch their own mistakes unprompted; at LIGHT/STANDARD a "refute your own result", "double-check your answer", or "re-verify before responding" step compounds with that native behaviour and spends tokens without improving the result. The single exception is the DEEP/FRONTIER self-refutation rule — at those tiers, adversarial self-checking is the frontier-model behaviour that prompts best, and it is scoped to them deliberately. The conduct block's *"never report success you haven't verified"* is a reporting-honesty rule about running the stated command and admitting failure — it is not a re-check pass, and it applies at every tier.

Genuine verification still belongs in a dispatch, but as **tool execution, not introspection**: the exact test and lint commands from the delegation contract, and project-specific checklists (tenant scoping, transaction boundaries) encoding knowledge the model cannot infer.

## Behaviour Notes

- **Never spawn without confirmation** — manifest first, approval second. *Exception:* when the triggering request itself authorises dispatch (names tiers or discovery, e.g. "use lower-tier subagents for discovery"), or the session is autonomous/non-interactive, show the manifest for transparency but proceed — explicit prior instruction counts as the confirmation, and a blocking gate in an autonomous session silently kills the task.
- **Model AND agent AND effort, always three** — no dispatch without a routed tier, a selected agent, and a pinned effort; a missing column of any kind is an incomplete manifest.
- **Tier and effort are orthogonal** — route them in separate passes. Never derive one from the other, and never treat the diagonal (cheap+low, premium+high) as the only valid pairings.
- **Flag, don't guess** — ambiguity is resolved with the user, not with a bigger model.
- **Deterministic before inferential** — if a task matches the routing table, its tier is settled; do not re-litigate.
- **Reuse context** — extract tasks from a plan already in the conversation rather than re-asking.
- **One-line tier reasons** — only for judgement-routed tasks; deterministic routes need no explanation.

---
The parallel-group write-set rule derived in concept from Builder.io's skills repo, MIT.
