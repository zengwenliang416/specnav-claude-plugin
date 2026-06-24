#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/helm-core"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
NO_STATE_FIXTURE="$ROOT/tests/fixtures/no-state"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
EXTERNAL_PROJECT="$TMP_DIR/external-project"
mkdir -p "$EXTERNAL_PROJECT"
PROJECT="$TMP_DIR/simple-project"
NO_STATE="$TMP_DIR/no-state"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
cp -R "$NO_STATE_FIXTURE" "$NO_STATE"

assert_grep() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! grep -q -- "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_grep_fixed() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! grep -Fq -- "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_jq() {
  local expression="$1"
  local file="$2"
  local message="$3"

  if ! jq -e "$expression" "$file" >/dev/null; then
    echo "$message" >&2
    exit 1
  fi
}

assert_grep 'helm-core/scripts/helm-session-start.js\|CLAUDE_PLUGIN_ROOT/scripts/helm-session-start.js' "$CORE/hooks/hooks.json" "session-start hook does not reference the helm core runtime"
assert_grep 'plugin-suite.js' "$CORE/commands/helm.md" "helm command does not reference plugin-suite.js"
assert_grep 'helm-bootstrap.js' "$CORE/commands/helm-bootstrap.md" "helm-bootstrap command does not reference helm-bootstrap.js"
assert_grep 'workflow-state.js' "$CORE/commands/helm-status.md" "helm-status command does not reference workflow-state.js"
assert_grep 'helm-doctor.js' "$CORE/commands/helm-doctor.md" "helm-doctor command does not reference helm-doctor.js"
assert_grep 'helm-bootstrap' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-bootstrap"
assert_grep 'helm-requirements' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-requirements"
assert_grep 'helm-verification' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-verification"
assert_grep 'helm-operations' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-operations"
assert_grep_fixed '--marketplace-root "$CLAUDE_PLUGIN_ROOT/../.."' "$CORE/commands/helm.md" "helm command does not document cwd-independent marketplace root"
assert_grep_fixed '--plugin helm-core --plugin <target-plugin>' "$CORE/commands/helm.md" "helm command does not document core plus target plugin require"
assert_grep_fixed '--marketplace-root "$CLAUDE_PLUGIN_ROOT/../.."' "$CORE/skills/helm-route/SKILL.md" "helm router does not document cwd-independent marketplace root"
assert_grep_fixed '--plugin helm-core --plugin <target-plugin>' "$CORE/skills/helm-route/SKILL.md" "helm router does not document core plus target plugin require"

suite_json="$TMP_DIR/plugin-suite-require.json"
suite_status=0
(
  cd "$EXTERNAL_PROJECT"
  export CLAUDE_PLUGIN_ROOT="$CORE"
  node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --json >"$suite_json"
) || suite_status=$?
if [ "$suite_status" -ne 0 ]; then
  echo "plugin-suite require failed from external project cwd with exit $suite_status" >&2
  exit 1
fi
assert_jq '.ok == true' "$suite_json" "plugin-suite require did not return ok true"
assert_jq '.plugins[] | select(.name == "helm-core" and .ok == true)' "$suite_json" "plugin-suite require did not include ok helm-core plugin"

suite_missing_root_json="$TMP_DIR/plugin-suite-require-missing-root.json"
suite_missing_root_status=0
(
  cd "$EXTERNAL_PROJECT"
  export CLAUDE_PLUGIN_ROOT="$CORE"
  node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --plugin helm-core --json >"$suite_missing_root_json"
) || suite_missing_root_status=$?
if [ "$suite_missing_root_status" -ne 2 ]; then
  echo "plugin-suite require without marketplace root exited $suite_missing_root_status, expected 2" >&2
  exit 1
fi
assert_jq '.blockers | index("missing-marketplace-json")' "$suite_missing_root_json" "plugin-suite require without marketplace root did not report missing marketplace"

INSTALLED_CACHE="$TMP_DIR/installed-cache/helm-marketplace"
mkdir -p "$INSTALLED_CACHE"
HELM_PLUGINS=(helm-core helm-requirements helm-prototype helm-development helm-verification helm-operations)
for plugin in "${HELM_PLUGINS[@]}"; do
  installed_plugin="$INSTALLED_CACHE/$plugin/9.9.9"
  mkdir -p "$installed_plugin"
  cp -R "$ROOT/plugins/$plugin/.claude-plugin" "$installed_plugin/.claude-plugin"
  cp "$ROOT/plugins/$plugin/helm-stage.json" "$installed_plugin/helm-stage.json"
