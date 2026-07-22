## Observation Protocol

### When to Observe

Observation is active throughout the **entire task session** — from the moment
tools are first used to produce deliverables, through any post-task feedback
or discussion, until the session ends. This includes:

1. **Active task execution** — creating documents, analysing websites,
   implementing structured data, writing code, building presentations, and
   similar substantive work.

2. **Post-task feedback and discussion** — when the user reviews output,
   provides corrections, suggests improvements, or discusses methodology
   after the active work phase. User feedback during these discussions is
   often the highest-signal input for skill improvement and must be captured
   with the same diligence as observations made during execution.

3. **Meta-discussion about skills or methodology** — when the conversation
   shifts to talking about how the work was done, what could be improved,
   or how skills should be structured. These discussions frequently surface
   observations that should be logged immediately.

4. **Reflective and strategic conversations** — Also activate during strategy
   sessions, planning conversations, and post-work reflections where the user
   is discussing how work should be done rather than doing it. These
   conversations frequently produce skill improvement insights that emerge
   during reflection, not just during execution.

**The observation mindset does not deactivate when the conversation shifts
from "doing work" to "discussing the work."** If the user provides feedback
about methodology, naming, skill design, or workflow improvements, log it as
an observation immediately, even if the conversation is in a discussion or
review phase rather than active task execution.

Observation is **not active** during casual conversation, quick factual
questions, or other non-task interactions where no tools are being used and
no deliverables are being discussed.

### What to Watch For

**Signals for a NEW skill:**

- A multi-step workflow that could be reused across projects or clients
- A methodology the user explains that isn't captured in any existing skill
- A task type that keeps coming up with similar structure and steps
- A domain-specific process with clear inputs, phases, and outputs
- The user describing a process they've refined over time ("I always do it
  this way", "the process for this is...")
- the agent and the user naturally developing a structured approach to a problem
  that could be formalised

**Signals for IMPROVING an existing skill:**

Any new information from a task that uses a skill and could make that skill
better is worth capturing. This includes problems, but also positive signals
and neutral observations. Examples:

- the agent doesn't follow a skill's rules despite them being documented — this
  means the skill needs stronger enforcement, not just better rules
- The user corrects the agent's output in a way that reveals a missing rule or
  an edge case the skill doesn't cover
- A skill's recommended workflow turns out to be less efficient than what
  emerged naturally during the task
- A technique or approach works particularly well and deserves to be promoted
  from incidental to explicitly recommended in the skill
- A workflow step turns out to be more important than the skill suggests, or
  less important than the emphasis it receives
- A new use case that the skill handles but doesn't explicitly document
- The user provides feedback that generalises beyond the current instance
- A skill assumption turns out to be wrong in practice
- New tools or capabilities make part of a skill's workflow obsolete or
  improvable
- The user's corrections form a pattern across multiple instances
- A general principle emerges that could apply to other skills too (see
  Principle Propagation below)
- The user suggests a naming, framing, or structural change to a skill —
  even conversationally — that could improve its effectiveness

**Signals for SIMPLIFYING an existing skill:**

Healthy skill maintenance requires both growth and pruning. Watch for
opportunities to remove unnecessary complexity, not just add new features.
Signals that a skill is ready to be simplified:

- A skill section or rule that has never been relevant across multiple
  sessions where the skill was active
- A rule added from a single observation that hasn't been validated by
  recurrence — one-off cases should not accumulate as permanent rules
- An elaborate workflow that users consistently shortcut or skip
- Sections that the agent loads but never acts on (dead weight in context
  window)
