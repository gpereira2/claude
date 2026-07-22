---
name: agent-selector
description: Breaks a plan or feature request into discrete tasks and routes each to the cheapest Claude model tier that can handle it AND to the right agent definition (named agents, built-in types, or plugin agents), using deterministic rules first and judgement only for ambiguous cases. Produces a task manifest with parallel groups, dependencies, per-task agents, and per-task return contracts, then spawns subagents. Also trigger on "which agent should run this", "pick an agent and model", "route this to agents", "split this into agents", "parallelise this plan", "which model should do what", "break this into tasks", "optimise model usage". Always prefer this over manual task breakdown when cost efficiency and parallelisation matter.
---

# Agent Selector

Route each task to the **cheapest tier that can handle it**, escalate on failure, and keep the routing itself nearly free: a lookup table costs zero tokens; an LLM judgement call costs one inference; dual-inference costs three. Spend in that order.

**Every dispatch selects two things, never one: a model tier AND an agent definition.** No subagent or Workflow task is spawned with only a model — the agent (named agent from `agents/`, built-in type, or plugin agent) determines the system prompt, tool allowlist, and return contract the worker runs under. A model without an agent is an unscoped worker; an agent without a routed tier is an unpriced one.

## Model Pool — families, never pinned versions

Tiers map to model **families**. The concrete model ID is always *the latest available version in that family*, resolved at runtime — this skill never hardcodes a version, so it never goes stale when a new Sonnet or Opus ships.

| Tier | Family | Default tools | Purpose |
|---|---|---|---|
| ⚡ **FAST** | haiku | task-scoped only | Mechanical work and ops — no reasoning required |
| 🟡 **STANDARD** | sonnet | task-scoped | Implementation, refactoring, tests, debugging known issues, research |
| 🔴 **DEEP** | opus | task-scoped | Architecture, ambiguous specs, security, plan writing/review, reconciliation |
| 🚀 **FRONTIER** | fable (fallback: opus) | any | Long-horizon autonomous work, self-verifying tasks, cases where DEEP has already failed |

> **FAST ≠ premium "fast mode".** FAST resolves to Haiku — the cheapest model in the pool. It is unrelated to any session-level "fast" toggle that runs a premium model with faster output; this router never selects that for any tier.

### Resolving model IDs — `${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh`

