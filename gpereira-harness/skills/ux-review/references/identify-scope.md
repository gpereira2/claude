# Section 2: Identify scope

## 2.1 Get the starting point

If not already given: "What would you like to review? Give me a ticket key (like ABC-123) or a PR link."

## 2.2 Resolve the full picture

Fetch through whatever issue-tracker and code-host MCPs are configured — resolve the tool from the live MCP surface; don't assume a specific tracker. Use the code host (e.g. `gh`) for PRs.

| Reviewer gives | Claude does |
|----------------|-------------|
| **Ticket** | Fetch the ticket → check its links/attachments for a PR → search the code host by ticket key in the title or branch. No PR? "Found the ticket but no code ready yet. Review the requirements instead, or come back later?" |
| **PR** | Fetch the PR → extract the ticket key from the title (`[ABC-123]`) or branch → fetch the ticket. No ticket? "No linked ticket found — I'll use the PR description." |

## 2.3 Gather material (silently)

- **From the ticket:** summary, description, acceptance criteria, comments, attachments.
- **From the PR:** description, screenshots, test plan, and the changed areas — to know which pages are affected. Never surface file names to the reviewer.
- **From Figma:** if a Figma URL appears in the ticket or PR and the Figma MCP is available, fetch the design for visual comparison.

## 2.4 Present the context

"Here's what I found:

**What it's about:** [plain-language summary]
**The problem it solves:** [from the description]
**What should have changed:** [user-facing terms — 'a new section on the checkout page', not a component name]
**Design reference:** [Figma found → 'I'll compare against the linked design.' / none → 'No design linked. Got a Figma URL?']

Does this look right, or is there context to add?"

## 2.5 Check out and run the branch

After the reviewer confirms:

- Check out the PR's branch (plain git).
- **Bring the app up the way this project does** — follow its `CLAUDE.md` / setup docs for installing dependencies, preparing the database, and starting the dev server. This skill doesn't define those commands; each project has its own. If the project documents no way to run it, say so and ask the reviewer how they normally start it.
- **Never run destructive database commands** (wipes, fresh migrations, resets) — forbidden regardless of consent; a review must not cost the reviewer their local data.
- If the app won't start after the project's normal steps: "The app didn't come up — this needs a developer before we can review. I'll stop here." Stop and refer on.
- "Ready. Let's start."
