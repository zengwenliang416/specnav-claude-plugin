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

assert_no_bash_placeholders() {
  local file="$1"
  local bash_blocks="$tmp_dir/$(basename "$file").bash-blocks"

  awk '
    /^```bash$/ { in_block = 1; next }
    /^```$/ && in_block { in_block = 0; next }
    in_block { print }
  ' "$file" >"$bash_blocks"

  if grep -Eq '<[^[:space:]>][^>]*>' "$bash_blocks"; then
    echo "bash code block contains placeholder angle brackets: $file" >&2
    exit 1
  fi
}

jq -e '.plugins | length == 6' "$ROOT/.claude-plugin/marketplace.json" >/dev/null
jq -e '.plugins[].name' "$ROOT/.claude-plugin/marketplace.json" >/tmp/specnav-plugin-names.txt
jq -e 'all(.plugins[].source; startswith("./plugins/"))' "$ROOT/.claude-plugin/marketplace.json" >/dev/null
grep -q '"specnav-core"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-requirements"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-prototype"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-development"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-verification"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-operations"' /tmp/specnav-plugin-names.txt

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for plugin in specnav-core specnav-requirements specnav-prototype specnav-development specnav-verification specnav-operations; do
  test -d "$ROOT/plugins/$plugin/skills"
  test -d "$ROOT/plugins/$plugin/scripts"
  test -f "$ROOT/plugins/$plugin/.claude-plugin/plugin.json"
  test -f "$ROOT/plugins/$plugin/specnav-stage.json"
  jq -e '.name == "'"$plugin"'"' "$ROOT/plugins/$plugin/.claude-plugin/plugin.json" >/dev/null
  jq -e '.plugin == "'"$plugin"'"' "$ROOT/plugins/$plugin/specnav-stage.json" >/dev/null

  declared_skills="$tmp_dir/$plugin.skills"
  jq -r '.skills[]?' "$ROOT/plugins/$plugin/specnav-stage.json" | sort >"$declared_skills"

  while IFS= read -r command; do
    test -f "$ROOT/plugins/$plugin/commands/$command.md"
  done < <(jq -r '.commands[]?' "$ROOT/plugins/$plugin/specnav-stage.json")

  while IFS= read -r skill; do
    test -f "$ROOT/plugins/$plugin/skills/$skill/SKILL.md"
  done < <(jq -r '.skills[]?' "$ROOT/plugins/$plugin/specnav-stage.json")

  while IFS= read -r skill_file; do
    skill="$(basename "$(dirname "$skill_file")")"
    if ! grep -Fxq "$skill" "$declared_skills"; then
      echo "undeclared skill in $plugin: $skill" >&2
      exit 1
    fi
  done < <(find "$ROOT/plugins/$plugin/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort)

  while IFS= read -r contract; do
    test -f "$ROOT/plugins/$plugin/$contract"
  done < <(jq -r '(.contracts // {})[]' "$ROOT/plugins/$plugin/specnav-stage.json")

  while IFS= read -r planned_contract; do
    test ! -e "$ROOT/plugins/$plugin/$planned_contract"
  done < <(jq -r '(.planned_contracts // {})[]' "$ROOT/plugins/$plugin/specnav-stage.json")
done

test -f "$ROOT/plugins/specnav-core/hooks/hooks.json"
test -f "$ROOT/plugins/specnav-core/scripts/specnav-lib.js"
test -f "$ROOT/plugins/specnav-core/scripts/workflow-state.js"
test -f "$ROOT/plugins/specnav-core/scripts/specnav-doctor.js"
test ! -e "$ROOT/plugins/specnav-core/commands/specnav-verify.md"
test ! -e "$ROOT/plugins/specnav-core/commands/specnav-archive.md"
for legacy_core_skill in archive bootstrap design explore fix implement propose tasks verify; do
  test ! -e "$ROOT/plugins/specnav-core/skills/$legacy_core_skill"
done

for command_file in "$ROOT"/plugins/*/commands/*.md; do
  grep -q 'specnav_plugin_root()' "$command_file"
  if grep -qF 'node - "$1"' "$command_file"; then
    echo "command resolver must not use slash-command positional $1: $command_file" >&2
    exit 1
  fi
  if grep -qF 'process.argv[2]' "$command_file"; then
    echo "command resolver must use SPECNAV_PLUGIN_NAME, not argv[2]: $command_file" >&2
    exit 1
  fi
  assert_no_bash_placeholders "$command_file"
  if grep -qF '$CLAUDE_PLUGIN_ROOT' "$command_file"; then
    echo "command must not rely on CLAUDE_PLUGIN_ROOT: $command_file" >&2
    exit 1
  fi
done

grep -Fq '$SPECNAV_REQUIREMENTS_ROOT/skills/specnav-requirements/SKILL.md' "$ROOT/plugins/specnav-requirements/commands/specnav-requirements.md"
grep -Fq '$SPECNAV_PROTOTYPE_ROOT/skills/specnav-prototype/SKILL.md' "$ROOT/plugins/specnav-prototype/commands/specnav-prototype.md"
grep -Fq '$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-plan/SKILL.md' "$ROOT/plugins/specnav-verification/commands/specnav-verify.md"

assert_first_before \
  "$ROOT/plugins/specnav-operations/commands/specnav-archive.md" \
  'node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js"' \
  'node "$SPECNAV_OPERATIONS_ROOT/scripts/archive-change.js" --json'

grep -Fq 'native' "$ROOT/plugins/specnav-operations/commands/specnav-archive.md"
grep -Fq 'OpenSpec skills' "$ROOT/plugins/specnav-operations/commands/specnav-archive.md"

for routing_file in \
  "$ROOT/plugins/specnav-core/commands/specnav.md" \
  "$ROOT/plugins/specnav-core/skills/specnav-route/SKILL.md"; do
  if grep -Eq 'load the corresponding SpecNav skill|-> `(explore|propose|design|tasks|implement|fix|verify|archive)`' "$routing_file"; then
    echo "legacy core lifecycle route remains in $routing_file" >&2
    exit 1
  fi
done

echo "specnav plugin suite layout fixtures ok"
