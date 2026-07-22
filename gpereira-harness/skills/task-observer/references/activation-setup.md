## Recommended Activation Setup

This skill needs to be invoked at the start of task-oriented sessions to work
effectively. Because skill invocation depends on the agent matching the user's
request against skill descriptions, a skill that monitors *all* tasks can be
overlooked when the agent is focused on the task itself.

To maximise activation reliability, add the following instruction to your
configuration file (e.g., CLAUDE.md, project instructions, or equivalent):

```
At the start of any task-oriented session — any interaction where you will
use tools and produce deliverables — invoke the task-observer skill before
beginning work. This ensures skill improvement opportunities are captured
throughout the session.

When loading any skill, check the observation log for OPEN observations
tagged to that skill. Apply their insights to the current work, even if
the skill file hasn't been updated yet. This enables immediate application
of observations before they're permanently integrated during the weekly
review.
```

This structural trigger works alongside the skill's description-level triggers.
The description is designed to match broadly against task-oriented language
("multi-step task", "agentic workflow", "work session", "tools and
deliverables"), but a configuration-level instruction provides an additional
safety net that doesn't depend on description matching alone.

**Note for all users:** Once CLAUDE.md or equivalent configuration is in place
with the activation instruction above, the description-level triggers serve as
a backup rather than the primary mechanism. This dual-layer approach prevents
the skill from being skipped in sessions where description matching alone might
miss the invocation signal.

**Anti-pattern to avoid:** Relying on one skill to load another is fragile
compared to loading both independently from CLAUDE.md. If task-observer depended
on another skill to invoke it, a breakdown in that chain would silence all
observation activity. Instead, load both task-observer and any related skills
directly from your configuration instructions.

### Detecting the Configuration File

At session start, the skill should check whether a configuration file
(CLAUDE.md, project instructions, or equivalent) exists and contains the
activation instruction. This detection serves two purposes:

1. **For users who already have the config:** Confirms the dual-layer
   activation is working. No action needed.

2. **For users who don't have the config:** The skill was activated via
   description matching alone, which is less reliable. Surface a brief
   suggestion to add the config-level instruction for more consistent
   activation in future sessions.

The detection approach depends on the environment:

- **Environments with file system access** (desktop tools, terminal-based
  tools): Check for a CLAUDE.md or equivalent file in the workspace root.
  If found, scan it for a task-observer activation instruction. If the file
  exists but doesn't mention task-observer, suggest adding the instruction.
  If no config file exists at all, suggest creating one.

- **Environments without file system access** (web-based chat): Check
  whether the system prompt or project instructions contain a task-observer
  activation instruction. If not, suggest that the user add one to their
  project settings or paste the instruction at the start of future sessions.

This check runs once at session start and does not repeat. Keep the
suggestion brief — one or two sentences, not a full tutorial.

### Compaction Behaviour

When a session context compacts mid-task, the CLAUDE.md structural trigger
re-invokes task-observer on the resumed session. No explicit re-invocation
is needed on the agent's part — the same activation instruction that fired
at the start of the original session fires again at the start of the
resumed session, because the resumed session reads CLAUDE.md anew.
Observations from before and after compaction append to the same log file
with continuous numbering.

This is the primary reason the CLAUDE.md structural trigger exists —
description-level triggers alone would not reliably guarantee re-invocation
on a resumed session, because the resumed session's opening message may
not match task-observer's trigger phrases even when the ongoing task is
task-oriented. The structural trigger fires regardless of the resumed
session's opening message.

---

