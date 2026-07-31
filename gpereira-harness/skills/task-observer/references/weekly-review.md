## Comprehensive Review (scheduled or fallback)

The comprehensive review cross-checks all open observations against all
skills, propagates cross-cutting principles to skills that don't yet
comply, and applies the improvements that don't need user input. There
are two ways it runs.

**Preferred mode — scheduled autonomous review.** A user-defined recurring
task (typical cadence: Monday/Wednesday/Friday mornings) registered with
the agent's scheduling system. This is preferred because it picks up open
observations on a regular cadence without depending on the user being
mid-session at exactly the right moment, and because the user is not
present, the review applies the non-escalated observations autonomously.

**Fallback mode — in-session 7-day trigger.** If no scheduled review is
registered (or none has run successfully in the last 7 days), a
comprehensive review fires automatically at the start of the next
task-oriented session. The fallback is a safety net for users who haven't
set up scheduled reviews — either because the environment doesn't support
scheduling or because they haven't done it yet.

### Trigger Mechanism

**Scheduled mode** runs via the user's chosen scheduling tool — no in-skill
trigger required.

**Fallback mode** is triggered by step 3 of the Session Start Protocol
(see Observation Log Management). The fallback fires when both of the
following are true:

- No scheduled review task is registered, OR the most recent successful
  scheduled review was more than 7 days ago.
- The in-session timestamp at
  `[workspace folder]/skill-observations/last-review-date.txt` is also
  more than 7 days old (or missing).

When the fallback fires, inform the user that the comprehensive review is
running and walk through Step 0 (recommend scheduling) before Step 1.

### Interactive vs Scheduled Runs — Approval Policy

The approval behaviour depends on who is present:

**Interactive sessions (user present):** Always ask the user before applying
or declining observations. Present observations grouped by skill with a one-
sentence summary each, and wait for explicit approval (blanket "apply all" or
selective). This preserves the collaborative feel and lets the user catch
observations they disagree with before any staging occurs.

**Scheduled autonomous runs (user not present):** Apply observations
autonomously by default. The safety net is the staging-plus-upload pattern:
updates go to `skill-updates/YYYY-MM-DD/{skill-name}/SKILL.md` and only
become live when the user explicitly uploads them. Nothing can silently
break because nothing is live until the user approves upload.

**Escalate without applying (report only) when any of these apply:**

1. **New skill creation.** Naming, scope, type (open-source vs internal),
   and licence are decisions that benefit from user input. Note the
   candidate in the report; don't create the skill.
2. **Removing or substantially restructuring existing content.** Any edit
   that deletes a section, replaces it with something smaller, or reshapes
   core methodology risks dropping institutional memory. Flag and report.
3. **An observation that flags its own uncertainty.** Phrases like "not
   sure if...", "this might be...", "worth discussing..." in the
   Suggested Improvement field are the observation asking for user input.
   Respect that.
4. **Conflicting observations.** Two observations that point in opposite
   directions, or where the integration path isn't obvious, should be
   surfaced rather than resolved autonomously.

Scheduled runs that escalate should still apply every non-escalated
observation before producing the report. A scheduled review that
produces 0 applied updates is functionally a report generator, which
wastes the scheduling.

### Review Steps

**Step 0 — Recommend scheduled review setup**

Before running the in-session fallback, check whether scheduled autonomous
reviews are set up. If not, surface a recommendation to the user — but
respect prior declines.

1. Check for the suppression marker at
   `[workspace folder]/skill-observations/scheduled-review-decline.txt`.
   If it exists and was last updated less than 30 days ago, AND the
   in-session fallback has not fired multiple times in that window, skip
   the recommendation. Proceed to Step 1.

2. Check whether a scheduled review task is registered. The signal is
   either a presence check via the platform's scheduling tool (preferred)
   or the existence of
   `[workspace folder]/skill-observations/scheduler-registered.txt`. If a
   registered scheduled review is found, no recommendation needed — skip
   to Step 1.

3. If no scheduled review is registered AND no recent decline marker
   exists (or the marker is stale because the fallback keeps firing),
   make an active recommendation:

   > "I notice you don't have a recurring skill review scheduled. The
   > task-observer recommends running this review on a cadence — e.g.,
   > Monday/Wednesday/Friday mornings — so it doesn't depend on you
   > being mid-session at the right moment. Want help setting one up?"

   - **If the user says yes:** walk through registering a scheduled task
     using the platform's scheduling capability. In Cowork, invoke the
     `create-shortcut` skill and its `set_scheduled_task` tool. In
     terminal-based environments, use cron or an equivalent scheduler.
     Use task name `weekly-skill-review` (or similar) and a sensible
     default cadence; let the user pick the day(s) and time. Once
     registered, read the draft task description at
     `[workspace folder]/skill-observations/scheduled-task-draft.md` and
     pass it as the task prompt. On success, write today's date to
     `[workspace folder]/skill-observations/scheduler-registered.txt`.
   - **If the user says no or defers:** write today's date to
     `[workspace folder]/skill-observations/scheduled-review-decline.txt`
     to suppress the recommendation for 30 days. Proceed to Step 1 and
     run the in-session fallback.

4. If no scheduling capability is available in the current environment,
   skip the recommendation silently and proceed to Step 1. Do not surface
   the recommendation in environments where the user couldn't act on it.

