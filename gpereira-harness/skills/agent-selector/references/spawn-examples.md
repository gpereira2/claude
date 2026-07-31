# Spawn examples

In-session Claude Code spawns sub-agents with the **Agent tool** and runs deterministic fan-outs with the **Workflow tool** — not `claude -p` shell-outs (those start a fresh process and lose your CLAUDE.md / MCP / skills). Set `model` per the tier table; set `subagent_type` to the matching custom agent from your Agent & Skill Selection Guide when one fits (otherwise it defaults).

## Claude Code — Agent tool (parallel + serial groups)

Dispatch independent tasks **in a single turn** so they run concurrently. Gate the next group by dispatching it in a later turn whose prompt pastes in the prior group's results.

```
# Parallel group A — two independent tasks in ONE message → run concurrently
Agent(model: "claude-haiku-4-5",  prompt: "[task 1 — mechanical]")
Agent(model: "claude-sonnet-5", prompt: "[task 2 — standard, effort: medium]")

# Serial group B — dispatched AFTER A returns, with A's outputs in the prompt
Agent(model: "claude-opus-4-8",   prompt: "[task 3 — complex; context from A pasted in]")
```

- `run_in_background: true` for long tasks — you're notified on completion and keep working meanwhile.
- `isolation: "worktree"` **only** when parallel agents edit the same files (prevents conflicts; adds ~200–500ms + disk per agent).
- Each agent inherits CLAUDE.md / MCP / skills — don't re-state the environment.
- Effort is a session/Workflow-level setting inherited by sub-agents, not an Agent-tool arg — set it on the spawning context and note the target in the manifest.

## Claude Code — Workflow tool (deterministic fan-out)

When the group is a bounded, repeatable fan-out — a review panel, dual-inference, the disagreement panel — encode it as a Workflow script so control flow is code, not model-driven turns:

```javascript
// parallel() = barrier (awaits all, returns together; nulls on failure → filter)
// pipeline() = NO barrier between stages (item A can be in stage 3 while B is in stage 1)
const results = (await parallel(TASKS.map(t => () =>
  agent(t.prompt, { label: t.id, model: t.model, schema: RESULT_SCHEMA }))))
  .filter(Boolean)
```

Workflows run **headless to completion**, so use them only where there is no human approval gate mid-flight. For gated, group-by-group execution that pauses for the user, keep the Agent tool.

### Workflow schema discipline

Schema validation guarantees shape, not substance. When a recipe uses `agent({schema})`:

- **Brevity budget in the prompt.** Add an explicit OUTPUT DISCIPLINE block (per-string word caps, array-length caps). Most `StructuredOutput retry cap (5) exceeded` deaths are output-length failures against many-required-field schemas, not genuine shape mismatches.
- **Minimal required set.** Keep required fields few — optional properties plus prompt instructions beat a large required set a verbose model keeps failing.
- **Sanity-check the object before a downstream stage consumes it** (e.g. drop a plan with fewer than 2 actions). A validated-but-degenerate placeholder (`{title:"t",rationale:"r",philosophy:"test"}`) passes validation and then silently decides the outcome.
- **Guard comparative stages against degeneracy.** Treat a judge / panel / tournament stage as invalid if any candidate is degenerate or missing, and re-run rather than report the "winner" — an empty chair or a strawman lets the contest resolve against nothing.

## Claude Code — dual-inference

```javascript
// Two siblings run the same task in parallel; a strong model reconciles.
const [a, b] = await parallel([
  () => agent(TASK, { label: "inf-A", model: "claude-opus-4-8" }),
  () => agent(TASK, { label: "inf-B", model: "claude-opus-4-7" }),  // version-delta sibling
])
const verdict = await agent(
  `Compare and reconcile these two answers.\n## A\n${a}\n## B\n${b}`,
  { model: "claude-opus-4-8", schema: RECONCILE_SCHEMA })
