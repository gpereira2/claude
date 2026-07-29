---
name: plan-arbiter
description: Arbitrates between two or more COMPETING plans for the same piece of work — typically produced by different agents, tools, or people — and produces one merged execution direction. Use when multiple plans, proposals, or strategies exist for the same task and a decision is needed between them. NOT for critiquing a single plan or document (use critical-reviewer for that) and NOT for splitting one agreed plan into tasks/agents (use agent-selector/orchestrator) — this skill only fires when plurality of plans is the premise.
---

# Plan Arbiter

Two or more plans for the same work rarely have one clean winner — usually each got something right that the other missed. The job is to merge them into a single direction, not to rank them and walk away.

**Boundary.** One plan to critique → `critical-reviewer`. One agreed plan to break into tasks → `agent-selector`/`orchestrator`. This skill only applies when the plans are actually competing alternatives for the same scope.

## 1. Collect the plans

Gather every candidate as text — pasted content, files, PR/issue descriptions, transcripts. Note who or what produced each one; that shapes what to check for later (an agent's plan may assume tools it doesn't have, a person's plan may skip steps they consider obvious).

## 2. Normalise onto comparable terms

Extract the same fields from every plan so they can be placed side by side:

- Objective and scope (what it actually solves — plans that look similar can target different boundaries).
- Concrete steps, in order.
- Files, modules, or interfaces touched.
- Assumptions and open questions it leaves unresolved.
- Validation approach — how it proves itself done.
- Rollback/reversibility if it goes wrong.

A plan that's long because it's thorough is not the same as a plan that's long because it's padded — normalising strips the difference in prose length so the comparison is on substance.

## 3. Score against the actual constraints

Judge each plan against the real environment, not against each other in the abstract:

- Does it match constraints that exist in this codebase/task (conventions, deploy windows, existing patterns) — check the real files/APIs it references, don't take its claims on faith.
- Is the sequencing safe (no step depends on a later step; risky/irreversible steps are late and gated)?
- Is the validation concrete (a specific test/command) or hand-wavy ("should work")?
- What does it cost to execute — time, tokens, number of moving parts — relative to the other plans?

Tie-break order when plans score closely: correctness against the real constraints, then safer/more reversible sequencing, then simpler first cut, then lower execution cost.

## 4. Identify what to graft from the loser(s)

Before discarding a weaker plan, extract anything in it that's better than the winner's equivalent — a smarter validation step, a safer rollback, a step it sequenced better. Name each grafted piece explicitly; don't silently blend everything into a "best of both" that can't be traced back.

## 5. Output one merged direction — not a ranking

The deliverable is a single execution plan, explicitly stated as such:

```md
Direction: <one plan, merged — not a leaderboard>

Chosen base: <which plan this builds from, and why>

Grafted in
- <specific step/idea>, from <other plan> — <why it's better>

Rejected
- <what was dropped>, from <plan> — <why>

Execution plan
1. ...
2. ...

Validation
- <concrete checks that prove it's done>

Open questions
- <anything still unresolved before execution starts>
```

If the plans are too far apart to merge (conflicting architectural premises), say that explicitly and name the one decision that has to be made first — don't force a merge that papers over a real disagreement.

---
Derived in concept from Builder.io's skills repo, MIT.