- Rules that contradict each other or create unnecessary complexity
- Complexity added "just in case" that has never triggered
- A documented rule that the agent consistently fails to follow — the rule
  isn't reaching the moment of decision. The fix is rarely to write it more
  loudly; usually it's either to remove the rule, or to convert it from
  narrative guidance into structural enforcement (a checklist, a
  verification step, or a tool call that can't be skipped).

Treat the list above as a review checklist when looking at any of your own
skills — a "yes" on any signal is a candidate for simplification or
removal, not just a flag for future consideration.

During weekly reviews, ask "what can we remove?" as deliberately as you ask
"what should we add?" When a previously-applied observation turns out to be
a one-off that hasn't recurred, mark it as declined and consider reverting
the change.

**Signals to NOT log:**

- One-off corrections that don't generalise beyond the current instance
- User preferences already captured in an existing skill
- Tool bugs or temporary issues unrelated to skill methodology
- Observations that would require proprietary client information to be useful
  in an open-source skill (unless an internal skill is the right home)

### How to Log

Append observations to the persistent observation log **silently** during the
session. The user should not be interrupted by the logging process.

**When a user correction, methodology insight, or skill-relevant event occurs,
write it to the log file within the same turn or the immediately following
turn — do not accumulate observations in memory for batch-writing later.** The
act of writing is the enforcement mechanism; mental notes are not observations.
Tie observation flushing to existing workflow checkpoints — e.g., when marking
a task-list item as completed, check whether any unlogged observations have
accumulated and write them before proceeding.

**Mandatory observation checkpoint after every 3rd task-list completion:** After
marking the 3rd, 6th, 9th (etc.) task-list item as completed in a session,
pause and explicitly ask: "Have any unlogged observations accumulated?" This is
a hard checkpoint, not a suggestion — the skill has demonstrated that softer
"check when completing items" guidance gets lost during cognitively demanding
analytical work. The count doesn't need to be precise; the rule is: roughly
every third completion, stop and flush. If nothing has accumulated, the pause
costs seconds. If observations have accumulated, this prevents the common
failure mode where the skill is loaded but no observations are written until
the user explicitly asks.

**Before assigning any observation number, run a mandatory pre-logging step:**
Search the entire log file for all lines matching the pattern `### Observation \d+:`,
extract the highest observation number already in use, and increment from there.
This must happen every time, regardless of whether you think you know the current
count from earlier in the session. Never rely on session memory or summaries for
the next number. Always read the actual log file. A one-liner like the following
suffices:

```bash
# GNU grep (Linux, Cowork):
grep -oP '### Observation \K\d+' log.md | sort -n | tail -1

# macOS / POSIX-compatible alternative:
grep -o '### Observation [0-9]*' log.md | grep -o '[0-9]*' | sort -n | tail -1
```

This prevents the recurring numbering collision issue where partial reads of large
files create a false sense of awareness of the current count.

**Write-time verification assertion (mandatory):** The pre-logging step above
catches honest mistakes, but is vulnerable to parallel-session scenarios where
multiple task-oriented sessions on the same day each compute "next number"
against a snapshot and then collide on write. To catch this class of collision,
after determining the proposed next number and immediately before appending,
re-read the log and assert the number does not already exist:

```bash
PROPOSED=$(( $(grep -oP '### Observation \K\d+' log.md | sort -n | tail -1) + 1 ))
grep -qE "^### Observation ${PROPOSED}:" log.md && {
  echo "COLLISION on #${PROPOSED} — another writer has claimed this number"; exit 1; }
# If assertion passes, proceed with the append using #${PROPOSED}.
```

If the assertion fires, increment past all existing numbers (not just by 1)
and re-check. Treat an assertion failure as a meta-observation worth logging
— it indicates either a parallel-session collision or a stale read elsewhere
in the workflow.

**Post-write verification (mandatory — closes the TOCTOU race):** The
pre-write assertion catches stale-read collisions but cannot close the
time-of-check-to-time-of-use race between the assertion and the append.
In shell, `grep -q && cat >> ...` is two separate operations: the grep
passes at T0, the append lands at T1. Any other session that appends
between T0 and T1 can claim the same number — this race has been observed
in production, producing duplicate observation pairs in the active log.

After the append, re-read the log and count occurrences of the just-written
observation number. If the count is greater than 1, a parallel session has
collided — renumber the current session's entry to `max+1` in place via
`sed`. Concrete shell:

```bash
WRITTEN=$(grep -cE "^### Observation ${PROPOSED}:" log.md)
if [ "$WRITTEN" -gt 1 ]; then
  # Find my line (the last occurrence, since I just appended) and renumber
  MY_LINE=$(grep -nE "^### Observation ${PROPOSED}:" log.md \
    | tail -1 | cut -d: -f1)
  NEW_NUM=$(( $(grep -oP '^### Observation \K\d+' log.md \
    | sort -n | tail -1) + 1 ))
  sed -i "${MY_LINE}s/^### Observation ${PROPOSED}:/### Observation ${NEW_NUM}:/" log.md
fi
```

This turns the pre-write assertion into a pre-and-post pair. Pre-write
catches stale-read collisions cheaply; post-write catches race collisions
by renumbering instead of failing. Either way, the log ends up with no
duplicates. Alternative approaches — lockfile, atomic append, transactional
write — are heavier and require more infrastructure; the
post-write-verify-and-renumber pattern works with plain shell and
self-heals.

**Why both checks are required:** Stale-read collisions and race-condition
collisions are different classes of error. The pre-write assertion closes
the first; the post-write verification closes the second. Stacking more
pre-write layers does not close race cases — only a post-write check can.
When the shared state is a log file written by parallel agents, the
reliable pattern is check-then-act-then-verify.

**Session-start staleness check:** At the start of any task-oriented session,
note the modification time of `log.md`. If it was modified in the last few
hours (i.e., a parallel or recent session has been writing to it), be extra
cautious about the numbering pre-check — do not trust any mental model of
"current number" and always re-read the log immediately before appending each
observation, not just once at session start.

**Format and insertion rules:** Always use the `### Observation NNN:` format. Always append new observations to the END of the log file. Never insert observations mid-file. Never use alternative ID formats (e.g., `OBS-YYYY-MMDD-NN`). One format, one insertion point — this ensures the log is greppable, countable, and reviewable programmatically.

Each observation follows this format:

```markdown
### Observation [N]: [Short descriptive title]

**Date:** [date]
**Session context:** [brief description of what task was being worked on]
**Skill:** [existing skill name, or "New skill candidate: [working name]"]
**Type:** [open-source | internal]
**Phase/Area:** [which part of the skill or workflow this relates to]

**Issue:** [What happened or what was observed. Be specific — include what
The agent did, what the user corrected, or what pattern emerged. Include enough
detail that someone reading this weeks later can understand the context
without having seen the original conversation.]

**Suggested improvement:** [Concrete suggestion for what to change or create.
For existing skills, reference the specific section or rule. For new skills,
describe the scope and key components.]

**Principle:** [The generalisable takeaway — why this matters beyond this
specific instance. This is the most important part. It turns a single
observation into a reusable insight.]
```

This format was refined through iterative real-world use. The structure works
because it forces specificity (Issue), actionability (Suggested improvement),
and generalisation (Principle).

**Context preservation check:** When logging an observation, verify that all
information needed to act on it is available in the shared folder. If the
observation depends on uploaded files, API responses, or session-local data,
save that context to the appropriate workspace location BEFORE logging the
observation. Add a `**Reference file:**` line to the observation pointing to
where the context lives. Observations that reference data only available in
the current session (uploaded files, API outputs, in-memory results) are
incomplete — a future review session will have the observation but not the
data needed to implement it.

### Handoff Doc Analysis

When a handoff doc arrives for observation logging, extract observations
systematically from both explicit and implicit sources:

1. **Log all explicitly stated observations first.** These are easy to
   surface and should be logged without filtering.

2. **Then systematically analyse the full document.** Read every section
   asking: "What skill gaps, improvement opportunities, or new skill
   candidates are implied here but not stated?" Handoff docs contain
   significant signal beyond what was explicitly captured during the session.

3. **Pay special attention to:**
   - Action items (each one may imply a missing skill or workflow)
   - Open questions (unresolved ambiguity often signals a decision framework gap)
   - The "work completed" narrative (patterns across work items may reveal meta-skills)
   - Session notes (reflective insights about process, not just content)

4. **Log the additional observations with clear attribution.** Indicate that
   they were derived from analysis of the handoff doc, not from the original
   session. This preserves the distinction between stated and derived insights.

### Archival on Write

The observation log is kept lean through event-driven archival that runs on
every log write, rather than accumulating resolved entries until a periodic
review clears them out.

**Defining "from a previous update":**
The phrase "from a previous update" means entries whose status was already
resolved in a *previous SESSION or prior log write*, not entries marked
ACTIONED or DECLINED in the current session. Crucially: entries marked
ACTIONED or DECLINED during the current session's weekly review must NOT be
archived during that same session's writes. They earn their one round of
visibility in the active log — the archival happens on the NEXT session's
log write or the next weekly review.

**Archival Timing During Weekly Reviews:**
The weekly review performs archival in two phases:

1. **Step 1 (at review start):** Archive entries from previous sessions.
   Before loading observations, archive any ACTIONED or DECLINED entries
   that were marked in prior sessions. This clears old resolved items.

2. **Step 6 (after marking ACTIONED):** Do NOT archive immediately. When
   observations are marked ACTIONED during the current review (Step 6), they
   remain in the active log. Archive them on the next log write — either
   when the next session writes to the log, or when the following week's
   review begins (Step 1 of the next review cycle).

This prevents the premature archival problem: entries just actioned during
the current session stay visible for one full update cycle before moving to
the archive.

**Archive File Structure:**
Move resolved entries to an archive file at:

```
[workspace folder]/skill-observations/archive/log-[date].md
```

where `[date]` is today's date in `YYYY-MM-DD` format.

The archive file preserves the full header and status key from the original
log. After archiving, the active `log.md` retains only its header, separator,
and all OPEN entries plus any entries that were *just* marked ACTIONED or
DECLINED in this update.

**Safety Check Before Archiving:**
Before moving any entry to the archive, verify that it was NOT marked
ACTIONED or DECLINED in the current session. If it was, keep it in the
active log. This prevents the same-session premature archival that the
observation lifecycle describes. One way to implement this: track a set
of entry IDs marked ACTIONED/DECLINED in the current session, and exclude
them from the archival pass.

The result: the active log stays focused on OPEN items and recently-resolved
entries, while the archive provides the complete historical record.

---

