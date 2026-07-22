## Acting on Observations

This skill identifies WHAT to build or improve. This section covers HOW —
specifically, the cross-context decision framework for choosing between
direct application, skill-creator handoff, and new-skill creation.

**Trigger gate (when):** Observations are acted on only in three contexts:

1. **The comprehensive review** — scheduled mode preferred, in-session
   fallback if no scheduled review has run in 7+ days. See
   "## Comprehensive Review (scheduled or fallback)" for the procedure.
2. **Explicit user requests during a task session** — "update X skill",
   "act on observation #N now", "apply this rule to the skill". The user
   is naming the action; the agent executes within the framework below.
3. **In-session correction when a skill is producing wrong output and
   the user should be aware** — surface immediately rather than wait
   for the next review.

Observations are NOT applied during normal task sessions outside these
contexts. Mid-task work produces observations only; those observations
get applied at the next review or by request. The default is log,
don't act.

**Mechanism framework (which):** When acting in any of those contexts,
the rest of this section guides the choice between applying changes
directly to the skill file, handing off to the skill-creator for
substantial restructuring, or creating a new skill from scratch.

### Small Changes

If the improvement is clearly additive, low-risk, and doesn't require testing
to verify it works, it can be applied directly to the skill:

- Adding a new rule or anti-pattern to an existing list
- Clarifying existing wording that proved ambiguous
- Adding a note or edge case to an existing section
- Fixing a factual error

Examples: Adding a new anti-pattern to a skill's anti-patterns list.
Clarifying that inline code comments should be context-aware within their
own document.

After creating or updating any skill file, always present it using `present_files` so the user can review and install it directly from the conversation.

### Substantial Changes (Use Skill-Creator if Available)

If the change could affect the skill's behaviour in ways that need
verification, hand off to the skill-creator if available:

- Restructuring phases or workflows
- Adding new capabilities or sections
- Changing core methodology or decision frameworks
- Any change where "does this actually work better?" is a genuine question

However, match the rigour of the skill creation process to the complexity and
audience. Skill-creator is valuable for open-source skills that need testing,
for skills with complex logic, or when the design isn't yet clear. For internal
skills where requirements are established in conversation, writing directly is
more efficient.

If skill-creator is not available, use the observations as a specification
and make the changes directly — but flag them to the user as substantial
changes that may need manual review.

Examples: Restructuring a skill to make an automated workflow the primary
path instead of a secondary option. Adding an entirely new setup phase to
a skill that previously started with content work.

### Creating New Skills

Use the skill-creator for new skills when available. Provide the
observation(s) as context — they contain the intent, scope, and initial
design thinking needed to get started efficiently. Without skill-creator,
the observations serve as a detailed brief for building the skill manually.

When creating a new skill, determine its type early:

- If it's open-source, strip out any client-specific details and generalise
- If it's internal, include all relevant specifics freely
- If uncertain, default to open-source — strip out specifics and generalise,
  then let the user decide whether any internal details need to be added


