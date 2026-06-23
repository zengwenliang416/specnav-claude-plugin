#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" list --marketplace-root "$ROOT" --json >/tmp/helm-suite-list.json
jq -e '.ok == true' /tmp/helm-suite-list.json >/dev/null
jq -e '.plugins | length == 6' /tmp/helm-suite-list.json >/dev/null
jq -e '.plugins[] | select(.name == "helm-core" and .stage == "core")' /tmp/helm-suite-list.json >/dev/null
jq -e '.plugins[] | select(.name == "helm-verification" and .stage == "verification")' /tmp/helm-suite-list.json >/dev/null

node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" resolve --marketplace-root "$ROOT" --plugin helm-requirements --json >/tmp/helm-suite-requirements.json
jq -e '.ok == true' /tmp/helm-suite-requirements.json >/dev/null
jq -e '.plugin.name == "helm-requirements"' /tmp/helm-suite-requirements.json >/dev/null
jq -e '.plugin.stage == "requirements"' /tmp/helm-suite-requirements.json >/dev/null

node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" require --marketplace-root "$ROOT" --plugin helm-core --plugin helm-requirements --json >/tmp/helm-suite-require.json
jq -e '.ok == true' /tmp/helm-suite-require.json >/dev/null

set +e
node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" require --marketplace-root "$ROOT" --plugin helm-missing --json >/tmp/helm-suite-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/helm-suite-missing.json >/dev/null
jq -e '.blockers[] | select(. == "missing-plugin:helm-missing")' /tmp/helm-suite-missing.json >/dev/null

echo "helm plugin suite resolver fixtures ok"
