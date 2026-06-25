#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

assert_first_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local first_line
  local second_line

  first_line="$(grep -nF "$first" "$file" | head -n1 | cut -d: -f1 || true)"
  second_line="$(grep -nF "$second" "$file" | head -n1 | cut -d: -f1 || true)"

  if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
    echo "expected '$first' before '$second' in $file" >&2
    exit 1
  fi
}

jq -e '.plugins | length == 6' "$ROOT/.claude-plugin/marketplace.json" >/dev/null
jq -e '.plugins[].name' "$ROOT/.claude-plugin/marketplace.json" >/tmp/helm-plugin-names.txt
jq -e 'all(.plugins[].source; startswith("./plugins/"))' "$ROOT/.claude-plugin/marketplace.json" >/dev/null
grep -q '"helm-core"' /tmp/helm-plugin-names.txt
grep -q '"helm-requirements"' /tmp/helm-plugin-names.txt
grep -q '"helm-prototype"' /tmp/helm-plugin-names.txt
grep -q '"helm-development"' /tmp/helm-plugin-names.txt
grep -q '"helm-verification"' /tmp/helm-plugin-names.txt
grep -q '"helm-operations"' /tmp/helm-plugin-names.txt

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for plugin in helm-core helm-requirements helm-prototype helm-development helm-verification helm-operations; do
  test -d "$ROOT/plugins/$plugin/skills"
  test -d "$ROOT/plugins/$plugin/scripts"
  test -f "$ROOT/plugins/$plugin/.claude-plugin/plugin.json"
  test -f "$ROOT/plugins/$plugin/helm-stage.json"
  jq -e '.name == "'"$plugin"'"' "$ROOT/plugins/$plugin/.claude-plugin/plugin.json" >/dev/null
  jq -e '.plugin == "'"$plugin"'"' "$ROOT/plugins/$plugin/helm-stage.json" >/dev/null

  declared_skills="$tmp_dir/$plugin.skills"
  jq -r '.skills[]?' "$ROOT/plugins/$plugin/helm-stage.json" | sort >"$declared_skills"

  while IFS= read -r command; do
    test -f "$ROOT/plugins/$plugin/commands/$command.md"
  done < <(jq -r '.commands[]?' "$ROOT/plugins/$plugin/helm-stage.json")

  while IFS= read -r skill; do
    test -f "$ROOT/plugins/$plugin/skills/$skill/SKILL.md"
  done < <(jq -r '.skills[]?' "$ROOT/plugins/$plugin/helm-stage.json")

  while IFS= read -r skill_file; do
    skill="$(basename "$(dirname "$skill_file")")"
    if ! grep -Fxq "$skill" "$declared_skills"; then
      echo "undeclared skill in $plugin: $skill" >&2
      exit 1
    fi
  done < <(find "$ROOT/plugins/$plugin/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort)

  while IFS= read -r contract; do
    test -f "$ROOT/plugins/$plugin/$contract"
  done < <(jq -r '(.contracts // {})[]' "$ROOT/plugins/$plugin/helm-stage.json")

  while IFS= read -r planned_contract; do
    test ! -e "$ROOT/plugins/$plugin/$planned_contract"
  done < <(jq -r '(.planned_contracts // {})[]' "$ROOT/plugins/$plugin/helm-stage.json")
done

test -f "$ROOT/plugins/helm-core/hooks/hooks.json"
test -f "$ROOT/plugins/helm-core/scripts/helm-lib.js"
test -f "$ROOT/plugins/helm-core/scripts/workflow-state.js"
test -f "$ROOT/plugins/helm-core/scripts/helm-doctor.js"
test ! -e "$ROOT/plugins/helm-core/commands/helm-verify.md"
test ! -e "$ROOT/plugins/helm-core/commands/helm-archive.md"
for legacy_core_skill in archive bootstrap design explore fix implement propose tasks verify; do
  test ! -e "$ROOT/plugins/helm-core/skills/$legacy_core_skill"
done

for command_file in "$ROOT"/plugins/*/commands/*.md; do
  grep -q 'helm_plugin_root()' "$command_file"
  if grep -qF '$CLAUDE_PLUGIN_ROOT' "$command_file"; then
    echo "command must not rely on CLAUDE_PLUGIN_ROOT: $command_file" >&2
    exit 1
  fi
done

assert_first_before \
  "$ROOT/plugins/helm-operations/commands/helm-archive.md" \
  'node "$HELM_CORE_ROOT/scripts/plugin-suite.js"' \
  'node "$HELM_OPERATIONS_ROOT/scripts/archive-gate.js"'

for routing_file in \
  "$ROOT/plugins/helm-core/commands/helm.md" \
  "$ROOT/plugins/helm-core/skills/helm-route/SKILL.md"; do
  if grep -Eq 'load the corresponding Helm skill|-> `(explore|propose|design|tasks|implement|fix|verify|archive)`' "$routing_file"; then
    echo "legacy core lifecycle route remains in $routing_file" >&2
    exit 1
  fi
done

echo "helm plugin suite layout fixtures ok"
