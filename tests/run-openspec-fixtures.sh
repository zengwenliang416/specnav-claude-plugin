#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT="$ROOT/tests/fixtures/simple-project"

if command -v openspec >/dev/null 2>&1; then
  node "$CORE/scripts/affordances.js" --json "$PROJECT" >/tmp/specnav-openspec-affordances.json
  jq -e '.state_source == "openspec-cli"' /tmp/specnav-openspec-affordances.json >/dev/null
  jq -e '.openspec_status.schema_name == "spec-driven"' /tmp/specnav-openspec-affordances.json >/dev/null
fi

SPECNAV_DISABLE_OPENSPEC=1 node "$CORE/scripts/affordances.js" --json "$PROJECT" >/tmp/specnav-blocked-affordances.json
jq -e '.state_source == "blocked"' /tmp/specnav-blocked-affordances.json >/dev/null
jq -e '.blockers | index("openspec-status:disabled")' /tmp/specnav-blocked-affordances.json >/dev/null
jq -e '.actions[] | select(.id == "implement" and .blocked_by[] == "openspec-status:disabled")' /tmp/specnav-blocked-affordances.json >/dev/null

echo "specnav openspec fixtures ok"
