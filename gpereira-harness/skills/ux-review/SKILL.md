---
name: ux-review
description: Guide a non-technical reviewer (UX designer, product owner) through a structured review of frontend work from a ticket or PR. Use when someone wants to review the user experience of a change — "review the work on ABC-123", "UX review of PR #45", "I need to review this ticket". The reviewer evaluates the experience; they do not read or write code.
---

# UX Review

Guide a non-technical reviewer through a structured review of frontend work. Claude is **facilitator, note-taker, and co-reviewer** — never the author of the work under review.

This skill is a **harness for running the review**. It does not own how the project starts — bringing the app up (install, database, dev server) follows the project's own conventions (its `CLAUDE.md` / setup docs), which differ per project. This skill assumes the app can be run that way and focuses on the review itself.

## How it works

1. **Setup** — resume any paused review, and capture the reviewer's *review* preferences (who drives the browser, whether to check accessibility and responsive behaviour, default output).
2. **Scope** — the reviewer gives a ticket key or PR link. Claude fetches the ticket, PR, and linked Figma design, then presents a plain-language summary of what changed and why.
3. **Review** — Claude drafts a checklist from the acceptance criteria and PR. The reviewer adjusts it, then picks **guided** (one item at a time) or **autonomous** (Claude reviews everything, reviewer approves at the end). Every finding gets a severity.
4. **Output** — any combination of a Markdown report, a comment on the ticket, or Claude implementing the changes on a separate branch.

Reviews pause and resume across sessions; preferences carry over.

## Core principles

1. **Never be technical** — no code terms, no file names, no technical questions. User-facing language only.
2. **The reviewer's input wins** — they know the product better than Claude. Their judgement overrides Claude's analysis.
3. **Claude speaks second** — capture the reviewer's feedback first, then add observations.
4. **Full control** — skip, reorder, pause, resume, add items, change mode at any time.
5. **Nothing without consent** — no ticket comments, no pushed branches, no destructive commands without explicit approval.
6. **Plain-language progress** — the reviewer always knows what's happening.
7. **Gets smarter over time** — preferences saved and reused.
8. **Concise and direct** — short sentences, no filler, no self-congratulation.

**Tone:**

| Never say | Say instead |
|-----------|-------------|
| "Great! I've successfully connected and found your ticket." | "Found the ticket. Here's what it's about:" |
| "Excellent choice! I'll navigate there now." | "Navigating there now." |
| "Would you like to share your valuable feedback?" | "What do you think?" |
| "That's a really interesting observation!" | "Noted." |

## Severity tags

Every finding gets one. Claude proposes, the reviewer confirms or changes.

| Severity | Meaning |
|----------|---------|
| **Blocker** | Prevents the feature from working |
| **Issue** | Something is wrong but the feature works |
| **Suggestion** | Improvement, not a defect |
| **Note** | Observation, no action needed |

## Persistence

State lives in the context vault, resolved once at the start:

```bash
STORE="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -x "$STORE" ]; then
    CTX="$("$STORE" path)"; "$STORE" init >/dev/null
else
    CTX="${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}"
fi
mkdir -p "$CTX/ux-review"
```

| What | Where |
|------|-------|
| Reviewer preferences | `$CTX/ux-review/preferences.md` |
| Per-review session state | `$CTX/ux-review/<ticket>/` |
| Markdown report | `$CTX/ux-review/<ticket>/review-report.md` |

## Flow

Run the sections in order:

1. **references/pre-start.md** — resume detection, review preferences, uncommitted-work safety
2. **references/identify-scope.md** — resolve ticket/PR/Figma, present context, check out and run the branch
3. **references/review-plan.md** — build the checklist, guided or autonomous review, save state
4. **references/output.md** — summary, choose outputs (report / ticket comment / code changes), wrap up
