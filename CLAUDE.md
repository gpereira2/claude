# Claude Config Repo

This repository tracks personal Claude Code configuration for syncing across machines.

## Structure

- `config/` — symlink target for `~/.claude/`. Contains CLAUDE.md (global instructions), settings.json, agents, skills, and plugins.
- `mcp.json` — standalone MCP server definitions, merged into `~/.claude.json` via `scripts/merge-mcp.sh`.
- `scripts/` — utility scripts (currently just merge-mcp.sh).

## Conventions

- Machine-specific config (hooks, paths) belongs in `settings.local.json`, which is gitignored.
- Plugin cache is gitignored — only plugin manifests and configs are tracked.
- Memory files are not tracked.
- Skills follow the Claude Code structure: `config/skills/<name>/SKILL.md`.
- Agents are markdown files in `config/agents/`.

## Working in this repo

- When adding a new skill, create `config/skills/<name>/SKILL.md` with appropriate frontmatter.
- When adding MCP servers, add to `mcp.json` and test with `./scripts/merge-mcp.sh`.
- The `.gitignore` excludes a large number of transient Claude files — check it before adding new config types.
