#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQ="$ROOT/plugins/helm-requirements"
PROJECT="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

test -f "$REQ/scripts/foundation-specs.js"
test -f "$REQ/scripts/requirements-contract.js"
test -f "$REQ/skills/foundation-spec/SKILL.md"
test -f "$REQ/skills/requirements/SKILL.md"

grep -q 'helm-requirements' "$REQ/commands/helm-requirements.md"
grep -Fq 'node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require' "$REQ/commands/helm-requirements.md"
grep -Fq -- '--marketplace-root "$CLAUDE_PLUGIN_ROOT/../.."' "$REQ/commands/helm-requirements.md"

mkdir -p "$TMP_DIR/external-project"
set +e
(
  cd "$TMP_DIR/external-project"
  export CLAUDE_PLUGIN_ROOT="$REQ"
  node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin helm-requirements --json
) >"$TMP_DIR/external-plugin-suite-require.json"
STATUS=$?
set -e
[[ "$STATUS" == "0" ]]
jq -e '.ok == true' "$TMP_DIR/external-plugin-suite-require.json" >/dev/null
jq -e '.plugins | length == 2' "$TMP_DIR/external-plugin-suite-require.json" >/dev/null
jq -e '.plugins[] | select(.name == "helm-core" and .ok == true)' "$TMP_DIR/external-plugin-suite-require.json" >/dev/null
jq -e '.plugins[] | select(.name == "helm-requirements" and .ok == true)' "$TMP_DIR/external-plugin-suite-require.json" >/dev/null

set +e
PROJECT_DIR="$PROJECT" node "$REQ/scripts/foundation-specs.js" --json >"$TMP_DIR/foundation-specs.json"
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' "$TMP_DIR/foundation-specs.json" >/dev/null
jq -e '.blockers[] | select(. == "missing-foundation-spec:ui-design")' "$TMP_DIR/foundation-specs.json" >/dev/null

set +e
PROJECT_DIR="$PROJECT" node "$REQ/scripts/requirements-contract.js" --json >"$TMP_DIR/requirements-contract.json"
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' "$TMP_DIR/requirements-contract.json" >/dev/null

echo "helm requirements plugin fixtures ok"
