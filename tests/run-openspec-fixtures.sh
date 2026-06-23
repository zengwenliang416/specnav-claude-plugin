#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/helm-core"
PROJECT="$ROOT/tests/fixtures/simple-project"

if command -v openspec >/dev/null 2>&1; then
  node "$CORE/scripts/affordances.js" --json "$PROJECT" >/tmp/helm-openspec-affordances.json
  jq -e '.state_source == "openspec-cli"' /tmp/helm-openspec-affordances.json >/dev/null
  jq -e '.openspec_status.schema_name == "spec-driven"' /tmp/helm-openspec-affordances.json >/dev/null
fi

HELM_DISABLE_OPENSPEC=1 node "$CORE/scripts/affordances.js" --json "$PROJECT" >/tmp/helm-fallback-affordances.json
jq -e '.state_source == "filesystem"' /tmp/helm-fallback-affordances.json >/dev/null
jq -e '.active_change == "add-dark-mode"' /tmp/helm-fallback-affordances.json >/dev/null

echo "helm openspec fixtures ok"
