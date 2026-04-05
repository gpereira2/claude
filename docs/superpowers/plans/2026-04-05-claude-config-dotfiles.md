# Claude Config Dotfiles — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up a dotfiles repo that tracks `~/.claude/` config (skills, agents, plugins, settings, MCP servers) with a `config/` subdirectory as the symlink target.

**Architecture:** Flat `config/` directory mirrors `~/.claude/` structure. MCP servers kept in a standalone `mcp.json` with a `jq`-based merge script. Repo-level files (README, scripts) live at root.

**Tech Stack:** Shell (bash), jq

---

## File Structure

| File | Responsibility |
|------|---------------|
| `.gitignore` | Exclude memory, local settings, plugin cache, transient files |
| `config/CLAUDE.md` | Placeholder for global instructions (user copies their own) |
| `config/settings.json` | Placeholder for global settings (user copies their own) |
| `config/agents/.gitkeep` | Track empty agents directory |
| `config/skills/.gitkeep` | Track empty skills directory |
| `config/plugins/.gitkeep` | Track empty plugins directory (cache excluded) |
| `mcp.json` | Standalone MCP server definitions |
| `scripts/merge-mcp.sh` | Merges mcp.json into ~/.claude.json |
| `README.md` | Setup instructions, structure overview |
| `CLAUDE.md` | Repo-level Claude instructions for working in this repo |

---

### Task 1: Create .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Create the .gitignore file**

```gitignore
# Machine-specific settings (hooks, paths)
config/settings.local.json

# Memory (ephemeral, project-specific)
config/memory/
config/MEMORY.md

# Plugin cache (downloaded content, regenerated on install)
config/plugins/cache/

# Session state
.claude-project

# OS files
.DS_Store

# Claude transient files
config/history.jsonl
config/debug/
config/sessions/
config/paste-cache/
config/cache/
config/statsig/
config/telemetry/
config/stats-cache.json
config/policy-limits.json
config/mcp-needs-auth-cache.json
config/usage-data/
config/shell-snapshots/
config/session-env/
config/file-history/
config/backups/
config/todos/
config/tasks/
config/plans/
config/projects/
config/teams/
config/ide/
config/icons/
config/chrome/
config/downloads/
config/phpstorm/
config/keybindings.json
config/statusline-command.sh
config/mcp.json
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "feat: add .gitignore excluding transient and machine-specific files"
```

---

### Task 2: Create config directory structure

**Files:**
- Create: `config/CLAUDE.md`
- Create: `config/settings.json`
- Create: `config/agents/.gitkeep`
- Create: `config/skills/.gitkeep`
- Create: `config/plugins/.gitkeep`

- [ ] **Step 1: Create config directory and placeholder files**

```bash
mkdir -p config/agents config/skills config/plugins
```

- [ ] **Step 2: Create config/CLAUDE.md**

Create `config/CLAUDE.md` with a minimal placeholder:

```markdown
# Global Instructions

<!-- Replace this with your ~/.claude/CLAUDE.md content -->
```

- [ ] **Step 3: Create config/settings.json**

Create `config/settings.json` with an empty settings object:

```json
{}
```

- [ ] **Step 4: Create .gitkeep files for empty directories**

```bash
touch config/agents/.gitkeep config/skills/.gitkeep config/plugins/.gitkeep
```

- [ ] **Step 5: Commit**

```bash
git add config/
git commit -m "feat: add config directory structure with placeholders"
```

---

### Task 3: Create mcp.json

**Files:**
- Create: `mcp.json`

- [ ] **Step 1: Create mcp.json with empty mcpServers**

Create `mcp.json` at repo root:

```json
{
  "mcpServers": {}
}
```

- [ ] **Step 2: Commit**

```bash
git add mcp.json
git commit -m "feat: add standalone mcp.json for MCP server definitions"
```

---

### Task 4: Create merge-mcp.sh script

**Files:**
- Create: `scripts/merge-mcp.sh`

- [ ] **Step 1: Create the scripts directory**

```bash
mkdir -p scripts
```

- [ ] **Step 2: Write merge-mcp.sh**

Create `scripts/merge-mcp.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MCP_FILE="$REPO_ROOT/mcp.json"
CLAUDE_JSON="$HOME/.claude.json"

# Check dependencies
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed." >&2
  echo "Install it: brew install jq (macOS) or sudo apt install jq (Linux)" >&2
  exit 1
fi

# Validate mcp.json exists and has mcpServers
if [[ ! -f "$MCP_FILE" ]]; then
  echo "Error: $MCP_FILE not found." >&2
  exit 1
fi

if ! jq -e '.mcpServers' "$MCP_FILE" &>/dev/null; then
  echo "Error: $MCP_FILE missing mcpServers key." >&2
  exit 1
fi

# Create ~/.claude.json if it doesn't exist
if [[ ! -f "$CLAUDE_JSON" ]]; then
  echo '{}' > "$CLAUDE_JSON"
fi

# Merge: repo mcp.json mcpServers into ~/.claude.json
# Existing entries in ~/.claude.json are preserved; repo entries override on conflict
MERGED=$(jq -s '
  .[0] as $claude |
  .[1].mcpServers as $repo_servers |
  $claude | .mcpServers = ((.mcpServers // {}) * $repo_servers)
' "$CLAUDE_JSON" "$MCP_FILE")

echo "$MERGED" > "$CLAUDE_JSON"

SERVERS_COUNT=$(jq '.mcpServers | length' "$MCP_FILE")
echo "Merged $SERVERS_COUNT MCP server(s) from mcp.json into $CLAUDE_JSON"
```

- [ ] **Step 3: Make script executable**

```bash
chmod +x scripts/merge-mcp.sh
```

- [ ] **Step 4: Test the script with a dry run**

Run: `bash -n scripts/merge-mcp.sh`
Expected: No output (syntax OK)

- [ ] **Step 5: Commit**

```bash
git add scripts/
git commit -m "feat: add merge-mcp.sh script for merging MCP servers into claude.json"
```

---

### Task 5: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite README.md**

Replace the existing README with:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README with setup instructions and structure overview"
```

---

### Task 6: Add repo-level CLAUDE.md

**Files:**
- Create: `CLAUDE.md` (repo root)

- [ ] **Step 1: Create CLAUDE.md at repo root**

Create `CLAUDE.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add repo-level CLAUDE.md with conventions and structure"
```
