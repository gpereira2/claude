## Task-Oriented Sessions — Observation vs Action

Skill development and iteration work happens in multiple environments: in Cowork with persistent storage, in Claude Code with project directories, and in web-based chat without file system access. Cross-environment coordination is essential to prevent regressions — a skill updated in one environment can silently omit content from another if the wrong base file is used.

### Skill file locations — read-only mount vs workspace copy

When working with skills, understand the distinction between the **live file** (the authoritative source) and **workspace copies** (working drafts or staged updates):

1. **The live file is read-only in Cowork.** In Cowork, the live skill file is mounted read-only at `.claude/skills/{skill}/SKILL.md`. You can read it, but you cannot edit it directly — the file system will reject write attempts with `EROFS` (Read-Only File System). This is intentional: it prevents accidental overwrites of the canonical version.

2. **Read from the live file, not cached memory.** Always start skill edits by reading the current live file — not from a workspace copy, a prior draft, or a memory-based reconstruction. This is the only way to guarantee your updates are based on the current canonical content.

3. **Stage edits in the workspace folder.** Write updated versions to `[workspace folder]/skill-updates/[date]/[skill-name]/SKILL.md`. This separation keeps the read-only mount clean and gives you a clear staging area for review before the user replaces the live file.

4. **After staging, present the file for user review.** Always use `present_files` to show the updated skill so the user can review changes and upload directly. Do not attempt to write directly to the mounted skills directory — that will fail with a permission error.

5. **Before overwriting or replacing any existing staged or workspace copy of a skill, diff it against the live file.** If they differ, the workspace copy is stale and your edits must be rebased on the live version — otherwise you risk silently dropping content added by another session. This rule is also codified in CLAUDE.md under "Skill Editing — Always Start From the Live File" as a cross-environment guard. The concrete failure mode: a Claude Code session produced an updated skill that was based on a stale snapshot and silently omitted two substantial sections added to the live skill earlier the same day. The regression was caught only because a pre-merge diff against the mount revealed the missing content.

### Task-session skill updates — stage in the workspace

When a task session produces a skill update (through weekly review, direct improvement, or observation-driven changes), follow this workflow:

1. Read the live file at `.claude/skills/{skill}/SKILL.md`
2. Make all edits to that content
3. Save the complete updated file to `[workspace folder]/skill-updates/[today]/[skill-name]/SKILL.md`
4. Use `present_files` to show it to the user for review
5. The user uploads the file to install it

This keeps the mount clean, stages updates for review, and gives you a clear separation between read-only source and working copy.

**Cross-environment note:** Claude Code now shares the same skills as Cowork via the anthropic-skills capability. The "always start from the live file" rule applies in both environments. In Claude Code, the live file is surfaced by the capabilities system; in Cowork, it's the read-only mount at `.claude/skills/{skill}/SKILL.md`. The diff-before-overwrite requirement applies regardless of which environment produced the update.

---
---

## Delivering Updated Skills to the User

When the weekly review (or any other process) produces updated skill files,
they are delivered to the user through the conversation using `present_files`.
Cowork's UI includes an upload button on presented skill files that allows
the user to install them directly into their capabilities — no manual file
copying needed.

### Delivery Process

1. Save each updated SKILL.md to the workspace folder for record-keeping:

   ```
   [workspace folder]/skill-updates/[date]/[skill-name]/SKILL.md
   ```

2. Present each updated skill file using `present_files` so the user can
   review it inline and install it directly via the upload button.

3. Present the user with a summary using this format:

   ```
   ## Weekly Skill Review Complete — [date]

   The following skills have been updated based on [N] open observations
   and [N] cross-cutting principles.

   ### Updated Skills

   **[skill-name]**
   - Changes: [1-sentence summary of what changed]
   - Observations applied: #[N], #[N]

   [repeat for each updated skill]

   ### Observations Actioned
   [list of observation numbers and titles marked ACTIONED]

   ### Skipped (needs manual review)
   [any observations that couldn't be applied, with reasons]
   ```

### Keep-Two Rule

The `skill-updates/` directory uses a rolling retention policy: for any
given skill, keep only the two most recent date directories. When a skill
appears in more than two date directories, delete the oldest copies. This
prevents the workspace from accumulating stale update history while still
keeping a short rollback window.

3. Do not proceed with other work until the user has acknowledged the
   summary. The user does not need to replace the files immediately, but
   they should be aware of what's pending.

---

