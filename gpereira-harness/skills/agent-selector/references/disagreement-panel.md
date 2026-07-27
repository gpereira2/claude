# Disagreement panel (multi-judge adjudication)

The N-judge generalisation of dual-inference (see SKILL.md). Convene it when a **plan, design, or finding is complex AND contested** — the cost of a wrong call is high and a single reviewer (or a 2-model dual-inference) isn't enough. A panel of judges with **distinct adversarial personas** evaluate independently and in parallel; their *disagreement* is the signal, not noise to average away.

Tiers below are the harness tiers (`LIGHT` / `STANDARD` / `DEEP` / `FRONTIER`) resolved at runtime via `${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh` — never hardcode model IDs here or in a dispatch.

## When to convene

- An architecture / design decision with no obvious right answer (the agent-selector judgement tier).
- A plan whose approach is contested or far-reaching (orchestrator Phase 2/3).
- Final-review reviewers materially disagree on blocker-vs-not (orchestrator Phase 4).
- A migration, security boundary, or irreversible change where wrong = costly.
- **NOT** for tasks with one obvious correct answer, or pure mechanical work — a panel there just burns tokens and manufactures noise.

## The judges (5 by default)

Odd count avoids ties. Five captures ~90% of the independence you can realistically get; **3 is minimum viable, 7 is the ceiling** — beyond that, judges' shared blind spots dominate and extra votes add nothing. Each judge gets a **distinct adversarial focal lens** (a 2-sentence brief telling it what to attack), never a generic "evaluate quality" — holistic, agreeable judges systematically over-rate.

| Judge | Focal lens (adversarial — frame as "find why this fails") | Tier |
|---|---|---|
| Skeptic | Find every fatal flaw; assume it ships and breaks. What's the failure? | LIGHT |
| Risk / Security | Blast radius, tenant/isolation boundaries, auth/authz, mass assignment, data leaks, irreversibility. | STANDARD |
| Pragmatist | Simplest path that works. YAGNI — flag over-engineering, premature abstraction, unrequested scope. | LIGHT |
| Maintainer | 12-month code health: module boundaries, established patterns, coupling, naming, test coverage. | DEEP |
| Domain / User advocate | Correctness from the end-user's view; real workflows, edge cases, awkward data states. | STANDARD |

**Diversity is the whole point.** Spread judges across model *generations* (not just tiers) so they don't all share one model's blind spots — a previous-generation model in one seat is a feature, and `resolve-models.sh` can list versions within a family for exactly this.

> **Cross-provider ceiling (honest caveat).** All judges here are Claude — same-provider models have correlated errors (research shows even *cross-family* judges correlate ~0.6; same-family much more). Persona + generation diversity + adversarial framing is the independence you can get inside one provider. If you can reach other providers via API/MCP, diversifying provider families is the single biggest independence gain — do it there.

## Each judge returns (schema)

```json
{ "verdict": "APPROVE | REVISE | REJECT | ABSTAIN",
  "confidence": 0.0,
  "rationale": "why, in 2-4 sentences",
  "top_risks": ["..."],
  "blocking": true }
```

`ABSTAIN` is first-class — a judge that genuinely can't decide should abstain, not emit a noisy low-confidence vote.

## Aggregation — divergence gates the path

Compute the spread (std-dev of `confidence`, or the verdict split). **Don't force a majority vote on a contested call.**

| Divergence | Path |
|---|---|
| **Low** (tight agreement) | Confidence-weighted majority → done. |
| **Medium** | **Meta-judge** at a tier *above* the panel (DEEP, or FRONTIER for the hardest) reads all verdicts + rationales and *synthesises* — surfacing the disagreement, not averaging it. Use a stronger or different generation than the panel so it doesn't just rubber-stamp the majority. If your setup permission-gates the top family, ask before routing the meta-judge there. |
| **High** (or ≥2 `ABSTAIN`, or the meta-judge abstains) | One **anti-conformity debate** round, then **escalate to the user** with the meta-judge's disagreement summary. |

