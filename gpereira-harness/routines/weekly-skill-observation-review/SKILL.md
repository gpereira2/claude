---
name: weekly-skill-observation-review
description: Weekly task-observer review — consolidate OPEN skill observations into skill updates. Register as a scheduled routine (see docs/ROUTINES.md); not auto-loaded as a session skill.
---

Run the `task-observer` comprehensive weekly review for this machine's skill library. This is a standalone run with no prior conversation context.

1. Read the procedure in the `task-observer` skill's `references/weekly-review.md` and follow it exactly.
2. The observation log is `~/.claude/skill-observations/log.md`; cross-cutting principles are in `principles.md` in the same directory; skills live in `~/.claude/skills/`.
3. Process every OPEN observation. Only global skills — files under `~/.claude/skills/` — are eligible for edits: apply clearly additive, low-risk improvements directly to the target skill file (keep a dated backup under `~/.claude/skill-updates/YYYY-MM-DD/` for substantial rewrites, retaining the two most recent per skill); stage substantial restructures there for manual review instead of applying. If an observation targets a repo-committed skill (any project's `.claude/` tree), leave it OPEN with the reason "repo skill — out of scope for this run". If it targets a plugin-shipped skill (anything under `~/.claude/plugins/`, or a skill this machine's harness plugin ships), leave it OPEN and tag the reason with the literal token `DEFERRED-TO-SYNC` — for example, "plugin skill, DEFERRED-TO-SYNC". Use that exact token: `monday-harness-sync` greps the log for it to build its candidate set, and an entry that omits it is invisible to the routine that would have ported it. Plain ASCII, one word, no emphasis — so it survives line wrapping and reformatting. Do not edit or stage either kind. Mark each processed observation ACTIONED (with a one-line note) or leave OPEN with a reason.
4. Respect the confidentiality boundary: nothing client-identifying enters open-source-tagged skills, and scrub PII everywhere.
5. Update `~/.claude/skill-observations/last-review-date.txt` to today's date (YYYY-MM-DD).
6. Finish with a short summary: observations actioned/declined/left open, skills changed, anything staged for manual review.

Do not modify repo-committed skill assets in any project, nor installed plugin files (including the plugin cache under `~/.claude/plugins/`). The only files this run may change live under `~/.claude/skills/`, `~/.claude/skill-observations/`, and `~/.claude/skill-updates/`.
