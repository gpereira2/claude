# Dual-Inference

> The **2-judge special case** of the disagreement panel (`disagreement-panel.md`). Use dual-inference for a second independent take on a *single task*; use the full panel when a *plan or decision* is complex **and** contested.

Use this pattern when a task is **both**:
- **Complex** — a skilled engineer would need to think before starting, AND
- **Critical** — getting it wrong has meaningful cost (data loss, security boundary, irreversible migration, core architecture decision)

## How it works

Split the task into two sibling tasks with identical prompts but **different models**. The orchestrator picks the two models independently — any combination from the full pool is valid. Run them in parallel, then reconcile:

```
Task N-a: [description] — inference A → <model A>
Task N-b: [description] — inference B → <model B>
Task N+1: Reconcile N-a and N-b           → claude-opus-4-8 (Orchestrator tier)
```

The reconciliation agent compares both outputs and produces a structured report:

```
## Reconciliation Report

### Agreement (high confidence — proceed)
- [points both agreed on]

### Divergence (requires resolution)
- [point A said X, B said Y] — recommended resolution: [merged view or escalate]

### Confidence Score
[0–100] — based on agreement ratio

### Final Recommendation
[merged output ready for downstream use]

### Escalate to Human
[yes/no] — yes if any divergence cannot be confidently resolved
```

Downstream agents consume `Final Recommendation` directly. The orchestrator uses `Escalate to Human` to decide whether to pause the pipeline.

## Model pairing

| Scenario | Inference A | Inference B | Why |
|---|---|---|---|
| Critical architecture, cost matters | `claude-sonnet-5` | `claude-opus-4-8` | Different capability levels — divergence is meaningful |
| Security boundary, highest confidence | `claude-opus-4-8` | `claude-fable-5` ⚠️ | Both top-tier; disagreement = genuine ambiguity (Fable 5 is permission-gated — ask first) |
| Complex feature, version delta | `claude-opus-4-8` | `claude-opus-4-7` | Sibling generations; the version gap surfaces edge cases |
| Ambiguous spec, exploring approaches | `claude-opus-4-8` | `claude-opus-4-6` | An older sibling may take a different, simpler path |

## When NOT to use

- Task is ambiguous — clarify first; don't double the noise
- Task has one obvious correct answer — duplicate inference adds cost with no signal
- Pure mechanical / ops work — disagreement carries no useful signal
- Latency is the hard constraint — reconciliation adds a serial step

## Manifest representation

```
| N-a | [task] — inference A | 🔁 Dual-Inference | <model-a> | ... | —          | parallel |
| N-b | [task] — inference B | 🔁 Dual-Inference | <model-b> | ... | —          | parallel |
| N+1 | Reconcile N-a / N-b  | 🟣 Orchestrator   | opus-4-8  | none | #N-a, #N-b | serial   |
```