done
installed_inventory="$TMP_DIR/installed-inventory.json"
for plugin in "${HELM_PLUGINS[@]}"; do
  jq -n \
    --arg id "$plugin@helm-marketplace" \
    --arg installPath "$INSTALLED_CACHE/$plugin/9.9.9" \
    '{id: $id, version: "9.9.9", scope: "user", enabled: true, installPath: $installPath}'
done | jq -s '.' >"$installed_inventory"

installed_suite_json="$TMP_DIR/plugin-suite-installed-cache.json"
installed_suite_status=0
(
  cd "$EXTERNAL_PROJECT"
  export HELM_ALLOW_INSTALLED_PLUGIN_DISCOVERY=1
  export HELM_PLUGIN_LIST_JSON
  HELM_PLUGIN_LIST_JSON="$(cat "$installed_inventory")"
  node "$CORE/scripts/plugin-suite.js" list --marketplace-root "$INSTALLED_CACHE" --json >"$installed_suite_json"
) || installed_suite_status=$?
if [ "$installed_suite_status" -ne 0 ]; then
  echo "plugin-suite installed-cache list failed with exit $installed_suite_status" >&2
  cat "$installed_suite_json" >&2
  exit 1
fi
assert_jq '.ok == true' "$installed_suite_json" "plugin-suite installed-cache list did not return ok true"
assert_jq '.discovery == "claude-plugin-list"' "$installed_suite_json" "plugin-suite installed-cache list did not use claude-plugin-list discovery"
assert_jq '.plugins | length == 6' "$installed_suite_json" "plugin-suite installed-cache list did not include all six plugins"

disabled_inventory="$TMP_DIR/installed-disabled-inventory.json"
jq 'map(if .id == "helm-core@helm-marketplace" then .enabled = false else . end)' "$installed_inventory" >"$disabled_inventory"
disabled_suite_json="$TMP_DIR/plugin-suite-installed-disabled.json"
disabled_suite_status=0
(
  cd "$EXTERNAL_PROJECT"
  export HELM_ALLOW_INSTALLED_PLUGIN_DISCOVERY=1
  export HELM_PLUGIN_LIST_JSON
  HELM_PLUGIN_LIST_JSON="$(cat "$disabled_inventory")"
  node "$CORE/scripts/plugin-suite.js" list --marketplace-root "$INSTALLED_CACHE" --json >"$disabled_suite_json"
) || disabled_suite_status=$?
if [ "$disabled_suite_status" -ne 2 ]; then
  echo "plugin-suite installed-cache disabled exited $disabled_suite_status, expected 2" >&2
  cat "$disabled_suite_json" >&2
  exit 1
fi
assert_jq '.blockers | index("disabled-plugin:helm-core")' "$disabled_suite_json" "plugin-suite installed-cache disabled did not report disabled plugin"

workflow_state_json="$TMP_DIR/workflow-state.json"
workflow_state_status=0
PROJECT_DIR="$PROJECT" node "$CORE/scripts/workflow-state.js" --json >"$workflow_state_json" || workflow_state_status=$?
if [ "$workflow_state_status" -ne 0 ]; then
  echo "workflow-state exited $workflow_state_status, expected 0" >&2
  exit 1
fi
assert_jq '.ok == true' "$workflow_state_json" "workflow-state did not report ok true"
assert_jq '.plugin_suite.ok == true' "$workflow_state_json" "workflow-state did not include ok plugin suite"
assert_jq '.required_plugins | index("helm-operations")' "$workflow_state_json" "workflow-state did not include operations dependency"
assert_jq '.actions[] | select(.id == "status" and .state == "ready")' "$workflow_state_json" "workflow-state did not expose ready status action"

workflow_missing_json="$TMP_DIR/workflow-state-missing-openspec.json"
workflow_missing_status=0
PROJECT_DIR="$NO_STATE" node "$CORE/scripts/workflow-state.js" --json >"$workflow_missing_json" || workflow_missing_status=$?
if [ "$workflow_missing_status" -ne 2 ]; then
  echo "workflow-state missing openspec exited $workflow_missing_status, expected 2" >&2
  cat "$workflow_missing_json" >&2
  exit 1
fi
assert_jq '.status == "blocked"' "$workflow_missing_json" "workflow-state did not block missing openspec"
assert_jq '.blockers | index("missing-openspec")' "$workflow_missing_json" "workflow-state did not report missing-openspec"
assert_jq '.actions[] | select(.id == "bootstrap" and .state == "ready")' "$workflow_missing_json" "workflow-state did not expose bootstrap repair action"

