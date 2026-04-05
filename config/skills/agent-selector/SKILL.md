---
name: agent-selector
description: Analyses a plan or feature request and breaks it into discrete TODO steps, assigns each step to the optimal Claude model and tier based on complexity, then either spawns them as parallel subagents (Claude Code) or produces a structured task manifest (Claude.ai Teams). Use this skill whenever the user says "split this into agents", "assign this to models", "parallelise this plan", "which model should do what", "break this into tasks", "optimise model usage", or shares a plan and wants it executed efficiently across multiple Claude instances. Always prefer this skill over manual task breakdown when cost efficiency and parallelisation matter.
---

# Agent Selector

Analyse a plan, break it into discrete TODOs, assign each to the optimal model tier, then either spawn subagents or produce a manifest — depending on the environment.

## Step 1: Environment Detection

Before anything else, detect the execution context:

- **Claude Code** → spawn subagents via `claude -p --model <model>` for each task
- **Claude.ai Teams** → produce a structured JSON/Markdown manifest for the Teams workflow engine
- **Ambiguous** → ask the user which environment they're targeting

## Step 2: Plan Analysis

Read the full plan before doing anything. Identify:
- Discrete, atomic units of work (each TODO should be completable independently)
- Dependencies between tasks (which must run serial vs parallel)
- Ambiguous or underspecified tasks (flag these before assigning — don't guess)

## Step 3: Task Assignment

Assign each TODO to a tier using the table below. Default to **Standard** when uncertain — never under-power a task to save tokens.

### Tier Reference

| Tier | Model | Tools | Assign When |
|---|---|---|---|
| 🟢 **Mechanical** | `claude-haiku-4-5` | none | Boilerplate, renaming, formatting, simple CRUD, migration files, config updates, basic test generation from already-designed logic |
| ⚫ **Ops** | `claude-haiku-4-5` | bash, fs | Running scripts, file I/O, grepping logs, moving files, triggering deploys, repetitive CLI tasks — no reasoning needed |
| 🔵 **Research** | `claude-sonnet-4-6` | web_search | Unfamiliar libraries, CVE checks, latest docs, exploring options before deciding, dependency audits |
| 🟡 **Standard** | `claude-sonnet-4-6` | none | Feature implementation from clear spec, refactoring, writing docs, debugging known issues, API integration from docs, Docker/CI config |
| 🟠 **Review** | `claude-sonnet-4-6` | codebase | Code review, security audit of existing code, test coverage analysis, dead code detection, PR summaries |
| 🩵 **Test Architect** | `claude-sonnet-4-6` | codebase | Designing test strategy, writing integration/e2e tests, mocking complex dependencies, test data factories |
| 🟤 **Data** | `claude-sonnet-4-6` | fs, code_exec | Schema design, query optimisation, seed generation, data transformations, ETL logic |
| 🔴 **Complex** | `claude-opus-4-6` | none | Architecture decisions, ambiguous specs, designing new systems, cross-service data flow, anything where the *approach* is unclear |
| 🔶 **Security** | `claude-opus-4-6` | codebase, web_search | Threat modelling, auth flow review, secrets scanning, OWASP checks, pen test planning |
| 🟣 **Orchestrator** | `claude-opus-4-6` | subagents | Breaking down epics, resolving inter-task dependencies, sequencing parallel vs serial work, merging outputs from other agents |

### Assignment Heuristic

> If the TODO has a single obvious implementation path → Haiku or Sonnet.
> If a skilled engineer would need to *think before starting* → Opus.
> If it's pure shell execution with no reasoning → Ops/Haiku.
> When in doubt → Standard/Sonnet. Never under-power.

## Step 4: Output

### Format — Task Manifest

Always produce the manifest first, regardless of environment. Show it to the user for confirmation before spawning anything.

```
## Task Manifest

| # | Task | Tier | Model | Tools | Depends On | Run |
|---|------|------|-------|-------|------------|-----|
| 1 | [task description] | 🟢 Mechanical | haiku-4-5 | none | — | parallel |
| 2 | [task description] | 🟡 Standard | sonnet-4-6 | none | — | parallel |
| 3 | [task description] | 🔴 Complex | opus-4-6 | none | #1, #2 | serial |

**Parallel groups:**
- Group A (run together): #1, #2
- Group B (after A): #3

**Estimated token efficiency:** [X% cheaper than running all tasks on Opus]
```

Always include:
- Dependency chain
- Parallel groupings
- A rough token efficiency note (qualitative is fine)

### Flagged Items

Before the manifest, list any tasks that are too ambiguous to assign:

```
⚠️ Needs clarification before assignment:
- "[task]" — unclear whether this requires new architecture or extends existing. Which?
```

Resolve these with the user before proceeding.

## Step 5: Execution

### Claude Code — Spawn Subagents

After user confirms the manifest, spawn each group in order:

```bash
# Parallel group A
claude -p --model claude-haiku-4-5 "[task 1 full prompt]" &
claude -p --model claude-sonnet-4-6 "[task 2 full prompt]" &
wait

# Serial group B
claude -p --model claude-opus-4-6 "[task 3 full prompt with context from A outputs]"
```

**Rules for subagent prompts:**
- Each prompt must be fully self-contained — no shared state assumed
- Include relevant codebase context explicitly in the prompt
- For tasks depending on prior outputs, pass those outputs in the prompt
- Keep prompts focused — one responsibility per agent

### Claude.ai Teams — Manifest Only

Output the manifest as a structured JSON block the Teams workflow engine can consume:

```json
{
  "plan": "[original plan summary]",
  "tasks": [
    {
      "id": 1,
      "description": "[task]",
      "tier": "mechanical",
      "model": "claude-haiku-4-5",
      "tools": [],
      "depends_on": [],
      "run": "parallel"
    }
  ],
  "groups": [
    { "group": "A", "tasks": [1, 2], "run": "parallel" },
    { "group": "B", "tasks": [3], "run": "serial", "after": "A" }
  ]
}
```

## Behaviour Notes

- **Never spawn without confirmation** — always show the manifest and wait for user approval first
- **Flag blockers** — if a task is ambiguous, don't guess the tier, ask
- **Merge outputs** — if running in Claude Code, after all agents complete, offer to run an Orchestrator-tier agent to merge and review the combined output
- **Reuse context** — if the plan was produced in this conversation, extract tasks directly from it rather than asking the user to re-describe
- **Token transparency** — always explain *why* a task got its tier, briefly, so the user can override