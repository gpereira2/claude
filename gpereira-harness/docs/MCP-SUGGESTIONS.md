---
title: MCP Suggestions
type: doc
tags: [claude, harness, mcp]
---

# MCP Suggestions (not installed)

This harness deliberately ships **no MCP registrations** — no server URLs, no
scopes, no auth. MCP choices are personal and workspace-specific, so each user
wires their own after install. This file is only a suggestion of what pairs
well with the harness workflow.

The orchestrator and workers function without any MCP; these extend reach.

## Commonly paired (register your own)

- **Ticket system** — whatever you use for issues/tickets. The orchestrator
  reads a ticket reference and persists state to the context vault regardless of
  source.
- **Source host** — a Git host connector for PR creation/review, if you want
  the pipeline to open PRs rather than just produce diffs.
- **Internal company MCP** — any org-specific server you rely on.

## How to add one

Register MCP servers in your own Claude Code config (project `.mcp.json` or user
settings). Do **not** add them to this plugin — keeping them out is what makes
the harness portable and safe to share. If a shared teammate copy contained your
endpoints or scopes, it would leak workspace access.
