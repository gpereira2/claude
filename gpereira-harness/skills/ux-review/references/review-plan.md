# Section 3: Review plan

## 3.1 Draft the checklist

Build items in plain language, in priority order of source:

1. Acceptance criteria from the ticket
2. PR description
3. Claude's read of the affected pages/features
4. Figma comparison items (if a design was found)

Add optional items only where the preference is on:
- **Accessibility:** e.g. "Check colour contrast on new elements", "Verify keyboard navigation".
- **Responsive:** e.g. "Check the layout at tablet size", "Verify nothing breaks on a small screen".

## 3.2 Present and negotiate

"Based on the ticket and PR, here's what I suggest:

**Core checks:** 1. … 2. …
**Accessibility checks:** _(if on)_ …
**Responsive checks:** _(if on)_ …

You're in full control — remove, add, reword, or replace the whole list. What would you change?"

Adjust until the reviewer is happy, then confirm the final list.

## 3.3 Choose the mode

"How would you like to run this?
- **Guided** — one item at a time, you give feedback after each.
- **Autonomous** — I go through everything and present the findings at the end."

## 3.4a Guided mode

For each item:

1. **Present:** "Next: [item]".
2. **Navigate:** per the saved preference; the reviewer can override per item.
3. **Compare:** if a design exists, show design vs live.
4. **Reviewer explores** — in their own time.
5. **Collect feedback:** "What do you think?"
6. **Add observations** — after the reviewer, never before.
7. **Severity:** propose one — "I'd call this an Issue. Agree?" — reviewer confirms or changes.
8. **Record** feedback + observations + severity.
9. **Move on:** "Next?"

Reviewer controls: "skip" → mark skipped; "let me check item 5 first" → reorder; "go back to item 2" → revisit; "add something" → new item mid-review; "stop" → save and resume later.

## 3.4b Autonomous mode

Work through each item with the browser, capturing a screenshot at each step; compare against Figma where it applies; run the accessibility and responsive checks if their preferences are on; tag each finding with a proposed severity. Then present grouped by severity:

"Done. Here's what I found:
**Blockers:** [item] — [description + screenshot]
**Issues:** …
**Suggestions:** …
**All clear:** [item] — looks good

For each, tell me if you agree, disagree, or want to change the severity."

## 3.5 Save state (continuously)

Write to `$CTX/ux-review/<ticket>/`: the checklist with per-item status (done / skipped / pending), feedback (reviewer + Claude), severity, screenshots and design comparisons, the mode, and a timestamp.
