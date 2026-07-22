# gpereira-harness

A portable Claude Code **plugin**. Bundles the `orchestrator` and `agent-selector`
skills, four named worker agents, four-tier model routing that survives model
version changes, and an Obsidian-compatible context store — installed through
Claude Code's native plugin system, no shell installer required.

**Not included, by design:** MCP registrations (URLs, scopes, auth) and hooks
that reference them. Those are personal and workspace-specific, so each user
wires their own. See [`docs/MCP-SUGGESTIONS.md`](docs/MCP-SUGGESTIONS.md). This
keeps the harness safe to share — nothing in here leaks workspace access.

---

## Install

```
/plugin marketplace add gpereira2/claude
/plugin install gpereira-harness@gpereira-harness-marketplace
```

That's it — the plugin system loads the skills and agents, sets
`${CLAUDE_PLUGIN_ROOT}` for the bundled libs, and picks up `hooks/hooks.json`
(empty by default). Nothing is written into `~/.claude`, and no MCP config is
touched. Reload in place with `/plugin` after an update.

The context vault is created lazily on first use (default `~/.claude/context`,
override with `$CLAUDE_CONTEXT_DIR`).

---

## What's inside

| Path | Purpose |
|------|---------|
| `skills/orchestrator/` | Pure-coordinator pipeline conductor; persists state to the context vault, never the repo |
| `skills/agent-selector/` | Plan → tiered task manifest → parallel worker subagents |
| `agents/*.md` | `discovery`, `implementer`, `test-writer`, `reviewer` — least-privilege tool allowlists |
| `lib/resolve-models.sh` | Hybrid tier→model resolver: live Anthropic Models API, falls back to `tiers.json` offline |
| `lib/tiers.json` | FAST / STANDARD / DEEP / FRONTIER → family regex patterns + pinned fallbacks |
| `lib/context-store.sh` | Resolves `$CLAUDE_CONTEXT_DIR` (default `~/.claude/context`); inits an Obsidian vault |
| `lib/templates/ticket.md.tmpl` | Obsidian-compatible ticket note (frontmatter + embedded JSON) |
| `hooks/hooks.json` | Empty scaffold — add your own; no MCP refs |
| `docs/` | MCP suggestions + a `CLAUDE.md` example (template only) |
| `test/smoke.sh` | Sanity checks (resolver JSON, vault init, manifest validity) + a leak gate |

---

## Model routing (version-agnostic)

Tiers map to **family regex patterns**, never dated model IDs.
`resolve-models.sh` queries the Anthropic Models API and picks the newest model
whose ID matches each tier's pattern; when the API is unreachable it uses the
pinned `fallback` in `tiers.json`. New model versions are adopted automatically
— retune by editing `tiers.json` alone.

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh"          # {"FAST":...,"STANDARD":...,"DEEP":...,"FRONTIER":...}
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh" DEEP     # single tier
```

| Tier | Family | Notes |
|------|--------|-------|
| FAST | `^claude-haiku` | cheapest; mechanical work |
| STANDARD | `^claude-sonnet` | implementation, tests, research |
| DEEP | `^claude-opus` | architecture, ambiguous specs, review |
| FRONTIER | `^claude-fable` | long-horizon/self-verifying work |

> **FRONTIER → Fable.** FRONTIER targets the Fable family, which is
> permission-gated and absent from most API keys. Its fallback is Opus, so on a
> key without Fable access the resolver returns a working Opus model rather than
> nothing — FRONTIER only *activates* Fable when the key can actually see it.
> If you never use Fable, point FRONTIER back at `^claude-opus` in `tiers.json`.

Live resolution needs `ANTHROPIC_API_KEY` in the environment and `curl`; without
either, it falls back silently to `tiers.json`.

---

## Context store (Obsidian-compatible)

Pipeline state lives in a vault, **not** in the project repo. Location:
`$CLAUDE_CONTEXT_DIR`, default `~/.claude/context`.

The folder is a valid Obsidian vault (`.obsidian/` marker). Per-ticket notes use
YAML frontmatter, `[[wikilinks]]` that resolve within the vault, and fenced json
blocks so both the prose and the machine state render in Obsidian preview. Paths
in notes are relative — no absolute machine paths get baked in.

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/context-store.sh" path              # resolved vault dir
"${CLAUDE_PLUGIN_ROOT}/lib/context-store.sh" init              # create vault + index
"${CLAUDE_PLUGIN_ROOT}/lib/context-store.sh" ticket-dir T-123  # per-ticket subdir
```

---

## CLAUDE.md — example only

Your `~/.claude/CLAUDE.md` (identity, company context, "who I am") is **personal
and never installed or overwritten** by this plugin — for the same reason MCP
endpoints aren't bundled: it would leak your identity onto every teammate.

A template ships at [`docs/CLAUDE.example.md`](docs/CLAUDE.example.md). Copy it to
`~/.claude/CLAUDE.md` and fill in your own.

Operational context (how the orchestrator and workers behave, the tier
vocabulary) does **not** live in `CLAUDE.md` — it lives in the skill bodies, so
it travels with the capability and doesn't depend on anyone's global config.
Don't use a hook to inject `CLAUDE.md`; the file is already Claude Code's native
mechanism for standing context, and a hook would only reimplement it worse.

---

## Requirements

`bash`, `jq` (routing), `curl` (live routing; optional).

## Verify before publishing changes

```bash
bash test/smoke.sh   # → PASS: all smoke checks + leak gate clean
```

The leak gate fails the build if any company-internal reference or hardcoded key
material slips into the shareable files.

## License

MIT — see [`LICENSE`](LICENSE).
