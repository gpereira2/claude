#!/usr/bin/env bash
# smoke.sh — minimal sanity checks + leak gate. Exit non-zero on any failure.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq not installed"

# 1. resolver returns valid JSON with all four tiers
OUT="$("$ROOT/lib/resolve-models.sh")"
echo "$OUT" | jq -e '.FAST and .STANDARD and .DEEP and .FRONTIER' >/dev/null \
  || fail "resolver did not return all four tiers: $OUT"

# 2. single-tier lookup returns a non-empty string
[ -n "$("$ROOT/lib/resolve-models.sh" DEEP)" ] || fail "DEEP resolved empty"
[ -n "$("$ROOT/lib/resolve-models.sh" FRONTIER)" ] || fail "FRONTIER resolved empty"

# 3. context store initialises into an isolated temp vault
TMPV="$(mktemp -d)"; trap 'rm -rf "$TMPV"' EXIT
CLAUDE_CONTEXT_DIR="$TMPV" "$ROOT/lib/context-store.sh" init >/dev/null
[ -d "$TMPV/.obsidian" ] || fail "vault missing .obsidian marker"
[ -f "$TMPV/index.md" ] || fail "vault missing index.md"
CLAUDE_CONTEXT_DIR="$TMPV" "$ROOT/lib/context-store.sh" ticket-dir T-1 >/dev/null
[ -d "$TMPV/tickets/T-1" ] || fail "ticket dir not created"

# 4. manifests are valid JSON
jq -e . "$ROOT/.claude-plugin/plugin.json" >/dev/null || fail "plugin.json invalid"

# 5. leak gate — no company-internal references in shareable content.
#    Scans prose/config (skills, agents, docs, README, manifests); the libs are
#    excluded from the term scan because they legitimately reference the public
#    Anthropic Models API. A hit here means an internal reference slipped in.
INTERNAL='street|agentsoftware|spectre\.atlassian|network_id|LettingsManagement|SalesAndLettings|storage/claude'
if grep -rInE "$INTERNAL" \
     "$ROOT/skills" "$ROOT/agents" "$ROOT/docs" "$ROOT/README.md" \
     "$ROOT/.claude-plugin" 2>/dev/null; then
  fail "internal reference(s) found above — sanitise before publishing"
fi

# 6. secret gate — no hardcoded key material anywhere in the plugin.
if grep -rInE 'sk-ant-[A-Za-z0-9_-]{8}' "$ROOT" --include='*.sh' --include='*.md' --include='*.json' 2>/dev/null; then
  fail "hardcoded API key material found above"
fi

echo "PASS: all smoke checks + leak gate clean"