bootstrap_project="$TMP_DIR/bootstrap-project"
cp -R "$NO_STATE_FIXTURE" "$bootstrap_project"
bootstrap_json="$TMP_DIR/helm-bootstrap.json"
bootstrap_status=0
PROJECT_DIR="$bootstrap_project" node "$CORE/scripts/helm-bootstrap.js" --json >"$bootstrap_json" || bootstrap_status=$?
if [ "$bootstrap_status" -ne 0 ]; then
  echo "helm-bootstrap exited $bootstrap_status, expected 0" >&2
  cat "$bootstrap_json" >&2
  exit 1
fi
assert_jq '.ok == true' "$bootstrap_json" "helm-bootstrap did not report ok true"
assert_jq '.status == "initialized"' "$bootstrap_json" "helm-bootstrap did not report initialized"
assert_jq '.next_actions | index("/helm-requirements")' "$bootstrap_json" "helm-bootstrap did not report requirements next action"
test -d "$bootstrap_project/openspec"
test -f "$bootstrap_project/openspec/.helm/workflow-state.json"

session_ready_json="$TMP_DIR/session-ready.json"
PROJECT_DIR="$PROJECT" node "$CORE/scripts/helm-session-start.js" >"$session_ready_json"
assert_jq '.status == "ready"' "$session_ready_json" "session start did not report ready for openspec project"
test -f "$PROJECT/openspec/.helm/workflow-state.json"
test -s "$PROJECT/openspec/.helm/context/requirements-context.jsonl"
test -s "$PROJECT/openspec/.helm/context/prototype-context.jsonl"
test -s "$PROJECT/openspec/.helm/context/implement-context.jsonl"
test -s "$PROJECT/openspec/.helm/context/verify-context.jsonl"
test -s "$PROJECT/openspec/.helm/context/ops-context.jsonl"
test -f "$PROJECT/openspec/.helm/journal/index.md"

session_blocked_json="$TMP_DIR/session-blocked.json"
PROJECT_DIR="$NO_STATE" node "$CORE/scripts/helm-session-start.js" >"$session_blocked_json" 2>"$TMP_DIR/session-blocked.err"
assert_jq '.status == "blocked"' "$session_blocked_json" "session start did not report blocked without openspec"
assert_jq '.blockers | index("missing-openspec")' "$session_blocked_json" "session start did not report missing-openspec"
assert_jq '.recommended_command == "/helm-bootstrap"' "$session_blocked_json" "session start did not recommend helm-bootstrap"
assert_jq '.allowed_actions | index("/helm-bootstrap")' "$session_blocked_json" "session start did not include helm-bootstrap allowed action"
grep -Fq 'missing-openspec' "$TMP_DIR/session-blocked.err"
grep -Fq '/helm-bootstrap' "$TMP_DIR/session-blocked.err"

doctor_json="$TMP_DIR/helm-doctor.json"
doctor_status=0
node "$CORE/scripts/helm-doctor.js" --json >"$doctor_json" || doctor_status=$?
if [ "$doctor_status" -ne 0 ]; then
  echo "helm-doctor exited $doctor_status, expected 0" >&2
  exit 1
fi
assert_jq '.ok == true' "$doctor_json" "helm-doctor did not report ok true"
assert_jq '.suite.ok == true' "$doctor_json" "helm-doctor did not include ok plugin suite"
assert_jq '.checks[] | select(.name == "plugin-suite" and .ok == true)' "$doctor_json" "helm-doctor did not pass plugin-suite check"
assert_jq '.checks[] | select(.name == "openspec-cli" and .ok == true)' "$doctor_json" "helm-doctor did not pass openspec-cli check"

project_doctor_json="$TMP_DIR/helm-doctor-project.json"
PROJECT_DIR="$PROJECT" node "$CORE/scripts/helm-doctor.js" --json >"$project_doctor_json"
assert_jq '.ok == true' "$project_doctor_json" "helm-doctor with project did not report ok true"
assert_jq '.checks[] | select(.name == "context-manifests" and .ok == true)' "$project_doctor_json" "helm-doctor did not pass context-manifests check"
assert_jq '.checks[] | select(.name == "journal" and .ok == true)' "$project_doctor_json" "helm-doctor did not pass journal check"

affordances_json="$TMP_DIR/helm-core-affordances.json"
PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >"$affordances_json"
assert_jq '.active_change == "add-dark-mode"' "$affordances_json" "affordances did not report active_change add-dark-mode"

echo "helm core runtime fixtures ok"
