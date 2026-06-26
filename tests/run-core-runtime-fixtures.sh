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
assert_grep 'helm-route.js' "$CORE/commands/helm.md" "helm command does not reference helm-route.js"
assert_grep 'resolve-runtime.js' "$CORE/commands/helm.md" "helm command does not reference resolve-runtime.js"
assert_grep 'helm-bootstrap.js' "$CORE/commands/helm-bootstrap.md" "helm-bootstrap command does not reference helm-bootstrap.js"
assert_grep 'workflow-state.js' "$CORE/commands/helm-status.md" "helm-status command does not reference workflow-state.js"
assert_grep 'helm-doctor.js' "$CORE/commands/helm-doctor.md" "helm-doctor command does not reference helm-doctor.js"
assert_grep 'helm-route.js' "$CORE/skills/helm-route/SKILL.md" "helm router skill does not reference helm-route.js"
assert_grep 'helm-bootstrap' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-bootstrap"
assert_grep 'helm-requirements' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-requirements"
assert_grep 'helm-foundation-specs' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-foundation-specs"
assert_grep 'foundation-specs.js' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention foundation-specs.js"
assert_grep 'development-conventions' "$CORE/skills/helm-route/SKILL.md" "helm router does not document development-conventions mismatch"
assert_grep 'helm-verification' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-verification"
assert_grep 'helm-operations' "$CORE/skills/helm-route/SKILL.md" "helm router does not mention helm-operations"
assert_grep 'helm-foundation-specs' "$CORE/commands/helm.md" "helm command does not mention helm-foundation-specs"
assert_grep 'foundation-specs.js' "$CORE/commands/helm.md" "helm command does not mention foundation-specs.js"
assert_grep 'target_plugin' "$CORE/commands/helm.md" "helm command does not document router target plugin"
assert_grep 'required_plugins' "$CORE/skills/helm-route/SKILL.md" "helm router does not document required plugins"

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

COMMAND_HOME="$TMP_DIR/command-home"
COMMAND_CACHE="$COMMAND_HOME/.claude/plugins/cache/helm-marketplace/helm-core/9.9.9"
mkdir -p "$(dirname "$COMMAND_CACHE")"
cp -R "$CORE" "$COMMAND_CACHE"
command_bootstrap_project="$TMP_DIR/command-bootstrap-project"
cp -R "$NO_STATE_FIXTURE" "$command_bootstrap_project"
command_bootstrap_script="$TMP_DIR/helm-bootstrap-command.sh"
awk '
  /^```bash$/ { in_block = 1; next }
  /^```$/ && in_block { exit }
  in_block { print }
' "$CORE/commands/helm-bootstrap.md" >"$command_bootstrap_script"
command_bootstrap_json="$TMP_DIR/helm-bootstrap-command.json"
command_bootstrap_status=0
(
  cd "$command_bootstrap_project"
  unset CLAUDE_PLUGIN_ROOT
  HOME="$COMMAND_HOME" PROJECT_DIR="$command_bootstrap_project" bash "$command_bootstrap_script" >"$command_bootstrap_json"
) || command_bootstrap_status=$?
if [ "$command_bootstrap_status" -ne 0 ]; then
  echo "helm-bootstrap command failed with CLAUDE_PLUGIN_ROOT unset, exit $command_bootstrap_status" >&2
  cat "$command_bootstrap_json" >&2
  exit 1
fi
assert_jq '.ok == true' "$command_bootstrap_json" "helm-bootstrap command did not report ok true with installed-cache resolver"
test -d "$command_bootstrap_project/openspec"

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

route_bootstrap_json="$TMP_DIR/helm-route-bootstrap.json"
route_bootstrap_status=0
PROJECT_DIR="$NO_STATE" HELM_MARKETPLACE_ROOT="$ROOT" node "$CORE/scripts/helm-route.js" --intent "continue implementation" --json >"$route_bootstrap_json" || route_bootstrap_status=$?
if [ "$route_bootstrap_status" -ne 0 ]; then
  echo "helm-route missing openspec exited $route_bootstrap_status, expected 0" >&2
  cat "$route_bootstrap_json" >&2
  exit 1
