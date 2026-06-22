#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
FIXTURE="$(mktemp -d)"
cp -R "$BASE/." "$FIXTURE/"
trap 'rm -rf "$FIXTURE"' EXIT

node "$ROOT/scripts/affordances.js" --json "$FIXTURE" >/tmp/helm-affordances.json
jq -e '.active_change == "add-dark-mode"' /tmp/helm-affordances.json >/dev/null

node "$ROOT/scripts/risk-tier.js" --paths src/ui/theme.ts >/tmp/helm-risk.json
jq -e '.tier == "standard"' /tmp/helm-risk.json >/dev/null

PROJECT_DIR="$FIXTURE" node "$ROOT/scripts/verify.js" >/tmp/helm-verify.md
jq -e '.status == "green"' "$FIXTURE/openspec/changes/add-dark-mode/verify-report.json" >/dev/null

PROJECT_DIR="$FIXTURE" node "$ROOT/scripts/archive-gate.js" >/tmp/helm-archive.txt

printf '{"tool_input":{"file_path":"src/ui/theme.ts"}}' | PROJECT_DIR="$FIXTURE" node "$ROOT/scripts/helm-guard.js" >/tmp/helm-guard.out 2>/tmp/helm-guard.err

if printf '{"tool_input":{"file_path":"src/server/auth.ts"}}' | PROJECT_DIR="$FIXTURE" node "$ROOT/scripts/helm-guard.js" >/tmp/helm-guard-deny.out 2>/tmp/helm-guard-deny.err; then
  echo "expected scope denial" >&2
  exit 1
fi

echo "helm smoke ok"
