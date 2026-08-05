---
name: handoff
description: Compact the current conversation into a curated handoff document a fresh agent can read to pick the work up. Saved to the context vault.
argument-hint: "[what the next session will focus on]"
disable-model-invocation: true
---

# Handoff

Write a curated handoff document that summarises this conversation so a fresh agent can continue the work without re-reading the transcript.

## The handoff system

This skill is the **curated** tier of one handoff system. The `precompact-handoff.sh` and `sessionstart-handoff.sh` hooks are the **automatic** tier: a shell hook has no model, so at compaction it can only dump raw transcript to `⟨vault⟩/handoffs/auto/<session>.md` and re-inject it on resume. This skill is the model-synthesised version, invoked deliberately, and it seeds itself from that snapshot. Both tiers live under one vault folder — `handoffs/auto/` for the raw snapshots, `handoffs/` for the curated docs.

## Seed from the latest auto-snapshot

Before synthesising, read the most recent auto-snapshot for this session as raw material — it already holds the recent transcript:

```bash
STORE="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -x "$STORE" ]; then
    CTX="$("$STORE" path)"; "$STORE" init >/dev/null
else
    CTX="${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}"
fi
ls -t "$CTX/handoffs/auto/"*.md 2>/dev/null | head -1
```

The snapshot is a starting point, not the document — synthesise the curated handoff from the live conversation, using the snapshot to jog what the transcript held.

## Contents

Carry only the **live thread** — what you were doing, why, the current state, and what comes next. Anything already captured elsewhere (a spec, plan, ADR, issue, commit, or diff) is referenced by path or URL, never copied: duplicating it just creates a second copy to keep in sync.

- **Goal** — the outcome the work is driving at, in one or two lines.
- **State** — what is done, what is in flight, what is verified vs assumed.
- **Next** — the concrete next step, and any decision waiting on the user.
- **Watch out** — the gotchas and dead ends already hit, so they aren't repeated.
- **References** — specs, plans, issues, key files (`path:line`), by pointer.
- **Suggested skills** — the skills the next agent should reach for to continue.

If the user passed an argument, treat it as what the next session will focus on and slant the document toward that.

**Redact** anything sensitive — API keys, passwords, personal data — rather than carrying it into the document.

## Where it goes

Write the curated doc to `$CTX/handoffs/<slug>.md` with YAML frontmatter (`title`, `type: handoff`, `tags`), then report the path so it can be handed on. This is per-user working state — it lives in the vault, never the project repo.
