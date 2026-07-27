#!/usr/bin/env bash
# resolve-models.sh — map LIGHT/STANDARD/DEEP/FRONTIER tiers to concrete model IDs.
#
# Strategy (hybrid):
#   1. Try the Anthropic Models API and pick the NEWEST model per tier by
#      matching the family pattern in tiers.json against live model IDs.
#   2. If the API is unreachable (offline / no key), fall back to the pinned
#      "fallback" ID in tiers.json.
#
# Version-agnostic: tiers map to FAMILY PATTERNS (regex), never to hardcoded
# dated IDs. When Anthropic ships a newer version of a family, this picks it up
# automatically without editing the plugin.
#
# Usage:
#   resolve-models.sh              # print all tiers as JSON
#   resolve-models.sh LIGHT         # print one tier's resolved model ID
#
# Env:
#   ANTHROPIC_API_KEY   optional; enables live resolution
#   TIERS_FILE          override path to tiers.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIERS_FILE="${TIERS_FILE:-$SCRIPT_DIR/tiers.json}"
API_URL="https://api.anthropic.com/v1/models"

if ! command -v jq >/dev/null 2>&1; then
  echo "resolve-models.sh: requires 'jq'" >&2
  exit 1
fi

# Pull live model IDs (newest first). Empty on any failure — caller falls back.
fetch_live_models() {
  [ -n "${ANTHROPIC_API_KEY:-}" ] || return 0
  command -v curl >/dev/null 2>&1 || return 0
  curl -fsS --max-time 8 "$API_URL?limit=1000" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" 2>/dev/null \
    | jq -r '.data | sort_by(.created_at) | reverse | .[].id' 2>/dev/null || true
}

LIVE_MODELS="$(fetch_live_models)"

resolve_tier() {
  local tier="$1"
  local pattern fallback
  pattern="$(jq -r --arg t "$tier" '.tiers[$t].pattern' "$TIERS_FILE")"
  fallback="$(jq -r --arg t "$tier" '.tiers[$t].fallback' "$TIERS_FILE")"

  if [ -n "$LIVE_MODELS" ]; then
    local match
    match="$(printf '%s\n' "$LIVE_MODELS" | grep -E "$pattern" | head -n1 || true)"
    if [ -n "$match" ]; then
      printf '%s' "$match"
      return 0
    fi
  fi
  printf '%s' "$fallback"
}

TIERS=(LIGHT STANDARD DEEP FRONTIER)

if [ "$#" -ge 1 ]; then
  resolve_tier "$1"
  echo
  exit 0
fi

printf '{'
first=1
for t in "${TIERS[@]}"; do
  [ $first -eq 1 ] || printf ','
  first=0
  printf '"%s":"%s"' "$t" "$(resolve_tier "$t")"
done
printf '}\n'
