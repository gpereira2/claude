# Claude Config Dotfiles Repo — Design Spec

**Date:** 2026-04-05
**Status:** Approved

## Purpose

Version-controlled repository for tracking `~/.claude/` configuration — skills, agents, plugins, settings, and MCP servers — for syncing across Mac and Linux machines.

## Repository Structure

```
├── README.md                      # Setup instructions, what's tracked
├── config/                        # Symlink target → ~/.claude/
│   ├── CLAUDE.md                  # Global instructions
│   ├── settings.json              # Global settings & permissions
│   ├── agents/                    # Custom agent definitions (.md)
│   ├── skills/                    # Custom skills (<name>/SKILL.md)
│   └── plugins/                   # Plugin configs (cache/ excluded)
├── mcp.json                       # Standalone MCP server definitions
├── scripts/
│   └── merge-mcp.sh               # Merges mcp.json into ~/.claude.json
├── .gitignore
```

## Setup

Two steps:

1. **Symlink config:** `ln -s /path/to/repo/config ~/.claude`
2. **Merge MCP servers:** `./scripts/merge-mcp.sh`

No install script — differences between Mac and Linux are handled manually. Machine-specific config (hooks, paths) stays in `settings.local.json` which is gitignored.

## What Gets Tracked

| Item | Path | Description |
|------|------|-------------|
| Global instructions | `config/CLAUDE.md` | Instructions applied to all projects |
| Global settings | `config/settings.json` | Permissions, model preferences |
| Agents | `config/agents/` | Custom subagent definitions (markdown) |
| Skills | `config/skills/` | Custom skills (`<name>/SKILL.md` + supporting files) |
| Plugins | `config/plugins/` | Plugin manifests/configs |
| MCP servers | `mcp.json` | Standalone MCP server definitions |

## What Gets Excluded (.gitignore)

| Item | Path | Reason |
|------|------|--------|
| Memory | `config/memory/`, `config/MEMORY.md` | Ephemeral, project-specific |
| Local settings | `config/settings.local.json` | Machine-specific hooks/paths |
| Plugin cache | `config/plugins/cache/` | Downloaded content, regenerated on install |
| Session state | `.claude-project` | Transient |

## MCP Merge Script

`scripts/merge-mcp.sh`:

- Reads `mcp.json` from the repo root
- Merges its `mcpServers` entries into `~/.claude.json`
- Preserves existing entries in `~/.claude.json` not present in the repo file
- Requires `jq`
- Idempotent — safe to run repeatedly

### mcp.json Format

Uses the standard Claude `mcpServers` structure:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "...",
      "args": ["..."],
      "env": {}
    }
  }
}
```

## Design Decisions

1. **Config subdirectory (`config/`)** — separates repo-level files (README, scripts) from Claude config content. Symlink target is `repo/config/ → ~/.claude/`.
2. **Standalone `mcp.json`** — keeps MCP definitions modular and portable, merged into `~/.claude.json` via script rather than tracked as part of `~/.claude/`.
3. **No commands/ directory** — skills supersede commands and support additional features (supporting files, frontmatter). Existing commands can be migrated to skills.
4. **No install script for OS differences** — keeps things simple per user preference. Machine-specific settings stay in gitignored `settings.local.json`.
5. **Memory excluded** — project-specific and conversation-ephemeral, not useful to version control.
