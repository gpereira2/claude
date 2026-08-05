# Writing for agents

The authoring standard for every document an agent in this harness consumes — a `SKILL.md`, an agent or command definition, a `references/` file, `AGENTS.md` / `CLAUDE.md`, anything reached by a pointer. The packaging differs; the writing does not. The same levers make each one predictable: the agent takes the same *process* every run, rather than producing the same output.

Adapted from Matt Pocock's [`writing-for-agents`](https://github.com/mattpocock/skills) skill (MIT).

## Context pointers

A **context pointer** names out-of-context material and encodes the condition for reaching it — a skill's `description`, a line in `AGENTS.md` naming a doc. The pointer's *wording*, not its target, decides when the agent reaches the material, and how reliably. A must-have target behind a weak pointer is a variance bug: sharpen the wording first; inline the material only if that fails.

A pointer does two jobs — say what the material is, and list the **branches** that trigger reaching it. Every word of an always-loaded pointer costs on every turn:

- **Front-load the leading word** — the pointer does its triggering work there.
- **One trigger per branch.** Synonyms renaming one branch are one branch written twice; keep only genuinely distinct branches.
- **Cut identity the body already carries.**

## The two loads

Every document and pointer spends one of two budgets:

- **Context load** — always-loaded material on the agent's window (a skill description, an `AGENTS.md` line): tokens and attention spent every turn whether or not it fires.
- **Cognitive load** — the cost on the human of remembering which documents exist and when to reach for each. Not a cost to minimise blindly — it's the price of human agency. Spend it where judgement matters; remove it where it doesn't.

Material behind a pointer escapes context load at the price of the pointer's line. Material with no pointer rides entirely on cognitive load.

## Information hierarchy

Content is **steps** (ordered actions) and **reference** (facts consulted on demand), mixing freely. The decision is where each piece sits on a ladder ranked by how immediately it's needed:

1. **In-file step** — what the agent does, in order.
2. **In-file reference** — consulted on demand; often a legitimately flat peer-set (every rule of a review on one rung).
3. **Disclosed reference** — pushed to a separate file behind a pointer, loaded only when the pointer fires.

**Progressive disclosure** is the move down the ladder so the top stays legible. Branching is the test: inline what every branch needs; push behind a pointer what only some branches reach. **Co-location** is the within-file companion — keep a concept's definition, rules, and caveats under one heading so reading one part brings its neighbours. **Sprawl** is the failure mode: a document too long even when every line is live; the cure is the ladder.

## Completion criteria

Every step ends on the condition that tells the agent the work is done. Two properties make it a lever:

- **Clarity** — can the agent tell done from not-done? A vague bound ("understanding reached") invites premature completion. Sharpen the bound first; only split the sequence across a real context boundary (a hand-off or subagent) if it's irreducibly fuzzy.
- **Demand** — how much it requires. "Every modified model accounted for" forces more legwork than "produce a change list". Demand binds flat reference too ("every rule applied"), which is how an all-reference document still carries an exhaustiveness bar.

The strongest criteria are both checkable and exhaustive.

## Leading words

A **leading word** is a compact concept already in the model's pretraining that the agent thinks with while running the document (*seam*, *tracer bullet*, *red*, *tight*). Repeated as a token — never spelled out as a sentence — it anchors a whole region of behaviour in the fewest tokens by recruiting priors the model holds. It anchors twice: in the body it makes the agent reach for the same behaviour every time; in a pointer it links shared language across prompts, docs, and code so the material is reached more reliably. Reach for an existing word before coining one — a made-up word recruits no priors.

**Negation** is the failure mode beside it: steering by prohibition drags the forbidden behaviour into context and makes it *more* available. Prompt the **positive** — state the target behaviour so the banned one is never spoken. Keep a prohibition only as a hard guardrail you can't phrase positively, and even then pair it with the positive target.

## Pruning

- **Single source of truth.** Keep each meaning in one authoritative place; duplication costs maintenance and tokens and inflates a meaning's apparent rank.
- **The environment is a source of truth.** `package.json` scripts, config, directory layout, `--help` — a document restating them is a cache that goes stale. Cache only what the agent can't find by looking: the unwritten convention, the reason behind a choice, the gotcha no config confesses.
- **Relevance.** Every line must still bear on what the document does. Without a pruning discipline the default fate is sediment — stale layers that settle because adding feels safe and removing feels risky.
- **No-ops.** Hunt sentence by sentence for instructions the model already obeys by default; they pay load to say nothing. When one fails the test, delete the whole sentence. The same test grades leading words: one too weak to beat the default ("be thorough") is a no-op — the fix is a stronger word ("relentless"), not a different technique.

## Skill mechanics — invocation

When the document is a skill, one extra choice trades the two loads:

- **Model-invoked** — keep a `description`, so the agent can fire it autonomously and other skills can reach it. The description is a permanent context-load pointer; write it with the pointer rules above. Choose this only when the agent (or another skill) must reach it on its own.
- **User-invoked** — set `disable-model-invocation: true`. Zero context load; the `description` becomes a human-facing one-liner with triggers stripped. You are the index that remembers it exists. Choose this when it only ever fires by hand.

When user-invoked skills multiply past what you can remember, a **router skill** (one user-invoked skill naming the others and when to reach for each) cures the piled-up cognitive load.
