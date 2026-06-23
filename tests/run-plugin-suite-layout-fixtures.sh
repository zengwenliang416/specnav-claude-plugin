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
  test -d "$ROOT/plugins/$plugin/skills"
  test -d "$ROOT/plugins/$plugin/scripts"
  test -f "$ROOT/plugins/$plugin/.claude-plugin/plugin.json"
  test -f "$ROOT/plugins/$plugin/helm-stage.json"
  jq -e '.name == "'"$plugin"'"' "$ROOT/plugins/$plugin/.claude-plugin/plugin.json" >/dev/null
  jq -e '.plugin == "'"$plugin"'"' "$ROOT/plugins/$plugin/helm-stage.json" >/dev/null

  while IFS= read -r command; do
    test -f "$ROOT/plugins/$plugin/commands/$command.md"
  done < <(jq -r '.commands[]?' "$ROOT/plugins/$plugin/helm-stage.json")

  while IFS= read -r skill; do
    test -f "$ROOT/plugins/$plugin/skills/$skill/SKILL.md"
  done < <(jq -r '.skills[]?' "$ROOT/plugins/$plugin/helm-stage.json")

  while IFS= read -r contract; do
    test -f "$ROOT/plugins/$plugin/$contract"
  done < <(jq -r '(.contracts // {})[]' "$ROOT/plugins/$plugin/helm-stage.json")
done

test -f "$ROOT/plugins/helm-core/hooks/hooks.json"
test -f "$ROOT/plugins/helm-core/scripts/helm-lib.js"
test -f "$ROOT/plugins/helm-core/scripts/workflow-state.js"
test -f "$ROOT/plugins/helm-core/scripts/helm-doctor.js"
test ! -e "$ROOT/plugins/helm-core/commands/helm-verify.md"
test ! -e "$ROOT/plugins/helm-core/commands/helm-archive.md"

echo "helm plugin suite layout fixtures ok"
