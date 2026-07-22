# gpereira-harness

A portable Claude Code **plugin**. Bundles the `orchestrator`, `agent-selector`,
and `task-observer` skills, four named worker agents, a set of enforcement /
safety / observability hooks, four-tier model routing that survives model
version changes, an Obsidian-compatible context store, and routine templates —
installed through Claude Code's native plugin system, no shell installer
required.

**Not included, by design:** MCP registrations (URLs, scopes, auth). Those are
personal and workspace-specific, so each user wires their own. See
[`docs/MCP-SUGGESTIONS.md`](docs/MCP-SUGGESTIONS.md). The bundled hooks are
plugin-scoped and reference no endpoints — nothing here leaks workspace access.

---

## Install

```
/plugin marketplace add gpereira2/claude
/plugin install gpereira-harness@gpereira-harness-marketplace
```

The plugin system loads the skills, agents, and `hooks/hooks.json`, and sets
`${CLAUDE_PLUGIN_ROOT}` for the bundled libs and hook scripts. Nothing is written
into `~/.claude` and no MCP config is touched. Reload in place with `/plugin`
after an update.

The context vault is created lazily on first use (default `~/.claude/context`,
override with `$CLAUDE_CONTEXT_DIR`).

**Requirements:** `bash`, `jq`, `python3` (two guard hooks), `curl` (live model
routing; optional).

---

## What's inside

| Path | Purpose |
|------|---------|
| `skills/orchestrator/` | Pure-coordinator pipeline conductor; persists state to the context vault, never the repo |
| `skills/agent-selector/` | Plan → tiered task manifest → parallel worker subagents |
| `skills/task-observer/` | Continuous skill-improvement registry (observation log + weekly review). Third-party, CC BY 4.0 — see below |
| `agents/*.md` | `discovery`, `implementer`, `test-writer`, `reviewer` — least-privilege tool allowlists |
| `hooks/` | Enforcement, safety, and observability hooks wired via `hooks/hooks.json` (see below) |
| `lib/resolve-models.sh` | Hybrid tier→model resolver: live Anthropic Models API, falls back to `tiers.json` offline |
| `lib/tiers.json` | FAST / STANDARD / DEEP / FRONTIER → family regex patterns + pinned fallbacks |
| `lib/context-store.sh` | Resolves `$CLAUDE_CONTEXT_DIR` (default `~/.claude/context`); inits an Obsidian vault |
| `routines/` | Scheduled-task templates (not auto-loaded) — see [`docs/ROUTINES.md`](docs/ROUTINES.md) |
| `docs/` | MCP suggestions, routine registration, and a `CLAUDE.md` example (template only) |
| `test/smoke.sh` | Sanity checks + a leak gate (internal-reference / secret / absolute-path scan) |

---

## Hooks

Plugin-scoped and endpoint-free — they wire into your session via
`hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}` paths, and touch no
`settings.json` and no MCP config.

| Hook | Event | Role |
|------|-------|------|
| `agent-dispatch-conduct-gate.sh` | PreToolUse(Task) | Blocks a dispatch that carries a return contract but no conduct block |
| `subagent-contract-gate.sh` | SubagentStop | Validates a worker's final message is honest contract JSON (fail-open) |
| `subagent-trace.sh` | SubagentStart/Stop | Appends a JSONL audit trace of every subagent to the vault |
| `subagent-trace-summary.sh` | (CLI helper) | Renders a markdown summary table from a trace file |
| `bash-clause-guard.py` | PreToolUse(Bash) | Deny-only guard: decomposes compound commands, blocks catastrophic clauses |
| `secret-scan-guard.py` | PreToolUse(Write\|Edit) | Asks before writing content that looks like real credentials |
| `precompact-handoff.sh` | PreCompact | Snapshots in-flight session state before compaction |
| `sessionstart-handoff.sh` | SessionStart(resume\|compact) | Re-injects the pre-compaction snapshot on resume |
| `storage-root-hint.sh` | SessionStart / SubagentStart | Injects the vault (`$CLAUDE_CONTEXT_DIR`) as the canonical doc/state root, keeping generated files out of the repo |
| `plan-persist-context.sh` | PostToolUse(ExitPlanMode) | Nudges the approved plan into the vault (`tickets/<TICKET>/plan.md` or `plans/<date>-slug.md`) |
| `docs-location-guard.sh` | PreToolUse(Write) | **Opt-in** (`CLAUDE_HARNESS_DOCS_GUARD=1`): redirects new generated `.md` from the repo to the vault; off by default so it never fights real repo docs |

