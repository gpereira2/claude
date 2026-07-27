---
name: monday-harness-sync
description: Weekly Monday sync between the live user-level harness and the portable plugin — picks up whatever the Friday task-observer review changed and propagates it per-hunk. Register as a scheduled routine (see docs/ROUTINES.md); not auto-loaded as a session skill.
---

Reconcile the live user-level harness with the portable plugin copy. This is a
standalone run with **no prior conversation context**, so every step is explicit.

**Why Monday.** The `weekly-skill-observation-review` routine runs Friday and
edits skills under `~/.claude/` in place. Those edits are the week's real
learnings, and they land only on the live side. Monday picks them up while the
reasoning is still recoverable from the observation log, and before a second
week of drift makes the classification ambiguous.

## Directories

- **Live harness:** `~/.claude` — skills, agents, hooks, commands.
- **Plugin:** `$CLAUDE_HARNESS_PLUGIN_DIR`, falling back to the plugin root that
  contains this routine. Resolve it once and report which path you used.
- **Observation log:** `~/.claude/skill-observations/log.md`, with cross-cutting
  principles in `principles.md` alongside it.

If the plugin directory cannot be resolved, stop and report — do not guess.

## Procedure

1. **Read `routines/harness-sync/SKILL.md` in the plugin and follow it.** That
   file is the authority on how to reconcile; this routine only schedules it and
   bounds what may be changed unattended. Do not re-derive the method.

2. **Read the week's observations first.** Everything in the log marked ACTIONED
   since the previous Monday run is the candidate set — those are the entries the
   Friday review applied to the live side. An ACTIONED observation whose change
   is missing from the plugin is a `live → plugin` candidate; the log entry is
   also where the *reasoning* comes from, which the port must carry.

3. **Classify every difference** into `live → plugin`, `plugin → live`, or
   stays-private, per harness-sync Step 1. Never bulk-copy in either direction:
   the two sides are different lineages, and a copy silently reverts whatever the
   other side learned most recently.

4. **Apply only the clearly-safe changes.** Additive, low-risk ports go in
   directly: a new hook, a new principle, a sharpened instruction, a corrected
   path. Anything that restructures a skill, renames a routing tier, deletes
   content, or changes a guard's verdict shape is **staged, not applied** — write
   it to `~/.claude/skill-updates/YYYY-MM-DD/plugin-sync/` with a one-line note
   on what it would change and why it needs a human.

5. **Never delete, never commit, never push.** Leave the plugin working tree
   dirty for review. Deletions and anything previously held back by the user are
   reported as decisions with a recommendation, not actioned.

6. **Carry the reasoning.** Per harness-sync Step 4, each ported item records the
   failure that motivated it, the date verified, and what was deliberately left
   out. A ported mechanism without its discovery gets deleted as
   over-engineering, or re-broken identically.

7. **Verify.** Run the plugin's `test/smoke.sh` (sanity checks, leak gate,
   behavioural guard checks) and any hook self-tests. Then close the batch with
   an **independent** check — `git -C <plugin> diff --stat` and a grep for a new
   sentinel string — rather than trusting the edit results (principles #2, #9).

8. **Record the run.** Write today's date to
   `~/.claude/skill-observations/last-plugin-sync.txt` so the next run knows its
   window. If the file is absent, treat the window as the last 7 days.

## Report

Finish with a short summary, in this order:

- Plugin directory used, and the observation window covered.
- What moved `live → plugin`, and what moved `plugin → live`.
- What was staged for human review, and where.
- What stayed private, and why (so it is not re-litigated next week).
- Verification result: smoke gate pass/fail, and the `diff --stat`.
- Anything still undecided.

If nothing drifted, say so in one line. A quiet week is a valid outcome and
needs no manufactured changes.

## Bounds

Read-mostly. This routine edits only files under `~/.claude/` and the resolved
plugin directory, and touches no project repository. It runs unattended, so when
a judgement call is genuinely close, stage it and report rather than deciding.
