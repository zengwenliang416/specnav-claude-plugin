#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
CORE="$ROOT/plugins/specnav-core"
FIXTURE="$(mktemp -d)"
cp -R "$BASE/." "$FIXTURE/"
trap 'rm -rf "$FIXTURE"' EXIT

node "$CORE/scripts/affordances.js" --json "$FIXTURE" >/tmp/specnav-affordances.json
jq -e '.active_change == "add-dark-mode"' /tmp/specnav-affordances.json >/dev/null

node "$CORE/scripts/risk-tier.js" --paths src/ui/theme.ts >/tmp/specnav-risk.json
jq -e '.tier == "standard"' /tmp/specnav-risk.json >/dev/null

PROJECT_DIR="$FIXTURE" node "$CORE/scripts/verify.js" >/tmp/specnav-verify.md
jq -e '.status == "green"' "$FIXTURE/openspec/changes/add-dark-mode/verify-report.json" >/dev/null

PROJECT_DIR="$FIXTURE" node "$CORE/scripts/archive-gate.js" >/tmp/specnav-archive.txt

printf '{"tool_input":{"file_path":"src/ui/theme.ts"}}' | PROJECT_DIR="$FIXTURE" node "$CORE/scripts/specnav-guard.js" >/tmp/specnav-guard.out 2>/tmp/specnav-guard.err

if printf '{"tool_input":{"file_path":"src/server/auth.ts"}}' | PROJECT_DIR="$FIXTURE" node "$CORE/scripts/specnav-guard.js" >/tmp/specnav-guard-deny.out 2>/tmp/specnav-guard-deny.err; then
  echo "expected scope denial" >&2
  exit 1
fi

echo "specnav smoke ok"