**Debate, if used:** exactly one round. Show each judge the others' rationales and instruct it to **state and defend its disagreement before reconsidering** — naive debate collapses correct minorities into the majority. Debate's value is surfacing divergence, not persuasion; never use it as the primary aggregation.

When judges **agree >95%**, treat it as a correlation signal (shared blind spot), not a quality signal — swap in a more divergent generation.

## Workflow-tool recipe

The panel is a textbook `parallel()` fan-out + reconcile pipeline — no human gate mid-flight, so a Workflow fits:

```javascript
const M = JSON.parse(POOL)   // from lib/resolve-models.sh, passed in via args
const JUDGES = [
  { persona: "skeptic",    lens: "Find every fatal flaw; assume it ships and breaks.",         model: M.LIGHT    },
  { persona: "risk",       lens: "Blast radius, isolation boundaries, auth, data leaks.",       model: M.STANDARD },
  { persona: "pragmatist", lens: "Simplest path; flag over-engineering and unrequested scope.", model: M.LIGHT    },
  { persona: "maintainer", lens: "12-month health: module boundaries, coupling, test cover.",   model: M.DEEP     },
  { persona: "advocate",   lens: "End-user correctness; real workflows and edge cases.",        model: M.STANDARD },
]
const verdicts = (await parallel(JUDGES.map(j => () =>
  agent(`You are the ${j.persona}. ${j.lens} Adversarially evaluate the artefact below.\n\n${ARTEFACT}`,
        { label: `judge:${j.persona}`, model: j.model, schema: VERDICT_SCHEMA }))))
  .filter(Boolean)

const spread = stddev(verdicts.map(v => v.confidence))   // plain JS, not an agent
if (spread <= 0.20) {
  // low → confidence-weighted majority, done
} else {
  const meta = await agent(
    `Reconcile these judge verdicts. Surface the real disagreement; do not average it. ` +
    `Recommend APPROVE/REVISE/REJECT or ESCALATE, with a 2-sentence rationale.\n${JSON.stringify(verdicts)}`,
    { model: M.DEEP, schema: META_SCHEMA })
  // spread > 0.35 (or meta.escalate) → present meta.summary to the user
}
```

Every `agent()` call pins `model` explicitly — a Workflow `agent()` with `model` omitted inherits the main-loop model, which would flatten the whole panel to one model and destroy the diversity the pattern depends on.

## Failure modes (mitigations are baked into the above)

- **Correlated errors** — same model ⇒ shared blind spots. Spread generations; >95% agreement is a correlation signal, not quality.
- **Agreeableness bias** — judges over-rate work matching their priors. Mitigated by adversarial ("find why it fails") framing, not "rate this".
- **Debate mode-collapse** — minority capitulates to the majority. Mitigated by the anti-conformity instruction + one round only.
- **Meta-judge homogenisation** — a meta-judge of the same generation as the panel majority rubber-stamps it. Put it a tier above.
- **Length / position bias** — judges favour longer or first-listed options. Keep judges rubric-bound; randomise option order in pairwise calls.

## Evidence basis

A panel of smaller diverse judges beats a single large judge at a fraction of the cost ([PoLL, arXiv 2404.18796](https://arxiv.org/abs/2404.18796)); diversity has a hard ceiling from correlated errors ([arXiv 2605.29800](https://arxiv.org/html/2605.29800)); distinct personas beat identical ones ([ChatEval, arXiv 2308.07201](https://arxiv.org/abs/2308.07201)); a meta-judge resists bias better than majority vote ([arXiv 2505.19477](https://arxiv.org/pdf/2505.19477)); escalate-don't-force on low confidence ([Trust-or-Escalate, ICLR 2025, arXiv 2407.18370](https://arxiv.org/abs/2407.18370)); confidence-weighted aggregation beats plain majority ([CISC, arXiv 2502.06233](https://arxiv.org/abs/2502.06233)).