```

The reconciler returns Agreement / Divergence / Confidence / Final Recommendation / Escalate-to-Human (schema in `references/dual-inference.md`). For the N-judge, diverse-persona generalisation, see `references/disagreement-panel.md`.

## Sub-agent prompt rules

- Embed the worker-conduct block (`references/worker-conduct.md`) **verbatim** in every dispatch, immediately before the return contract — never paraphrase it
- DEEP/FRONTIER-tier tasks additionally get the self-refutation step (rule 10 in the same file)
- Each prompt must be fully self-contained — assume no shared state beyond inherited CLAUDE.md / MCP / skills
- Include relevant codebase context explicitly
- For tasks depending on prior outputs, pass those outputs in the prompt
- One responsibility per agent — keep prompts focused
- Use a `schema` on Workflow `agent({schema})` when you need structured data back instead of prose (validated at the tool layer, so the model retries on mismatch)
- **Conventions the diff must satisfy** — add a line sourced from the user's standing preferences (memory / CLAUDE.md): closed value sets as backed enums, no vendor-specific identifiers, facades over helpers, and any other known convention. A green suite and an approving review don't cover preferences nobody encoded — so encode them, and tell review dispatches to enforce naming/typing conventions, not only security/correctness.
- **Dependency-manifest work** — when a task may touch `composer.json` / `package.json` / a lockfile, name the exact allowed operation (`composer require pkg`, `npm install pkg` — never blanket `update` / `--with-all-dependencies`) and require the worker to verify via lockfile diff that only the intended package and its new transitives moved, reporting any wider movement as `partial`. "Unblock yourself" (conduct rule 4) needs a blast-radius boundary: the narrowest state change that clears the blocker.
- **Doc-verification dispatches** — when a worker's verdict on external-doc compliance is load-bearing for a decision or a review severity, require it to quote the relevant doc passage verbatim, and cross-check the local-code side yourself. Subagents asked to validate X-against-Y reliably read Y (the docs) but skip X (the local code); the dispatcher must supply or verify X.

## Return contract (Agent/Task dispatch)

When you dispatch via the Agent/Task tool, embed a **return contract** so the main context parses structured data back instead of free-form prose. (The Workflow tool's native `schema` param does this for you — validated at the tool layer — so this section is for Agent/Task dispatches.)

- State the contract explicitly in the prompt as a fenced block.
- The subagent's **final message** must be a single line of JSON matching the schema; intermediate updates go above it, only the last line is parsed.
- **LIGHT-tier / async dispatches** — the JSON must be the VERY LAST thing emitted, with nothing after it: cheap-tier (Haiku) background workers tend to add filler turns (`Task complete.`, `Session ended.`) that the harness then surfaces as the result. Tell them: "if re-prompted after you have already emitted the JSON, repeat it verbatim rather than acknowledging." For LIGHT-tier background runs, prefer a schema-enforced Workflow `agent({schema})` (validated at the tool layer) over relying on final-message positioning.
- **On resume after completion** — a worker re-notified or resumed after finishing its work must re-emit the FULL populated contract JSON, never an empty-array acknowledgement (`"task already complete, ending turn"`). Agents treat post-completion wakeups as no-ops and default to empty; state the resume behaviour in the contract. For investigation-type dispatches, make disk persistence part of the contract — write the deliverable to a named file and return its path in the JSON — so the artefact is recoverable even when a resume returns empty.
- **Idle is not delivery** — a background worker going idle/available is a completion *signal*, not proof its contract arrived: the final-message slot can be empty or carry stray filler (a "hello test", a "complete and delivered" line) instead of the JSON. Treat completion and delivery as separate events. If an idle worker's contract never surfaced, recover cheaply — a SendMessage ping ("resend your final JSON verbatim") retrieves it without re-running the work; re-dispatching from scratch is wasteful and non-idempotent. (Orchestrators with a task output-file should read the last contract match from that transcript first — cheaper still, no agent resume needed.)
- Required keys are always present — unknown values are `null`, never omitted.
- On failure, the subagent still returns the contract — `status: "failed"` for attempted-but-couldn't-complete (with `tests.failure_tail` populated), `status: "blocked"` with a `blocker` string when something outside its reach is needed. No free-form failure messages.

**Default schema** — extend with task-specific fields (`pr_url`, `migration_name`, `inspections_clean`, etc.), keeping all base keys present even when unused:

```json
{"task_id":"<id from task list>","status":"ok|partial|blocked|failed","summary":"<one-sentence outcome>","files_changed":["<path>"],"commands_run":["<cmd>"],"tests":{"ran":true,"passed":true,"command":"<cmd>","failure_tail":null},"assumptions":["<decision made without asking>"],"blocker":null,"followups":["<note>"]}
```

**Status semantics (enforced):**

- `ok` requires `tests.ran: true`, or an explicit reason in `summary` why verification was impossible — no unverified success.
- Any silent gap (a sub-item skipped, a check not run) means `partial`, never `ok`.
- `failed` = attempted and could not complete; feeds the escalation cascade. `blocked` = needs something outside the worker's reach, named in `blocker`.
- On failure, `tests.failure_tail` carries the last ~15 lines of failing output; the escalation retry consumes this as evidence, never the transcript.

End every dispatching prompt with the conduct block (`references/worker-conduct.md`), then:

> **Return contract** — your final message must be exactly one line of JSON matching this schema. No prose after it.
> ```
> {schema here}
> ```

## Claude.ai Teams — manifest only

Output the manifest as a structured JSON block the Teams workflow engine consumes:

```json
{
  "plan": "[original plan summary]",
  "tasks": [
    {
      "id": 1,
      "description": "[task]",
      "tier": "mechanical",
      "model": "claude-haiku-4-5",
      "effort": null,
      "tools": [],
      "depends_on": [],
      "run": "parallel"
    },
    {
      "id": 2,
      "description": "[task]",
      "tier": "complex",
      "model": "claude-opus-4-8",
      "effort": "xhigh",
      "tools": [],
      "depends_on": [1],
      "run": "serial"
    }
  ],
  "groups": [
    { "group": "A", "tasks": [1], "run": "parallel" },
    { "group": "B", "tasks": [2], "run": "serial", "after": "A" }
  ]
}
```
