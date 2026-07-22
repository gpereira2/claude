## Principle Propagation

When an observation reveals a general principle — something that applies not
just to the skill being improved but to skills in general — it should be
propagated across the skill library, not just applied to the one skill that
triggered it.

### The Cross-Cutting Principles File

Cross-cutting principles are tracked in a persistent file alongside the
observation log:

```
[workspace folder]/skill-observations/principles.md
```

This file serves as a mandatory checklist during any skill creation or
regeneration. Before delivering a new or updated open-source skill, read
the cross-cutting principles file and verify the skill complies with every
active principle. This is what turns general principles from good intentions
into enforced standards.

### How It Works

1. During a skill update, an observation reveals a principle that applies
   broadly — not just to the skill being worked on
2. Log it as an observation with `Skill: All skills` and surface it to the
   user
3. If the user approves it as a cross-cutting principle, add it to the
   cross-cutting principles file
4. From that point forward, every skill creation or regeneration includes
   a compliance check against the full list of active principles

### Propagation Timing

The user decides when and how to propagate each principle:

- **Immediate propagation** — for principles important enough to warrant
  updating all existing skills right away (e.g., a confidentiality rule)
- **Opportunistic propagation** — for principles that can be applied the
  next time each skill is updated or regenerated (e.g., adding a licence
  statement)

### Cross-Cutting Principles File Structure

```markdown
# Cross-Cutting Principles

Principles that apply to all skills. This file is read as a mandatory
checklist during any skill creation or regeneration.

---

## Active Principles

### 1. [Principle title]
**Added:** [date]
**Applies to:** [all skills | all open-source skills | all skills with rules]
**Requirement:** [what the principle requires]
**Propagation:** [immediate | opportunistic]
**Status:** [active]
```

---