The 30-day suppression isn't permanent. If the in-session fallback keeps
firing within the suppression window — a signal that the recurring need
is real and the one-time decline was situational — the recommendation
re-surfaces on the next firing.

**Step 1 — Load observations and principles**

Read the observation log at `[workspace folder]/skill-observations/log.md`.
Extract all observations with status OPEN. Also read
`[workspace folder]/skill-observations/principles.md` and
extract all active principles.

If there are no OPEN observations and all principles are already propagated,
skip the review, update the timestamp, and proceed with the session. Inform
the user briefly: "Weekly skill review: no open observations or outstanding
principles. All skills are current."

**Step 2 — Inventory all skills**

Use `<available_skills>` from the system prompt to identify all skills. In
environments where this tag is not present, use the skills directory or
equivalent listing mechanism to discover available skills.

For each skill, read its SKILL.md file at the location provided. Exclude
built-in platform skills from being updated — only update custom skills
created by the user.

**Known system skills (read-only, cannot be replaced by the user):**
docx, pdf, xlsx, pptx, skill-creator, schedule. This list may grow as the
platform evolves — if a skill update fails because the user cannot overwrite
the file, add it to this list.

**Custom skills** (owned by the user, can be replaced) are everything else
in the skills directory that isn't on the system list above.

**Duplicate-name check.** While inventorying, flag any skill *name* that
appears from more than one source (repo skill, plugin, claude.ai/Cowork
sync). A name is a routing key — two sources shipping the same name is a
collision, not redundancy: it burns always-loaded description tokens twice
and makes routing between them arbitrary. Resolving a collision (uninstall,
rename, or prune the sync) is a structural user decision, so report it in
the summary rather than resolving it autonomously.

**Step 3 — Cross-check observations against every skill**

For each OPEN observation, evaluate whether it is relevant to each skill. Do
NOT rely solely on the observation's own "Skill" field — observations may
contain general principles that apply more broadly than the original context
suggested. Consider both the specific "Suggested improvement" and the general
"Principle" fields. Build a mapping of skill → [relevant observations].

**If the review is interactive (user present):** Present ALL observations to the user in a single message, grouped by skill. For each observation, show the number, title, and a one-sentence summary. Flag any observations that are ambiguous, risky, or require a judgment call as 'Needs your input'. All other observations are treated as straightforward and can be applied without individual discussion.

**If the review is scheduled autonomous (user not present):** Skip the user-facing present step. Apply the approval policy from "Interactive vs Scheduled Runs" above: apply every non-escalated observation and record the escalated ones (new-skill candidates, removal/restructuring, self-flagged uncertainty, conflicting observations) in the review report without applying them. Proceed directly to Step 4.

**Step 4 — Cross-check cross-cutting principles against every skill**

For each active cross-cutting principle, check whether each skill already
complies. Flag any skills that do not yet implement the principle.

**Step 5 — Apply updates**

In interactive runs, wait for user confirmation (blanket "apply all" or selective approval) before creating updates. In scheduled autonomous runs, proceed directly to applying all non-escalated observations. For each skill that has relevant observations or non-compliant principles, create an updated version of its SKILL.md. When editing:

- Integrate the insight into the appropriate section of the skill (don't just
  append a list of observations at the bottom)
- Preserve the skill's existing structure, voice, and author attribution
- Make the improvement feel native to the skill, not bolted on
- If an observation suggests a new phase, step, anti-pattern, or checklist
  item, place it where it logically belongs

**Routing observations that target system skills:** When an observation
targets a system skill (see the known system skills list in Step 2), do NOT
skip it. Instead, route the improvement to a **complementary skill** — a
user-owned skill named `{system-skill}-extras` (e.g., `docx-extras`) that
layers additional guidance on top of the system skill. If the complementary
skill doesn't exist yet, create it. The complementary skill should:
- State which system skill it extends
- Contain only the delta — the additional rules, anti-patterns, or guidance
  not present in the system skill
- Be loaded alongside the system skill (add a note to CLAUDE.md or
  equivalent configuration if needed)

This ensures observations targeting system skills are still actionable,
even though the system skill files themselves cannot be modified.

**Important:** Do not edit skill files in place. Save updated versions to the
workspace folder for user review and manual replacement (see Delivering
Updated Skills below).

**Step 6 — Mark observations as ACTIONED**

After successfully creating an updated skill based on an observation, update
that observation's status in `log.md` from OPEN to ACTIONED. Add a brief note
about which skill(s) were updated, e.g.:

`ACTIONED — Applied to [skill-name] (weekly review [date])`

Note: the standard archival-on-write mechanism (see "Archival on Write" in
the Observation Protocol) will automatically archive these newly-resolved
entries on the next log write. No separate archival step is needed here.

**Step 7 — Update timestamp**

Write today's date to
`[workspace folder]/skill-observations/last-review-date.txt`.

**Step 8 — Present summary and user action items**

Present each updated skill file using `present_files`, then show the user a summary following the format in Delivering Updated Skills above. The user can install updated skills directly from the conversation using the upload button on each presented file.

### Constraints

- Do not modify observation entries beyond their status field
- Do not create new skills — only update existing ones. If an observation
  suggests a new skill, note it in the summary for the user to action
  separately via the skill-creator
- If an observation seems relevant but you're unsure how to integrate it,
  skip it and note the uncertainty in the summary
- Treat observations marked "internal" with the same rigour as "open-source"

---

