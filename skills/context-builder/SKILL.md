---
name: context-builder
description: Scans a codebase and generates or updates AGENTS.md files — the industry standard for AI agent context (supported by Claude Code, Cursor, Copilot, Codex, Gemini CLI, and more). Use this skill whenever the user says "build context", "generate AGENTS.md", "document this repo for agents", "scaffold agent context", "update AGENTS.md", "onboard agents to this project", or starts a session where multi-agent work is about to happen. Also trigger when the user says "what should go in AGENTS.md" or asks how to help AI tools understand their codebase. Always generates a human-reviewed draft — never writes files silently.
---

# Context Builder

Scan the codebase and produce `AGENTS.md` files that follow the industry standard format. Human reviews and approves every file before it's written — the skill scaffolds, the human owns the content.

## Philosophy

> LLM-generated context files that are written and forgotten degrade agent performance.
> Human-curated files that are kept accurate improve it.
> This skill's job is to make curation fast — not to replace it.

**Rules:**
- Never write files without explicit user approval
- Keep every AGENTS.md under 150 lines — long files bury signal
- Prefer commands and conventions over prose descriptions
- Link to existing docs rather than duplicating them
- Flag anything uncertain — don't invent conventions

---

## Step 1: Check for Existing AGENTS.md Files

```bash
find . -name "AGENTS.md" -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -not -path '*/vendor/*' | sort
```

**If files exist → Update Mode** (Step 4)
**If no files exist → Generate Mode** (Step 2)

---

## Step 2: Scan the Codebase

Be surgical — scan broad, read deep only where ambiguous.

### 2.1 Structure
```bash
find . -maxdepth 3 -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -not -path '*/vendor/*' -not -path '*/dist/*' -not -path '*/.next/*' \
  -not -path '*/coverage/*' | sort
```

### 2.2 Read these files (if they exist, in priority order)
1. `CLAUDE.md` / `.claude/` — existing Claude instructions, treat as ground truth
2. `README.md` — project overview
3. `package.json` / `composer.json` — scripts, deps, engines
4. `docker-compose.yml` / `Dockerfile` — services, ports
5. `.env.example` — env vars
6. `Makefile` — common commands
7. Main router / entry point file

### 2.3 Detect stack
From config files and extensions identify:
- Language + version (PHP 8.3, Node 20, etc.)
- Framework (Laravel, NestJS, Next.js, etc.)
- Database(s) + cache
- Queue system
- Test framework(s)
- CI/CD platform

### 2.4 Recent activity
```bash
git log --oneline -10 2>/dev/null
git diff --stat HEAD~3 HEAD 2>/dev/null
```

### 2.5 Tech debt signals
```bash
grep -r "TODO\|FIXME\|HACK" --include="*.php" --include="*.ts" --include="*.js" \
  -l . 2>/dev/null | head -10
```

---

## Step 3: Decide Which Folders Need AGENTS.md

Not every folder needs one. Create AGENTS.md in a folder when it has:
- Non-obvious conventions or patterns
- Its own build/test commands
- Domain-specific vocabulary
- Known gotchas that would trip up an agent
- Different rules from the parent

**Typical placement for PHP/Node projects:**

```
AGENTS.md                    <- root — always
app/ or src/
├── Services/AGENTS.md       <- if business logic has non-obvious patterns
├── Api/ or Http/AGENTS.md   <- if routing/request conventions are complex
├── Jobs/ or Workers/        <- if queue/async patterns need explanation
infrastructure/AGENTS.md     <- if Docker/K8s/Terraform has gotchas
tests/AGENTS.md              <- if test conventions differ from defaults
```

Only propose folders where you found genuinely non-obvious information. Don't create AGENTS.md files just to have them.

---

## Step 4: Draft the Files

### Root AGENTS.md Template

