#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
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

assert_grep 'specnav-core/scripts/specnav-session-start.js\|CLAUDE_PLUGIN_ROOT/scripts/specnav-session-start.js' "$CORE/hooks/hooks.json" "session-start hook does not reference the specnav core runtime"
assert_grep 'specnav-route.js' "$CORE/commands/specnav.md" "specnav command does not reference specnav-route.js"
assert_grep 'resolve-runtime.js' "$CORE/commands/specnav.md" "specnav command does not reference resolve-runtime.js"
assert_grep 'specnav-bootstrap.js' "$CORE/commands/specnav-bootstrap.md" "specnav-bootstrap command does not reference specnav-bootstrap.js"
assert_grep 'workflow-state.js' "$CORE/commands/specnav-status.md" "specnav-status command does not reference workflow-state.js"
assert_grep 'specnav-doctor.js' "$CORE/commands/specnav-doctor.md" "specnav-doctor command does not reference specnav-doctor.js"
assert_grep 'specnav-route.js' "$CORE/skills/specnav-route/SKILL.md" "specnav router skill does not reference specnav-route.js"
assert_grep 'specnav-bootstrap' "$CORE/skills/specnav-route/SKILL.md" "specnav router does not mention specnav-bootstrap"
assert_grep 'specnav-requirements' "$CORE/skills/specnav-route/SKILL.md" "specnav router does not mention specnav-requirements"
assert_grep 'specnav-foundation-specs' "$CORE/skills/specnav-route/SKILL.md" "specnav router does not mention specnav-foundation-specs"
assert_grep 'foundation-specs.js' "$CORE/skills/specnav-route/SKILL.md" "specnav router does not mention foundation-specs.js"
assert_grep 'development-conventions' "$CORE/skills/specnav-route/SKILL.md" "specnav router does not document development-conventions mismatch"
assert_grep 'specnav-verification' "$CORE/skills/specnav-route/SKILL.md" "specnav router does not mention specnav-verification"
assert_grep 'specnav-operations' "$CORE/skills/specnav-route/SKILL.md" "specnav router does not mention specnav-operations"
assert_grep 'specnav-foundation-specs' "$CORE/commands/specnav.md" "specnav command does not mention specnav-foundation-specs"
assert_grep 'foundation-specs.js' "$CORE/commands/specnav.md" "specnav command does not mention foundation-specs.js"
assert_grep 'target_plugin' "$CORE/commands/specnav.md" "specnav command does not document router target plugin"
assert_grep 'required_plugins' "$CORE/skills/specnav-route/SKILL.md" "specnav router does not document required plugins"

suite_json="$TMP_DIR/plugin-suite-require.json"
suite_status=0
(
  cd "$EXTERNAL_PROJECT"
  export CLAUDE_PLUGIN_ROOT="$CORE"
  node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin specnav-core --json >"$suite_json"
) || suite_status=$?
if [ "$suite_status" -ne 0 ]; then
  echo "plugin-suite require failed from external project cwd with exit $suite_status" >&2
  exit 1
fi
assert_jq '.ok == true' "$suite_json" "plugin-suite require did not return ok true"
assert_jq '.plugins[] | select(.name == "specnav-core" and .ok == true)' "$suite_json" "plugin-suite require did not include ok specnav-core plugin"

suite_missing_root_json="$TMP_DIR/plugin-suite-require-missing-root.json"
suite_missing_root_status=0
(
  cd "$EXTERNAL_PROJECT"
  export CLAUDE_PLUGIN_ROOT="$CORE"
  node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --plugin specnav-core --json >"$suite_missing_root_json"
) || suite_missing_root_status=$?
if [ "$suite_missing_root_status" -ne 2 ]; then
  echo "plugin-suite require without marketplace root exited $suite_missing_root_status, expected 2" >&2
  exit 1
fi
assert_jq '.blockers | index("missing-marketplace-json")' "$suite_missing_root_json" "plugin-suite require without marketplace root did not report missing marketplace"

