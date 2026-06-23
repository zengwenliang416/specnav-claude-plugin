#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

jq -e '.plugins | length == 6' "$ROOT/.claude-plugin/marketplace.json" >/dev/null
jq -e '.plugins[].name' "$ROOT/.claude-plugin/marketplace.json" >/tmp/helm-plugin-names.txt
grep -q '"helm-core"' /tmp/helm-plugin-names.txt
grep -q '"helm-requirements"' /tmp/helm-plugin-names.txt
grep -q '"helm-prototype"' /tmp/helm-plugin-names.txt
grep -q '"helm-development"' /tmp/helm-plugin-names.txt
grep -q '"helm-verification"' /tmp/helm-plugin-names.txt
grep -q '"helm-operations"' /tmp/helm-plugin-names.txt

for plugin in helm-core helm-requirements helm-prototype helm-development helm-verification helm-operations; do
  test -f "$ROOT/plugins/$plugin/.claude-plugin/plugin.json"
  test -f "$ROOT/plugins/$plugin/helm-stage.json"
  jq -e '.name == "'"$plugin"'"' "$ROOT/plugins/$plugin/.claude-plugin/plugin.json" >/dev/null
  jq -e '.plugin == "'"$plugin"'"' "$ROOT/plugins/$plugin/helm-stage.json" >/dev/null
done

test -f "$ROOT/plugins/helm-core/hooks/hooks.json"
test -f "$ROOT/plugins/helm-core/scripts/helm-lib.js"
test -f "$ROOT/plugins/helm-core/commands/helm.md"
test -f "$ROOT/plugins/helm-requirements/commands/helm-requirements.md"
test -f "$ROOT/plugins/helm-prototype/commands/helm-prototype.md"
test -f "$ROOT/plugins/helm-development/commands/helm-implement.md"
test -f "$ROOT/plugins/helm-verification/commands/helm-verify.md"
test -f "$ROOT/plugins/helm-operations/commands/helm-release.md"
test -f "$ROOT/plugins/helm-operations/commands/helm-archive.md"

echo "helm plugin suite layout fixtures ok"
