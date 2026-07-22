# gpereira2/claude

A Claude Code **plugin marketplace**. The root `.claude-plugin/marketplace.json`
publishes the plugins in this repo; today that's **`gpereira-harness`**.

## Install

```
/plugin marketplace add gpereira2/claude
/plugin install gpereira-harness@gpereira-harness-marketplace
```

## What's here

| Path | Purpose |
|------|---------|
| `.claude-plugin/marketplace.json` | Marketplace manifest — lists the plugins and where they live |
| `gpereira-harness/` | The harness plugin: orchestrator + agent-selector + task-observer skills, four worker agents, enforcement/safety/observability hooks, four-tier model routing, an Obsidian-compatible context store, and routine templates. See its [README](gpereira-harness/README.md). |
| `.github/workflows/smoke.yml` | CI: runs the plugin's smoke test + leak gate on every push/PR |

## gpereira-harness in one line

A portable harness that packages a delegate-everything pipeline (orchestrator →
tiered agent-selector → worker agents), self-enforcing conduct/contract hooks,
and per-user vault-backed state — with **no MCP registrations and no personal
`CLAUDE.md`** bundled, so it's safe to share. Full details in the
[plugin README](gpereira-harness/README.md).

## Developing

```bash
bash gpereira-harness/test/smoke.sh   # → PASS: all smoke checks + leak gate clean
```

The leak gate fails on any company-internal reference, absolute home path, or
hardcoded key material in the shareable files — the same check CI runs.

## License

MIT — see [`gpereira-harness/LICENSE`](gpereira-harness/LICENSE).
`gpereira-harness/skills/task-observer/` is third-party, CC BY 4.0 (attribution
in the skill).
