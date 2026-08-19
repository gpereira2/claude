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
| `skills/agent-selector/references/worker-conduct.md` | The canonical conduct block, embedded verbatim in every dispatch — single source for the skill, the orchestrator's delegation contract, and `/review-queue` |
| `skills/agent-selector/references/disagreement-panel.md` | N-judge adversarial adjudication for decisions that are complex *and* contested; the generalisation of dual-inference |
| `skills/task-observer/` | Continuous skill-improvement registry (observation log + weekly review). Third-party, CC BY 4.0 — see below |
| `skills/visual-plan/` | Renders a vault plan or recap as a self-contained Artifact/HTML view — vault markdown stays the record, the page is only a view |
| `skills/agent-watchdog/` | Audits a *different* agent's or tool's handed-over work for drift from the brief and unverified completion claims |
| `skills/plan-arbiter/` | Merges two or more competing plans for the same work into one execution direction |
| `skills/adhd/` | `/adhd` — user-invoked only; shapes every reply for zero-friction reading until told to stop |
| `skills/for-junior-dev/` | `/for-junior-dev` — user-invoked only; pitches prose at a developer new to the codebase. Jargon glossed at first use, facts kept, code untouched |
| `skills/research/` | Investigates a question against primary sources only and leaves a cited note in the vault's `spikes/` |
| `skills/resolving-merge-conflicts/` | Resolves an in-progress merge/rebase by intent — traces each side to its source, never `--abort`, finishes the operation |
| `skills/handoff/` | `/handoff` — the curated tier of the handoff system: synthesises a vault handoff doc for a fresh agent (seeded from the auto-snapshot below), referencing artifacts rather than copying them |
| `skills/ux-review/` | Guides a non-technical reviewer through a structured UX review of a ticket/PR; a review harness that leaves project startup to the project |
| `agents/*.md` | `discovery`, `implementer`, `test-writer`, `reviewer` — least-privilege tool allowlists |
| `hooks/` | Enforcement, safety, and observability hooks wired via `hooks/hooks.json` (see below) |
| `lib/resolve-models.sh` | Hybrid tier→model resolver: live Anthropic Models API, falls back to `tiers.json` offline |
| `lib/tiers.json` | LIGHT / STANDARD / DEEP / FRONTIER → family regex patterns + pinned fallbacks |
| `lib/context-store.sh` | Resolves `$CLAUDE_CONTEXT_DIR` (default `~/.claude/context`); inits an Obsidian vault |
| `commands/` | `/start-ticket` (ticket → fresh branch/worktree + seeded vault folder + orchestrator recommendation), `/create-pr` (draft PR in a fixed format), `/review-queue` (parallel review of PRs awaiting you; never posts unprompted) |
| `routines/` | Scheduled-task templates (not auto-loaded) — see [`docs/ROUTINES.md`](docs/ROUTINES.md) |
| `docs/PRINCIPLES.md` | Cross-cutting principles, each extracted from an observed failure — the checklist for writing or reviewing a skill |
| `docs/writing-for-agents.md` | The authoring standard for skills and agent-facing docs — context pointers, the two loads, information hierarchy, leading words, pruning |
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
| `pretooluse-guard.py` | PreToolUse(Read\|Edit\|Write\|Grep\|Glob\|NotebookEdit\|Bash) | Single-spawn safety guard merging three checks: deny-only bash clause decomposition (blocks catastrophic clauses inside compound commands), hard-blocks reads of `auth.json`, `.env*` (bar `.example`/`.sample`/`.template`/`.dist`), `.npmrc`, `netrc`, and `*.pem` on both file-path and shell-command inputs, and **blocks** writing content that looks like real credentials (set `SECRET_SCAN_GUARD_MODE=ask` for the soft posture — but see the note below before relying on it) |
| `pr-context-hint.sh` | SessionStart | Injects the current branch's PR state — number, draft, CI rollup, review decision, mergeability — via read-only `gh`. Skips default branches; fails open |
| `context-status.sh` | statusline filter | Writes raw per-session context data for an external dashboard and passes stdin through. Not wired by `hooks.json` — pipe it before your statusline command |
| `precompact-handoff.sh` | PreCompact | Automatic tier of the handoff system: snapshots in-flight state to the vault's `handoffs/auto/` before compaction |
| `sessionstart-handoff.sh` | SessionStart(resume\|compact) | Re-injects the vault auto-snapshot on resume; the `handoff` skill turns it into a curated doc |
| `storage-root-hint.sh` | SessionStart / SubagentStart | Injects the vault (`$CLAUDE_CONTEXT_DIR`) as the canonical doc/state root, keeping generated files out of the repo |
| `plan-persist-context.sh` | PostToolUse(ExitPlanMode) | Nudges the approved plan into the vault (`tickets/<TICKET>/plan.md` or `plans/<date>-slug.md`) |
| `docs-location-guard.sh` | PreToolUse(Write) | **Opt-in** (`CLAUDE_HARNESS_DOCS_GUARD=1`): redirects new generated `.md` from the repo to the vault; off by default so it never fights real repo docs |
| `php-convention-lint.sh` | PostToolUse(Write\|Edit) | **Opt-in** (`CLAUDE_HARNESS_PHP_LINT=1`): advisory warnings on edited `.php` files for unprefixed `Log::` messages and static job dispatch. Reports, never blocks; off by default since both are project policy, not universal PHP |

