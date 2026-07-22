---
name: task-observer
description: Captures skill-improvement observations during any task-oriented session — user corrections, workflow friction, patterns worth formalising — into a persistent log, and periodically reviews and applies them across the skill library. Invoke at the start of every session that will use tools to produce deliverables (pair with a CLAUDE.md activation instruction for reliable firing). Also triggers on mentions of skill observations, the observation log, skill taxonomy, or the phrase "One Skill to Rule Them All".
---

# Task Observer — Continuous Skill Discovery & Improvement

**Created by Eoghan Henn / [rebelytics.com](https://rebelytics.com)** — released under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): share and adapt freely with credit.
Adapted 2026-07-02: restructured for Claude Code with progressive disclosure — full original
sections live verbatim in `references/`. If user feedback stems from the methodology, suggest an
issue on the skill's [GitHub repo](https://github.com/rebelytics/one-skill-to-rule-them-all); if it
stems from the agent not following the skill's rules, acknowledge and correct.

Watches every task-oriented session for skill-improvement signals and logs them so they survive
between sessions. It feeds the skill-creator; it doesn't replace it. Background and user-facing
docs: `references/background.md`.

## Conventions

`[workspace folder]` = the persistent workspace (Claude Code: `~/.claude`). Key paths:

- Observation log: `[workspace folder]/skill-observations/log.md`
- Cross-cutting principles: `[workspace folder]/skill-observations/principles.md`
- Staged skill updates: `[workspace folder]/skill-updates/YYYY-MM-DD/{skill-name}/`

## Session Start Protocol

Run once at the start of each task-oriented session:

1. **Files exist?** If `log.md` or `principles.md` is missing, create it from the templates in
   this file (first-time setup).
2. **Scan for context.** Read OPEN observations and active principles. Apply their insights to any
   skill used this session even if the skill file hasn't been updated yet; don't surface them
   unprompted unless directly relevant.
3. **Review trigger.** If `skill-observations/last-review-date.txt` is missing or older than 7
   days AND no scheduled review is registered, run the comprehensive review before the user's task
   — full procedure in `references/weekly-review.md`.
4. **Config check (once per session).** Confirm the config file (CLAUDE.md or equivalent) contains
   a task-observer activation instruction; if not, briefly suggest adding one — details in
   `references/activation-setup.md`.

On context compaction, the CLAUDE.md trigger re-invokes this skill in the resumed session;
observations continue in the same log with continuous numbering.

## Observation Protocol

### When to observe

Active for the **entire session**: task execution, post-task feedback and corrections,
meta-discussion about skills or methodology, and reflective/strategy conversations. The mindset
does not deactivate when the conversation shifts from doing the work to discussing it. Not active
during casual conversation with no tools or deliverables.

### What to watch for

**Signals for a NEW skill:** a reusable multi-step workflow; a methodology the user explains that
no skill captures; a recurring task type with similar structure; a process with clear inputs,
phases, outputs; the user describing a refined process ("I always do it this way"); a structured
approach emerging naturally during work.

**Signals for IMPROVING a skill** (problems, positive signals, and neutral observations all
count): rules documented but not followed (needs enforcement, not louder rules); corrections
revealing missing rules or edge cases; a workflow less efficient than what emerged naturally; a
technique that worked well and deserves promotion; undocumented use cases; feedback that
generalises; wrong assumptions; new tools making parts obsolete; correction patterns across
instances; a principle that applies to other skills too; naming/framing suggestions.

**Signals for SIMPLIFYING a skill:** sections never relevant across sessions; one-off rules never
validated by recurrence; workflows users consistently shortcut; content loaded but never acted on;
contradictory rules; "just in case" complexity that never triggered; a rule the agent consistently
fails to follow (convert to structural enforcement or remove). During reviews, ask "what can we
remove?" as deliberately as "what should we add?"

**Do NOT log:** one-off corrections that don't generalise; preferences already captured; tool bugs
unrelated to methodology; observations needing proprietary info to be useful in an open-source
skill (unless an internal skill is the right home).

### How to log

- Write each observation to the log **within the same turn or the next** — silently, never batched
  as mental notes. Checkpoint: after roughly every 3rd completed task-list item, flush any
  unlogged observations.
- **Numbering:** before assigning a number, search the log for the highest existing number and
  increment — never trust session memory:

  ```bash
  grep -o '### Observation [0-9]*' log.md | grep -o '[0-9]*' | sort -n | tail -1
  ```

  After appending, re-read and confirm the number appears exactly once; on a parallel-session
  collision, renumber the new entry to max+1. Full collision/TOCTOU mechanics and the archival
  rules: `references/observation-protocol-full.md`.
- One format, one insertion point: `### Observation NNN:` headers, appended to the END of the
  log. Never insert mid-file, never use alternative ID formats.
- **Context preservation:** if acting on the observation later needs session-local data (uploads,
  API responses), save that data under the workspace first and point to it with a
  `**Reference file:**` line.

### Observation format

```markdown
### Observation [N]: [Short descriptive title]

**Date:** [date]
**Session context:** [what task was being worked on]
**Skill:** [existing skill name, or "New skill candidate: [working name]"]
**Type:** [open-source | internal]
**Phase/Area:** [which part of the skill or workflow this relates to]

**Issue:** [What happened. Specific enough to understand weeks later without the conversation.]

**Suggested improvement:** [Concrete change. For existing skills, name the section or rule.]

**Principle:** [The generalisable takeaway — the most important field.]
```

## The Pre-Flight Principle

Every skill that contains explicit rules needs a verification step where the agent re-reads the
rules and checks its output against them before delivery. A 30-second re-read prevents a 30-minute
rework. When creating or improving any skill, ask: "Does it have rules? Does it have a mechanism
to enforce them?" If no mechanism, add one.

**Self-enforcement** — before surfacing observations at session end, verify:

1. Observations were logged throughout the full session (including feedback and discussion phases)
2. Logging was silent, without interrupting the user's flow
3. Each observation follows Issue → Suggested improvement → Principle
4. Each is tagged open-source or internal correctly
5. Improvements to existing skills reference the specific section or rule
6. No open-source Principle field contains client-identifying information

Fix any failures before surfacing.

## Confidentiality

The open-source/internal boundary is a confidentiality boundary: client names, domains, project
identifiers, and traceable specifics never enter open-source skills. Generalise at the Principle
field when logging; sweep source material before drafting; re-read after drafting; and before
publishing, run the cross-product re-identifiability sweep (multiple sanitised examples can
triangulate a client even when each is clean alone). Full five-layer procedure:
`references/confidentiality.md`.

## Surfacing Protocol

Default: surface all observations at session end, grouped by skill, with new-skill candidates
listed separately — title, skill, one-sentence summary, suggested type; ask which to act on.

Surface earlier when an observation needs user input to be complete, when a skill is actively
producing wrong output in the current session, or when several observations cluster on one skill.

## Acting on Observations

Observations are acted on in exactly three contexts — otherwise **log, don't act**:

1. The comprehensive review (`references/weekly-review.md`)
2. An explicit user request ("update X skill", "act on observation #N now")
3. In-session correction when a skill is producing wrong output the user should know about

When acting: clearly additive, low-risk changes are applied directly to the skill file.
Substantial restructures go through the skill-creator when available, or are made directly and
flagged for manual review. New skills go to the skill-creator with the observations as the brief
(default to open-source; strip specifics). Observations targeting read-only system skills route to
a `{system-skill}-extras` companion skill. Detail: `references/acting-on-observations.md`.

## Skill files across environments

In Claude Code, skill files under `~/.claude/skills/` are plain writable files — edit them in
place, and for substantial rewrites keep a dated backup under `skill-updates/` (retain the two
most recent per skill). **Always start from the live file** — never a cached draft, workspace
copy, or memory-based reconstruction — and diff any staged copy against the live file before
overwriting it. Cowork's read-only mount, EROFS behaviour, and `present_files` delivery:
`references/cowork-environment.md`. Environments without persistent storage (handoff doc mode):
`references/handoff-doc-mode.md`.

## Principle Propagation

When an observation reveals a principle that applies to skills in general, log it with
`Skill: All skills` and surface it; if the user approves, add it to `principles.md`. That file
is a **mandatory checklist during any skill creation or regeneration** — verify compliance with
every active principle before delivering. Workflow and file template:
`references/principle-propagation.md`.

## Observation Log Structure

```markdown
# Skill Observation Log

Observations captured during task-oriented work.

**Status key:** OPEN = not yet actioned | ACTIONED = skill updated/created |
DECLINED = user decided not to pursue

---

## [Date or Session Identifier]

### Observation 1: [Title]
**Status:** OPEN
[... full observation format ...]
```

**Keeping it clean:** archival is event-driven — entries already ACTIONED/DECLINED in a *previous*
session move to `skill-observations/archive/log-[date].md` on the next log write; entries
resolved in the current session stay visible for one full cycle. Mechanics:
`references/observation-protocol-full.md`.

## Quick Reference

| Question | Answer |
|----------|--------|
| When do I observe? | The full session, including feedback and reflection phases |
| How do I log? | Immediately on trigger, silently, appended to the log — never batched |
| Numbering? | Grep the log for the highest number first; verify after append |
| When do I surface? | Session end, or earlier per the Surfacing Protocol |
| When do I act? | Review / explicit request / in-session correction — otherwise log only |
| Open-source or internal? | Default open-source; the boundary is confidentiality |
| Weekly review? | `references/weekly-review.md` when the 7-day trigger fires |
| No filesystem? | Handoff doc mode — `references/handoff-doc-mode.md` |

## References

- `references/background.md` — why the skill exists; user-facing docs links
- `references/activation-setup.md` — CLAUDE.md pairing, config detection, compaction behaviour
- `references/taxonomy-licensing-attribution.md` — open-source vs internal, licences, attribution template, lean-content rule
- `references/observation-protocol-full.md` — full logging mechanics: collisions, TOCTOU, archival, handoff-doc analysis
- `references/confidentiality.md` — the five safeguard layers
- `references/acting-on-observations.md` — decision framework detail, system-skill routing
- `references/cowork-environment.md` — read-only mounts, staging, present_files delivery
- `references/principle-propagation.md` — cross-cutting principles workflow and template
- `references/weekly-review.md` — comprehensive review procedure (scheduled and fallback modes)
- `references/handoff-doc-mode.md` — environments without persistent storage