TASKS_PROJECT="$TMP_DIR/tasks-project"
TASKS_CHANGE="normalize-tasks"
mkdir -p "$TASKS_PROJECT/openspec/.specnav" "$TASKS_PROJECT/openspec/changes/$TASKS_CHANGE"
printf '%s\n' "$TASKS_CHANGE" >"$TASKS_PROJECT/openspec/.specnav/active-change"
cat >"$TASKS_PROJECT/openspec/changes/$TASKS_CHANGE/tasks.md" <<'MD'
# Tasks

- user can review payroll payslips
1. HR can export CPF contribution summary
MD
tasks_normalize_json="$TMP_DIR/tasks-normalize.json"
tasks_normalize_status=0
PROJECT_DIR="$TASKS_PROJECT" node "$CORE/scripts/tasks-md.js" normalize --json >"$tasks_normalize_json" || tasks_normalize_status=$?
if [ "$tasks_normalize_status" -ne 2 ]; then
  echo "tasks-md normalize exited $tasks_normalize_status, expected 2 for unchecked normalized tasks" >&2
  cat "$tasks_normalize_json" >&2
  exit 1
fi
assert_grep_fixed '- [ ] user can review payroll payslips' "$TASKS_PROJECT/openspec/changes/$TASKS_CHANGE/tasks.md" "tasks-md did not normalize plain bullet to checkbox"
assert_grep_fixed '- [ ] HR can export CPF contribution summary' "$TASKS_PROJECT/openspec/changes/$TASKS_CHANGE/tasks.md" "tasks-md did not normalize numbered task to checkbox"
assert_jq '.changed == true' "$tasks_normalize_json" "tasks-md normalize did not report changed true"
assert_jq '.blockers | index("tasks-md:incomplete-checkboxes")' "$tasks_normalize_json" "tasks-md normalize did not report incomplete checkbox blocker"

INSTALLED_CACHE="$TMP_DIR/installed-cache/specnav-marketplace"
mkdir -p "$INSTALLED_CACHE"
SPECNAV_PLUGINS=(specnav-core specnav-requirements specnav-prototype specnav-development specnav-verification specnav-operations specnav-codegraph)
for plugin in "${SPECNAV_PLUGINS[@]}"; do
  installed_plugin="$INSTALLED_CACHE/$plugin/9.9.9"
  mkdir -p "$installed_plugin"
  cp -R "$ROOT/plugins/$plugin/.claude-plugin" "$installed_plugin/.claude-plugin"
  cp "$ROOT/plugins/$plugin/specnav-stage.json" "$installed_plugin/specnav-stage.json"
done
installed_inventory="$TMP_DIR/installed-inventory.json"
for plugin in "${SPECNAV_PLUGINS[@]}"; do
  jq -n \
    --arg id "$plugin@specnav-marketplace" \
    --arg installPath "$INSTALLED_CACHE/$plugin/9.9.9" \
    '{id: $id, version: "9.9.9", scope: "user", enabled: true, installPath: $installPath}'
done | jq -s '.' >"$installed_inventory"

installed_suite_json="$TMP_DIR/plugin-suite-installed-cache.json"
installed_suite_status=0
(
  cd "$EXTERNAL_PROJECT"
  export SPECNAV_ALLOW_INSTALLED_PLUGIN_DISCOVERY=1
  export SPECNAV_PLUGIN_LIST_JSON
  SPECNAV_PLUGIN_LIST_JSON="$(cat "$installed_inventory")"
  node "$CORE/scripts/plugin-suite.js" list --marketplace-root "$INSTALLED_CACHE" --json >"$installed_suite_json"
) || installed_suite_status=$?
if [ "$installed_suite_status" -ne 0 ]; then
  echo "plugin-suite installed-cache list failed with exit $installed_suite_status" >&2
  cat "$installed_suite_json" >&2
  exit 1
fi
assert_jq '.ok == true' "$installed_suite_json" "plugin-suite installed-cache list did not return ok true"
assert_jq '.discovery == "claude-plugin-list"' "$installed_suite_json" "plugin-suite installed-cache list did not use claude-plugin-list discovery"
assert_jq '.plugins | length == 7' "$installed_suite_json" "plugin-suite installed-cache list did not include all seven plugins"

