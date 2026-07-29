---
name: agent-watchdog
description: Audits work produced by a DIFFERENT agent, tool or person — another CLI's session, a teammate's handover, a pasted run summary — against the original ask, checking for drift from the brief and unverified completion claims rather than code style. Requires an explicit second-actor signal in the request itself: "check what the other agent did", "audit this handover", "did that tool actually finish it", "it says it's done, verify that", "reconcile these two accounts of the same work". A request to review a diff, branch or PR with NO such signal is not this skill — that is code-review or a review skill. Stress-testing a single plan or document is critical-reviewer. The presence of the words "PR" or "branch" is never on its own enough to select this skill.
---

# Agent Watchdog

A second agent's summary of its own work is a claim, not evidence. This skill re-derives the brief, then checks the claim against what actually changed — independently, by running things.

**Boundary.** If the work is yours, or there is one document/plan to critique, this is the wrong skill — use `code-review`/a review skill or `critical-reviewer`. This skill only fires when a *separate* agent or tool produced the artefact under audit.

## 1. Establish the original ask

Reconstruct the brief before looking at what was done — never read the other agent's summary first, or its framing becomes the anchor.

- Pull the actual request: the ticket/issue, the original prompt, the PR description's stated intent, or the user's own wording of what they asked for.
- Note explicit constraints (scope limits, "don't touch X", required approach) and implicit acceptance criteria (tests pass, no regressions, matches existing patterns).
- If the ask is only available as a paraphrase inside the other agent's own transcript, say so — that's a weaker source, not a substitute for the real one.

## 2. Extract what the other agent claims

Read its final summary, PR description, commit messages, or handover note. List every discrete claim ("added tests", "fixed the race condition", "verified in the browser") as a separate item — don't accept a bundled "done, all good".

## 3. Verify independently — run things, don't read summaries

For each claim, find primary evidence rather than trusting the narration:

- Read the actual diff, not the description of the diff.
- Run the tests it claims to have added or fixed. A claimed-passing suite that you haven't run is unverified, full stop.
- Check for a test that would fail if the claimed fix were reverted — no such test means the claim is unproven, not proven.
- Re-run any command it claims to have run (build, lint, migration) and compare output.
- For UI claims, load the page/screen yourself rather than accepting a description.
- Check CI status directly rather than trusting "CI is green" in a summary.

## 4. Classify every finding

Bucket each item — don't leave a flat list:

- **Drift** — work diverges from the original brief (extra scope, different approach than asked, silently dropped requirement).
- **Incomplete** — part of the brief was never attempted.
- **Unverified claim** — the agent said it was done/passing/fixed but you found no evidence it checked, or couldn't reproduce the check.
- **Genuine defect** — a real bug or regression, independent of whether it was claimed to work.

A finding with no evidence you personally gathered doesn't belong in the report.

## 5. Report

Lead with the verdict, then the evidence:

```md
Verdict: <matches brief / drifted / incomplete / claims unverified — pick the dominant one>

Original ask
- <brief, source>

Claimed
- <what the other agent said it did>

Verified
- <what you independently confirmed, and how>

Findings
- [drift] ...
- [incomplete] ...
- [unverified-claim] ...
- [genuine-defect] ...
```

Never present a finding as fact if you only inferred it from prose — say "unverified" instead.

---
Derived in concept from Builder.io's skills repo, MIT.
