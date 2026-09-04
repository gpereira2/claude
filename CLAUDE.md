# Claude Config Repo

A Claude Code **plugin marketplace** (published via `.claude-plugin/marketplace.json`)
plus a tracked mirror of the personal global config, so a machine rebuild doesn't lose it.

See [README.md](README.md) for install instructions and the plugin overview.

## Structure

- `.claude-plugin/marketplace.json` — marketplace manifest. Lists the plugins and where they live.
- `gpereira-harness/` — the published plugin: skills, worker agents, hooks, routines, four-tier
  model routing, and a vault-backed context store. Has its own README, docs, and test suite.
- `SYSTEM_PROMPT.md` — mirror of `~/.claude/CLAUDE.md`. Not auto-loaded by Claude Code, so it
  is inert here; restore with `cp SYSTEM_PROMPT.md ~/.claude/CLAUDE.md`.
- `skills/`, `agents/` — standalone assets kept outside the plugin. `agent-selector` also
  exists inside `gpereira-harness/skills/`; the plugin copy is the one that ships.
  `regression-check` lives here only — it is not in the plugin, so `~/.claude/skills/` is
  its live location and this is the mirror. Keep the two in sync by hand, or the copies
  drift silently.
- `mcp.json` — MCP server definitions, kept out of the plugin by design so nothing personal
  is published. Merge into `~/.claude.json` by hand.
- `.github/workflows/smoke.yml` — CI. Runs the plugin smoke test and leak gate on every push and PR.

## Conventions

- **Nothing personal in `gpereira-harness/`.** No company references, no absolute home paths,
  no MCP registrations, no personal `CLAUDE.md`. The leak gate enforces this.
- The leak gate only scans **inside the plugin** (`skills/`, `agents/`, `hooks/`, `routines/`,
  `commands/`, `docs/`, `README.md`, `.claude-plugin/`). Files at the repo root — including
  `SYSTEM_PROMPT.md` and `mcp.json` — are **not** covered, so review those by hand.
- Machine-specific config belongs in `settings.local.json`, which is gitignored and never tracked here.
- Plugin cache, memory files and `files.zip` are gitignored — check `.gitignore` before adding
  a new config type.
- Skills follow the standard layout: `<skills-dir>/<name>/SKILL.md`, with optional `references/`.
- This repo is private. It is still the wrong place for tokens or key material — the secret gate
  fails the build on anything that looks like one.

## Working in this repo

- Run the smoke test before pushing anything that touches the plugin:

  ```bash
  bash gpereira-harness/test/smoke.sh
  ```

- When adding a skill to the plugin, create `gpereira-harness/skills/<name>/SKILL.md` with
  `name` and `description` frontmatter, then re-run the smoke test. Write it against
  `gpereira-harness/docs/writing-for-agents.md` — the authoring standard for skills and
  agent-facing docs.
- When changing `~/.claude/CLAUDE.md`, re-copy it to `SYSTEM_PROMPT.md` and update the
  `Last synced` date in its header comment — the mirror is manual, nothing syncs it automatically.
- Cross-cutting principles live in `gpereira-harness/docs/PRINCIPLES.md`. The personal copy at
  `~/.claude/skill-observations/principles.md` is maintained separately; adding a principle to
  one does not propagate it to the other.
