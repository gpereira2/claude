# Section 4: Output

## 4.1 Review summary

Present findings grouped by severity:

"Summary for [ticket] — [title]:
Items reviewed: X of Y (Z skipped)
**Blockers (N):** … **Issues (N):** … **Suggestions (N):** … **Notes (N):** …

Accurate? Any corrections before we proceed?"

The reviewer's corrections take priority.

## 4.2 Choose output(s)

If a default preference is saved: "Last time you went with [report and comment]. Same again, or different?"

Otherwise: "What should I do with these? Pick any, all, or none:
1. **Report** — a formatted Markdown file to share with the developer.
2. **Ticket comment** — post the findings on the ticket.
3. **Code changes** — I implement the fixes on a separate branch.
Or just keep the notes."

Outputs aren't mutually exclusive.

### Output A — Markdown report

Save to `$CTX/ux-review/<ticket>/review-report.md`: title, date and reviewer, a summary with severity counts, findings grouped by severity (each with feedback, observations, screenshots, design comparison), accessibility and responsive findings if checked, and a consolidated list of suggested changes. Non-technical throughout. Preview before finalising.

### Output B — Ticket comment

Post through the configured issue-tracker MCP — blockers first, then issues, suggestions, passes. **Preview first:** "Here's what I'll post. Happy with this?" Post only after explicit approval.

### Output C — Code changes

- Create a branch: `<original-branch>-ux-review`.
- Implement the reviewer's agreed UI changes.
- Commit: "UX review changes for [ticket]".
- **Never push without asking:** "Made the changes locally. Want me to push and open a draft PR?" — yes → push + draft PR linking the original PR and ticket; no → leave it local.
- Describe changes in plain language ("moved the button to the right", not a CSS property).

## 4.3 Wrap up

"Done. Here's what we produced:
- [Report at $CTX/ux-review/<ticket>/review-report.md]
- [Comment posted to the ticket]
- [Changes on branch <original-branch>-ux-review]

Start another review, or finished?"

- Another → back to Section 2.
- Finished → save final state and exit.