### Two things to know before trusting a guard

**An "ask" verdict may be inert.** A session running with auto-approval
(permission mode `auto`, or a skip-prompt setting) resolves `permissionDecision:
"ask"` to approve with no prompt shown. A guard built on "ask" then blocks
nothing while appearing installed. Verified in one such environment: a write
containing a clean match for the AWS-key pattern completed with no prompt and no
block. That is why `pretooluse-guard.py`'s secret scan defaults to a hard block
and its credential-file check only ever emits `{"decision": "block"}`.

**A guard must never emit an explicit *approve*.** Approving the inputs it does
not care about does not merely pass the call — it short-circuits the permission
check that would otherwise have prompted. With a broad matcher (this one spans
`Bash`), a single narrow guard would silently auto-approve every unrelated
command in its scope. These hooks block, or exit silently. Nothing else.

**Matcher coverage is not obvious.** `Grep` prints file content but is *not*
matched by `Read|Edit|Write` — a credential guard wired only to those three
leaves an open channel. `pretooluse-guard.py` therefore matches the full
set of content-returning tools. Its `*.pem` rule is deliberately path-only:
matching `.pem` inside shell commands also caught legitimate local-TLS
certificate tooling, for no security gain, since the vector is *reading* a key.

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
| LIGHT | `^claude-haiku` | cheapest; mechanical work |
| STANDARD | `^claude-sonnet` | implementation, tests, research |
| DEEP | `^claude-opus` | architecture, ambiguous specs, review |
| FRONTIER | `^claude-fable` | long-horizon work; DEEP has already failed |

### Effort is a second, independent dial

Tier picks **which model**; `effort` picks **how hard it thinks**. They are
orthogonal and are routed in separate passes — there is no one-to-one mapping,
and the useful manifests are usually off the diagonal:

| Pairing | Use |
|---|---|
| DEEP + `medium` | Code review — accuracy holds at lower effort, so a capable reviewer is cheap enough to gate every group |
| LIGHT + `medium` | Wide mechanical sweep with many small judgement calls |
| DEEP + `xhigh` | Architecture, security boundaries, irreversible migrations |
| STANDARD + `low` | Bulk edits from a settled pattern |

Both dials must be **pinned explicitly on every dispatch**. Omitted, each falls
back to session inheritance and silently discards the manifest's routing — the
run does not error, it just costs the wrong amount. The failure escalation
cascade climbs effort *before* tier, since most failures are under-thought
rather than under-powered.

> **No self-verification instructions.** Current models verify their own work
> and catch their own mistakes unprompted, so "double-check your answer" or
> "refute your own result" steps compound with native behaviour and spend
> tokens for nothing. The harness deliberately contains none. Real verification
> still belongs in a dispatch, but as *tool execution* — the contract's test and
> lint commands, and project checklists encoding knowledge a model cannot infer.

> **FRONTIER → Fable.** FRONTIER targets the Fable family, which is
> permission-gated and absent from most API keys. Its fallback is Opus, so on a
> key without Fable access the resolver returns a working Opus model rather than
> nothing. If you never use Fable, point FRONTIER back at `^claude-opus` in
> `tiers.json`.

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/resolve-models.sh"          # {"LIGHT":...,"STANDARD":...,"DEEP":...,"FRONTIER":...}
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