disabled_inventory="$TMP_DIR/installed-disabled-inventory.json"
jq 'map(if .id == "specnav-core@specnav-marketplace" then .enabled = false else . end)' "$installed_inventory" >"$disabled_inventory"
disabled_suite_json="$TMP_DIR/plugin-suite-installed-disabled.json"
disabled_suite_status=0
(
  cd "$EXTERNAL_PROJECT"
  export SPECNAV_ALLOW_INSTALLED_PLUGIN_DISCOVERY=1
  export SPECNAV_PLUGIN_LIST_JSON
  SPECNAV_PLUGIN_LIST_JSON="$(cat "$disabled_inventory")"
  node "$CORE/scripts/plugin-suite.js" list --marketplace-root "$INSTALLED_CACHE" --json >"$disabled_suite_json"
) || disabled_suite_status=$?
if [ "$disabled_suite_status" -ne 2 ]; then
  echo "plugin-suite installed-cache disabled exited $disabled_suite_status, expected 2" >&2
  cat "$disabled_suite_json" >&2
  exit 1
fi
assert_jq '.blockers | index("disabled-plugin:specnav-core")' "$disabled_suite_json" "plugin-suite installed-cache disabled did not report disabled plugin"

COMMAND_HOME="$TMP_DIR/command-home"
COMMAND_CACHE="$COMMAND_HOME/.claude/plugins/cache/specnav-marketplace/specnav-core/9.9.9"
mkdir -p "$(dirname "$COMMAND_CACHE")"
cp -R "$CORE" "$COMMAND_CACHE"
command_bootstrap_project="$TMP_DIR/command-bootstrap-project"
cp -R "$NO_STATE_FIXTURE" "$command_bootstrap_project"
command_bootstrap_script="$TMP_DIR/specnav-bootstrap-command.sh"
awk '
  /^```bash$/ { in_block = 1; next }
  /^```$/ && in_block { exit }
  in_block { print }
' "$CORE/commands/specnav-bootstrap.md" >"$command_bootstrap_script"
command_bootstrap_json="$TMP_DIR/specnav-bootstrap-command.json"
command_bootstrap_status=0
(
  cd "$command_bootstrap_project"
  unset CLAUDE_PLUGIN_ROOT
  HOME="$COMMAND_HOME" PROJECT_DIR="$command_bootstrap_project" bash "$command_bootstrap_script" >"$command_bootstrap_json"
) || command_bootstrap_status=$?
if [ "$command_bootstrap_status" -ne 0 ]; then
  echo "specnav-bootstrap command failed with CLAUDE_PLUGIN_ROOT unset, exit $command_bootstrap_status" >&2
  cat "$command_bootstrap_json" >&2
  exit 1
fi
assert_jq '.ok == true' "$command_bootstrap_json" "specnav-bootstrap command did not report ok true with installed-cache resolver"
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
assert_jq '.required_plugins | index("specnav-operations")' "$workflow_state_json" "workflow-state did not include operations dependency"
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

route_bootstrap_json="$TMP_DIR/specnav-route-bootstrap.json"
route_bootstrap_status=0
PROJECT_DIR="$NO_STATE" SPECNAV_MARKETPLACE_ROOT="$ROOT" node "$CORE/scripts/specnav-route.js" --intent "continue implementation" --json >"$route_bootstrap_json" || route_bootstrap_status=$?
if [ "$route_bootstrap_status" -ne 0 ]; then
  echo "specnav-route missing openspec exited $route_bootstrap_status, expected 0" >&2
  cat "$route_bootstrap_json" >&2
  exit 1
