---
title: Routines
type: doc
tags: [claude, harness, routines]
---

# Routines (scheduled tasks)

A Claude Code plugin cannot *contain* a running scheduled task — routines are
registered per-machine, not carried inside a plugin. So this plugin ships the
**routine skills** as templates under `routines/`, and you register the ones you
want on your own machine.

`routines/` is **not** auto-loaded (unlike `skills/` and `agents/`). Nothing here
runs until you schedule it.

## What ships

| Routine | What it does | Depends on |
|---|---|---|
| `weekly-skill-observation-review` | Runs the `task-observer` weekly review — consolidates OPEN skill observations into skill updates | the bundled `task-observer` skill |

Machine- or workspace-specific routines (control-board checks, regression sweeps,
Docker/worktree pruning, anything that DMs a chat workspace) are intentionally
**not** shipped — they hardcode paths, tickets, and endpoints that are yours, not
portable. Use the pattern below to build your own.

## How to register a routine

Routines run as standalone scheduled sessions. Register one with whatever
scheduler your Claude Code setup uses — for example the `schedule` skill, a
`scheduled-tasks/` entry, or a cron job that invokes `claude -p`:

```bash
# Example: a weekly cron entry (Mondays 09:00) running the shipped routine.
# Point the prompt at the routine skill body so the scheduled session follows it.
0 9 * * 1  claude -p "Follow the weekly-skill-observation-review routine in the \
  gpereira-harness plugin (routines/weekly-skill-observation-review/SKILL.md) exactly." \
  >> "$HOME/.claude/logs/weekly-skill-review.log" 2>&1
```

Adapt the schedule and invocation to your environment. Keep routine **state**
(logs, review dates) under your personal `~/.claude/`, never in a project repo.

## Writing your own

Copy `routines/weekly-skill-observation-review/SKILL.md` as a template:

- Frontmatter `name` + `description` (one line each).
- A numbered, self-contained procedure — a routine runs with **no prior
  conversation context**, so it must be fully explicit.
- Read-only routines must say so loudly and take no destructive action.
- Reference paths relative to `~/.claude/` or the context vault, never absolute
  machine paths, so the routine travels between machines.
