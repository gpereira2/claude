---
name: visual-plan
description: Renders an approved implementation plan, or a completed change's recap, as a self-contained visual page — published as a Claude Artifact when that tool is available, otherwise written as a standalone HTML file next to the plan in the context vault. Two modes — "plan" (phases, sequencing, dependencies, decisions with rationale, rejected alternatives, open risks) and "recap" (a diff or PR walkthrough — before/after, files touched by concern, what was verified). Trigger on "show me the plan", "make a visual plan", "render this as a page", "visual recap of this PR", "turn this plan into something I can look at", or any request for a shareable/visual rendering of a plan or change. Do NOT trigger on ordinary planning — the ordinary plan-mode flow and its plan-persist hook already produce and save the plan; this skill only adds a visual view on top when one is explicitly wanted.
---

# Visual Plan

Adds a visual VIEW on top of the plan/recap markdown that already lives in the
context vault. It never replaces that markdown and never runs instead of it.

**The vault markdown is the record. The Artifact (or HTML file) is only a
view, generated from it.** Every run of this skill writes or updates the vault
markdown first, then renders the visual from that content. Never produce a
visual with no corresponding markdown — if the markdown does not exist yet,
write it before rendering anything.

Reaching for this on a small change is waste — a two-line fix or a plan the
user already approved in chat needs no page. Use it only when a visual or
shareable rendering is explicitly wanted.

## Two modes

- **`plan`** — an approved implementation plan: phases and sequencing,
  dependencies between them, decisions with their rationale, alternatives that
  were rejected and why, open risks.
- **`recap`** — what a completed change actually did: a diff or PR summarised
  as a walkthrough, before/after behaviour, files touched grouped by concern,
  what was verified (tests run, manual checks).

Both modes follow the same pipeline: resolve vault location → write/update
markdown → render HTML → publish or save.

## Step 1 — resolve the vault location

Resolve the vault root the same way the harness always does:

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/context-store.sh" path
```

Then pick the destination the same way `plan-persist-context.sh` does — a
ticket branch gets `tickets/<TICKET>/`, anything else gets a dated slug under
`plans/`:

- Ticket work: `<vault>/tickets/<TICKET>/plan.md` (or `recap.md`)
- Untracked work: `<vault>/plans/<date>-<slug>.md` (or `<date>-<slug>-recap.md`)

If a `plan.md` already exists for this ticket from the plan-persist hook,
treat it as the source and reconcile rather than duplicating it — don't create
a second markdown file for the same plan.

## Step 2 — write or update the markdown

Before touching HTML, make sure the markdown in the vault is current:

- `plan` mode: phases, dependencies, decisions + rationale, rejected
  alternatives, open risks — the same content the plan-persist hook asks for.
- `recap` mode: summarise the diff/PR into a walkthrough — what changed and
  why, files grouped by concern, what was verified. Read the actual diff
  before writing this; don't describe a change you haven't looked at.

## Step 3 — render the HTML

Build one self-contained HTML file from the markdown's content, next to it in
the same vault folder (`plan.html` / `recap.html`, or the slug's `-recap.html`
variant). Constraints that are non-negotiable because of how the Artifact tool
actually works:

- **Fully self-contained.** A strict CSP blocks every external host — no CDN
  scripts, no external stylesheets or fonts, no remote images. Inline all CSS
  and JS; embed any asset as a data URI.
- **Diagrams via Mermaid, not hand-drawn SVG.** Dependency graphs, phase
  sequencing, and before/after flows render natively from
  `<pre class="mermaid">...</pre>` blocks in HTML — no library to vendor.
  Prefer this over hand-rolled SVG whenever the content is a graph or flow.
- **Theme-aware.** Support both light and dark — the artifact renders in
  whichever theme the viewer has set.
- **No horizontal page scroll.** Wide tables or diagrams get their own
  `overflow-x: auto` container; the page body never scrolls sideways.
- **Favicon and description required to publish** — one or two emoji, kept
  stable across re-publishes of the same plan/recap. Only change it on a hard
  topic pivot, not on routine updates.

Load the `artifact-design` skill before writing the page, same as any other
Artifact — it calibrates how much design effort the content warrants.

## Step 4 — publish or save

**If the Artifact tool is available:** publish the HTML file with it. Reuse
the **same file path** on every subsequent update of this plan/recap — a
different path mints a new URL, fragmenting one plan across several links.
The stable path is exactly the one from Step 3, so re-running this skill on
the same ticket/plan always redeploys the same Artifact.

**If the Artifact tool is not available** (headless session, plain CLI, no
Artifact capability in this environment): skip publishing. The HTML file from
Step 3 already exists in the vault next to the markdown — tell the user its
path and that it can be opened directly in a browser. Nothing else is needed;
the skill has still fully done its job because the markdown record and a
visual view of it both exist on disk.

In both cases, nothing generated by this skill leaves the machine except the
one Artifact publish call itself, which goes to the user's own Claude
Artifacts — never a third-party plan-hosting service, and never any other
destination.

## What this skill is not

- Not a replacement for the plan-persist hook or the ordinary plan-mode flow —
  those already produce and save the plan; this only visualises it.
- Not for every plan. A plan approved in chat and immediately implemented
  needs no visual — only render one when a visual or shareable rendering was
  actually asked for.
- Not a way to move plan storage anywhere new — the vault markdown stays the
  single record; this generates a derived view alongside it, never instead of
  it.
