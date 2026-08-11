# Cross-Cutting Principles

Principles that apply to every skill in this harness. Read as a checklist when
creating or regenerating a skill, and when reviewing a dispatch prompt.

Each one was extracted from an observed failure in real use, not from theory.
The failure mode is stated first, because that is the part that generalises.

---

### 1. The private/shared boundary decides where a rule lives

Personal workflow rules belong in your user-level config; team rules belong in
repo-committed assets. Decide placement by **who should receive the rule**, not
by which file you happen to have open. A personal preference committed to a
shared repo silently imposes itself on everyone; a team invariant left in
personal config silently fails to reach anyone.

### 2. Never trust a silent write in a write-then-execute handoff

Capture write/edit results (never collapse them to `ok`), read back a sentinel
from the new version, and verify through a second channel — `git status`, a
grep for the new string, an executor echo — before executing or declaring done.

**Tool-mechanics corollary.** Reads must go through the channel the write-gate
watches: read a target with the file-reading tool, not with `sed`/`grep` via a
shell, or a subsequent edit may be rejected as "not read". Never map an edit
result to a constant (`.then(() => 'ok')`) — that converts loud failures into
silent ones. Close every bulk-edit batch with an independent verification.

*Seen again while writing this file:* a `sed -i '' 's/\bWORD\b/…/'` reported
success and changed nothing, because BSD `sed` does not support `\b`. The test
suite passed — because nothing had changed. Only an independent grep caught it.

### 3. Search prior artefacts before dispatching discovery

Before broad discovery, search your memory index and context store for prior
deliverables on the topic. Persist expensive validated artefacts — queries,
findings, resolved schemas — at the moment they are created, not at the end of
the session that produced them.

### 4. Reconcile imported best-practice against runtime capability

Check any externally-researched pattern against what the environment can
actually do. Adapt it, and record the residual gap as an explicit caveat,
rather than importing an unachievable ideal that reads as satisfied.

### 5. Reference external-surface tools by function, not identifier

Name the function ("the issue tracker's fetch-issue tool"), never a
connection-specific prefix or a generated UUID. Permission allow/deny lists
must be verified against the live tool surface of the environment they run in,
because identifiers are regenerated and prefixes differ per installation.

### 6. Check the schema before designing a behavioural heuristic

Before designing a heuristic (time windows, multi-column absence checks,
`IS NULL` predicates), inspect the actual schema — a native column often makes
the heuristic unnecessary. Before relying on a column's *absence* as a signal,
find what **writes** it: an auto-populated column makes "absence" an invalid
signal, and a sibling table with an insert hook means a `JOIN … IS NULL` never
sees `NULL`. Cheap to check, expensive to skip.

### 7. A validator reads the reference but skips the subject

When a sub-agent is asked to validate X against Y — local code against docs, an
implementation against a spec — it reliably reads Y (the reference) and
hand-waves X (the subject). When its verdict is load-bearing, require it to
quote the reference verbatim, and cross-check the subject side yourself before
acting on the severity it reports.

### 8. Routing must be enforced by explicit per-dispatch pins, not policy memory

Inheritance defaults differ by dispatch surface: a Task-tool call honours an
agent's frontmatter model when `model` is omitted, while a Workflow `agent()`
call with `opts.model` omitted inherits the **main-loop** model and silently
ignores the manifest's tier. The same applies to `effort`. Wherever a model is
permission-gated or a user override is active, pin it explicitly on every
dispatch; never rely on a gate holding through default inheritance. A user
override, once given, applies pipeline-wide and is recorded in run state so a
resumed run honours it.

### 9. Deferred-await conveniences are only safe for commutative operations

Where a runtime auto-awaits deferred values only at return time, two such
assignments in one script run **concurrently with no ordering guarantee**. Safe
for independent reads; unsafe for anything with an ordering dependency —
create-then-delete of one resource, write-then-read of one file. Force a
sequencing point with an explicit await, or a read races ahead of the write and
produces a misleading "not found".

*Seen while writing this file:* two greps assigned without awaiting disagreed
about the same line of the same file, because they raced the write that was
supposed to precede them.

### 10. A guard may say "no" — never "yes to everything else"

A `PreToolUse` hook that emits an explicit *approve* verdict on the paths it
does not care about does not merely pass: it **short-circuits the permission
check** that would otherwise have prompted. With a broad matcher, one narrow
guard silently auto-approves every unrelated call in its scope, including
dangerous ones. Guards block or exit silently. Nothing else.

Corollary: prefer a verdict shape you have **verified fires** in your own
environment. An "ask" verdict is inert under auto-approving permission modes,
so a guard relying on it blocks nothing while appearing to be installed.

### 11. A test-time control only fakes the layer that reads it

Faking a clock, a config value, or a piece of state controls exactly one
process — the one that reads the faked value. It does not extend across a
process boundary. A framework's test-clock helper rewrites the application's
notion of "now"; the database's own wall-clock functions (`NOW()`,
`CURRENT_TIMESTAMP`, `NOW() - INTERVAL …`) never see it, and neither do queue
delays, cache TTLs, or timestamps minted by an external service. The test goes
green while the asserted behaviour was never exercised.

When a change straddles that boundary, name the divergence rather than trusting
the green test: pass the faked value in as a parameter, do the comparison in the
faked layer, or assert against absolute timestamps.

Corollary — a green test is not evidence of one correct behaviour. Two
independent defects can cancel out and read as correctness: in the originating
case a real-time comparison would have taken the wrong branch, but an
auto-created sibling row made the outer `IS NULL` false, so the test passed for
neither intended reason. When a test passes on a path you have just changed,
confirm it fails with the change reverted. *(Verified 2026-08-04.)*

### 12. "I cannot change it" is not "it has not been changed"

When a work item is blocked because its target lies outside your write
boundary, the blocker justifies **not editing** — it never justifies assuming
the target is unchanged. Someone else can change a file you cannot.

Read the target before recording or re-recording a blocked status, and close the
item if the content is already there. Three observations sat OPEN across four
consecutive reviews, were escalated to the user as a pending decision, and had
their patch text staged for manual application — all while the content was
already merged upstream by someone else. One `grep` of the target file at any
point would have closed all three. The check is cheap; the stall compounds,
because each pass re-derives the same reasoning and re-asks the same question.

Corollary: an item held for a *user decision* is the highest-priority candidate
for this check, not the lowest. Escalating a question that no longer needs
answering spends the user's attention on nothing and erodes the escalation
channel. *(Verified 2026-08-04.)*

### 13. A sub-agent's "no X exists" is a claim about its search, not about the codebase

Negative existence findings are the most dangerous class of sub-agent output,
because absence of evidence from a bounded search is indistinguishable in the
report from evidence of absence. A worker that greps three plausible names and
finds nothing reports the same sentence as a worker that proved the thing does
not exist. Build a plan on it and a generically-named module that the search
terms missed gets re-invented as a whole slice of duplicated infrastructure.

Two rules follow. **Workers qualify negative claims** — any "no X exists" /
"nothing handles Y" names the paths, globs and terms actually searched.
**Consumers re-verify before building on one** — a plan element whose
justification is a negative claim gets one first-party grep before a task is
written against it.

Structural-sharing claims ("both trees wrap the same component") sit in the same
class: duplicated copies and a shared import are identical in a file listing,
and the wrong reading changes the shape of the work. *(Verified 2026-08-07.)*
