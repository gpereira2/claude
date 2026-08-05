# Section 1: Pre-start

## 1.1 Resume detection

Check `$CTX/ux-review/` for an existing session.

**If found:** "I found an unfinished review for ABC-123 from [date]. Pick up where you left off, or start fresh?"

**If resuming:** load the saved state, pull the latest changes on the branch (the developer may have pushed fixes since), bring the app back up the project's usual way, and continue from where the reviewer stopped.

## 1.2 Review preferences

Check `$CTX/ux-review/preferences.md`. If missing or incomplete, ask only what's missing and save it for next time. These are *review* preferences — not project setup, which the project owns.

| Preference | Ask once | Values |
|------------|----------|--------|
| **Navigation** | "During reviews, want me to drive the browser, or do you prefer to? You can change this anytime." | `claude` / `self` |
| **Accessibility** | "Include basic accessibility checks?" | `yes` / `no` |
| **Responsive** | "Check different screen sizes?" | `yes` / `no` |
| **Default output** | "After a review, what do you usually want — a report, a comment on the ticket, code changes, or a mix?" | e.g. `report,comment` |

## 1.3 Handle uncommitted changes

Reviewing means switching branches, so the current work must be safe first. Check `git status` and the current branch.

- **On the base branch (`${CLAUDE_BASE_BRANCH:-main}`):** never commit here. "You have unsaved changes on the main branch, which I won't commit to. Want to save them elsewhere first, or stash them temporarily?"
- **On a feature branch:** "You have unsaved changes on [branch]. Want me to commit them before we switch?" — commit if yes; stash only as a last resort, warning about it.
- **Nothing uncommitted:** carry on.
