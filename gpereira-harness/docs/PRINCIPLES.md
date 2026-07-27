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