fi
assert_jq '.ok == true' "$route_bootstrap_json" "specnav-route missing openspec did not report ok true"
assert_jq '.target_plugin == "specnav-core"' "$route_bootstrap_json" "specnav-route missing openspec did not target specnav-core"
assert_jq '.command == "/specnav-bootstrap"' "$route_bootstrap_json" "specnav-route missing openspec did not route to specnav-bootstrap"
assert_jq '.skill == "specnav-bootstrap"' "$route_bootstrap_json" "specnav-route missing openspec did not select specnav-bootstrap skill"
assert_jq '.affordance_state == "missing-openspec"' "$route_bootstrap_json" "specnav-route missing openspec did not expose missing-openspec state"
assert_jq '.no_fallback == true' "$route_bootstrap_json" "specnav-route did not mark no_fallback true"

route_foundation_json="$TMP_DIR/specnav-route-foundation.json"
route_foundation_status=0
PROJECT_DIR="$PROJECT" SPECNAV_MARKETPLACE_ROOT="$ROOT" node "$CORE/scripts/specnav-route.js" --intent "create complete project standards and foundation specs" --json >"$route_foundation_json" || route_foundation_status=$?
if [ "$route_foundation_status" -ne 2 ]; then
  echo "specnav-route foundation exited $route_foundation_status, expected 2" >&2
  cat "$route_foundation_json" >&2
  exit 1
fi
assert_jq '.target_plugin == "specnav-requirements"' "$route_foundation_json" "specnav-route foundation did not target specnav-requirements"
assert_jq '.command == "/specnav-requirements"' "$route_foundation_json" "specnav-route foundation did not route to specnav-requirements"
assert_jq '.skill == "specnav-foundation-specs"' "$route_foundation_json" "specnav-route foundation did not select specnav-foundation-specs"
assert_jq '.skills | index("specnav-repository-discovery")' "$route_foundation_json" "specnav-route foundation did not include repository discovery step"
assert_jq '.blockers | index("missing-foundation-spec:ui-design")' "$route_foundation_json" "specnav-route foundation did not report ui-design blocker"
assert_jq '.blockers | index("missing-foundation-spec:system-architecture")' "$route_foundation_json" "specnav-route foundation did not report system architecture blocker"

route_verify_json="$TMP_DIR/specnav-route-verify.json"
route_verify_status=0
PROJECT_DIR="$PROJECT" SPECNAV_MARKETPLACE_ROOT="$ROOT" node "$CORE/scripts/specnav-route.js" --intent "verify implementation" --json >"$route_verify_json" || route_verify_status=$?
if [ "$route_verify_status" -ne 0 ]; then
  echo "specnav-route verification exited $route_verify_status, expected 0" >&2
  cat "$route_verify_json" >&2
  exit 1
fi
assert_jq '.target_plugin == "specnav-verification"' "$route_verify_json" "specnav-route verification did not target specnav-verification"
assert_jq '.command == "/specnav-verify"' "$route_verify_json" "specnav-route verification did not route to specnav-verify"
assert_jq '.skill == "specnav-verify-plan"' "$route_verify_json" "specnav-route verification did not select specnav-verify-plan"
assert_jq '.required_plugins | index("specnav-verification")' "$route_verify_json" "specnav-route verification did not require specnav-verification"

bootstrap_project="$TMP_DIR/bootstrap-project"
cp -R "$NO_STATE_FIXTURE" "$bootstrap_project"
bootstrap_json="$TMP_DIR/specnav-bootstrap.json"
bootstrap_status=0
PROJECT_DIR="$bootstrap_project" node "$CORE/scripts/specnav-bootstrap.js" --json >"$bootstrap_json" || bootstrap_status=$?
if [ "$bootstrap_status" -ne 0 ]; then
  echo "specnav-bootstrap exited $bootstrap_status, expected 0" >&2
  cat "$bootstrap_json" >&2
  exit 1
fi
assert_jq '.ok == true' "$bootstrap_json" "specnav-bootstrap did not report ok true"
assert_jq '.status == "initialized"' "$bootstrap_json" "specnav-bootstrap did not report initialized"
assert_jq '.next_actions | index("/specnav-requirements")' "$bootstrap_json" "specnav-bootstrap did not report requirements next action"
test -d "$bootstrap_project/openspec"
test -f "$bootstrap_project/openspec/.specnav/workflow-state.json"