The two gate hooks make the harness self-enforcing: the conduct/contract rules in
`orchestrator` + `agent-selector` are checked by hooks, not left to good
intentions. Traces land in the vault (`tickets/<TICKET>/subagents.jsonl` or
`traces/subagents-<date>.jsonl`), never in the project repo.

---

## Model routing (version-agnostic)

Tiers map to **family regex patterns**, never dated model IDs.
`resolve-models.sh` queries the Anthropic Models API and picks the newest model
whose ID matches each tier's pattern; when the API is unreachable it uses the
pinned `fallback` in `tiers.json`.

| Tier | Family | Notes |
|------|--------|-------|
| FAST | `^claude-haiku` | cheapest; mechanical work |
| STANDARD | `^claude-sonnet` | implementation, tests, research |
| DEEP | `^claude-opus` | architecture, ambiguous specs, review |
| FRONTIER | `^claude-fable` | long-horizon/self-verifying work |

> **FRONTIER → Fable.** FRONTIER targets the Fable family, which is
> permission-gated and absent from most API keys. Its fallback is Opus, so on a
> key without Fable access the resolver returns a working Opus model rather than
> nothing. If you never use Fable, point FRONTIER back at `^claude-opus` in
> `tiers.json`.

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh"          # {"FAST":...,"STANDARD":...,"DEEP":...,"FRONTIER":...}
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh" DEEP     # single tier
```

---

## Context store (Obsidian-compatible)

Pipeline state lives in a vault, **not** in the project repo. Location:
`$CLAUDE_CONTEXT_DIR`, default `~/.claude/context`. The folder is a valid
Obsidian vault (`.obsidian/` marker); per-ticket notes use YAML frontmatter,
`[[wikilinks]]`, and fenced json blocks so prose and machine state both render.

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/context-store.sh" path              # resolved vault dir
"${CLAUDE_PLUGIN_ROOT}/lib/context-store.sh" ticket-dir T-123  # per-ticket subdir
```

---

## Routines

A plugin can't contain a live scheduled task, so routine **skills** ship as
templates under `routines/` (not auto-loaded) and you register the ones you want
per-machine. See [`docs/ROUTINES.md`](docs/ROUTINES.md). Machine/workspace-specific
routines are intentionally excluded.

---

## task-observer (third-party)

`skills/task-observer/` is **Created by Eoghan Henn / rebelytics.com**, released
under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) and bundled here
unmodified with its attribution intact. It captures skill-improvement
observations into `~/.claude/skill-observations/` and consolidates them in a
weekly review — the "self-discovery" layer that lets the skill set improve over
time.

---

## CLAUDE.md — example only

Your `~/.claude/CLAUDE.md` (identity, company context) is **personal and never
installed or overwritten** by this plugin. A template ships at
[`docs/CLAUDE.example.md`](docs/CLAUDE.example.md). Operational context lives in
the skill bodies, not `CLAUDE.md`, so it travels with the capability.

## Verify before publishing changes

```bash
bash test/smoke.sh   # → PASS: all smoke checks + leak gate clean
```

The leak gate fails the build on any company-internal reference, absolute home
path, or hardcoded key material in the shareable files.

## License

MIT — see [`LICENSE`](LICENSE). `skills/task-observer/` is CC BY 4.0 (see above).
