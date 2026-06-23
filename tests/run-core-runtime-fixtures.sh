#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/helm-core"
PROJECT="$ROOT/tests/fixtures/simple-project"

grep -q 'helm-core/scripts/helm-session-start.js\|CLAUDE_PLUGIN_ROOT/scripts/helm-session-start.js' "$CORE/hooks/hooks.json"
grep -q 'plugin-suite.js' "$CORE/commands/helm.md"
grep -q 'workflow-state.js' "$CORE/commands/helm-status.md"
grep -q 'helm-doctor.js' "$CORE/commands/helm-doctor.md"
grep -q 'helm-requirements' "$CORE/skills/helm-router/SKILL.md"
grep -q 'helm-verification' "$CORE/skills/helm-router/SKILL.md"
grep -q 'helm-operations' "$CORE/skills/helm-router/SKILL.md"

PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >/tmp/helm-core-affordances.json
jq -e '.active_change == "add-dark-mode"' /tmp/helm-core-affordances.json >/dev/null

echo "helm core runtime fixtures ok"
