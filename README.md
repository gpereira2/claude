# Claude Config

Personal Claude Code configuration tracked in git for syncing across machines.

## What's tracked

| Directory/File | Purpose |
|----------------|---------|
| `config/CLAUDE.md` | Global instructions for all projects |
| `config/settings.json` | Global settings and permissions |
| `config/agents/` | Custom agent definitions |
| `config/skills/` | Custom skills |
| `config/plugins/` | Plugin configs (cache excluded) |
| `mcp.json` | MCP server definitions |

## Setup

### 1. Clone the repo

```bash
git clone <repo-url> ~/claude-config
```

### 2. Symlink config

Back up your existing config if needed, then symlink:

```bash
mv ~/.claude ~/.claude.bak  # optional backup
ln -s ~/claude-config/config ~/.claude
```

### 3. Merge MCP servers

```bash
./scripts/merge-mcp.sh
```

This merges `mcp.json` entries into `~/.claude.json`. Existing entries are preserved; repo entries override on conflict. Requires `jq`.

## Adding content

### Skills

```bash
mkdir -p config/skills/my-skill
# Create config/skills/my-skill/SKILL.md with frontmatter and instructions
```

### Agents

```bash
# Create config/agents/my-agent.md with agent definition
```

### MCP servers

Add entries to `mcp.json` under `mcpServers`, then run `./scripts/merge-mcp.sh`.

## What's excluded

- `config/memory/` — project-specific, ephemeral
- `config/settings.local.json` — machine-specific hooks and paths
- `config/plugins/cache/` — downloaded plugin content
- Transient files (sessions, history, debug logs, etc.)