fi
assert_jq '.ok == true' "$route_bootstrap_json" "helm-route missing openspec did not report ok true"
assert_jq '.target_plugin == "helm-core"' "$route_bootstrap_json" "helm-route missing openspec did not target helm-core"
assert_jq '.command == "/helm-bootstrap"' "$route_bootstrap_json" "helm-route missing openspec did not route to helm-bootstrap"
assert_jq '.skill == "helm-bootstrap"' "$route_bootstrap_json" "helm-route missing openspec did not select helm-bootstrap skill"
assert_jq '.affordance_state == "missing-openspec"' "$route_bootstrap_json" "helm-route missing openspec did not expose missing-openspec state"
assert_jq '.no_fallback == true' "$route_bootstrap_json" "helm-route did not mark no_fallback true"

route_foundation_json="$TMP_DIR/helm-route-foundation.json"
route_foundation_status=0
PROJECT_DIR="$PROJECT" HELM_MARKETPLACE_ROOT="$ROOT" node "$CORE/scripts/helm-route.js" --intent "create complete project standards and foundation specs" --json >"$route_foundation_json" || route_foundation_status=$?
if [ "$route_foundation_status" -ne 2 ]; then
  echo "helm-route foundation exited $route_foundation_status, expected 2" >&2
  cat "$route_foundation_json" >&2
  exit 1
fi
assert_jq '.target_plugin == "helm-requirements"' "$route_foundation_json" "helm-route foundation did not target helm-requirements"
assert_jq '.command == "/helm-requirements"' "$route_foundation_json" "helm-route foundation did not route to helm-requirements"
assert_jq '.skill == "helm-foundation-specs"' "$route_foundation_json" "helm-route foundation did not select helm-foundation-specs"
assert_jq '.skills | index("helm-repository-discovery")' "$route_foundation_json" "helm-route foundation did not include repository discovery step"
assert_jq '.blockers | index("missing-foundation-spec:ui-design")' "$route_foundation_json" "helm-route foundation did not report ui-design blocker"
assert_jq '.blockers | index("missing-foundation-spec:system-architecture")' "$route_foundation_json" "helm-route foundation did not report system architecture blocker"

route_verify_json="$TMP_DIR/helm-route-verify.json"
route_verify_status=0
PROJECT_DIR="$PROJECT" HELM_MARKETPLACE_ROOT="$ROOT" node "$CORE/scripts/helm-route.js" --intent "verify implementation" --json >"$route_verify_json" || route_verify_status=$?
if [ "$route_verify_status" -ne 0 ]; then
  echo "helm-route verification exited $route_verify_status, expected 0" >&2
  cat "$route_verify_json" >&2
  exit 1
fi
assert_jq '.target_plugin == "helm-verification"' "$route_verify_json" "helm-route verification did not target helm-verification"
assert_jq '.command == "/helm-verify"' "$route_verify_json" "helm-route verification did not route to helm-verify"
assert_jq '.skill == "helm-verify-plan"' "$route_verify_json" "helm-route verification did not select helm-verify-plan"
assert_jq '.required_plugins | index("helm-verification")' "$route_verify_json" "helm-route verification did not require helm-verification"

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

# Non-Helm project (no marker, no openspec) — session stays inactive, no routing noise
session_inactive_json="$TMP_DIR/session-inactive.json"
PROJECT_DIR="$NO_STATE" node "$CORE/scripts/helm-session-start.js" >"$session_inactive_json" 2>"$TMP_DIR/session-inactive.err"
assert_jq '.status == "inactive"' "$session_inactive_json" "session start did not report inactive for non-Helm project"

# Helm project missing openspec (.helm.json present) — session blocks and routes to bootstrap
session_helm_broken="$TMP_DIR/session-helm-broken"
mkdir -p "$session_helm_broken"
printf '{"schema_version":1,"enabled":true}\n' >"$session_helm_broken/.helm.json"
session_blocked_json="$TMP_DIR/session-blocked.json"
PROJECT_DIR="$session_helm_broken" node "$CORE/scripts/helm-session-start.js" >"$session_blocked_json" 2>"$TMP_DIR/session-blocked.err"
assert_jq '.status == "blocked"' "$session_blocked_json" "Helm project without openspec did not block"
assert_jq '.blockers | index("missing-openspec")' "$session_blocked_json" "Helm project did not report missing-openspec"
assert_jq '.recommended_command == "/helm-bootstrap"' "$session_blocked_json" "Helm project did not recommend helm-bootstrap"
grep -Fq 'missing-openspec' "$TMP_DIR/session-blocked.err"

