## Environment Compatibility

The observation methodology works in any environment where the agent can interact
with users during task-oriented work. The persistence mechanism is what varies.

### With Persistent Storage

In environments with file system access (desktop tools with workspace folders,
terminal-based tools with project directories, or similar), the full workflow
applies as described: observations are logged to a persistent file, the cross-
cutting principles file is read during skill regeneration, and the log carries
over between sessions automatically.

### Without Persistent Storage

In environments without file system access (web-based chat interfaces or
similar), the skill still works — the observation methodology is environment-
independent. The difference is that persistence becomes the user's
responsibility, and the skill shifts into **handoff doc mode** to support
this.

**How handoff doc mode works:**

- Observations are captured within the conversation and surfaced before the
  session ends, as usual
- Instead of writing to a log file, observations are collected in-session
  and presented in a structured **handoff document** before the session ends
- The handoff doc includes: all observations in full format, any decisions
  made during the session, action items and next steps, and any working
  artifacts (drafts, analyses) that need to survive into the next session
- The user copies this document to their own storage (notes app, file system,
  etc.) and pastes it into the next session to restore context
- Cross-cutting principles should be included in the handoff doc so the user
  can provide them when starting a new session

**Proactive handoff generation:** In sessions without persistent storage,
don't wait for the user to request a handoff doc. When the conversation
starts to wind down — the user is summarising, saying "that's it for now,"
or the substance is wrapping up — proactively offer to generate one. A
premature offer is a minor interruption; a missing one is lost work.

**Handoff doc format:**

```markdown
# Session Handoff: [Session Topic]

**Date:** [date]
**Context:** [what was worked on and what the next session needs to know]

## Decisions Made
[numbered list of decisions]

## Observations Logged
[full observation entries in standard format]

## Cross-Cutting Principles (current)
[any principles that were active or newly added]

## Action Items
[what needs to happen next, with enough context to resume]

## Working Artifacts
[any drafts, analyses, or intermediate work products in full]
```

This is less seamless than the persistent-storage workflow, but the core value
— systematically capturing insights that would otherwise be lost — is
preserved. The observation format and surfacing protocol are identical in both
environments.

---

