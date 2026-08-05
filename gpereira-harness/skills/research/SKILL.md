---
name: research
description: Investigate a question against high-trust primary sources and leave a cited Markdown note behind in the context vault. Use when the user wants a topic researched, docs or API facts gathered, an unfamiliar library or protocol understood, or reading legwork delegated so the main session keeps moving.
---

# Research

Answer a question from the sources that **own** the answer, and leave a note whose every claim traces back to one of them.

Spin the reading up as a **background agent** so the main session keeps working while it reads.

## The agent's job

1. **Read primary sources only** — official docs, source code, specs, first-party APIs, the RFC itself. A secondary write-up (a blog post, a forum answer, a summary of the docs) is a lead to the primary source, never the citation. Follow every claim back to the source that owns it.
2. **Cite every claim.** Each statement in the note carries the URL or `file_path:line` it came from. A claim with no source does not go in the note.
3. **Separate fact from inference.** What a source states and what you concluded from it are different tiers — mark the second as yours.
4. **Record what the sources don't settle.** A question they leave open is itself a finding; write it down rather than closing the gap from memory.

## Where the note goes

Resolve the vault the way the rest of the harness does, then write under `spikes/`:

```bash
STORE="${CLAUDE_PLUGIN_ROOT:-}/lib/context-store.sh"
if [ -x "$STORE" ]; then
    CTX="$("$STORE" path)"; "$STORE" init >/dev/null
else
    CTX="${CLAUDE_CONTEXT_DIR:-$HOME/.claude/context}"
fi
mkdir -p "$CTX/spikes"
```

Write one Markdown file to `$CTX/spikes/<slug>.md`, Obsidian-compatible: YAML frontmatter (`title`, `type: research`, `tags`), then the question, the findings each with its citation, the open questions, and a sources list. Report the path back; keep the note's body out of the main session's context.

## Completion criterion

Done when every claim in the note carries a primary-source citation, the open questions are listed rather than papered over, and the file is saved and its path reported.