```markdown
# [Project Name]
[1-2 sentences: what this project does and who uses it]

## Core Commands
[backtick]``bash
# Install
[command]

# Dev server
[command]

# Tests
[command]

# Lint / type-check
[command]

# Build
[command]
[backtick]``

## Project Layout
[backtick]``
[directory tree — 1 level deep, with a comment on each key folder]
[backtick]``

## Stack
- Language: [e.g. PHP 8.3 / Node 20]
- Framework: [e.g. Laravel 11 / Express 5]
- Database: [e.g. MySQL 8 + Redis 7]
- Queue: [e.g. Laravel Horizon / BullMQ]
- Tests: [e.g. PHPUnit / Jest + Supertest]
- CI: [e.g. GitHub Actions]

## Conventions
- [Specific, actionable — e.g. "Services are constructor-injected, never newed directly"]
- [e.g. "All API responses use JsonResource transformers — never return raw models"]
- [e.g. "DB writes go through Repository classes, never directly in Controllers"]

## Environment Variables
| Variable | Purpose | Example |
|---|---|---|
| [VAR] | [what it does] | [safe example value] |

## Gotchas
- [Non-obvious thing — e.g. "Migrations run on a separate DB connection in tests"]
- [e.g. "The payments service uses a different auth token from the main API"]

## Out of Scope
- [Things NOT in this repo — e.g. "Infrastructure provisioning is in the infra/ repo"]
```

### Subfolder AGENTS.md Template

Keep these short — 30-50 lines max. They inherit root context, don't repeat it.

```markdown
# [Folder Name]

[1 sentence: what lives here and its single responsibility]

## Conventions
- [Folder-specific pattern]
- [Folder-specific pattern]

## Key Files
| File | Purpose |
|---|---|
| [filename] | [what it does] |

## Gotchas
- [Gotcha specific to this folder]
```

---

## Step 5: Present Drafts for Review

**Never write files first.** Present each draft inline:

```
Here are the proposed AGENTS.md files. Review each one — edit anything
wrong, unclear, or missing before I write them to disk.

---
### 📄 AGENTS.md (root)
[draft content]

---
### 📄 src/Services/AGENTS.md
[draft content]

---
⚠️ Uncertain: [anything you could not confirm — ask rather than guess]

Ready to write? Reply "write all", "write [filename]", or edit first.
```

---

## Step 6: Write Approved Files

Only after explicit user confirmation:

```bash
cat > path/to/AGENTS.md << 'EOF'
[approved content]
EOF

echo "✅ Written: path/to/AGENTS.md"
```

Then report:
```
✅ Written 3 files:
- AGENTS.md (root)
- src/Services/AGENTS.md
- tests/AGENTS.md

Tip: commit these alongside your next code change — not as a standalone commit.
This keeps context in sync with the code it describes.
```

---

## Update Mode (files already exist)

Don't regenerate from scratch. Diff against reality:

```bash
# What changed recently
git log --oneline --since="30 days ago" 2>/dev/null

# New files since last AGENTS.md update
git diff --name-only HEAD $(git log --oneline -- AGENTS.md | head -1 | awk '{print $1}') 2>/dev/null
```

Present targeted suggestions only — not the full file:

```
Existing AGENTS.md found. Here's what may be stale:

🔄 Possible updates needed:
- New folder `src/Notifications/` — not documented
- `docker-compose.yml` changed — ports may have shifted
- 3 new vars in `.env.example`: QUEUE_TIMEOUT, CACHE_TTL, SENTRY_DSN

Suggested additions (showing diffs only):
[show only changed/new sections]

Apply these? Reply "yes", "some", or edit first.
```

---

## Behaviour Notes

- **150 line limit per file** — if a draft exceeds this, split into subfolders or link to existing docs
- **Commands over prose** — a runnable command beats 10 lines of description every time
- **No secrets** — variable names only from `.env`, never actual values
- **Monorepo aware** — propose a root summary + per-service AGENTS.md for multi-service repos
- **CLAUDE.md compatibility** — if `CLAUDE.md` exists, don't duplicate it; add a note in AGENTS.md pointing to it for Claude-specific instructions
- **Stay humble** — if you can't confirm a convention from the code, flag it with ⚠️ and ask
- **Commit discipline** — always remind: AGENTS.md should be committed with related code changes, not in isolation