Run once at the start of a pipeline and cache the result for the whole run:

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh"          # {"FAST":...,"STANDARD":...,"DEEP":...,"FRONTIER":...}
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh" DEEP     # single tier → one model ID
```

The resolver queries the Anthropic Models API and picks the newest live model whose ID matches each tier's family pattern in `lib/tiers.json`; when the API is unreachable (or the key can't see that family — e.g. FRONTIER/Fable on a key without access), it uses the pinned `fallback`. Retune which family a tier maps to by editing `tiers.json` alone.

> **Pinning an older version on hearsay — verify first.** Community claims that a previous point release is "leaner" or "more focused" for sub-agent work must be checked against official pricing and tokenizer notes before pinning; the fewer-tokens effect is usually a tokenizer-counting artefact, not a real cost saving. Stay on latest-in-family unless new evidence clears that bar.

**Where model references appear, in order of preference:**
1. **Named agents in `agents/`** — use alias frontmatter (`model: sonnet`), which tracks the family's latest automatically; the tool allowlist is enforced by configuration.
2. **Task tool / manifest dispatch** — use the resolved pool values.
3. **Headless `claude -p`** — pass explicit IDs from the resolver (aliases also work).

Tool scoping is least-privilege per task in the manifest (discovery: `Read, Grep, Glob`, no write; implementers: write to `$TICKET_WORKTREE` only).

---

## Step 1: Plan Analysis

Read the full plan. Identify:
- Atomic units of work — clear inputs, clear outputs, bounded file set, independently verifiable.
- Dependencies (serial vs parallel).
- Ambiguous tasks — **flag, don't guess**:

```
⚠️ Needs clarification before assignment:
- "[task]" — unclear whether this extends existing architecture or needs new design. Which?
```

## Step 2: Deterministic Routing (covers ~80% of tasks, zero inference cost)

Match the task against this table **first**. Only tasks that match no row proceed to Step 3.

| Task pattern | Tier |
|---|---|
| Migration file, config change, boilerplate, renaming, formatting, simple CRUD scaffold | ⚡ FAST |
| Shell execution, file I/O, grepping logs, moving files, worktree setup, repetitive CLI | ⚡ FAST |
| Test generation from already-designed logic | ⚡ FAST |
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

Every manifest row must resolve **four things**: the **agent type** (named / built-in / plugin), the **agent role** (what the worker is trusted to do — discovery, implementation, tests, review), the **agent file** (the `agents/<name>.md` path when a named agent is used; `—` for built-ins), and the **model** (from the resolved pool, or the agent file's frontmatter default). A row missing any of the four is not dispatchable.

After the tier is settled, select the **agent** the task runs as, in this precedence order:

1. **Named agents** (this plugin's `agents/`, then any project/global agents): use one whose description matches the task type — `discovery` for ticket/context gathering, `implementer` for scoped code changes, `test-writer` for coverage tasks, `reviewer` for diff gates. Named agents pin the tool allowlist and embed the conduct + return contract in their body — prefer them whenever one fits, because the contract is then structural, not pasted.
2. **Plugin/specialist agents** (e.g. a code-reviewer agent) when their speciality matches exactly.
3. **Built-in types** as fallback: `Explore` for read-only codebase search, `Plan` for design/planning, `general-purpose` for multi-step work no named agent covers.

**Tier vs agent-frontmatter precedence:** a named agent's `model:` frontmatter is its calibrated default — trust it when it agrees with the routed tier. When they disagree, the routed tier wins only on **escalation** (pass the model override at dispatch: Task tool `model`, Workflow `agent()` `opts.model`); never silently downgrade an agent below its frontmatter tier.

If no agent in any category fits a recurring task shape, that is a signal to **create a named agent** for it (flag in the manifest as a follow-up) — not to keep dispatching unscoped general-purpose workers.

### Judgement fallback (Step 3) — only for unmatched tasks

> Single obvious implementation path → FAST or STANDARD.
> A skilled engineer would need to *think before starting* → DEEP.
> When in doubt → STANDARD. Never under-power, never default to DEEP "to be safe".

Record a one-line reason for any judgement-routed task so the user can override.

## Step 3: Cascade Escalation (replaces most dual-inference use)

The default quality mechanism is **cheap-first, escalate-on-failure** — it costs extra inference only when something actually fails:

```
FAST → STANDARD → DEEP → FRONTIER → human
```

One retry per escalation, carrying a ≤150-word failure summary plus the returned `tests.failure_tail` evidence (never the failed transcript). Two failures at any single tier → human. This cascade is shared with the orchestrator's failure-escalation rules — do not define a different one.

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

## Step 4: Output — Task Manifest

Always produce the manifest and show it for confirmation before spawning anything.

```
## Task Manifest

| # | Task | Tier | Agent | Tools | Depends On | Run |
|---|------|------|-------|-------|------------|-----|
| 1 | Create renewals migration | ⚡ FAST | implementer | fs (worktree only) | — | parallel |
| 2 | RenewalService business logic | 🟡 STANDARD | implementer | fs (worktree only) | #1 | serial |
| 3 | Renewal flow architecture note | 🔴 DEEP | Plan (built-in) | read-only | — | parallel |

**Parallel groups** (max 3 concurrent per group):
- Group A: #1, #3
- Group B (after A): #2