doctor_json="$TMP_DIR/helm-doctor.json"
doctor_status=0
HELM_PLUGIN_LIST_JSON="$(cat "$installed_inventory")" node "$CORE/scripts/helm-doctor.js" --json >"$doctor_json" || doctor_status=$?
if [ "$doctor_status" -ne 0 ]; then
  echo "helm-doctor exited $doctor_status, expected 0" >&2
  exit 1
fi
assert_jq '.ok == true' "$doctor_json" "helm-doctor did not report ok true"
assert_jq '.suite.ok == true' "$doctor_json" "helm-doctor did not include ok plugin suite"
assert_jq '.checks[] | select(.name == "plugin-suite" and .ok == true)' "$doctor_json" "helm-doctor did not pass plugin-suite check"
assert_jq '.checks[] | select(.name == "openspec-cli" and .ok == true)' "$doctor_json" "helm-doctor did not pass openspec-cli check"

project_doctor_json="$TMP_DIR/helm-doctor-project.json"
HELM_PLUGIN_LIST_JSON="$(cat "$installed_inventory")" PROJECT_DIR="$PROJECT" node "$CORE/scripts/helm-doctor.js" --json >"$project_doctor_json"
assert_jq '.ok == true' "$project_doctor_json" "helm-doctor with project did not report ok true"
assert_jq '.checks[] | select(.name == "context-manifests" and .ok == true)' "$project_doctor_json" "helm-doctor did not pass context-manifests check"
assert_jq '.checks[] | select(.name == "journal" and .ok == true)' "$project_doctor_json" "helm-doctor did not pass journal check"

affordances_json="$TMP_DIR/helm-core-affordances.json"
PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >"$affordances_json"
assert_jq '.active_change == "add-dark-mode"' "$affordances_json" "affordances did not report active_change add-dark-mode"

single_change_project="$TMP_DIR/single-change-project"
cp -R "$PROJECT_FIXTURE" "$single_change_project"
rm "$single_change_project/openspec/.helm/active-change"
rm -f "$single_change_project/openspec/.helm/workflow-state.json"
single_change_affordances_json="$TMP_DIR/single-change-affordances.json"
PROJECT_DIR="$single_change_project" node "$CORE/scripts/affordances.js" --json >"$single_change_affordances_json"
assert_jq '.active_change == "add-dark-mode"' "$single_change_affordances_json" "affordances did not infer the only change"

workflow_state_project="$TMP_DIR/workflow-state-active-project"
cp -R "$PROJECT_FIXTURE" "$workflow_state_project"
rm "$workflow_state_project/openspec/.helm/active-change"
mkdir -p "$workflow_state_project/openspec/changes/another-change"
cat >"$workflow_state_project/openspec/.helm/workflow-state.json" <<'JSON'
{
  "schema_version": 1,
  "active_change": "add-dark-mode"
}
JSON
workflow_state_affordances_json="$TMP_DIR/workflow-state-affordances.json"
PROJECT_DIR="$workflow_state_project" node "$CORE/scripts/affordances.js" --json >"$workflow_state_affordances_json"
assert_jq '.active_change == "add-dark-mode"' "$workflow_state_affordances_json" "affordances did not read workflow-state active_change"

ambiguous_change_project="$TMP_DIR/ambiguous-change-project"
cp -R "$PROJECT_FIXTURE" "$ambiguous_change_project"
rm "$ambiguous_change_project/openspec/.helm/active-change"
rm -f "$ambiguous_change_project/openspec/.helm/workflow-state.json"
mkdir -p "$ambiguous_change_project/openspec/changes/another-change"
ambiguous_change_affordances_json="$TMP_DIR/ambiguous-change-affordances.json"
PROJECT_DIR="$ambiguous_change_project" node "$CORE/scripts/affordances.js" --json >"$ambiguous_change_affordances_json"
assert_jq '.active_change == null' "$ambiguous_change_affordances_json" "affordances inferred an ambiguous active change"
assert_jq '.state_source == "no-active-change"' "$ambiguous_change_affordances_json" "affordances did not report no-active-change for ambiguous changes"

echo "helm core runtime fixtures ok"