session_ready_json="$TMP_DIR/session-ready.json"
PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-session-start.js" >"$session_ready_json"
assert_jq '.status == "ready"' "$session_ready_json" "session start did not report ready for openspec project"
test -f "$PROJECT/openspec/.specnav/workflow-state.json"
test -s "$PROJECT/openspec/.specnav/context/requirements-context.jsonl"
test -s "$PROJECT/openspec/.specnav/context/prototype-context.jsonl"
test -s "$PROJECT/openspec/.specnav/context/implement-context.jsonl"
test -s "$PROJECT/openspec/.specnav/context/verify-context.jsonl"
test -s "$PROJECT/openspec/.specnav/context/ops-context.jsonl"
test -f "$PROJECT/openspec/.specnav/journal/index.md"

# Non-SpecNav project (no marker, no openspec) — session stays inactive, no routing noise
session_inactive_json="$TMP_DIR/session-inactive.json"
PROJECT_DIR="$NO_STATE" node "$CORE/scripts/specnav-session-start.js" >"$session_inactive_json" 2>"$TMP_DIR/session-inactive.err"
assert_jq '.status == "inactive"' "$session_inactive_json" "session start did not report inactive for non-SpecNav project"

# SpecNav project missing openspec (.specnav.json present) — session blocks and routes to bootstrap
session_specnav_broken="$TMP_DIR/session-specnav-broken"
mkdir -p "$session_specnav_broken"
printf '{"schema_version":1,"enabled":true}\n' >"$session_specnav_broken/.specnav.json"
session_blocked_json="$TMP_DIR/session-blocked.json"
PROJECT_DIR="$session_specnav_broken" node "$CORE/scripts/specnav-session-start.js" >"$session_blocked_json" 2>"$TMP_DIR/session-blocked.err"
assert_jq '.status == "blocked"' "$session_blocked_json" "SpecNav project without openspec did not block"
assert_jq '.blockers | index("missing-openspec")' "$session_blocked_json" "SpecNav project did not report missing-openspec"
assert_jq '.recommended_command == "/specnav-bootstrap"' "$session_blocked_json" "SpecNav project did not recommend specnav-bootstrap"
grep -Fq 'missing-openspec' "$TMP_DIR/session-blocked.err"

doctor_json="$TMP_DIR/specnav-doctor.json"
doctor_status=0
SPECNAV_PLUGIN_LIST_JSON="$(cat "$installed_inventory")" node "$CORE/scripts/specnav-doctor.js" --json >"$doctor_json" || doctor_status=$?
if [ "$doctor_status" -ne 0 ]; then
  echo "specnav-doctor exited $doctor_status, expected 0" >&2
  exit 1
fi
assert_jq '.ok == true' "$doctor_json" "specnav-doctor did not report ok true"
assert_jq '.suite.ok == true' "$doctor_json" "specnav-doctor did not include ok plugin suite"
assert_jq '.checks[] | select(.name == "plugin-suite" and .ok == true)' "$doctor_json" "specnav-doctor did not pass plugin-suite check"
assert_jq '.checks[] | select(.name == "openspec-cli" and .ok == true)' "$doctor_json" "specnav-doctor did not pass openspec-cli check"

project_doctor_json="$TMP_DIR/specnav-doctor-project.json"
SPECNAV_PLUGIN_LIST_JSON="$(cat "$installed_inventory")" PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-doctor.js" --json >"$project_doctor_json"
assert_jq '.ok == true' "$project_doctor_json" "specnav-doctor with project did not report ok true"
assert_jq '.checks[] | select(.name == "context-manifests" and .ok == true)' "$project_doctor_json" "specnav-doctor did not pass context-manifests check"
assert_jq '.checks[] | select(.name == "journal" and .ok == true)' "$project_doctor_json" "specnav-doctor did not pass journal check"

affordances_json="$TMP_DIR/specnav-core-affordances.json"
PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >"$affordances_json"
assert_jq '.active_change == "add-dark-mode"' "$affordances_json" "affordances did not report active_change add-dark-mode"