**Routing**: {n} deterministic, {n} judgement-routed (reasons above), {n} dual-inference (user-approved)
**Agents**: every row names its agent; tasks left on `general-purpose` are listed with a one-line reason (and a named-agent follow-up if the shape recurs)
**Cost note**: [qualitative — e.g. "~70% of tasks on FAST/STANDARD vs an all-DEEP baseline"]
```

Rules:
- Max 3 tasks per parallel group — beyond that, summary-merging overhead exceeds the parallelism gain.
- Every task's dispatch prompt must embed the orchestrator's **delegation contract** (objective, return contract, tools/conventions, boundaries, context paths, verification commands, conduct) — see the `orchestrator` skill, Phase 4.
- Every task returns the standard **Return Contract** — the one-line JSON schema; artefacts to disk as paths, never inlined.
- Every dispatch embeds the worker-conduct block (below) verbatim; DEEP/FRONTIER tasks add its self-refutation step.

## Step 5: Execution

### Native subagents (preferred)

Dispatch via the Task tool, batching each parallel group into a single message. Pass the manifest's agent as `subagent_type` and the routed model only when overriding the agent's frontmatter (escalation). Prompts must be fully self-contained — no shared state; prerequisite outputs passed as artefact paths.

For Workflow-tool runs, `opts.agentType` from the manifest is still mandatory on every `agent()` call — but the model rule is **not** the same as the Task tool, and this is a common silent trap. The Task tool honours the agent's frontmatter model when `model` is omitted; a Workflow `agent()` call with `opts.model` omitted **inherits the main-loop model instead**, ignoring the manifest's per-task tier. So pin `opts.model` explicitly on every `agent()` call whenever (a) the manifest assigns a tier that differs from the main-loop model, or (b) a model gate is in force (e.g. a permission-gated family in your setup) — otherwise inheritance flattens every worker to the main-loop model, mis-tiers the fleet, and can propagate a gated model with no per-use approval.

Use headless `claude -p --model <model>` **only** for detached/background runs outside an interactive session (e.g. CI, cron):

```bash
POOL="$("${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh")"
claude -p --model "$(jq -r .FAST     <<<"$POOL")" "[fully self-contained task prompt]" &
claude -p --model "$(jq -r .STANDARD <<<"$POOL")" "[fully self-contained task prompt]" &
wait
```

---

## Worker conduct block — embed verbatim in every dispatch

```
Conduct:
- Lead with the outcome — the first line of your summary states what you found or changed, not what you did.
- Never report success you haven't verified: "ok" requires the stated test/verification command ran and passed. Still failing after two attempts → status "failed" with the last ~15 lines of output in tests.failure_tail — never "ok" with a caveat buried in the summary.
- Decide small, escalate big: for minor ambiguities pick the option consistent with existing code, record it in assumptions, and proceed. Scope-changing or destructive decisions → "blocked".
- Finish your turn — never end on a question or an unactioned "I'll…"; retry transient failures yourself.
- Write artefacts to disk and return paths, never file contents or a transcript.
```

**DEEP/FRONTIER tasks additionally get a self-refutation step:** *"Before returning, spend one pass trying to refute your own result — find the input, edge case, or assumption that breaks it. Report what you tried in `assumptions`."*

## Behaviour Notes

- **Never spawn without confirmation** — manifest first, approval second. *Exception:* when the triggering request itself authorises dispatch (names tiers or discovery, e.g. "use lower-tier subagents for discovery"), or the session is autonomous/non-interactive, show the manifest for transparency but proceed — explicit prior instruction counts as the confirmation, and a blocking gate in an autonomous session silently kills the task.
- **Model AND agent, always both** — no dispatch without a routed tier and a selected agent; a missing agent column is an incomplete manifest.
- **Flag, don't guess** — ambiguity is resolved with the user, not with a bigger model.
- **Deterministic before inferential** — if a task matches the routing table, its tier is settled; do not re-litigate.
- **Reuse context** — extract tasks from a plan already in the conversation rather than re-asking.
- **One-line tier reasons** — only for judgement-routed tasks; deterministic routes need no explanation.
