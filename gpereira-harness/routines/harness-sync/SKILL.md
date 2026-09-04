---
name: harness-sync
description: Sync discoveries between the live user-level harness (~/.claude) and this portable plugin, per-hunk and in both directions. Use when either side has learned something the other lacks — a new hook, a corrected instruction, a model/effort recalibration, a principle extracted from a failure. Trigger with "sync my harness", "update the plugin from my config", or "propagate this discovery to the plugin".
---

# Harness Sync

Propagate real-world learnings between two copies of the same harness: the
**live** user-level config (`~/.claude`) and this **portable** plugin. Both
change independently, so this is a per-hunk reconciliation, never a copy.

## The rule that makes this safe

**Never bulk-copy in either direction.** The two sides are not
newer-versus-older — they are different lineages. The live copy carries personal
and project-specific detail; the plugin carries packaging conventions
(`${CLAUDE_PLUGIN_ROOT}` paths, `lib/` layout, marketplace manifests) that a
copy from live would destroy. A `cp` also silently reverts whatever the *other*
side learned most recently.

## Step 1 — Classify every difference before changing anything

Enumerate the deltas, then sort each into exactly one bucket:

```bash
LIVE=~/.claude; PLUG=<plugin root>
for f in $(ls "$LIVE/hooks"); do
  if [ -f "$PLUG/hooks/$f" ]; then
    diff -q "$LIVE/hooks/$f" "$PLUG/hooks/$f" >/dev/null 2>&1 \
      && echo "SAME  $f" || echo "DRIFT $f"
  else echo "LIVEONLY $f"; fi
done
```

Repeat for `skills/*/SKILL.md`, `agents/`, `commands/`, `routines/`.

| Bucket | Meaning | Action |
|---|---|---|
| **live → plugin** | A mechanism proven in practice: a new hook, a sharper instruction, a principle extracted from a failure | Port the *content*, rewrite the *packaging* |
| **plugin → live** | A correction made while working on the plugin that the live copy still lacks | Apply it down to `~/.claude`, or the live harness stays miscalibrated |
| **neither** | Project- or person-specific detail | Leave private; note the decision so it is not re-litigated next time |

For a DRIFT file, read the actual diff before deciding — a single file often
contains hunks belonging to all three buckets.

## Step 2 — The portability test for LIVEONLY items

Ask **"does this encode a portable mechanism with project-specific config, or is
it bound to the project?"** — not "does it have a project name in it".

- **Parameterisable** → abstract it, ship the config as an example with
  placeholders. A guard keyed to machine-specific connection UUIDs becomes a
  guard reading its identifiers from config.
- **Bound** → leave it private. Project-lifecycle and repo-convention hooks
  belong to the project.
- **Definitionally personal** → leave it private. A voice or style skill cannot
  be abstracted; the specificity *is* the artefact.

## Step 3 — Port, with the packaging rewritten

When moving content into the plugin:

- Absolute home paths → `$HOME`, `${CLAUDE_PLUGIN_ROOT}`, or the vault variable.
- Script paths → the plugin's layout, not the live layout.
- Tool references → **by function**, never a connection-specific prefix or a
  generated UUID (`docs/PRINCIPLES.md` #5).
- Company names, internal hostnames, ticket prefixes, table and domain names →
  genericised. The leak gate enforces this; run it rather than eyeballing.
- A new hook must be **wired into `hooks/hooks.json`** and added to the smoke
  test's existence loop. A hook in `hooks/` that no manifest references is a
  dead file that reads as installed.

## Step 4 — Carry the *reasoning*, not just the code

This is the step that decays if skipped. A ported hook without its discovery is
a hook the next person deletes as over-engineering, or re-breaks identically.

For each ported item, record in the README or the hook's docstring:

- The failure that motivated it, with the date it was verified.
- The **non-obvious coverage detail** — which matcher, which tool, which path
  shape, and what was deliberately left out and why.
- Anything proven **inert** in a real environment. Shipping a control that
  silently does not fire is worse than shipping nothing, because installers
  believe they are covered.

If the discovery generalises beyond the one file, add it to
`docs/PRINCIPLES.md` as a numbered principle, stating the failure mode first.

## Step 5 — Verify, then report honestly

```bash
bash test/smoke.sh          # sanity + leak gate + behavioural guard checks
for f in <abs plugin root>/hooks/*.test.py; do python3 "$f"; done
git -C <plugin root> diff --stat
```

**Glob the hook self-tests; never name one by filename.** The guards get merged
and renamed, so a hard-coded path rots into a step that runs nothing and reports
success. `credential-file-guard.test.py` became `pretooluse-guard.test.py` when
three guards merged into one spawn, and on 2026-09-02 a verification step was
still pointing at the dead path. A glob that matches zero files is itself a
finding — say so rather than passing. *(Verified 2026-09-04.)*

Per `docs/PRINCIPLES.md` #2, close the batch with an **independent** check — a
grep for the new sentinel, a `git diff --stat` — rather than trusting the edit
results. Two traps that have both fired here before:

- BSD `sed` does not support `\b`. A rename can report success and change
  nothing, and a test suite will pass *because* nothing changed. Use `perl -pi`.
- Concurrent unawaited shell calls race the write they are meant to verify
  (principle #9). Force sequencing when a read must follow a write.
- A sentinel grep is only evidence once it has been shown to match *somewhere*.
  Make the check **two-sided**: assert the sentinel is present where it should
  be before concluding it is absent where it should not be. On 2026-08-26 a
  sentinel lifted from a bolded phrase matched zero on both sides — and the
  plugin-side zero read as the desired "nothing was applied" result, so a run
  that greped only the side expected to be empty would have recorded a false
  PASS on a search string that could not have matched anything anywhere. A
  sentinel that matches nowhere is a broken search, not a clean result. Pick it
  from running prose — no Markdown emphasis, no path separators, nothing a
  formatter may rewrite. A run that applies nothing needs this positive control
  most, because its "absent" assertion is otherwise untestable (principle #13).
- Read a file through the **file-reading tool** before writing it. A write whose
  only prior read went through a shell `cat` is rejected by the write-gate, and
  the rejection lands at the end of the run on the stamp write — the one write
  whose silent loss corrupts the next run's window. Shell inspection is not a
  read for this purpose. *(Verified 2026-09-04.)*

Report what moved, what was deliberately left private, and what is still
undecided. Never present a sync as complete while a bucket is unresolved.

## What this routine does not decide

Deletions, and anything the user has previously held back — a duplicated copy
of a skill, stray committed artefacts, whether an unreferenced directory should
still exist. Surface these as decisions with a recommendation. At minimum, stop
a stale duplicate from contradicting the shipped one.