single_change_project="$TMP_DIR/single-change-project"
cp -R "$PROJECT_FIXTURE" "$single_change_project"
rm "$single_change_project/openspec/.specnav/active-change"
rm -f "$single_change_project/openspec/.specnav/workflow-state.json"
single_change_affordances_json="$TMP_DIR/single-change-affordances.json"
PROJECT_DIR="$single_change_project" node "$CORE/scripts/affordances.js" --json >"$single_change_affordances_json"
assert_jq '.active_change == "add-dark-mode"' "$single_change_affordances_json" "affordances did not infer the only change"

registry_focus_project="$TMP_DIR/registry-focus-project"
cp -R "$PROJECT_FIXTURE" "$registry_focus_project"
rm "$registry_focus_project/openspec/.specnav/active-change"
mkdir -p "$registry_focus_project/openspec/changes/another-change"
cat >"$registry_focus_project/openspec/.specnav/change-registry.json" <<'JSON'
{
  "schema_version": 1,
  "current_focus": "add-dark-mode",
  "changes": [
    {"id": "add-dark-mode", "stage": "development", "status": "active"},
    {"id": "another-change", "stage": "requirements", "status": "active"}
  ]
}
JSON
registry_focus_affordances_json="$TMP_DIR/registry-focus-affordances.json"
PROJECT_DIR="$registry_focus_project" node "$CORE/scripts/affordances.js" --json >"$registry_focus_affordances_json"
assert_jq '.active_change == "add-dark-mode"' "$registry_focus_affordances_json" "affordances did not read registry current_focus"
assert_jq '.change_resolution.source == "change-registry"' "$registry_focus_affordances_json" "affordances did not report change-registry source"

ambiguous_change_project="$TMP_DIR/ambiguous-change-project"
cp -R "$PROJECT_FIXTURE" "$ambiguous_change_project"
rm "$ambiguous_change_project/openspec/.specnav/active-change"
rm -f "$ambiguous_change_project/openspec/.specnav/workflow-state.json"
mkdir -p "$ambiguous_change_project/openspec/changes/another-change"
ambiguous_change_affordances_json="$TMP_DIR/ambiguous-change-affordances.json"
PROJECT_DIR="$ambiguous_change_project" node "$CORE/scripts/affordances.js" --json >"$ambiguous_change_affordances_json"
assert_jq '.active_change == null' "$ambiguous_change_affordances_json" "affordances inferred an ambiguous active change"
assert_jq '.state_source == "ambiguous"' "$ambiguous_change_affordances_json" "affordances did not report ambiguous for ambiguous changes"
assert_jq '.blockers | index("ambiguous-change")' "$ambiguous_change_affordances_json" "affordances did not report ambiguous-change blocker"

legacy_project="$TMP_DIR/legacy-entrypoint-project"
cp -R "$PROJECT_FIXTURE" "$legacy_project"
mkdir -p "$legacy_project/.claude/skills/openspec-propose" "$legacy_project/.claude/commands/opsx"
printf '%s\n' '---' 'name: openspec-propose' '---' >"$legacy_project/.claude/skills/openspec-propose/SKILL.md"
printf '%s\n' '---' 'name: "OPSX: Propose"' '---' >"$legacy_project/.claude/commands/opsx/propose.md"
legacy_affordances_json="$TMP_DIR/legacy-affordances.json"
PROJECT_DIR="$legacy_project" node "$CORE/scripts/affordances.js" --json >"$legacy_affordances_json"
assert_jq '.blockers | index("legacy-openspec-workflow")' "$legacy_affordances_json" "affordances did not block legacy OpenSpec workflow entrypoints"
assert_jq '.legacy_openspec_entrypoints[] | select(.name == "openspec-propose")' "$legacy_affordances_json" "affordances did not list legacy openspec-propose skill"
assert_jq '.legacy_openspec_entrypoints[] | select(.name == "opsx/propose")' "$legacy_affordances_json" "affordances did not list legacy opsx/propose command"

echo "specnav core runtime fixtures ok"
