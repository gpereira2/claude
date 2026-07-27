#!/usr/bin/env bash
# smoke.sh — sanity checks + leak gate. Exit non-zero on any failure.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq not installed"

# 1. resolver returns valid JSON with all four tiers
OUT="$("$ROOT/lib/resolve-models.sh")"
echo "$OUT" | jq -e '.LIGHT and .STANDARD and .DEEP and .FRONTIER' >/dev/null \
  || fail "resolver did not return all four tiers: $OUT"

# 2. single-tier lookups return non-empty strings
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
jq -e . "$ROOT/hooks/hooks.json" >/dev/null || fail "hooks.json invalid"

# 5. every hook referenced by hooks.json exists and is executable
for f in agent-dispatch-conduct-gate.sh subagent-contract-gate.sh subagent-trace.sh \
         subagent-trace-summary.sh precompact-handoff.sh sessionstart-handoff.sh \
         storage-root-hint.sh plan-persist-context.sh docs-location-guard.sh \
         secret-scan-guard.py bash-clause-guard.py credential-file-guard.py \
         pr-context-hint.sh; do
  [ -f "$ROOT/hooks/$f" ] || fail "missing hook: $f"
  [ -x "$ROOT/hooks/$f" ] || fail "hook not executable: $f"
done

# 6. hook scripts parse (bash -n / py_compile)
for f in "$ROOT"/hooks/*.sh; do bash -n "$f" || fail "bash syntax error: $f"; done
command -v python3 >/dev/null 2>&1 && { python3 -m py_compile "$ROOT"/hooks/*.py || fail "python syntax error in hooks"; }

# 7. guard hooks make the right decision (behavioural, not just syntax)
echo '{"tool_input":{"command":"x && rm -rf ~"}}' | python3 "$ROOT/hooks/bash-clause-guard.py" \
  | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null || fail "bash-guard did not deny rm -rf ~"
echo '{"tool_input":{"command":"ls -la"}}' | python3 "$ROOT/hooks/bash-clause-guard.py" \
  | grep -q . && fail "bash-guard should be silent on a safe command" || true

# credential-file-guard: blocks credential reads across every content-returning tool,
# including Grep (which is NOT covered by a Read|Edit|Write matcher yet prints file content).
python3 "$ROOT/hooks/credential-file-guard.test.py" >/dev/null || fail "credential-file-guard unit cases failed"
for TOOL_JSON in '{"tool_name":"Read","tool_input":{"file_path":"/repo/auth.json"}}' \
                 '{"tool_name":"Grep","tool_input":{"pattern":"x","path":"/repo/.npmrc"}}' \
                 '{"tool_name":"Bash","tool_input":{"command":"cat /repo/auth.json"}}'; do
  echo "$TOOL_JSON" | python3 "$ROOT/hooks/credential-file-guard.py" \
    | jq -e '.decision=="block"' >/dev/null || fail "credential-guard failed to block: $TOOL_JSON"
done
echo '{"tool_name":"Read","tool_input":{"file_path":"/repo/composer.json"}}' \
  | python3 "$ROOT/hooks/credential-file-guard.py" | grep -q . \
  && fail "credential-guard should be silent on a normal file" || true

# secret-scan-guard: default posture is a hard block, not an unreliable "ask".
printf '{"tool_input":{"file_path":"/tmp/x","content":"AKIA%s"}}' "0000000000000000" \
  | python3 "$ROOT/hooks/secret-scan-guard.py" | jq -e '.decision=="block"' >/dev/null \
  || fail "secret-scan-guard did not block key material by default"

# 8. leak gate — no company-internal references in shareable content.
#    Scans prose/config/hooks/routines; lib/ is excluded because it legitimately
#    references the public Anthropic Models API.
INTERNAL='street|agentsoftware|spectre\.atlassian|network_id|LettingsManagement|SalesAndLettings|storage/claude'
if grep -rInE "$INTERNAL" \
     "$ROOT/skills" "$ROOT/agents" "$ROOT/hooks" "$ROOT/routines" "$ROOT/commands" "$ROOT/docs" \
     "$ROOT/README.md" "$ROOT/.claude-plugin" 2>/dev/null; then
  fail "internal reference(s) found above — sanitise before publishing"
fi

# 9. no absolute home paths baked into shareable files
if grep -rInE '/Users/[a-z]+/|/home/[a-z]+/' \
     "$ROOT/skills" "$ROOT/agents" "$ROOT/hooks" "$ROOT/routines" "$ROOT/commands" "$ROOT/docs" 2>/dev/null; then
  fail "absolute home path(s) found above — use \$HOME / \${CLAUDE_PLUGIN_ROOT} / vault"
fi

# 10. secret gate — no hardcoded key material anywhere in the plugin.
if grep -rInE 'sk-(ant|live)-[A-Za-z0-9]{12}' "$ROOT" --include='*.sh' --include='*.md' --include='*.json' 2>/dev/null; then
  fail "hardcoded API key material found above"
fi

echo "PASS: all smoke checks + leak gate clean"
